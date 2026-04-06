#[cfg(test)]
mod routeregel_tests {
    use crate::routeregel::{CuiperRouteActie, CuiperRouteRegel};

    #[test]
    fn patroon_dubbelster_matcht_diep_pad() {
        let regel = CuiperRouteRegel::nieuw(
            "test",
            "klant/**",
            CuiperRouteActie::Doorsturen("klant/**".into()),
            10,
        );
        assert!(regel.past_op("klant/acme/sensor/temp"));
        assert!(regel.past_op("klant/"));
        assert!(!regel.past_op("lab/projectA"));
    }

    #[test]
    fn patroon_enkel_ster_matcht_alleen_een_niveau() {
        let regel = CuiperRouteRegel::nieuw(
            "test",
            "klant/*",
            CuiperRouteActie::Doorsturen("klant/*".into()),
            10,
        );
        assert!(regel.past_op("klant/acme"));
        assert!(!regel.past_op("klant/acme/sensor")); // te diep
        assert!(!regel.past_op("lab/x"));
    }

    #[test]
    fn patroon_exact_matcht_alleen_exact() {
        let regel = CuiperRouteRegel::nieuw(
            "test",
            "klant/acme/sensor",
            CuiperRouteActie::Doorsturen("klant/acme/sensor".into()),
            10,
        );
        assert!(regel.past_op("klant/acme/sensor"));
        assert!(!regel.past_op("klant/acme/sensor/extra"));
        assert!(!regel.past_op("klant/acme"));
    }

    #[test]
    fn prioriteit_sortering() {
        let r1 = CuiperRouteRegel::nieuw("hoog", "a/**", CuiperRouteActie::Doorsturen("a".into()), 5);
        let r2 = CuiperRouteRegel::nieuw("laag", "b/**", CuiperRouteActie::Doorsturen("b".into()), 99);
        // lager getal = hogere prioriteit
        assert!(r1.prioriteit < r2.prioriteit);
    }
}

#[cfg(test)]
mod brug_tests {
    use crate::brug::{BrugFilter, CuiperNaamspaceBrug};

    #[test]
    fn filter_alles_laat_door() {
        let brug = CuiperNaamspaceBrug::nieuw("01TEST", "lab", "klant", BrugFilter::Alles, "test");
        assert!(brug.staat_toe("klant/acme/sensor"));
    }

    #[test]
    fn filter_geen_blokkeert_alles() {
        let brug = CuiperNaamspaceBrug::nieuw("01TEST", "lab", "klant", BrugFilter::Geen, "test");
        assert!(!brug.staat_toe("klant/acme/sensor"));
    }

    #[test]
    fn filter_patroon_matcht_substring() {
        let brug = CuiperNaamspaceBrug::nieuw(
            "01TEST", "lab", "klant",
            BrugFilter::Patroon("sensor".into()),
            "test",
        );
        assert!(brug.staat_toe("klant/acme/sensor/temp"));
        assert!(!brug.staat_toe("klant/acme/actuator"));
    }
}

#[cfg(test)]
mod router_tests {
    use crate::brug::{BrugFilter, CuiperNaamspaceBrug};
    use crate::router::CuiperRouter;
    use crate::routeregel::CuiperRouteActie;
    use crate::CuiperRouterFout;
    use cuiper_bus::signaal::CuiperSignaal;
    use serde_json;

    fn maak_signaal(key: &str, afzender: &str) -> CuiperSignaal {
        CuiperSignaal {
            key:       key.into(),
            afzender:  afzender.into(),
            timestamp: 0,
            payload:   serde_json::Value::Null,
        }
    }

    #[test]
    fn klant_signaal_binnen_namespace_doorgestuurd() {
        let mut router = CuiperRouter::nieuw().met_standaard_regels();
        let signaal = maak_signaal("klant/acme/sensor/temp", "klant/acme/agent");
        let actie = router.route(&signaal).unwrap();
        assert!(matches!(actie, CuiperRouteActie::Doorsturen(_)));
    }

    #[test]
    fn airgap_schending_geblokkeerd() {
        let mut router = CuiperRouter::nieuw().met_standaard_regels();
        // airgap afzender, bestemming buiten airgap
        let signaal = maak_signaal("klant/acme/data", "airgap/node1");
        let fout = router.route(&signaal).unwrap_err();
        assert!(matches!(fout, CuiperRouterFout::AirgapSchending { .. }));
    }

    #[test]
    fn airgap_intern_verkeer_toegestaan() {
        let mut router = CuiperRouter::nieuw().met_standaard_regels();
        let signaal = maak_signaal("airgap/node2/data", "airgap/node1");
        let actie = router.route(&signaal).unwrap();
        // airgap regel: LogEnDoorsturen
        assert!(matches!(actie, CuiperRouteActie::LogEnDoorsturen(_)));
    }

    #[test]
    fn namespace_schending_zonder_brug_geblokkeerd() {
        let mut router = CuiperRouter::nieuw().met_standaard_regels();
        // lab probeert te schrijven naar klant zonder brug
        let signaal = maak_signaal("klant/acme/resultaat", "lab/projectA/agent");
        let fout = router.route(&signaal).unwrap_err();
        assert!(matches!(fout, CuiperRouterFout::NamespaceSchending { .. }));
    }

    #[test]
    fn namespace_schending_met_brug_toegestaan() {
        let mut router = CuiperRouter::nieuw().met_standaard_regels();
        router.voeg_brug_toe(CuiperNaamspaceBrug::nieuw(
            "01BRUG01",
            "lab",
            "klant",
            BrugFilter::Alles,
            "lab mag resultaten doorstuuren naar klant",
        ));
        let signaal = maak_signaal("klant/acme/resultaat", "lab/projectA/agent");
        let actie = router.route(&signaal).unwrap();
        assert!(matches!(actie, CuiperRouteActie::Doorsturen(_)));
    }

    #[test]
    fn geen_route_voor_onbekende_namespace() {
        let mut router = CuiperRouter::nieuw().met_standaard_regels();
        let signaal = maak_signaal("onbekend/x/y", "onbekend/x/agent");
        let fout = router.route(&signaal).unwrap_err();
        assert!(matches!(fout, CuiperRouterFout::GeenRoute { .. }));
    }

    #[test]
    fn elke_beslissing_gelogd() {
        let mut router = CuiperRouter::nieuw().met_standaard_regels();
        let s1 = maak_signaal("klant/acme/x", "klant/acme/agent");
        let s2 = maak_signaal("lab/proj/y", "lab/proj/agent");
        let _ = router.route(&s1);
        let _ = router.route(&s2);
        // /dev/null verbod: beide beslissingen moeten in het log staan
        assert_eq!(router.routing_log().len(), 2);
    }

    #[test]
    fn airgap_beslissing_altijd_gelogd_ook_bij_fout() {
        let mut router = CuiperRouter::nieuw().met_standaard_regels();
        let signaal = maak_signaal("klant/x", "airgap/node1");
        let _ = router.route(&signaal); // fout, maar log mag niet leeg zijn
        assert_eq!(router.routing_log().len(), 1);
        assert!(router.routing_log()[0].actie.contains("AIRGAP"));
    }
}
