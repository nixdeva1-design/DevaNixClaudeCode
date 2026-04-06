/// CuiperNaamspaceBrug — expliciete brug tussen twee namespaces
///
/// Standaard mogen namespaces NIET met elkaar communiceren.
/// Een brug is een bewuste architectuurkeuze, altijd gedocumenteerd.
///
/// Voorbeeld: lab/projectA → klant/acme is alleen toegestaan
///   als er een brug is geconfigureerd met de juiste filters.
#[derive(Debug, Clone)]
pub struct CuiperNaamspaceBrug {
    pub ulid:      String,
    pub van:       String,   // namespace prefix
    pub naar:      String,   // namespace prefix
    pub filter:    BrugFilter,
    pub reden:     String,   // waarom bestaat deze brug
}

/// BrugFilter — welke signalen mogen de brug over
#[derive(Debug, Clone)]
pub enum BrugFilter {
    /// Alle signalen
    Alles,
    /// Alleen signalen waarvan de key dit patroon bevat
    Patroon(String),
    /// Geen enkel signaal (brug bestaat maar is gesloten)
    Geen,
}

impl CuiperNaamspaceBrug {
    pub fn nieuw(
        ulid: impl Into<String>,
        van: impl Into<String>,
        naar: impl Into<String>,
        filter: BrugFilter,
        reden: impl Into<String>,
    ) -> Self {
        Self {
            ulid:   ulid.into(),
            van:    van.into(),
            naar:   naar.into(),
            filter,
            reden:  reden.into(),
        }
    }

    /// Staat dit signaal toe via de brug?
    pub fn staat_toe(&self, key: &str) -> bool {
        match &self.filter {
            BrugFilter::Alles         => true,
            BrugFilter::Patroon(p)    => key.contains(p.as_str()),
            BrugFilter::Geen          => false,
        }
    }
}
