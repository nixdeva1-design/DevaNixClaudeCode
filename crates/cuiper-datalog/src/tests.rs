#[cfg(test)]
mod feit_tests {
    use crate::feit::{CuiperFeit, CuiperTerm};

    #[test]
    fn grond_feit_heeft_geen_variabelen() {
        let feit = CuiperFeit::nieuw("rol", vec![
            CuiperTerm::constante("cuiper"),
            CuiperTerm::constante("architect"),
        ]);
        assert!(feit.is_grond());
    }

    #[test]
    fn feit_met_variabele_is_niet_grond() {
        let feit = CuiperFeit::nieuw("rol", vec![
            CuiperTerm::variabele("X"),
            CuiperTerm::constante("architect"),
        ]);
        assert!(!feit.is_grond());
    }
}

#[cfg(test)]
mod motor_tests {
    use crate::databank::CuiperDatabank;
    use crate::feit::{CuiperFeit, CuiperTerm};
    use crate::motor::CuiperMotor;
    use crate::regel::CuiperRegel;

    fn c(s: &str) -> CuiperTerm { CuiperTerm::constante(s) }
    fn v(s: &str) -> CuiperTerm { CuiperTerm::variabele(s) }
    fn feit(rel: &str, args: Vec<CuiperTerm>) -> CuiperFeit { CuiperFeit::nieuw(rel, args) }

    #[test]
    fn motor_legt_grond_feiten_vast() {
        let mut db = CuiperDatabank::nieuw();
        let f = feit("entiteit", vec![c("cuiper"), c("architect")]);
        assert!(db.voeg_feit_toe(f.clone()));
        assert!(db.bevat(&f));
        assert_eq!(db.aantal_feiten(), 1);
    }

    #[test]
    fn motor_geen_duplicaten() {
        let mut db = CuiperDatabank::nieuw();
        let f = feit("naam", vec![c("deva")]);
        db.voeg_feit_toe(f.clone());
        db.voeg_feit_toe(f.clone()); // tweede keer
        assert_eq!(db.aantal_feiten(), 1);
    }

    #[test]
    fn motor_leidt_transitieve_relatie_af() {
        // bereikbaar(a, b) en bereikbaar(b, c) → bereikbaar(a, c)
        let mut db = CuiperDatabank::nieuw();

        // Feiten
        db.voeg_feit_toe(feit("bereikbaar", vec![c("a"), c("b")]));
        db.voeg_feit_toe(feit("bereikbaar", vec![c("b"), c("c")]));

        // Regel: bereikbaar(X, Z) :- bereikbaar(X, Y), bereikbaar(Y, Z)
        let hoofd   = feit("bereikbaar", vec![v("X"), v("Z")]);
        let lichaam = vec![
            feit("bereikbaar", vec![v("X"), v("Y")]),
            feit("bereikbaar", vec![v("Y"), v("Z")]),
        ];
        db.voeg_regel_toe(CuiperRegel::regel(hoofd, lichaam));

        let nieuw = CuiperMotor::evalueer(&mut db);
        assert!(nieuw > 0, "motor moet iets afleiden");
        assert!(db.bevat(&feit("bereikbaar", vec![c("a"), c("c")])));
    }

    #[test]
    fn motor_stopt_bij_vaste_punt() {
        // Geen nieuwe feiten meer afleidbaar → motor stopt
        let mut db = CuiperDatabank::nieuw();
        db.voeg_feit_toe(feit("naam", vec![c("cuiper")]));
        // Geen regels — motor doet één iteratie, vindt niets
        let nieuw = CuiperMotor::evalueer(&mut db);
        assert_eq!(nieuw, 0);
    }

    #[test]
    fn motor_eenvoudige_inferentie_een_stap() {
        // lid(cuiper). lid(deva). hive_lid(X) :- lid(X).
        let mut db = CuiperDatabank::nieuw();
        db.voeg_feit_toe(feit("lid", vec![c("cuiper")]));
        db.voeg_feit_toe(feit("lid", vec![c("deva")]));

        let hoofd   = feit("hive_lid", vec![v("X")]);
        let lichaam = vec![feit("lid", vec![v("X")])];
        db.voeg_regel_toe(CuiperRegel::regel(hoofd, lichaam));

        CuiperMotor::evalueer(&mut db);

        assert!(db.bevat(&feit("hive_lid", vec![c("cuiper")])));
        assert!(db.bevat(&feit("hive_lid", vec![c("deva")])));
    }
}
