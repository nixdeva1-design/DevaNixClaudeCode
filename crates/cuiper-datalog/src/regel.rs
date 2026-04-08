use crate::feit::CuiperFeit;

/// CuiperRegel — een Datalog regel
/// hoofd :- lichaam_1, lichaam_2, ...
///
/// Voorbeeld:
///   bereikbaar(X, Z) :- bereikbaar(X, Y), verbonden(Y, Z)
#[derive(Debug, Clone)]
pub struct CuiperRegel {
    pub hoofd:   CuiperFeit,
    pub lichaam: Vec<CuiperFeit>,
}

impl CuiperRegel {
    pub fn feit(hoofd: CuiperFeit) -> Self {
        Self { hoofd, lichaam: vec![] }
    }

    pub fn regel(hoofd: CuiperFeit, lichaam: Vec<CuiperFeit>) -> Self {
        Self { hoofd, lichaam }
    }

    /// Is dit een basisfeiten-declaratie (geen lichaam)?
    pub fn is_feit(&self) -> bool {
        self.lichaam.is_empty()
    }
}
