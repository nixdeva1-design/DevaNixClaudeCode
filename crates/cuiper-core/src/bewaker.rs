/// CuiperBewaker — runtime enforcer van de Cuiper3Markov garanties
///
/// De CuiperBewaker past de Cuiper3Markov toe op runtime niveau:
///   - Geen dubbele uitvoering (idempotency via ULID registry)
///   - Geen oneindige loops (max_iteraties verplicht)
///   - Geen corrupte datasets (validatie vóór gebruik)
///   - Geen timeouts zonder herstelplan (max_duur)
///
/// Elk beveiligd blok heeft een Cuip (CAN vóór, uitkomst ná).
/// De Bewaker beslist: doorgaan (C==B) of rollback (C!=B).
///
/// Naam: CuiperBewaker — niet CuiperWacht (wacht impliceert passief)
///   De Bewaker handelt actief: blokkeert, escaleert, sedimenteert.

use crate::cuip::CuiperCuip;
use crate::markov::{CuiperMarkovState, CuiperTransitie, CuiperUitkomst};
use std::collections::HashSet;
use std::time::{Duration, Instant};

/// Fout types die de CuiperBewaker kan rapporteren
#[derive(Debug, Clone)]
pub enum CuiperBewakeringsFout {
    /// Dezelfde ULID is al eerder uitgevoerd — dubbele uitvoering geblokkeerd
    DubbeleUitvoering(String),
    /// Operatie duurde langer dan max_duur
    TimeoutOverschreden { ulid: String, max: Duration, werkelijk: Duration },
    /// Loop overschreed max_iteraties zonder exit
    LoopZonderUitgang { ulid: String, iteraties: u32, max: u32 },
    /// Dataset validatie mislukt
    CorrupteDataset { ulid: String, reden: String },
    /// Markov C != B — rollback vereist
    MarkovMismatch { ulid: String, verwacht: String, werkelijk: String },
}

impl std::fmt::Display for CuiperBewakeringsFout {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::DubbeleUitvoering(id) =>
                write!(f, "BEWAKER: dubbele uitvoering geblokkeerd voor {id}"),
            Self::TimeoutOverschreden { ulid, max, werkelijk } =>
                write!(f, "BEWAKER: timeout {ulid} max={max:?} werkelijk={werkelijk:?}"),
            Self::LoopZonderUitgang { ulid, iteraties, max } =>
                write!(f, "BEWAKER: loop zonder uitgang {ulid} iteraties={iteraties} max={max}"),
            Self::CorrupteDataset { ulid, reden } =>
                write!(f, "BEWAKER: corrupte dataset {ulid}: {reden}"),
            Self::MarkovMismatch { ulid, verwacht, werkelijk } =>
                write!(f, "BEWAKER: Markov C!=B {ulid} verwacht={verwacht} werkelijk={werkelijk}"),
        }
    }
}

/// CuiperBewaker — de centrale bewaker instantie
pub struct CuiperBewaker {
    /// Registry van uitgevoerde ULIDs — voorkomt dubbele uitvoering
    uitgevoerd: HashSet<String>,
    /// Maximum duur per bewaakte operatie
    standaard_max_duur: Duration,
    /// Maximum iteraties per bewaakte loop
    standaard_max_iteraties: u32,
}

impl CuiperBewaker {
    pub fn nieuw() -> Self {
        Self {
            uitgevoerd:              HashSet::new(),
            standaard_max_duur:     Duration::from_secs(30),
            standaard_max_iteraties: 1_000,
        }
    }

    pub fn met_max_duur(mut self, duur: Duration) -> Self {
        self.standaard_max_duur = duur;
        self
    }

    pub fn met_max_iteraties(mut self, max: u32) -> Self {
        self.standaard_max_iteraties = max;
        self
    }

