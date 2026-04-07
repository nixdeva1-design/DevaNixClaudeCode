//! CuiperZelfcontroleAI — serieel context-bewustzijn
//!
//! Erft via: Cuiper → CuiperCore → CuiperDonut → CuiperZelfcontroleAI
//!
//! Huidige aanname: serieel von Neumann model.
//! De context wordt stap-voor-stap gelezen uit logs/context/ClaudeCodeContext.jsonl.
//! Elke stap is uniek geïdentificeerd door ULID + CuiperStapNr.
//!
//! CuiperStapNr aangemaakt: 45 — ULID: 01JWTFNKN5CONTEXT
//!
//! TOEKOMSTIGE UITVINDING (Cuiper=1, te groot voor stap 45):
//!   Het von Neumann bottleneck — serieel lezen van context is een beperking.
//!   Cuiper heeft een niet-serieel model in voorbereiding.
//!   Dit component is nu een STUB — het leest serieel, bereidt de interface voor.
//!   Zodra het niet-seriële model geformaliseerd is: interface ongewijzigd, implementatie vervangen.
//!
//! Recursie scope: Cuiper = Anker = Delimiter.
//!   Recursie is toegestaan maar begrensd. Max diepte via MAX_RECURSIE_DIEPTE.
//!   Cuiper=1 is de grens. Dieper dan Cuiper gaat niet — hij is het anker.

use crate::donut::CuiperDonut;
use crate::cuip::CuipWaarde;

/// Maximum recursie-diepte. Cuiper=1 is het anker — hier stopt de recursie.
pub const MAX_RECURSIE_DIEPTE: u32 = 10;

/// Snapshot van ClaudeCode's context op één CuiperStapNr.
/// Redundantie is toegestaan (data lake model) — elke stap is uniek via ULID + StapNr.
#[derive(Debug, Clone)]
pub struct CuiperContextSnapshot {
    pub ulid:           String,
    pub stap_nr:        u64,
    pub unix_ms:        u64,
    pub branch:         String,
    pub huidige_taak:   String,
    pub context_status: CuiperContextStatus,
    pub prompt_nr:      u32,
    pub recursie_diepte: u32,
    pub vorige_ulid:    Option<String>,    // keten terug naar vorige stap
}

/// Status van de context window op het moment van de dump.
#[derive(Debug, Clone, PartialEq)]
pub enum CuiperContextStatus {
    Ok,
    DrempelZacht,   // avg * 0.80 bereikt — waarschuw
    DrempelHard,    // avg * 0.95 bereikt — blokkeer
    Onbekend,
}

impl std::fmt::Display for CuiperContextStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Ok          => write!(f, "OK"),
            Self::DrempelZacht => write!(f, "DREMPEL_ZACHT"),
            Self::DrempelHard  => write!(f, "DREMPEL_HARD"),
            Self::Onbekend    => write!(f, "ONBEKEND"),
        }
    }
}

/// CuiperZelfcontroleAI — weet waar het systeem staat in een proces.
///
/// Leest context-dumps serieel (von Neumann model).
/// Elke aanroep van `waar_ben_ik()` leest de meest recente snapshot.
/// Bij recursie: `recursie_diepte` teller voorkomt oneindige lussen.
/// Cuiper=Anker: zodra diepte > MAX_RECURSIE_DIEPTE stopt de expansie.
pub struct CuiperZelfcontroleAI {
    naam:            String,
    ulid:            String,
    context_jsonl:   String,   // pad naar ClaudeCodeContext.jsonl
    recursie_diepte: u32,
}

impl CuiperDonut for CuiperZelfcontroleAI {
    fn cuiper_naam(&self) -> &str { &self.naam }
    fn cuiper_ulid(&self) -> &str { &self.ulid }
}

impl CuiperZelfcontroleAI {
    pub fn nieuw(context_jsonl: impl Into<String>) -> Self {
        Self {
            naam:            "CuiperZelfcontroleAI".into(),
            ulid:            "01COMP025ZELFCTR000000".into(),
            context_jsonl:   context_jsonl.into(),
            recursie_diepte: 0,
        }
    }

    /// Lees de meest recente context snapshot (serieel, laatste regel van JSONL).
    /// Von Neumann model: één regel tegelijk verwerkt.
    pub fn waar_ben_ik(&self) -> Result<CuiperContextSnapshot, ZelfcontrolesFout> {
        // Controleer passeer_ring voordat context gelezen wordt
        match self.passeer_ring("lees context") {
            CuipWaarde::Mislukt(reden) => return Err(ZelfcontrolesFout::WetSchending(reden)),
            _ => {}
        }

        let inhoud = std::fs::read_to_string(&self.context_jsonl)
            .map_err(|e| ZelfcontrolesFout::LezenMislukt(e.to_string()))?;

        let laatste = inhoud.lines()
            .filter(|r| !r.trim().is_empty())
            .last()
            .ok_or(ZelfcontrolesFout::GeenContext)?;

        self.parseer_snapshot(laatste)
    }

