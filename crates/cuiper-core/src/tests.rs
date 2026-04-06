#[cfg(test)]
mod cuip_tests {
    use crate::cuip::{CuiperCuip, CuipWaarde};

    #[test]
    fn cuip_begint_als_can() {
        let cuip = CuiperCuip::nieuw("01TEST000000000000000000000".into(), 42, "test operatie");
        assert!(cuip.is_can());
        assert_eq!(cuip.regelnr, 42);
        assert_eq!(cuip.omschrijving, "test operatie");
    }

    #[test]
    fn cuip_voltooid_na_succes() {
        let cuip = CuiperCuip::nieuw("01TEST000000000000000000001".into(), 1, "operatie")
            .voltooi();
        assert!(cuip.is_voltooid());
        assert!(!cuip.is_can());
    }

    #[test]
    fn cuip_mislukt_bewaart_reden() {
        let cuip = CuiperCuip::nieuw("01TEST000000000000000000002".into(), 5, "riskante operatie")
            .mislukt("verbinding verbroken");
        assert!(!cuip.is_can());
        assert!(!cuip.is_voltooid());
        assert!(matches!(cuip.waarde, CuipWaarde::Mislukt(ref r) if r == "verbinding verbroken"));
    }

    #[test]
    fn cuip_trail_formaat_bevat_alle_velden() {
        let cuip = CuiperCuip::nieuw("01TESTTRAIL00000000000000000".into(), 99, "trail test")
            .voltooi();
        let trail = cuip.als_trail_regel();
        assert!(trail.contains("01TESTTRAIL00000000000000000"));
        assert!(trail.contains("L:99"));
        assert!(trail.contains("trail test"));
        assert!(trail.contains("VOLTOOID"));
    }

    #[test]
    fn cuip_can_waarde_display() {
        let can = CuipWaarde::Can;
        assert_eq!(format!("{can}"), "CAN");
    }
}

#[cfg(test)]
mod markov_tests {
    use crate::markov::{CuiperMarkovState, CuiperTransitie, CuiperUitkomst};

    fn staat(versie: u64, beschrijving: &str) -> CuiperMarkovState {
        CuiperMarkovState {
            versie,
            beschrijving: beschrijving.into(),
            commit: None,
        }
    }

    #[test]
    fn markov_succes_als_c_gelijk_aan_b() {
        let a = staat(1, "huidige staat");
        let b = staat(2, "verwachte staat");
        let c = staat(2, "verwachte staat"); // C == B
        let mut t = CuiperTransitie::nieuw(a, b);
        t.registreer_c(c);
        assert_eq!(t.uitkomst(), CuiperUitkomst::Succes);
    }

    #[test]
    fn markov_rollback_als_c_verschilt_van_b() {
        let a = staat(1, "huidige staat");
        let b = staat(2, "verwachte staat");
        let c = staat(3, "andere staat"); // C != B
        let mut t = CuiperTransitie::nieuw(a, b);
        t.registreer_c(c);
        assert_eq!(t.uitkomst(), CuiperUitkomst::RollbackNaarA);
    }

    #[test]
    fn markov_pending_zonder_c() {
        let a = staat(1, "a");
        let b = staat(2, "b");
        let t = CuiperTransitie::nieuw(a, b);
        assert_eq!(t.uitkomst(), CuiperUitkomst::Pending);
    }
}

#[cfg(test)]
mod bewaker_tests {
    use crate::bewaker::{CuiperBewaker, CuiperBewakeringsFout};
    use crate::cuip::CuiperCuip;
    use std::time::Duration;

    #[test]
    fn bewaker_blokkeert_dubbele_uitvoering() {
        let mut bewaker = CuiperBewaker::nieuw();
        let ulid = "01TESTDOUBLE000000000000000".to_string();

        let cuip1 = CuiperCuip::nieuw(ulid.clone(), 1, "eerste keer");
        let cuip2 = CuiperCuip::nieuw(ulid.clone(), 2, "tweede keer — geblokkeerd");

        let _r1 = bewaker.bewaak(cuip1, None, || Ok::<_, String>("eerste"));
        let r2  = bewaker.bewaak(cuip2, None, || Ok::<_, String>("tweede"));

        assert!(matches!(r2, Err(CuiperBewakeringsFout::DubbeleUitvoering(_))));
    }

    #[test]
    fn bewaker_geeft_resultaat_bij_succes() {
        let mut bewaker = CuiperBewaker::nieuw();
        let cuip = CuiperCuip::nieuw("01TESTSUCCESS00000000000000".into(), 1, "test");

        let (waarde, afgeronde_cuip) = bewaker
            .bewaak(cuip, None, || Ok::<i32, String>(42))
            .expect("moet slagen");

        assert_eq!(waarde, 42);
        assert!(afgeronde_cuip.is_voltooid());
    }

    #[test]
    fn bewaker_loop_stopt_bij_max_iteraties() {
        let mut bewaker = CuiperBewaker::nieuw().met_max_iteraties(5);
        let result = bewaker.bewaak_loop(
            "01TESTLOOP000000000000000000".into(),
            Some(5),
            |_| false, // nooit klaar
        );
        assert!(matches!(result, Err(CuiperBewakeringsFout::LoopZonderUitgang { .. })));
    }

    #[test]
    fn bewaker_loop_slaagt_bij_exit_conditie() {
        let mut bewaker = CuiperBewaker::nieuw();
        let result = bewaker.bewaak_loop(
            "01TESTLOOPOK0000000000000000".into(),
            Some(100),
            |i| i == 3, // klaar na 3 iteraties
        );
        assert_eq!(result.unwrap(), 3);
    }

