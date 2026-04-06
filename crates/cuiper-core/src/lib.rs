//! cuiper-core — CuiperHive kern types
//!
//! Elke entiteit in het hive erft uit dit model:
//! nr, naam, karakter, archetype, rol, geschiedenis, functie, mandaat
//!
//! /dev/null verbod: geen panics zonder logging, geen silent failures.

pub mod entiteit;
pub mod hive;
pub mod mandaat;
pub mod markov;

pub use entiteit::{CuiperEntiteit, CuiperHiveNr};
pub use hive::CuiperHive;
pub use mandaat::CuiperMandaat;
pub use markov::{CuiperMarkovState, CuiperTransitie};
