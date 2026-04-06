/// CuiperMandaat — wat een entiteit mag doen, nooit mag doen, en verplicht doet
#[derive(Debug, Clone)]
pub struct CuiperMandaat {
    pub mag:      Vec<String>,
    pub nooit:    Vec<String>,
    pub verplicht: Vec<String>,
}

impl CuiperMandaat {
    pub fn cuiper() -> Self {
        Self {
            mag: vec![
                "Ontwerpen".into(),
                "Delegeren".into(),
                "Arbitreren".into(),
                "Sedimenteren".into(),
            ],
            nooit: vec![
                "/dev/null gebruiken".into(),
                "Data weggooien".into(),
                "Zonder trail handelen".into(),
            ],
            verplicht: vec![
                "Elke stap vastleggen".into(),
                "Mislukkingen documenteren".into(),
                "Eerste principes toepassen".into(),
            ],
        }
    }

    pub fn claude_code() -> Self {
        Self {
            mag: vec![
                "Schrijven".into(),
                "Committen".into(),
                "Pushen".into(),
                "Testen".into(),
                "Verificeren".into(),
            ],
            nooit: vec![
                "Pushen zonder trail log".into(),
                "Committen zonder CuiperStapNr".into(),
                "2>/dev/null gebruiken".into(),
            ],
            verplicht: vec![
                "KlaarMelding tonen na elke respons".into(),
                "ULID genereren".into(),
                "Trail log schrijven".into(),
                "Dynamische drempel bewaken".into(),
            ],
        }
    }
}
