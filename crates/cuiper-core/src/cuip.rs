/// CuiperCuip — de ontwerpeenheid om elke coderegel
///
/// De Cuip is een wrapper die om elke betekenisvolle code-eenheid wordt geschreven.
/// Hij declareert de intentie VÓÓR uitvoering, en registreert de uitkomst NA uitvoering.
///
/// Vóór uitvoering: waarde = CAN (alle potentie is aanwezig)
/// Na uitvoering:   waarde = Voltooid | Mislukt(reden) | Gesedimenteerd
///
/// Het regelnummer IN de Cuip is zelf een CAN waarde:
///   het is de positie in de code waar potentie bestaat.
///   Na uitvoering weten we of die potentie gerealiseerd werd.
///
/// Gebruik in Rust:
///   let cuip = CuiperCuip::nieuw(ulid, line!(), "lees entiteit uit databank");
///   let result = db.zoek(id);
///   let cuip = cuip.voltooi(result.is_ok(), "entiteit gelezen");
///
/// Gebruik in shell (via CuiperListener.sh):
///   CUIP=$(cuip_nieuw "git push naar remote" 42)
///   bash CuiperListener.sh --exec "git push" --naam "git-push" --stap $STAP
///   # CuiperListener registreert automatisch de uitkomst

use std::time::{SystemTime, UNIX_EPOCH};

/// CAN = pure potentie. Ongelijk aan null. Ongelijk aan NaN.
/// Een Cuip met waarde CAN bestaat — maar is nog niet uitgevoerd.
#[derive(Debug, Clone, PartialEq)]
pub enum CuipWaarde {
    /// Potentie aanwezig. Vóór uitvoering.
    Can,
    /// Succesvol uitgevoerd. Potentie gerealiseerd.
    Voltooid,
    /// Uitvoering mislukt. Reden gesedimenteerd, nooit /dev/null.
    Mislukt(String),
    /// Opgeslagen als historisch feit in de trail.
    Gesedimenteerd,
}

impl std::fmt::Display for CuipWaarde {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Can             => write!(f, "CAN"),
            Self::Voltooid        => write!(f, "VOLTOOID"),
            Self::Mislukt(reden) => write!(f, "MISLUKT: {reden}"),
            Self::Gesedimenteerd  => write!(f, "GESEDIMENTEERD"),
        }
    }
}

/// CuiperCuip — ontwerpeenheid met ULID, timestamp, regelnr, intentie
#[derive(Debug, Clone)]
pub struct CuiperCuip {
    pub ulid:         String,
    pub timestamp:    u64,
    pub regelnr:      u32,
    pub omschrijving: String,
    pub waarde:       CuipWaarde,
}

impl CuiperCuip {
    /// Maak een nieuwe Cuip aan. Waarde begint als CAN.
    ///
    /// # Voorbeeld
    /// ```rust
    /// use cuiper_core::CuiperCuip;
    /// let cuip = CuiperCuip::nieuw("01KN...".into(), line!(), "query database");
    /// ```
    pub fn nieuw(ulid: String, regelnr: u32, omschrijving: impl Into<String>) -> Self {
        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);

        Self {
            ulid,
            timestamp,
            regelnr,
            omschrijving: omschrijving.into(),
            waarde: CuipWaarde::Can,
        }
    }

    /// Voltooi de Cuip na succesvolle uitvoering. CAN → Voltooid.
    pub fn voltooi(mut self) -> Self {
        self.waarde = CuipWaarde::Voltooid;
        self
    }

    /// Markeer als mislukt. CAN → Mislukt(reden). Reden nooit weggooien.
    pub fn mislukt(mut self, reden: impl Into<String>) -> Self {
        self.waarde = CuipWaarde::Mislukt(reden.into());
        self
    }

    /// Sedimenteer: sla op als historisch feit.
    pub fn sedimenteer(mut self) -> Self {
        self.waarde = CuipWaarde::Gesedimenteerd;
        self
    }

    /// Is de Cuip nog in de CAN staat?
    pub fn is_can(&self) -> bool {
        self.waarde == CuipWaarde::Can
    }

    /// Is de Cuip succesvol afgerond?
    pub fn is_voltooid(&self) -> bool {
        self.waarde == CuipWaarde::Voltooid
    }

    /// Trail-formaat voor logging
    pub fn als_trail_regel(&self) -> String {
        format!(
            "Cuip | {} | {} | L:{} | {} | {}",
            self.ulid, self.timestamp, self.regelnr,
            self.omschrijving, self.waarde
        )
    }
}

/// Macro om een Cuip aan te maken met het huidige regelnummer
/// Vereist: een ULID string als eerste argument
///
/// Gebruik: `cuip!(mijn_ulid, "beschrijving van volgende regel")`
#[macro_export]
macro_rules! cuip {
    ($ulid:expr, $omschrijving:expr) => {
        $crate::cuip::CuiperCuip::nieuw($ulid, line!(), $omschrijving)
    };
}
