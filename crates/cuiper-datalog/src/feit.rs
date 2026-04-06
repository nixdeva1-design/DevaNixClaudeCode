/// CuiperTerm — een Datalog term: constante of variabele
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum CuiperTerm {
    Constante(String),
    Variabele(String), // begint met hoofdletter, conventie
}

impl CuiperTerm {
    pub fn constante(s: impl Into<String>) -> Self {
        Self::Constante(s.into())
    }
    pub fn variabele(s: impl Into<String>) -> Self {
        Self::Variabele(s.into())
    }
    pub fn is_grond(&self) -> bool {
        matches!(self, Self::Constante(_))
    }
}

/// CuiperFeit — een grond atoom: relatie(args...)
/// Voorbeeld: (CuiperEntiteit :naam "cuiper" :rol "architect")
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct CuiperFeit {
    pub relatie: String,
    pub args:    Vec<CuiperTerm>,
}

impl CuiperFeit {
    pub fn nieuw(relatie: impl Into<String>, args: Vec<CuiperTerm>) -> Self {
        Self { relatie: relatie.into(), args }
    }

    /// Controleer of dit een volledig grond feit is (geen variabelen)
    pub fn is_grond(&self) -> bool {
        self.args.iter().all(|t| t.is_grond())
    }
}
