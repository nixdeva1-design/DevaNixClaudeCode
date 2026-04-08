/// io_bus.rs — CuiperIOBus, CuiperIn, CuiperOut
///
/// Elke module (script, crate, NixOS service) heeft één CuiperIOBus:
///   CuiperIn  — agnostische inkomende bus: parameters, scope, namespace, stdin, wereld
///   CuiperOut — agnostische uitgaande bus: resultaten, stdout, trail, postgres, zenoh
///
/// De bus is polymorf agnostisch: CuiperWaarde draagt elk type.
/// Scope bepaalt isolatie: Lokaal / Globaal / Namespace(s) / Geïsoleerd (airgap)

use std::collections::BTreeMap;
use serde::{Deserialize, Serialize};
use crate::wereld::{CuiperParameters, CuiperVariabelen, CuiperWaarde, CuiperWereld};

// ─── CuiperScope ─────────────────────────────────────────────────────────────

/// Scope van een CuiperIOBus-verbinding
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum CuiperScope {
    /// Lokaal — variabelen leven alleen in deze executie
    Lokaal,
    /// Globaal — variabelen zichtbaar voor alle modules in dezelfde instantie
    Globaal,
    /// Namespace-geïsoleerd — bijv. "klant/acme", "lab/experiment1"
    Namespace(String),
    /// Volledig geïsoleerd — airgap, geen externe verbindingen toegestaan
    Geïsoleerd,
}

impl std::fmt::Display for CuiperScope {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Lokaal           => write!(f, "lokaal"),
            Self::Globaal          => write!(f, "globaal"),
            Self::Namespace(ns)   => write!(f, "namespace:{ns}"),
            Self::Geïsoleerd       => write!(f, "geïsoleerd"),
        }
    }
}

// ─── CuiperInType / CuiperOutType ────────────────────────────────────────────

/// Type van de inkomende bus
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum CuiperInType {
    Geen,
    Stdin,
    Args(Vec<String>),
    Bestand(String),
    Postgres,
    Zenoh { onderwerp: String },
    Trail,
    Git,
    Hook,        // aangeroepen als shell hook zonder directe input
    Intern,      // aanroep vanuit ander Cuiper component
}

/// Type van de uitgaande bus
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum CuiperOutType {
    Geen,
    Stdout,
    Stderr,
    Bestand(String),
    Postgres,
    Zenoh { onderwerp: String },
    Trail,
    Git,
    Intern,
}

// ─── CuiperIn ────────────────────────────────────────────────────────────────

/// CuiperIn — inkomende bus van een module
///
/// Draagt alle input: parameters, variabelen, omgeving, wereld-context.
/// Polymorf agnostisch: elke parameter is een CuiperWaarde.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CuiperIn {
    pub in_type:    CuiperInType,
    pub scope:      CuiperScope,
    pub namespace:  String,
    /// Geordende parameters (positieel + benoemd)
    pub parameters: CuiperParameters,
    /// Lokale variabelen voor deze executie
    pub variabelen: CuiperVariabelen,
    /// Volledige wereld-context (inclusief globale scope)
    pub wereld:     CuiperWereld,
    /// Ruwe stdin als tekst (indien CuiperInType::Stdin)
    pub stdin_buf:  Option<String>,
}

impl CuiperIn {
    pub fn nieuw(in_type: CuiperInType, scope: CuiperScope, namespace: impl Into<String>) -> Self {
        let ns = namespace.into();
        Self {
            in_type,
            scope: scope.clone(),
            namespace: ns.clone(),
            parameters: CuiperParameters::nieuw(),
            variabelen: CuiperVariabelen::nieuw(),
            wereld: CuiperWereld::nieuw(ns),
            stdin_buf: None,
        }
    }

    /// Bouwer: voeg parameter toe
    pub fn met_param(mut self, naam: impl Into<String>, waarde: CuiperWaarde) -> Self {
        self.parameters.voeg_toe(naam, waarde);
        self
    }

    /// Bouwer: zet variabele
    pub fn met_var(mut self, naam: impl Into<String>, waarde: CuiperWaarde) -> Self {
        self.variabelen.zet(naam, waarde);
        self
    }

    /// Bouwer: zet stdin buffer
    pub fn met_stdin(mut self, inhoud: impl Into<String>) -> Self {
        self.stdin_buf = Some(inhoud.into());
        self
    }

    /// Laad omgevingsvariabelen vanuit std::env in de wereld
    pub fn laad_omgeving(mut self) -> Self {
        self.wereld.laad_omgeving();
        self
    }

    /// Haal parameter op bij naam
    pub fn param(&self, naam: &str) -> Option<&CuiperWaarde> {
        self.parameters.haal(naam)
    }

    /// Haal parameter op bij positie
    pub fn param_pos(&self, index: usize) -> Option<&CuiperWaarde> {
        self.parameters.positie(index)
    }
}

// ─── CuiperOut ───────────────────────────────────────────────────────────────