    /// Parseer een JSON-regel naar een CuiperContextSnapshot.
    /// Serieel: één snapshot per aanroep — von Neumann bottleneck.
    fn parseer_snapshot(&self, json: &str) -> Result<CuiperContextSnapshot, ZelfcontrolesFout> {
        // Minimale JSON parser zonder externe dependency
        let haal_veld = |sleutel: &str| -> String {
            let zoek = format!("\"{}\":\"", sleutel);
            if let Some(start) = json.find(&zoek) {
                let rest = &json[start + zoek.len()..];
                if let Some(eind) = rest.find('"') {
                    return rest[..eind].to_string();
                }
            }
            String::new()
        };

        let haal_getal = |sleutel: &str| -> u64 {
            let zoek = format!("\"{}\":", sleutel);
            if let Some(start) = json.find(&zoek) {
                let rest = &json[start + zoek.len()..];
                let eind = rest.find(|c: char| !c.is_ascii_digit()).unwrap_or(rest.len());
                rest[..eind].parse().unwrap_or(0)
            } else {
                0
            }
        };

        let status = match haal_veld("context_status").as_str() {
            "OK"            => CuiperContextStatus::Ok,
            "DREMPEL_ZACHT" => CuiperContextStatus::DrempelZacht,
            "DREMPEL_HARD"  => CuiperContextStatus::DrempelHard,
            _               => CuiperContextStatus::Onbekend,
        };

        let vorige = {
            let v = haal_veld("vorige_stap_ulid");
            if v.is_empty() || v == "null" { None } else { Some(v) }
        };

        Ok(CuiperContextSnapshot {
            ulid:            haal_veld("ulid"),
            stap_nr:         haal_getal("cuiper_stap_nr"),
            unix_ms:         haal_getal("unix_ms"),
            branch:          haal_veld("branch"),
            huidige_taak:    haal_veld("huidige_taak"),
            context_status:  status,
            prompt_nr:       haal_getal("prompt_nr") as u32,
            recursie_diepte: self.recursie_diepte,
            vorige_ulid:     vorige,
        })
    }

    /// Controleer of de recursie binnen de scope van Cuiper=Anker valt.
    /// Cuiper=1 is de delimiter — hij begrenst de recursie-diepte.
    pub fn binnen_recursie_scope(&self) -> bool {
        self.recursie_diepte < MAX_RECURSIE_DIEPTE
    }

    /// Verhoog recursie-diepte. Retourneert Err als Cuiper=Anker bereikt is.
    pub fn verdiep_recursie(&self) -> Result<Self, ZelfcontrolesFout> {
        if self.recursie_diepte >= MAX_RECURSIE_DIEPTE {
            return Err(ZelfcontrolesFout::RecursieScopeOverschreden {
                diepte: self.recursie_diepte,
                max:    MAX_RECURSIE_DIEPTE,
                anker:  "Cuiper=1".into(),
            });
        }
        Ok(Self {
            recursie_diepte: self.recursie_diepte + 1,
            ..self.clone()
        })
    }
}

impl Clone for CuiperZelfcontroleAI {
    fn clone(&self) -> Self {
        Self {
            naam:            self.naam.clone(),
            ulid:            self.ulid.clone(),
            context_jsonl:   self.context_jsonl.clone(),
            recursie_diepte: self.recursie_diepte,
        }
    }
}

/// Fouten van CuiperZelfcontroleAI.
#[derive(Debug)]
pub enum ZelfcontrolesFout {
    LezenMislukt(String),
    GeenContext,
    WetSchending(String),
    RecursieScopeOverschreden { diepte: u32, max: u32, anker: String },
}

impl std::fmt::Display for ZelfcontrolesFout {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::LezenMislukt(e) =>
                write!(f, "Context lezen mislukt: {e}"),
            Self::GeenContext =>
                write!(f, "Geen context beschikbaar — nog geen dump geschreven"),
            Self::WetSchending(r) =>
                write!(f, "CuiperDonut wet geschonden: {r}"),
            Self::RecursieScopeOverschreden { diepte, max, anker } =>
                write!(f, "Recursie scope overschreden: diepte={diepte} max={max} anker={anker}"),
        }
    }
}

impl std::error::Error for ZelfcontrolesFout {}
