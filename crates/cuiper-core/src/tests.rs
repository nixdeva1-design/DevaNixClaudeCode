#[cfg(test)]
mod cuip_tests {
    use crate::cuip::{Cuip, CuiperCuip, CuipWaarde, CuiperRegel, cuip_hash, bereken_hash_str};

    #[test]
    fn cuip_begint_als_can() {
        let cuip = Cuip::nieuw("01TEST000000000000000000000".into(), 42, "test operatie");
        assert!(cuip.is_can());
        assert_eq!(cuip.regelnr, 42);
        assert_eq!(cuip.omschrijving, "test operatie");
    }

    #[test]
    fn cuip_heeft_hash() {
        let cuip = Cuip::nieuw("01TEST000000000000000000000".into(), 42, "test operatie");
        // Hash is deterministisch: zelfde input = zelfde hash
        let verwacht = cuip_hash("01TEST000000000000000000000", 42, "test operatie");
        assert_eq!(cuip.hash, verwacht);
        assert_eq!(cuip.hash_hex().len(), 16);
    }

    #[test]
    fn cuip_hash_is_deterministisch() {
        let h1 = cuip_hash("01ULID", 10, "actie");
        let h2 = cuip_hash("01ULID", 10, "actie");
        assert_eq!(h1, h2);
    }

    #[test]
    fn cuip_hash_verschilt_bij_andere_input() {
        let h1 = cuip_hash("01ULID", 10, "actie a");
        let h2 = cuip_hash("01ULID", 10, "actie b");
        assert_ne!(h1, h2);
    }

    #[test]
    fn cuip_met_bewaakte_regels() {
        let r1 = CuiperRegel::nieuw("geen_devnull", "output gaat naar trail");
        let r2 = CuiperRegel::nieuw("ulid_vereist", "elke stap heeft een ULID");
        let cuip = Cuip::nieuw("01TESTREGEL00000000000000000".into(), 1, "test met regels")
            .met_regel(r1.clone())
            .met_regel(r2.clone());
        assert_eq!(cuip.bewaakt.len(), 2);
        assert_eq!(cuip.bewaakt[0].naam, "geen_devnull");
        assert_eq!(cuip.bewaakt[1].naam, "ulid_vereist");
    }

    #[test]
    fn cuiper_regel_hash_is_deterministisch() {
        let r1 = CuiperRegel::nieuw("naam", "omschrijving");
        let r2 = CuiperRegel::nieuw("naam", "omschrijving");
        assert_eq!(r1.hash, r2.hash);
        assert_eq!(r1.hash_hex().len(), 16);
    }

    #[test]
    fn cuiper_regel_hash_verschilt_bij_andere_naam() {
        let r1 = CuiperRegel::nieuw("regel_a", "zelfde omschrijving");
        let r2 = CuiperRegel::nieuw("regel_b", "zelfde omschrijving");
        assert_ne!(r1.hash, r2.hash);
    }

    #[test]
    fn cuip_trail_bevat_hash_en_regels() {
        let r = CuiperRegel::nieuw("test_regel", "test");
        let cuip = Cuip::nieuw("01TESTTRAIL00000000000000000".into(), 99, "trail test")
            .met_regel(r)
            .voltooi();
        let trail = cuip.als_trail_regel();
        assert!(trail.contains("01TESTTRAIL00000000000000000"));
        assert!(trail.contains("L:99"));
        assert!(trail.contains("hash:"));
        assert!(trail.contains("regels:["));
        assert!(trail.contains("VOLTOOID"));
    }

    #[test]
    fn cuip_alias_cuipercuip_werkt() {
        // CuiperCuip is alias voor Cuip — backwards compatibility
        let cuip = CuiperCuip::nieuw("01TESTALIAS0000000000000000".into(), 1, "alias test");
        assert!(cuip.is_can());
    }

    #[test]
    fn cuip_voltooid_na_succes() {
        let cuip = Cuip::nieuw("01TEST000000000000000000001".into(), 1, "operatie").voltooi();
        assert!(cuip.is_voltooid());
        assert!(!cuip.is_can());
    }

    #[test]
    fn cuip_mislukt_bewaart_reden() {
        let cuip = Cuip::nieuw("01TEST000000000000000000002".into(), 5, "riskante operatie")
            .mislukt("verbinding verbroken");
        assert!(!cuip.is_can());
        assert!(matches!(cuip.waarde, CuipWaarde::Mislukt(ref r) if r == "verbinding verbroken"));
    }

    #[test]
    fn cuip_can_waarde_display() {
        assert_eq!(format!("{}", CuipWaarde::Can), "CAN");
    }

    #[test]
    fn bereken_hash_str_is_deterministisch() {
        let h1 = bereken_hash_str("cuiper test");
        let h2 = bereken_hash_str("cuiper test");
        assert_eq!(h1, h2);
    }
}