    /// Bewakend uitvoeren — één operatie, idempotent, met timeout
    ///
    /// De Cuip gaat van CAN naar Voltooid of Mislukt.
    /// De Bewaker logt de uitkomst en bepaalt de Markov transitie.
    pub fn bewaak<F, T>(
        &mut self,
        cuip: CuiperCuip,
        max_duur: Option<Duration>,
        operatie: F,
    ) -> Result<(T, CuiperCuip), CuiperBewakeringsFout>
    where
        F: FnOnce() -> Result<T, String>,
    {
        // Idempotency check
        if self.uitgevoerd.contains(&cuip.ulid) {
            return Err(CuiperBewakeringsFout::DubbeleUitvoering(cuip.ulid.clone()));
        }

        let max = max_duur.unwrap_or(self.standaard_max_duur);
        let start = Instant::now();

        // Voer uit
        let resultaat = operatie();
        let verstreken = start.elapsed();

        // Timeout check
        if verstreken > max {
            let cuip = cuip.mislukt(format!("timeout na {verstreken:?}"));
            return Err(CuiperBewakeringsFout::TimeoutOverschreden {
                ulid: cuip.ulid.clone(),
                max,
                werkelijk: verstreken,
            });
        }

        // Registreer als uitgevoerd (ook bij fout — voorkomt heruitvoering)
        self.uitgevoerd.insert(cuip.ulid.clone());

        match resultaat {
            Ok(waarde) => Ok((waarde, cuip.voltooi())),
            Err(reden) => {
                let cuip = cuip.mislukt(reden.clone());
                Err(CuiperBewakeringsFout::MarkovMismatch {
                    ulid:     cuip.ulid.clone(),
                    verwacht: "Voltooid".into(),
                    werkelijk: format!("Mislukt: {reden}"),
                })
            }
        }
    }

    /// Bewaakte loop — verplichte exit strategie
    ///
    /// De loop stopt bij:
    ///   - `predikaat` geeft true
    ///   - max_iteraties bereikt → CuiperBewakeringsFout::LoopZonderUitgang
    pub fn bewaak_loop<F>(
        &mut self,
        ulid: String,
        max_iteraties: Option<u32>,
        mut iteratie: F,
    ) -> Result<u32, CuiperBewakeringsFout>
    where
        F: FnMut(u32) -> bool, // geeft true als loop klaar is
    {
        let max = max_iteraties.unwrap_or(self.standaard_max_iteraties);
        let mut i = 0u32;

        loop {
            if i >= max {
                return Err(CuiperBewakeringsFout::LoopZonderUitgang {
                    ulid: ulid.clone(),
                    iteraties: i,
                    max,
                });
            }
            if iteratie(i) {
                return Ok(i);
            }
            i += 1;
        }
    }

    /// Dataset validatie vóór gebruik
    ///
    /// Elke validator functie geeft Ok(()) of Err(reden).
    /// Bij één fout: operatie geblokkeerd, reden gesedimenteerd.
    pub fn valideer_dataset<T>(
        &self,
        ulid: &str,
        data: &T,
        validators: &[fn(&T) -> Result<(), String>],
    ) -> Result<(), CuiperBewakeringsFout> {
        for validator in validators {
            if let Err(reden) = validator(data) {
                return Err(CuiperBewakeringsFout::CorrupteDataset {
                    ulid:  ulid.to_string(),
                    reden,
                });
            }
        }
        Ok(())
    }

    /// Markov transitie bepalen op basis van verwacht vs werkelijk
    pub fn markov_transitie(
        &self,
        staat_a: CuiperMarkovState,
        staat_b: CuiperMarkovState,
        staat_c: CuiperMarkovState,
    ) -> (CuiperUitkomst, CuiperTransitie) {
        let mut transitie = CuiperTransitie::nieuw(staat_a, staat_b);
        transitie.registreer_c(staat_c);
        let uitkomst = transitie.uitkomst();
        (uitkomst, transitie)
    }
}

impl Default for CuiperBewaker {
    fn default() -> Self {
        Self::nieuw()
    }
}
