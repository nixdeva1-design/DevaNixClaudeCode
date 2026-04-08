/// wereld.rs — CuiperWereld, CuiperWaarde, CuiperVariabelen, CuiperParameters
///
/// CuiperWaarde is het polymorf agnostisch type dat door de gehele CuiperIOBus
/// stroomt. Elke waarde kan elk type zijn — de bus is agnostisch.
///
/// Hiërarchie:
///   CuiperWereld       — globale context (namespace + variabelen + parameters)
///   CuiperVariabelen   — HashMap<String, CuiperWaarde> — benoemde waarden
///   CuiperParameters   — geordende Vec<(naam, CuiperWaarde)> — positie + naam
///   CuiperWaarde       — polymorf agnostisch: Nul | Bool | Int | Float | Tekst |
///                        Bytes | Lijst | Map | Dynamisch(JSON-string)

use std::collections::BTreeMap;
use serde::{Deserialize, Serialize};

// ─── CuiperWaarde ────────────────────────────────────────────────────────────

/// Polymorf agnostisch waarde type
///
/// `Dynamisch` houdt elk JSON-serialiseerbaar type als string.
/// Gebruik `Dynamisch` wanneer het type op compileer-tijd niet bekend is.
///
/// CuiperNul ≠ null, ≠ NaN — het is de CAN staat van een waarde:
///   potentie aanwezig, type nog niet bepaald.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum CuiperWaarde {
    /// CuiperNul — CAN, ongelijk aan null/NaN (zie Hive definitie: nr=0, Nul)
    Nul,
    Bool(bool),
    Int(i64),
    Float(f64),
    Tekst(String),
    Bytes(Vec<u8>),
    Lijst(Vec<CuiperWaarde>),
    /// Geordende map — BTreeMap voor determinisme
    Map(BTreeMap<String, CuiperWaarde>),
    /// Polymorf agnostisch: JSON-string voor elk onbekend of dynamisch type
    Dynamisch(String),
}

impl CuiperWaarde {
    pub fn is_nul(&self) -> bool { matches!(self, Self::Nul) }
    pub fn als_tekst(&self) -> Option<&str> {
        if let Self::Tekst(s) = self { Some(s) } else { None }
    }
    pub fn als_int(&self) -> Option<i64> {
        if let Self::Int(n) = self { Some(*n) } else { None }
    }
    pub fn als_bool(&self) -> Option<bool> {
        if let Self::Bool(b) = self { Some(*b) } else { None }
    }
    /// Serialiseer naar JSON-string (voor opslag/transport)
    pub fn als_json(&self) -> String {
        serde_json::to_string(self).unwrap_or_else(|e| format!("{{\"fout\":\"{e}\"}}"))
    }
    /// Deserializeer vanuit JSON-string
    pub fn van_json(s: &str) -> Result<Self, serde_json::Error> {
        serde_json::from_str(s)
    }
}

impl std::fmt::Display for CuiperWaarde {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Nul            => write!(f, "CuiperNul"),
            Self::Bool(b)        => write!(f, "{b}"),
            Self::Int(n)         => write!(f, "{n}"),
            Self::Float(v)       => write!(f, "{v}"),
            Self::Tekst(s)       => write!(f, "{s}"),
            Self::Bytes(b)       => write!(f, "<bytes:{}>", b.len()),
            Self::Lijst(l)       => write!(f, "[{}]", l.len()),
            Self::Map(m)         => write!(f, "{{{}}}", m.len()),
            Self::Dynamisch(s)   => write!(f, "~{s}"),
        }
    }
}

// ─── CuiperVariabelen ────────────────────────────────────────────────────────

/// CuiperVariabelen — benoemde waarden, polymorf agnostisch
/// Scope (lokaal/globaal/namespace) wordt bepaald door de CuiperIOBus
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CuiperVariabelen {
    inner: BTreeMap<String, CuiperWaarde>,
}

impl CuiperVariabelen {
    pub fn nieuw() -> Self { Self::default() }