#[cfg(test)]
mod wereld_tests {
    use crate::wereld::{CuiperWaarde, CuiperVariabelen, CuiperParameters, CuiperWereld};

    #[test]
    fn cuiper_waarde_nul_is_can() {
        let w = CuiperWaarde::Nul;
        assert!(w.is_nul());
    }

    #[test]
    fn cuiper_waarde_polymorf() {
        let tekst = CuiperWaarde::Tekst("hallo".into());
        let getal = CuiperWaarde::Int(42);
        let vlag  = CuiperWaarde::Bool(true);
        assert_eq!(tekst.als_tekst(), Some("hallo"));
        assert_eq!(getal.als_int(), Some(42));
        assert_eq!(vlag.als_bool(), Some(true));
    }

    #[test]
    fn cuiper_waarde_dynamisch_json_roundtrip() {
        let origeel = CuiperWaarde::Lijst(vec![
            CuiperWaarde::Int(1),
            CuiperWaarde::Tekst("twee".into()),
        ]);
        let json = origeel.als_json();
        let terug = CuiperWaarde::van_json(&json).unwrap();
        assert_eq!(origeel, terug);
    }

    #[test]
    fn cuiper_variabelen_zet_haal() {
        let mut v = CuiperVariabelen::nieuw();
        v.zet("naam", CuiperWaarde::Tekst("cuiper".into()));
        assert_eq!(v.haal("naam").unwrap(), &CuiperWaarde::Tekst("cuiper".into()));
        assert!(v.bevat("naam"));
        assert!(!v.bevat("onbekend"));
    }

    #[test]
    fn cuiper_variabelen_haal_of_geeft_standaard() {
        let v = CuiperVariabelen::nieuw();
        let r = v.haal_of("ontbreekt", CuiperWaarde::Int(99));
        assert_eq!(r, CuiperWaarde::Int(99));
    }

    #[test]
    fn cuiper_parameters_positieel_en_benoemd() {
        let p = CuiperParameters::nieuw()
            .met("ulid", CuiperWaarde::Tekst("01KN...".into()))
            .met("stap", CuiperWaarde::Int(57));
        assert_eq!(p.len(), 2);
        assert_eq!(p.haal("stap"), Some(&CuiperWaarde::Int(57)));
        assert_eq!(p.positie(0).unwrap(), &CuiperWaarde::Tekst("01KN...".into()));
    }

    #[test]
    fn cuiper_wereld_namespace_en_variabelen() {
        let mut w = CuiperWereld::nieuw("lab/experiment1");
        w.zet("teller", CuiperWaarde::Int(0));
        assert_eq!(w.namespace, "lab/experiment1");
        assert_eq!(w.haal("teller"), Some(&CuiperWaarde::Int(0)));
    }
}

#[cfg(test)]
mod io_bus_tests {
    use crate::io_bus::{CuiperIOBus, CuiperInType, CuiperOutType, CuiperScope};
    use crate::wereld::CuiperWaarde;

    #[test]
    fn io_bus_aanmaken_en_params() {
        let mut bus = CuiperIOBus::nieuw(
            "CuiperPromptCounter",
            "0.2.0",
            CuiperInType::Hook,
            CuiperOutType::Trail,
            CuiperScope::Globaal,
            "protocol",
        );
        bus.input.parameters.voeg_toe("stap_nr", CuiperWaarde::Int(57));
        assert_eq!(
            bus.input.param("stap_nr"),
            Some(&CuiperWaarde::Int(57))
        );
        assert_eq!(bus.module_naam, "CuiperPromptCounter");
    }

    #[test]
    fn io_bus_fout_markeert_niet_succes() {
        let mut bus = CuiperIOBus::nieuw(
            "CuiperTest", "0.1.0",
            CuiperInType::Geen, CuiperOutType::Geen,
            CuiperScope::Lokaal, "test",
        );
        assert!(bus.is_succes());
        bus.fout("iets ging mis");
        assert!(!bus.is_succes());
        assert!(bus.output.heeft_fouten());
    }

    #[test]
    fn io_bus_schrijf_en_trail() {
        let mut bus = CuiperIOBus::nieuw(
            "CuiperTest", "0.1.0",
            CuiperInType::Geen, CuiperOutType::Stdout,
            CuiperScope::Namespace("klant/acme".into()), "klant/acme",
        );
        bus.schrijf("uitvoer regel 1");
        bus.trail("trail entry 1");
        assert_eq!(bus.output.stdout_buf.len(), 1);
        assert_eq!(bus.output.trail_items.len(), 1);
    }

    #[test]
    fn scope_display() {
        assert_eq!(format!("{}", CuiperScope::Lokaal), "lokaal");
        assert_eq!(format!("{}", CuiperScope::Namespace("lab/x".into())), "namespace:lab/x");
        assert_eq!(format!("{}", CuiperScope::Geïsoleerd), "geïsoleerd");
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
