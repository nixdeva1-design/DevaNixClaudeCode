/// Cuiper3MarkovchainProtocol — drie staten, strikte transitieregels
///
/// A → B  (plannen)
/// B → C  (uitvoeren)
/// C == B → succes, ga naar A+1
/// C != B → rollback naar A

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CuiperMarkovState {
    pub versie:   u64,
    pub beschrijving: String,
    pub commit:   Option<String>,
}

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CuiperTransitie {
    pub staat_a: CuiperMarkovState, // huidige stabiele staat
    pub staat_b: CuiperMarkovState, // verwachte staat na wijziging
    pub staat_c: Option<CuiperMarkovState>, // werkelijke staat na uitvoering
}

impl CuiperTransitie {
    pub fn nieuw(a: CuiperMarkovState, b: CuiperMarkovState) -> Self {
        Self { staat_a: a, staat_b: b, staat_c: None }
    }

    /// Registreer de werkelijke uitkomst (staat C)
    pub fn registreer_c(&mut self, c: CuiperMarkovState) {
        self.staat_c = Some(c);
    }

    /// Bepaal de uitkomst: succes of rollback vereist
    pub fn uitkomst(&self) -> CuiperUitkomst {
        match &self.staat_c {
            None => CuiperUitkomst::Pending,
            Some(c) if c == &self.staat_b => CuiperUitkomst::Succes,
            Some(_) => CuiperUitkomst::RollbackNaarA,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub enum CuiperUitkomst {
    Pending,
    Succes,
    RollbackNaarA,
}
