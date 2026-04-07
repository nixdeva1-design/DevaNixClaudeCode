//! cuiper-core — CuiperHive kern types
//!
//! Elke entiteit in het hive erft uit dit model:
//! nr, naam, karakter, archetype, rol, geschiedenis, functie, mandaat
//!
//! /dev/null verbod: geen panics zonder logging, geen silent failures.
//!
//! Cuip — de kleinste eenheid:
//!   Elke betekenisvolle code-eenheid wordt gewrapped in een Cuip.
//!   Cuip bevat: ULID + timestamp + regelnr + omschrijving + hash + Vec<CuiperRegel>.
//!   hash       = deterministische fingerprint(ulid + regelnr + omschrijving)
//!   bewaakt    = vector van regels die deze Cuip bewaakt en over waakt
//!   waarde     = CAN (vóór) | Voltooid | Mislukt(reden) | Gesedimenteerd (ná)

pub mod bewaker;
pub mod cuip;
pub mod donut;
pub mod entiteit;
pub mod hive;
pub mod io_bus;
pub mod mandaat;
pub mod markov;
pub mod wereld;
pub mod zelfcontrole;
#[cfg(test)]
mod tests;

// Cuip — de kleinste eenheid (canonieke naam)
pub use cuip::{Cuip, CuiperCuip, CuipWaarde, CuiperRegel, bereken_hash_str, cuip_hash};

// CuiperIOBus — polymorf agnostisch I/O systeem
pub use io_bus::{
    CuiperIOBus, CuiperIn, CuiperOut,
    CuiperInType, CuiperOutType, CuiperScope,
};

// CuiperWereld — polymorf waarden + wereld context
pub use wereld::{
    CuiperWaarde, CuiperWereld,
    CuiperVariabelen, CuiperParameters,
};

// Bewaker, Donut, Entiteit, Hive, Mandaat, Markov, Zelfcontrole
pub use bewaker::{CuiperBewaker, CuiperBewakeringsFout};
pub use donut::{CuiperDonut, WetSchending, CUIPER_NORMEN, CUIPER_WAARDEN, CUIPER_WETTEN};
pub use entiteit::{CuiperEntiteit, CuiperHiveNr};
pub use hive::CuiperHive;
pub use mandaat::CuiperMandaat;
pub use markov::{CuiperMarkovState, CuiperTransitie, CuiperUitkomst};
pub use zelfcontrole::{
    CuiperZelfcontroleAI, CuiperContextSnapshot,
    CuiperContextStatus, ZelfcontrolesFout, MAX_RECURSIE_DIEPTE,
};
