/// CuiperNamespace — geïsoleerde sleutel-expressie ruimte op de Zenoh bus
///
/// Elk klant-/lab-/airgap-/agi-namespace is strikt gescheiden.
/// Schrijven buiten eigen namespace = CuiperBusFout::NamespaceSchending
#[derive(Debug, Clone, PartialEq)]
pub enum CuiperNamespace {
    Klant(String),  // klant/<client-id>/**
    Lab(String),    // lab/<project>/**
    Airgap,         // airgap/** — geen externe verbinding
    Agi(String),    // agi/<experiment>/**
}

impl CuiperNamespace {
    /// Genereer de volledige Zenoh key-expression prefix
    pub fn prefix(&self) -> String {
        match self {
            Self::Klant(id)   => format!("klant/{}", id),
            Self::Lab(proj)   => format!("lab/{}", proj),
            Self::Airgap      => "airgap".into(),
            Self::Agi(exp)    => format!("agi/{}", exp),
        }
    }

    /// Controleer of een key-expression binnen deze namespace valt
    pub fn staat_toe(&self, key: &str) -> bool {
        key.starts_with(&self.prefix())
    }
}
