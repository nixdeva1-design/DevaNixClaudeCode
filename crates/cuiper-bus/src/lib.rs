//! cuiper-bus — Zenoh signaalbus wrapper met namespace isolatie
//!
//! Namespaces: klant/**, lab/**, airgap/**, agi/**
//! Elke namespace is volledig geïsoleerd — geen cross-namespace lekkage.

pub mod namespace;
pub mod signaal;

pub use namespace::CuiperNamespace;
pub use signaal::CuiperSignaal;

use thiserror::Error;

#[derive(Debug, Error)]
pub enum CuiperBusFout {
    #[error("namespace schending: {0} mag niet in {1} schrijven")]
    NamespaceSchending(String, String),
    #[error("verbinding mislukt: {0}")]
    VerbindingMislukt(String),
    #[error("serialisatie fout: {0}")]
    SerialisatieFout(String),
}