    #[test]
    fn bewaker_dataset_validatie_blokkeert_corrupt() {
        let bewaker = CuiperBewaker::nieuw();
        let data = vec![1i32, -1, 2]; // -1 is ongeldig

        let validators: &[fn(&Vec<i32>) -> Result<(), String>] = &[
            |v| {
                if v.iter().any(|&x| x < 0) {
                    Err("negatieve waarde gevonden".into())
                } else {
                    Ok(())
                }
            },
        ];

        let result = bewaker.valideer_dataset("01TESTDATA00000000000000000", &data, validators);
        assert!(matches!(result, Err(CuiperBewakeringsFout::CorrupteDataset { .. })));
    }
}

#[cfg(test)]
mod entiteit_tests {
    use crate::entiteit::{CuiperEntiteit, CuiperHiveNr};

    #[test]
    fn entiteit_sedimenteert_zonder_verliezen() {
        let mut e = CuiperEntiteit::nieuw(
            CuiperHiveNr::CUIPER,
            "Cuiper",
            "Architect",
            "Souverein",
        );
        e.sedimenteer("eerste feit");
        e.sedimenteer("tweede feit");
        assert_eq!(e.geschiedenis.len(), 2);
        // Feiten worden nooit verwijderd
        assert_eq!(e.geschiedenis[0], "eerste feit");
    }

    #[test]
    fn hive_nrs_zijn_uniek() {
        assert_ne!(CuiperHiveNr::NUL, CuiperHiveNr::CUIPER);
        assert_ne!(CuiperHiveNr::DEVA, CuiperHiveNr::CLAUDE_CLI);
    }
}

#[cfg(test)]
mod donut_tests {
    use crate::cuip::CuipWaarde;
    use crate::donut::{CuiperDonut, CUIPER_WAARDEN, CUIPER_NORMEN, CUIPER_WETTEN};

    // Minimale component die CuiperDonut implementeert
    struct CuiperTestComponent {
        naam: &'static str,
        ulid: &'static str,
    }
    impl CuiperDonut for CuiperTestComponent {
        fn cuiper_naam(&self) -> &str { self.naam }
        fn cuiper_ulid(&self) -> &str { self.ulid }
    }

    #[test]
    fn waarden_normen_wetten_zijn_gevuld() {
        let c = CuiperTestComponent { naam: "CuiperTestComponent", ulid: "01TEST" };
        assert!(!c.waarden().is_empty());
        assert!(!c.normen().is_empty());
        assert!(!c.wetten().is_empty());
    }

    #[test]
    fn geweten_staat_geldige_actie_toe() {
        let c = CuiperTestComponent { naam: "CuiperTestComponent", ulid: "01TEST" };
        assert!(c.geweten("git commit -m 'CuiperStap40'").is_ok());
    }

    #[test]
    fn geweten_blokkeert_dev_null() {
        let c = CuiperTestComponent { naam: "CuiperTestComponent", ulid: "01TEST" };
        let fout = c.geweten("echo fout 2>/dev/null").unwrap_err();
        assert!(fout.to_string().contains("/dev/null verbod"));
    }

    #[test]
    fn geweten_blokkeert_naam_zonder_cuiper_prefix() {
        // Component met naam die wet schendt
        let wees = CuiperTestComponent { naam: "BacklogOperator", ulid: "01WEES" };
        let fout = wees.geweten("willekeurige actie").unwrap_err();
        assert!(fout.to_string().contains("Cuiper prefix"));
    }

    #[test]
    fn passeer_ring_geeft_voltooid_bij_geldig() {
        let c = CuiperTestComponent { naam: "CuiperTestComponent", ulid: "01TEST" };
        assert!(matches!(c.passeer_ring("git push"), CuipWaarde::Voltooid));
    }

    #[test]
    fn passeer_ring_geeft_mislukt_bij_wet_schending() {
        let c = CuiperTestComponent { naam: "CuiperTestComponent", ulid: "01TEST" };
        assert!(matches!(
            c.passeer_ring("rm output 2>/dev/null"),
            CuipWaarde::Mislukt(_)
        ));
    }

    #[test]
    fn wet_schending_is_nooit_stil() {
        // WetSchending implementeert Display — altijd leesbaar, nooit weggegooid
        let c = CuiperTestComponent { naam: "CuiperTestComponent", ulid: "01TEST" };
        let schending = c.geweten("bad 2>/dev/null").unwrap_err();
        let tekst = schending.to_string();
        assert!(!tekst.is_empty());
        assert!(tekst.contains("WetSchending"));
    }

    #[test]
    fn waarden_bevatten_wijsheid_en_logica() {
        assert!(CUIPER_WAARDEN.contains(&"wijsheid"));
        assert!(CUIPER_WAARDEN.contains(&"radicale logica"));
    }

    #[test]
    fn wetten_bevatten_dev_null_verbod_en_naamgevingswet() {
        assert!(CUIPER_WETTEN.iter().any(|w| w.contains("/dev/null verbod")));
        assert!(CUIPER_WETTEN.iter().any(|w| w.contains("CuiperNaamgevingswet")));
    }

    #[test]
    fn normen_bevatten_sedimentatie() {
        assert!(CUIPER_NORMEN.iter().any(|n| n.contains("gesedimenteerd")));
    }
}
