/// cuip.rs — Cuip, de kleinste eenheid van CuiperHive
///
/// Cuip is de basisatoom. Hij wikkelt elke betekenisvolle operatie in
/// een intentie (vóór) + uitkomst (ná).
///
/// Elke Cuip heeft:
///   - ulid        : unieke identifier
///   - timestamp   : unix seconden
///   - regelnr     : broncode regel (via `line!()`)
///   - omschrijving: intentie in mensentaal
///   - hash        : deterministische fingerprint(ulid + regelnr + omschrijving)
///   - bewaakt     : Vec<CuiperRegel> — regels die deze Cuip bewaakt
///   - waarde      : CAN | Voltooid | Mislukt(reden) | Gesedimenteerd

use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use std::time::{SystemTime, UNIX_EPOCH};

// ─── CuipWaarde ──────────────────────────────────────────────────────────────

/// CAN = pure potentie. Ongelijk aan null. Ongelijk aan NaN.
#[derive(Debug, Clone, PartialEq)]
pub enum CuipWaarde {
    Can,
    Voltooid,
    Mislukt(String),
    Gesedimenteerd,
}

impl std::fmt::Display for CuipWaarde {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Can            => write!(f, "CAN"),
            Self::Voltooid       => write!(f, "VOLTOOID"),
            Self::Mislukt(r)    => write!(f, "MISLUKT: {r}"),
            Self::Gesedimenteerd => write!(f, "GESEDIMENTEERD"),
        }
    }
}

// ─── Hash hulpfuncties ───────────────────────────────────────────────────────

/// Deterministische u64 hash van een string (DefaultHasher — geen externe deps)
pub fn bereken_hash_str(input: &str) -> u64 {
    let mut h = DefaultHasher::new();
    input.hash(&mut h);
    h.finish()
}

/// Cuip-hash: fingerprint van (ulid + regelnr + omschrijving)
pub fn cuip_hash(ulid: &str, regelnr: u32, omschrijving: &str) -> u64 {
    let mut h = DefaultHasher::new();
    ulid.hash(&mut h);
    regelnr.hash(&mut h);
    omschrijving.hash(&mut h);
    h.finish()
}

// ─── CuiperRegel ─────────────────────────────────────────────────────────────

/// CuiperRegel — een voorwaarde of wet die een Cuip bewaakt
/// Elke regel heeft een deterministische hash zodat identieke regels
/// herkenbaar zijn over instanties heen.
#[derive(Debug, Clone, PartialEq)]
pub struct CuiperRegel {
    pub naam:         String,
    pub omschrijving: String,
    /// Deterministische fingerprint: hash(naam:omschrijving)
    pub hash:         u64,
}

impl CuiperRegel {
    pub fn nieuw(naam: impl Into<String>, omschrijving: impl Into<String>) -> Self {
        let naam = naam.into();
        let omschrijving = omschrijving.into();
        let hash = bereken_hash_str(&format!("{naam}:{omschrijving}"));
        Self { naam, omschrijving, hash }
    }

    pub fn hash_hex(&self) -> String {
        format!("{:016x}", self.hash)
    }
}

impl std::fmt::Display for CuiperRegel {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "[{}] {} — {}", self.hash_hex(), self.naam, self.omschrijving)
    }
}

// ─── Cuip — de kleinste eenheid ──────────────────────────────────────────────

/// Cuip — de kleinste eenheid van CuiperHive
///
/// # Gebruik
/// ```rust
/// use cuiper_core::Cuip;
/// use cuiper_core::cuip::CuiperRegel;
///
/// let cuip = Cuip::nieuw("01KN...".into(), line!(), "schrijf trail log")
///     .met_regel(CuiperRegel::nieuw("geen_devnull", "output gaat naar trail"));
/// let cuip = cuip.voltooi();
/// println!("{}", cuip.als_trail_regel());
/// ```
#[derive(Debug, Clone)]
pub struct Cuip {
    pub ulid:         String,
    pub timestamp:    u64,
    pub regelnr:      u32,
    pub omschrijving: String,
    /// Deterministische fingerprint: hash(ulid + regelnr + omschrijving)
    pub hash:         u64,
    /// Vector van regels die deze Cuip bewaakt en over waakt
    pub bewaakt:      Vec<CuiperRegel>,
    pub waarde:       CuipWaarde,
}

impl Cuip {
    /// Maak een nieuwe Cuip. Waarde = CAN. Hash wordt berekend.
    pub fn nieuw(ulid: String, regelnr: u32, omschrijving: impl Into<String>) -> Self {
        let omschrijving = omschrijving.into();
        let hash = cuip_hash(&ulid, regelnr, &omschrijving);
        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);
        Self { ulid, timestamp, regelnr, omschrijving, hash, bewaakt: Vec::new(), waarde: CuipWaarde::Can }
    }

    pub fn met_regel(mut self, r: CuiperRegel) -> Self {
        self.bewaakt.push(r);
        self
    }

    pub fn met_regels(mut self, rs: Vec<CuiperRegel>) -> Self {
        self.bewaakt.extend(rs);
        self
    }

    pub fn hash_hex(&self) -> String { format!("{:016x}", self.hash) }

    pub fn voltooi(mut self) -> Self       { self.waarde = CuipWaarde::Voltooid; self }
    pub fn mislukt(mut self, r: impl Into<String>) -> Self { self.waarde = CuipWaarde::Mislukt(r.into()); self }
    pub fn sedimenteer(mut self) -> Self   { self.waarde = CuipWaarde::Gesedimenteerd; self }

    pub fn is_can(&self)     -> bool { self.waarde == CuipWaarde::Can }
    pub fn is_voltooid(&self) -> bool { self.waarde == CuipWaarde::Voltooid }

    pub fn als_trail_regel(&self) -> String {
        let hashes: Vec<String> = self.bewaakt.iter().map(|r| r.hash_hex()).collect();
        let regels_str = if hashes.is_empty() { "—".into() } else { hashes.join(",") };
        format!(
            "Cuip | {} | {} | L:{} | hash:{} | regels:[{}] | {} | {}",
            self.ulid, self.timestamp, self.regelnr,
            self.hash_hex(), regels_str, self.omschrijving, self.waarde
        )
    }
}

/// CuiperCuip — alias voor Cuip (backwards compatibility)
pub type CuiperCuip = Cuip;

// ─── Macro ───────────────────────────────────────────────────────────────────

/// `cuip!(ulid, "omschrijving")` — Cuip met huidig regelnummer
/// `cuip!(ulid, "omschrijving", regel1, regel2)` — met bewaakte regels
#[macro_export]
macro_rules! cuip {
    ($ulid:expr, $omschrijving:expr) => {
        $crate::cuip::Cuip::nieuw($ulid, line!(), $omschrijving)
    };
    ($ulid:expr, $omschrijving:expr, $($r:expr),+) => {
        $crate::cuip::Cuip::nieuw($ulid, line!(), $omschrijving)
            $(.met_regel($r))+
    };
}
