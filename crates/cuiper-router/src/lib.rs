//! cuiper-router — namespace-gebaseerde signaal routing engine
//!
//! De router beslist waar elk signaal naartoe gaat op basis van namespace.
//! Geen signaal verlaat zijn eigen namespace zonder expliciete brug.
//!
//! Namespaces:
//!   klant/<id>/**  → geïsoleerd per klant
//!   lab/<proj>/**  → geïsoleerd per project
//!   airgap/**      → GEEN externe verbinding toegestaan
//!   agi/<exp>/**   → ML/AI experimenten
//!
//! Signalen worden nooit geblokkeerd zonder logging.
//! /dev/null verbod: elke routing beslissing wordt gesedimenteerd.

pub mod router;
pub mod routeregel;
pub mod brug;
#[cfg(test)]
mod tests;

pub use router::CuiperRouter;
pub use routeregel::{CuiperRouteRegel, CuiperRouteActie};
pub use brug::CuiperNaamspaceBrug;

use thiserror::Error;

#[derive(Debug, Error)]
pub enum CuiperRouterFout {
    #[error("namespace schending: {afzender} mag niet schrijven naar {bestemming}")]
    NamespaceSchending { afzender: String, bestemming: String },
    #[error("airgap schending: {namespace} probeerde extern verkeer")]
    AirgapSchending { namespace: String },
    #[error("geen route voor {key}")]
    GeenRoute { key: String },
    #[error("brug niet geconfigureerd van {van} naar {naar}")]
    BrugOntbreekt { van: String, naar: String },
}
