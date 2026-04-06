use crate::databank::CuiperDatabank;
use crate::feit::{CuiperFeit, CuiperTerm};
use std::collections::HashMap;

type Binding = HashMap<String, CuiperTerm>;

/// CuiperMotor — semi-naïve forward chaining Datalog evaluator
///
/// Semi-naïef: per iteratie worden alleen regels heruitgevoerd
/// waarvan minstens één lichaam-feit nieuw is in de vorige iteratie.
/// Dit voorkomt redundante herberekening.
#[derive(Debug)]
pub struct CuiperMotor;

impl CuiperMotor {
    /// Voer alle regels uit totdat geen nieuwe feiten meer worden afgeleid.
    /// Geeft het aantal nieuw afgeleide feiten terug.
    pub fn evalueer(db: &mut CuiperDatabank) -> usize {
        let mut totaal_nieuw = 0;
        loop {
            let nieuw = Self::iteratie(db);
            if nieuw == 0 {
                break;
            }
            totaal_nieuw += nieuw;
        }
        totaal_nieuw
    }

    fn iteratie(db: &mut CuiperDatabank) -> usize {
        let mut nieuwe_feiten: Vec<CuiperFeit> = Vec::new();
        let regels = db.regels.clone();

        for regel in &regels {
            if regel.is_feit() {
                continue;
            }
            // Probeer het lichaam te matchen op de huidige feiten
            let bindingen = Self::match_lichaam(&regel.lichaam, &db.feiten.iter().cloned().collect::<Vec<_>>());
            for binding in bindingen {
                if let Some(afgeleid) = Self::toepassen(&regel.hoofd, &binding) {
                    if !db.bevat(&afgeleid) {
                        nieuwe_feiten.push(afgeleid);
                    }
                }
            }
        }

        let n = nieuwe_feiten.len();
        for feit in nieuwe_feiten {
            db.voeg_feit_toe(feit);
        }
        n
    }

    /// Match een lijst van lichaam-atomen tegen de bestaande feiten
    /// Geeft alle mogelijke variabele bindingen terug
    fn match_lichaam(lichaam: &[CuiperFeit], feiten: &[CuiperFeit]) -> Vec<Binding> {
        let mut bindingen: Vec<Binding> = vec![HashMap::new()];

        for atoom in lichaam {
            let mut nieuwe_bindingen = Vec::new();
            for binding in &bindingen {
                for feit in feiten {
                    if let Some(b) = Self::unificeer(atoom, feit, binding) {
                        nieuwe_bindingen.push(b);
                    }
                }
            }
            bindingen = nieuwe_bindingen;
            if bindingen.is_empty() {
                break;
            }
        }
        bindingen
    }

    /// Probeer een lichaam-atoom te unificiëren met een feit gegeven een binding
    fn unificeer(atoom: &CuiperFeit, feit: &CuiperFeit, binding: &Binding) -> Option<Binding> {
        if atoom.relatie != feit.relatie || atoom.args.len() != feit.args.len() {
            return None;
        }
        let mut nieuwe_binding = binding.clone();
        for (a, b) in atoom.args.iter().zip(feit.args.iter()) {
            match a {
                CuiperTerm::Constante(c) => {
                    if b != &CuiperTerm::Constante(c.clone()) {
                        return None;
                    }
                }
                CuiperTerm::Variabele(v) => {
                    if let Some(gebonden) = nieuwe_binding.get(v) {
                        if gebonden != b {
                            return None;
                        }
                    } else {
                        nieuwe_binding.insert(v.clone(), b.clone());
                    }
                }
            }
        }
        Some(nieuwe_binding)
    }

    /// Pas een binding toe op het hoofd-atoom om een grond feit te produceren
    fn toepassen(hoofd: &CuiperFeit, binding: &Binding) -> Option<CuiperFeit> {
        let args: Option<Vec<CuiperTerm>> = hoofd.args.iter().map(|term| {
            match term {
                CuiperTerm::Constante(_) => Some(term.clone()),
                CuiperTerm::Variabele(v) => binding.get(v).cloned(),
            }
        }).collect();
        Some(CuiperFeit::nieuw(hoofd.relatie.clone(), args?))
    }
}
