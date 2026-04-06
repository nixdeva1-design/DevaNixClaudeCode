//! cuiper-datalog — Datalog inferentie engine in Rust
//!
//! Geen Java, geen Prolog interpreter als extern proces.
//! Forward-chaining semi-naïve evaluatie, volledig in Rust.
//!
//! Architectuur:
//!   CuiperFeit     — basisfeiten (grond atomen)
//!   CuiperRegel    — inferentie regels (hoofd :- lichaam)
//!   CuiperDatabank — opslag van feiten en regels
//!   CuiperMotor    — semi-naïve forward chaining evaluator

pub mod feit;
pub mod regel;
pub mod databank;
pub mod motor;

pub use feit::CuiperFeit;
pub use regel::CuiperRegel;
pub use databank::CuiperDatabank;
pub use motor::CuiperMotor;
#[cfg(test)]
mod tests;

use thiserror::Error;

#[derive(Debug, Error)]
pub enum CuiperDatalogFout {
    #[error("ongeldige term: {0}")]
    OngeldigeTerm(String),
    #[error("regel conflict: {0}")]
    RegelConflict(String),
    #[error("inferentie fout: {0}")]
    InferentieFout(String),
}
