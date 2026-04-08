//! CuiperDonut — de erfenis-methode van CuiperCore
//!
//! Alle vaste waarden, normen, wetten en het geweten van het systeem.
//! Elk component dat van Cuiper erft, doet dit via CuiperDonut.
//!
//! De donut-topologie:
//!   - De hole = CAN (puur potentieel, nr=0, vóór uitvoering)
//!   - De ring = het corpus van wetten dat elke actie omringt
//!   - Van buiten naar binnen (CAN → Voltooid) gaat altijd door de ring.
//!   - Geen component kan de ring omzeilen zonder de wet te schenden.
//!
//! Hiërarchie:
//!   Cuiper → CuiperCore → CuiperDonut → [component] → [implementatie]

use crate::cuip::CuipWaarde;

// ─── Vaste waarden ────────────────────────────────────────────────────────────
// Onveranderlijk. Worden nooit overschreven — alleen uitgebreid via sedimentatie.

pub const CUIPER_WAARDEN: &[&str] = &[
    "wijsheid",
    "liefde",
    "wederkerigheid",
    "stewardship",
    "intellectuele integriteit",
    "efficiëntie boven emotie",
    "radicale logica",
    "onwrikbare focus",
    "controle van intentie",
    "eerste principes",
];

// ─── Normen ───────────────────────────────────────────────────────────────────
// Gedragsregels — beschrijven hoe gehandeld wordt, niet wat verboden is.

pub const CUIPER_NORMEN: &[&str] = &[
    "alles wordt gesedimenteerd — niets verdwijnt",
    "elke stap krijgt een ULID en wordt gelogd",
    "schrijven ≠ committen ≠ pushen ≠ vastleggen",
    "mislukking is eerste-principes materiaal",
    "data wordt geammendeerd, nooit verwijderd",
    "het systeem wordt sterker van elke fout",
];

// ─── Wetten ───────────────────────────────────────────────────────────────────
// Harde regels. Niet overtreedbaar. Detecteerbaar via CuiperDonut::geweten().

pub const CUIPER_WETTEN: &[&str] = &[
    "CuiperNaamgevingswet: alle namen beginnen met Cuiper in PascalCase",
    "erft_van wet: elke component erft via CuiperCore, nooit direct van Cuiper",
    "/dev/null verbod: geen output mag verdwijnen — alles is informatie",
    "sedimentatiewet: data wordt geammendeerd en gesedimenteerd, nooit gewist",
    "CuiperDonut wet: elke uitvoering passeert de ring — CAN → Voltooid|Mislukt",
    "Markov wet: A→B plannen, B→C uitvoeren, C≠B → rollback naar A",
];

// ─── CuiperDonut trait ────────────────────────────────────────────────────────
// De erfenis-vector. Elk component dat van Cuiper erft implementeert dit.

pub trait CuiperDonut {
    /// De naam van dit component — moet beginnen met "Cuiper" of "cuiper-".
    fn cuiper_naam(&self) -> &str;

    /// De ULID van dit component — uniek, onveranderlijk.
    fn cuiper_ulid(&self) -> &str;

    /// De vaste waarden van het systeem — geërfd, niet overschrijfbaar.
    fn waarden(&self) -> &'static [&'static str] {
        CUIPER_WAARDEN
    }

    /// De normen van het systeem — geërfd, niet overschrijfbaar.
    fn normen(&self) -> &'static [&'static str] {
        CUIPER_NORMEN
    }

    /// De wetten van het systeem — geërfd, niet overschrijfbaar.
    fn wetten(&self) -> &'static [&'static str] {
        CUIPER_WETTEN
    }

    /// Het geweten — toetst een actie aan de wetten vóór uitvoering.
    /// Retourneert Ok(()) als de actie de ring mag passeren.
    /// Retourneert Err(reden) als een wet geschonden wordt.
    ///
    /// Dit is de CAN-poort: vóór uitvoering controleert het geweten
    /// of de actie mag plaatsvinden. Zo niet → Mislukt, nooit stil.
    fn geweten(&self, actie: &str) -> Result<(), WetSchending> {
        // Wet 3: /dev/null verbod
        if actie.contains("/dev/null") {
            return Err(WetSchending {
                wet: CUIPER_WETTEN[2],
                actie: actie.to_string(),
                component: self.cuiper_naam().to_string(),
            });
        }

        // Wet 1: naamgevingswet — alleen controleerbaar voor bekende namen
        let naam = self.cuiper_naam();
        if !naam.starts_with("Cuiper") && !naam.starts_with("cuiper") {
            return Err(WetSchending {
                wet: CUIPER_WETTEN[0],
                actie: format!("component naam '{naam}' mist Cuiper prefix"),
                component: naam.to_string(),
            });
        }

        Ok(())
    }

    /// Voer een actie uit door de donut-ring.
    /// CAN → Voltooid als het geweten toestaat.
    /// CAN → Mislukt(reden) als een wet geschonden wordt.
    /// Nooit stil: het resultaat is altijd een CuipWaarde.
    fn passeer_ring(&self, actie: &str) -> CuipWaarde {
        match self.geweten(actie) {
            Ok(()) => CuipWaarde::Voltooid,
            Err(schending) => CuipWaarde::Mislukt(schending.to_string()),
        }
    }
}

// ─── WetSchending ─────────────────────────────────────────────────────────────
// Een wet is geschonden. Nooit stil weggooien — altijd propageren naar trail.

#[derive(Debug, Clone)]
pub struct WetSchending {
    pub wet:       &'static str,
    pub actie:     String,
    pub component: String,
}

impl std::fmt::Display for WetSchending {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "WetSchending[{}] in '{}': {}",
            self.component, self.actie, self.wet
        )
    }
}

impl std::error::Error for WetSchending {}