/// CuiperOut — uitgaande bus van een module
///
/// Draagt alle output: resultaten, foutmeldingen, trail entries, stdout buffer.
/// Nooit /dev/null — elke output wordt gesedimenteerd.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CuiperOut {
    pub out_type:    CuiperOutType,
    pub scope:       CuiperScope,
    pub namespace:   String,
    /// Uitvoer variabelen die andere modules kunnen lezen
    pub variabelen:  CuiperVariabelen,
    /// Ruwe stdout buffer
    pub stdout_buf:  Vec<String>,
    /// Foutmeldingen — gesedimenteerd, nooit weggooien
    pub fouten:      Vec<String>,
    /// Trail entries voor logs/trail/
    pub trail_items: Vec<String>,
    /// Exit code (0 = succes)
    pub exit_code:   i32,
}

impl CuiperOut {
    pub fn nieuw(out_type: CuiperOutType, scope: CuiperScope, namespace: impl Into<String>) -> Self {
        Self {
            out_type,
            scope,
            namespace: namespace.into(),
            variabelen: CuiperVariabelen::nieuw(),
            stdout_buf: Vec::new(),
            fouten: Vec::new(),
            trail_items: Vec::new(),
            exit_code: 0,
        }
    }

    /// Schrijf naar stdout buffer
    pub fn schrijf(&mut self, regel: impl Into<String>) {
        self.stdout_buf.push(regel.into());
    }

    /// Registreer een fout — nooit weggooien (/dev/null verbod)
    pub fn fout(&mut self, bericht: impl Into<String>) {
        let b = bericht.into();
        self.fouten.push(b.clone());
        self.exit_code = 1;
    }

    /// Voeg trail entry toe
    pub fn trail(&mut self, entry: impl Into<String>) {
        self.trail_items.push(entry.into());
    }

    /// Zet uitvoer variabele
    pub fn zet(&mut self, naam: impl Into<String>, waarde: CuiperWaarde) {
        self.variabelen.zet(naam, waarde);
    }

    pub fn is_succes(&self) -> bool { self.exit_code == 0 && self.fouten.is_empty() }
    pub fn heeft_fouten(&self) -> bool { !self.fouten.is_empty() }
}

// ─── CuiperIOBus ─────────────────────────────────────────────────────────────

/// CuiperIOBus — gecombineerde In + Out bus voor één module-executie
///
/// Elke module (script/crate/service) instantieert één CuiperIOBus.
/// De bus bevat de volledige I/O context: parameters, scope, namespace,
/// stdin/stdout, CuiperWereld, CuiperVariabelen, CuiperParameters.
///
/// Polymorf agnostisch: alle waarden zijn CuiperWaarde.
/// Scope-isolatie: Lokaal / Globaal / Namespace / Geïsoleerd.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CuiperIOBus {
    /// Module naam (CuiperCamelCase)
    pub module_naam: String,
    /// Module versie
    pub versie:      String,
    /// Inkomende bus
    pub input:       CuiperIn,
    /// Uitgaande bus
    pub output:      CuiperOut,
    /// Gedeelde metadata voor trace/audit
    pub metadata:    BTreeMap<String, String>,
}

impl CuiperIOBus {
    /// Maak een nieuwe CuiperIOBus voor een module
    pub fn nieuw(
        module_naam: impl Into<String>,
        versie: impl Into<String>,
        in_type: CuiperInType,
        out_type: CuiperOutType,
        scope: CuiperScope,
        namespace: impl Into<String>,
    ) -> Self {
        let ns = namespace.into();
        Self {
            module_naam: module_naam.into(),
            versie: versie.into(),
            input: CuiperIn::nieuw(in_type, scope.clone(), ns.clone()),
            output: CuiperOut::nieuw(out_type, scope, ns),
            metadata: BTreeMap::new(),
        }
    }

    /// Stel een metadata tag in (bijv. ulid, stap_nr, sessie_nr)
    pub fn met_meta(mut self, sleutel: impl Into<String>, waarde: impl Into<String>) -> Self {
        self.metadata.insert(sleutel.into(), waarde.into());
        self
    }

    /// Laad omgevingsvariabelen in de input bus
    pub fn laad_omgeving(mut self) -> Self {
        self.input = self.input.laad_omgeving();
        self
    }

    /// Haal input parameter op
    pub fn param(&self, naam: &str) -> Option<&CuiperWaarde> {
        self.input.param(naam)
    }

    /// Schrijf naar stdout van de output bus
    pub fn schrijf(&mut self, regel: impl Into<String>) {
        self.output.schrijf(regel);
    }

    /// Registreer fout (nooit stil)
    pub fn fout(&mut self, bericht: impl Into<String>) {
        self.output.fout(bericht);
    }

    /// Voeg trail entry toe
    pub fn trail(&mut self, entry: impl Into<String>) {
        self.output.trail(entry);
    }

    pub fn is_succes(&self) -> bool { self.output.is_succes() }
}