    pub fn zet(&mut self, naam: impl Into<String>, waarde: CuiperWaarde) {
        self.inner.insert(naam.into(), waarde);
    }

    pub fn haal(&self, naam: &str) -> Option<&CuiperWaarde> {
        self.inner.get(naam)
    }

    /// Haal of geef standaardwaarde terug (nooit /dev/null — altijd een waarde)
    pub fn haal_of(&self, naam: &str, standaard: CuiperWaarde) -> CuiperWaarde {
        self.inner.get(naam).cloned().unwrap_or(standaard)
    }

    pub fn bevat(&self, naam: &str) -> bool { self.inner.contains_key(naam) }
    pub fn len(&self) -> usize { self.inner.len() }
    pub fn is_leeg(&self) -> bool { self.inner.is_empty() }

    pub fn namen(&self) -> Vec<&str> { self.inner.keys().map(|s| s.as_str()).collect() }

    /// Samenvoegen — bij conflict wint de andere (amendement-principe: niets weg)
    pub fn samenvoeg(&mut self, andere: CuiperVariabelen) {
        for (k, v) in andere.inner {
            self.inner.entry(k).or_insert(v);
        }
    }
}

// ─── CuiperParameters ────────────────────────────────────────────────────────

/// CuiperParameters — geordende lijst van (naam, waarde) paren
/// Polymorf agnostisch: elk type waarde toegestaan
/// Volgorde is significant (positieel + benoemd)
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CuiperParameters {
    params: Vec<(String, CuiperWaarde)>,
}

impl CuiperParameters {
    pub fn nieuw() -> Self { Self::default() }

    pub fn voeg_toe(&mut self, naam: impl Into<String>, waarde: CuiperWaarde) {
        self.params.push((naam.into(), waarde));
    }

    /// Bouwer interface: `.met("naam", waarde)`
    pub fn met(mut self, naam: impl Into<String>, waarde: CuiperWaarde) -> Self {
        self.params.push((naam.into(), waarde));
        self
    }

    pub fn haal(&self, naam: &str) -> Option<&CuiperWaarde> {
        self.params.iter().find(|(n, _)| n == naam).map(|(_, v)| v)
    }

    pub fn positie(&self, index: usize) -> Option<&CuiperWaarde> {
        self.params.get(index).map(|(_, v)| v)
    }

    pub fn len(&self) -> usize { self.params.len() }
    pub fn is_leeg(&self) -> bool { self.params.is_empty() }

    pub fn als_vec(&self) -> &Vec<(String, CuiperWaarde)> { &self.params }
}

// ─── CuiperWereld ────────────────────────────────────────────────────────────

/// CuiperWereld — globale context van één module-executie
///
/// De wereld bevat de volledige staat die een module ziet:
///   namespace    : isolatiedomein (klant/**, lab/**, airgap/**, agi/**)
///   variabelen   : alle bekende variabelen in scope
///   parameters   : de input parameters van deze executie
///   omgeving     : systeem-omgevingsvariabelen (key=val)
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CuiperWereld {
    pub namespace:   String,
    pub variabelen:  CuiperVariabelen,
    pub parameters:  CuiperParameters,
    pub omgeving:    BTreeMap<String, String>,
}

impl CuiperWereld {
    pub fn nieuw(namespace: impl Into<String>) -> Self {
        Self {
            namespace: namespace.into(),
            variabelen: CuiperVariabelen::nieuw(),
            parameters: CuiperParameters::nieuw(),
            omgeving: BTreeMap::new(),
        }
    }

    /// Laad omgevingsvariabelen vanuit `std::env`
    pub fn laad_omgeving(&mut self) {
        for (k, v) in std::env::vars() {
            self.omgeving.insert(k, v);
        }
    }

    /// Zet een variabele in de wereld
    pub fn zet(&mut self, naam: impl Into<String>, waarde: CuiperWaarde) {
        self.variabelen.zet(naam, waarde);
    }

    /// Haal een variabele op
    pub fn haal(&self, naam: &str) -> Option<&CuiperWaarde> {
        self.variabelen.haal(naam)
    }
}
