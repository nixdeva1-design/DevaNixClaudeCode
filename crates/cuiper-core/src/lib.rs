//! cuiper-core — CuiperHive kern types
//!
//! Elke entiteit in het hive erft uit dit model:
//! nr, naam, karakter, archetype, rol, geschiedenis, functie, mandaat
//!
//! /dev/null verbod: geen panics zonder logging, geen silent failures.
//!
//! Ontwerp regel (Cuip stub):
//!   Elke betekenisvolle code-eenheid wordt gewrapped in een CuiperCuip.
//!   De Cuip bevat: ULID + unix timestamp + regelnr + omschrijving.
//!   Waarde vóór uitvoering = CAN (alle potentie aanwezig).
//!   Waarde na uitvoering   = Voltooid | Mislukt(reden).

pub mod bewaker;
pub mod cuip;
pub mod entiteit;
pub mod hive;
pub mod mandaat;
pub mod markov;

pub use bewaker::{CuiperBewaker, CuiperBewakeringsFout};
pub use cuip::{CuiperCuip, CuipWaarde};
pub use entiteit::{CuiperEntiteit, CuiperHiveNr};
pub use hive::CuiperHive;
pub use mandaat::CuiperMandaat;
pub use markov::{CuiperMarkovState, CuiperTransitie, CuiperUitkomst};
