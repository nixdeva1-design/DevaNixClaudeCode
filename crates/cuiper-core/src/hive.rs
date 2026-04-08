use crate::entiteit::{CuiperEntiteit, CuiperHiveNr};
use std::collections::HashMap;

/// CuiperHive — de verzameling van alle entiteiten
#[derive(Debug, Default)]
pub struct CuiperHive {
    entiteiten: HashMap<u64, CuiperEntiteit>,
}

impl CuiperHive {
    pub fn nieuw() -> Self {
        let mut hive = Self::default();

        // Vaste hive leden
        hive.registreer(CuiperEntiteit::nieuw(
            CuiperHiveNr::NUL,
            "Nul",
            "CAN, ongelijk aan null/NaN",
            "Nulpunt van het systeem",
        ));
        hive.registreer(CuiperEntiteit::nieuw(
            CuiperHiveNr::CUIPER,
            "Cuiper",
            "Architect, uitvinder",
            "Souverein, autonoom, anker, architect, developer, delimiter",
        ));
        hive.registreer(CuiperEntiteit::nieuw(
            CuiperHiveNr::DEVA,
            "Deva",
            "Login eigenaar",
            "Eigenaar van de runtime omgeving",
        ));
        hive.registreer(CuiperEntiteit::nieuw(
            CuiperHiveNr::CLAUDE_CLI,
            "ClaudeCode",
            "Uitvoerende LLM (CLI)",
            "Bouwen, vastleggen, sedimenteren",
        ));
        hive.registreer(CuiperEntiteit::nieuw(
            CuiperHiveNr::CLAUDE_WEB,
            "Claude.ai",
            "Uitvoerende LLM (web)",
            "Ontwerpen, redeneren, adviseren",
        ));

        hive
    }

    pub fn registreer(&mut self, entiteit: CuiperEntiteit) {
        self.entiteiten.insert(entiteit.nr.0, entiteit);
    }

    pub fn zoek(&self, nr: CuiperHiveNr) -> Option<&CuiperEntiteit> {
        self.entiteiten.get(&nr.0)
    }

    pub fn alle(&self) -> impl Iterator<Item = &CuiperEntiteit> {
        self.entiteiten.values()
    }
}
