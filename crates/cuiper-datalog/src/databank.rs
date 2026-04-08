use crate::feit::CuiperFeit;
use crate::regel::CuiperRegel;
use std::collections::HashSet;

/// CuiperDatabank — opslag van feiten en regels
/// /dev/null verbod: feiten worden nooit verwijderd, alleen gesedimenteerd
#[derive(Debug, Default)]
pub struct CuiperDatabank {
    pub feiten: HashSet<CuiperFeit>,
    pub regels: Vec<CuiperRegel>,
}

impl CuiperDatabank {
    pub fn nieuw() -> Self {
        Self::default()
    }

    /// Voeg een feit toe — idempotent, geen duplicaten
    pub fn voeg_feit_toe(&mut self, feit: CuiperFeit) -> bool {
        assert!(feit.is_grond(), "alleen grond feiten in de databank");
        self.feiten.insert(feit)
    }

    /// Voeg een regel toe
    pub fn voeg_regel_toe(&mut self, regel: CuiperRegel) {
        self.regels.push(regel);
    }

    /// Bevat de databank dit feit?
    pub fn bevat(&self, feit: &CuiperFeit) -> bool {
        self.feiten.contains(feit)
    }

    pub fn aantal_feiten(&self) -> usize {
        self.feiten.len()
    }
}
