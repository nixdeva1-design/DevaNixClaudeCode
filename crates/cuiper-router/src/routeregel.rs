/// CuiperRouteActie — wat de router doet met een signaal
#[derive(Debug, Clone, PartialEq)]
pub enum CuiperRouteActie {
    /// Doorsturen naar de bestemming
    Doorsturen(String),
    /// Blokkeren — namespace schending, reden gesedimenteerd
    Blokkeren(String),
    /// Loggen en doorsturen — voor audit
    LogEnDoorsturen(String),
    /// Brug nodig — signaal mag niet direct, vereist expliciete brug
    BrugVereist { van: String, naar: String },
}

/// CuiperRouteRegel — één routing beslissingsregel
///
/// Regels worden in volgorde geëvalueerd. Eerste match wint.
/// Geen match → signaal geblokkeerd met logging (geen /dev/null).
#[derive(Debug, Clone)]
pub struct CuiperRouteRegel {
    pub naam:      String,
    pub patroon:   String,    // key-expression prefix, bijv. "klant/acme/**"
    pub actie:     CuiperRouteActie,
    pub prioriteit: u32,      // lager = hogere prioriteit
}

impl CuiperRouteRegel {
    pub fn nieuw(
        naam: impl Into<String>,
        patroon: impl Into<String>,
        actie: CuiperRouteActie,
        prioriteit: u32,
    ) -> Self {
        Self {
            naam:      naam.into(),
            patroon:   patroon.into(),
            actie,
            prioriteit,
        }
    }

    /// Past dit patroon op de gegeven key?
    pub fn past_op(&self, key: &str) -> bool {
        let patroon = &self.patroon;
        if patroon.ends_with("/**") {
            let prefix = &patroon[..patroon.len() - 3];
            key.starts_with(prefix)
        } else if patroon.ends_with("/*") {
            // prefix = "klant/" (strip alleen de `*`)
            let prefix = &patroon[..patroon.len() - 1];
            key.starts_with(prefix) && !key[prefix.len()..].contains('/')
        } else {
            key == patroon
        }
    }
}
