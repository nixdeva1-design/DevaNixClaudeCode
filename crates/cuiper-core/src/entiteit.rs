use serde::{Deserialize, Serialize};

/// CuiperHiveNr — unieke identificatie per entiteit in de hive
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct CuiperHiveNr(pub u64);

impl CuiperHiveNr {
    pub const NUL:        Self = Self(0); // CAN, ongelijk aan null/NaN
    pub const CUIPER:     Self = Self(1); // Architect, uitvinder
    pub const DEVA:       Self = Self(2); // Login eigenaar
    pub const CLAUDE_CLI: Self = Self(3); // Uitvoerende LLM (CLI)
    pub const CLAUDE_WEB: Self = Self(4); // Uitvoerende LLM (web)
}

/// CuiperEntiteit — elke deelnemer in het hive systeem
/// Mens, dier, plant, machine, mineraal — alles heeft een entiteit.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CuiperEntiteit {
    pub nr:         CuiperHiveNr,
    pub naam:       String,
    pub karakter:   String,
    pub archetype:  String,
    pub rol:        String,
    pub geschiedenis: Vec<String>,
    pub functie:    String,
    pub mandaat:    String,
}

impl CuiperEntiteit {
    pub fn nieuw(
        nr: CuiperHiveNr,
        naam: impl Into<String>,
        rol: impl Into<String>,
        mandaat: impl Into<String>,
    ) -> Self {
        Self {
            nr,
            naam: naam.into(),
            karakter: String::new(),
            archetype: String::new(),
            rol: rol.into(),
            geschiedenis: Vec::new(),
            functie: String::new(),
            mandaat: mandaat.into(),
        }
    }

    /// Sedimenteer een historisch feit — nooit verwijderen
    pub fn sedimenteer(&mut self, feit: impl Into<String>) {
        self.geschiedenis.push(feit.into());
    }
}
