use crate::brug::CuiperNaamspaceBrug;
use crate::routeregel::{CuiperRouteActie, CuiperRouteRegel};
use crate::CuiperRouterFout;
use cuiper_bus::signaal::CuiperSignaal;

/// CuiperRouter — de centrale routing instantie
///
/// Gebruik:
///   let router = CuiperRouter::nieuw()
///       .met_standaard_regels();
///   let beslissing = router.route(&signaal)?;
pub struct CuiperRouter {
    regels:  Vec<CuiperRouteRegel>,    // gesorteerd op prioriteit
    bruggen: Vec<CuiperNaamspaceBrug>,
    /// Routing log: key → [beslissing, ...] — nooit weggooien
    log:     Vec<CuiperRoutingLog>,
}

/// CuiperRoutingLog — elke routing beslissing wordt gesedimenteerd
#[derive(Debug, Clone)]
pub struct CuiperRoutingLog {
    pub timestamp:  u64,
    pub signaal_key: String,
    pub afzender:   String,
    pub actie:      String,   // beschrijving van de beslissing
}

impl CuiperRouter {
    pub fn nieuw() -> Self {
        Self {
            regels:  Vec::new(),
            bruggen: Vec::new(),
            log:     Vec::new(),
        }
    }

    /// Laad standaard regels: airgap isolatie + namespace zelf-isolatie
    pub fn met_standaard_regels(mut self) -> Self {
        // Airgap: NOOIT extern verkeer
        self.voeg_regel_toe(CuiperRouteRegel::nieuw(
            "airgap-isolatie",
            "airgap/**",
            CuiperRouteActie::LogEnDoorsturen("airgap/**".into()),
            0, // hoogste prioriteit
        ));

        // Klant namespaces: intern doorsturen
        self.voeg_regel_toe(CuiperRouteRegel::nieuw(
            "klant-isolatie",
            "klant/**",
            CuiperRouteActie::Doorsturen("klant/**".into()),
            10,
        ));

        // Lab namespaces
        self.voeg_regel_toe(CuiperRouteRegel::nieuw(
            "lab-isolatie",
            "lab/**",
            CuiperRouteActie::Doorsturen("lab/**".into()),
            10,
        ));

        // AGI namespaces
        self.voeg_regel_toe(CuiperRouteRegel::nieuw(
            "agi-isolatie",
            "agi/**",
            CuiperRouteActie::Doorsturen("agi/**".into()),
            10,
        ));

        self
    }

    pub fn voeg_regel_toe(&mut self, regel: CuiperRouteRegel) {
        self.regels.push(regel);
        self.regels.sort_by_key(|r| r.prioriteit);
    }

    pub fn voeg_brug_toe(&mut self, brug: CuiperNaamspaceBrug) {
        self.bruggen.push(brug);
    }

    /// Bepaal de routing voor een signaal
    ///
    /// Elke beslissing wordt gelogd — geen /dev/null.
    pub fn route(
        &mut self,
        signaal: &CuiperSignaal,
    ) -> Result<CuiperRouteActie, CuiperRouterFout> {
        let key = &signaal.key;

        // Airgap check: airgap mag nooit extern verkeer ontvangen van buiten airgap
        if !key.starts_with("airgap/") && self.is_airgap_afzender(&signaal.afzender) {
            self.log_beslissing(signaal, "AIRGAP_SCHENDING geblokkeerd");
            return Err(CuiperRouterFout::AirgapSchending {
                namespace: signaal.afzender.clone(),
            });
        }

        // Namespace cross-check: afzender mag alleen schrijven in eigen namespace
        if let Err(fout) = self.check_namespace_isolatie(signaal) {
            self.log_beslissing(signaal, &format!("NAMESPACE_SCHENDING: {fout}"));
            return Err(fout);
        }

        // Eerste passende regel
        let gevonden = self.regels.iter().find(|r| r.past_op(key)).map(|r| {
            (r.naam.clone(), r.actie.clone())
        });
        if let Some((naam, actie)) = gevonden {
            self.log_beslissing(signaal, &format!("REGEL:{naam} → {actie:?}"));
            return Ok(actie);
        }

        // Geen regel gevonden
        self.log_beslissing(signaal, "GEEN_ROUTE geblokkeerd");
        Err(CuiperRouterFout::GeenRoute { key: key.clone() })
    }

    fn is_airgap_afzender(&self, afzender: &str) -> bool {
        afzender.starts_with("airgap/")
    }

    fn check_namespace_isolatie(&self, signaal: &CuiperSignaal) -> Result<(), CuiperRouterFout> {
        let afzender_ns = Self::namespace_van(&signaal.afzender);
        let bestemming_ns = Self::namespace_van(&signaal.key);

        if afzender_ns == bestemming_ns {
            return Ok(());
        }

        // Controleer of er een brug is
        for brug in &self.bruggen {
            if signaal.afzender.starts_with(&brug.van)
                && signaal.key.starts_with(&brug.naar)
                && brug.staat_toe(&signaal.key)
            {
                return Ok(());
            }
        }

        Err(CuiperRouterFout::NamespaceSchending {
            afzender:    signaal.afzender.clone(),
            bestemming:  signaal.key.clone(),
        })
    }

    fn namespace_van(key: &str) -> &str {
        key.splitn(3, '/').next().unwrap_or(key)
    }

    fn log_beslissing(&mut self, signaal: &CuiperSignaal, actie: &str) {
        self.log.push(CuiperRoutingLog {
            timestamp:   signaal.timestamp,
            signaal_key: signaal.key.clone(),
            afzender:    signaal.afzender.clone(),
            actie:       actie.to_string(),
        });
    }

    pub fn routing_log(&self) -> &[CuiperRoutingLog] {
        &self.log
    }
}
