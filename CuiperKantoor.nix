# CuiperKantoor NixOS configuratie schema
# Organisatiestructuur als Nix expressie

{
  cuiperKantoor = {

    # Identiteiten
    personen = {
      cuiper = {
        id = 1;
        naam = "Cuiper";
        rol = "Hoofd Architect & Eigenaar";
        mandaat = "volledig";
      };
      deva = {
        id = 2;
        naam = "Deva";
        rol = "AI Systeembeheerder";
        mandaat = "operationeel";
        verantwoordelijkheden = [
          "llm-toegangen"
          "betalingen"
          "dagelijks-beheer"
          "mandaten-uitdelen"
          "kosten-bewaken"
        ];
      };
    };

    aiPersoneel = {
      claudeCode = {
        id = 3;
        naam = "ClaudeCode";
        provider = "Anthropic";
        type = "CLI";
        mandaat = "tijdelijk-procesgebonden";
        gratis = false;
      };
      claudeAi = {
        id = 4;
        naam = "Claude.ai";
        provider = "Anthropic";
        type = "Web";
        mandaat = "tijdelijk-procesgebonden";
        gratis = false;
      };
    };

    # Omgevingen
    omgevingen = {
      ontwerp = {
        niveau = 1;
        dataKlasse = "geen-productie";
        toegang = [ "cuiper" "design-agents" ];
      };
      test = {
        niveau = 2;
        dataKlasse = "test";
        toegang = [ "kantoorpersoneel" "implementatie-agents" ];
      };
      productieHoofd = {
        niveau = 3;
        dataKlasse = "productie";
        beheer = "deva";
        mandaatVereist = true;
      };
      productieSub = {
        niveau = 3;
        dataKlasse = "productie";
        beheer = "deva";
        meervoudig = true;
        resourceTypes = [ "databases" "pakketten" "externe-systemen" ];
      };
    };

    # Infrastructuur
    infrastructuur = {
      kantoorServers = {
        type = "on-premise";
        eigenaar = "CuiperKantoor";
        gehuurd = false;
      };
      cloud = {
        azure = { provider = "Microsoft"; gehuurd = true; };
        aws   = { provider = "Amazon";    gehuurd = true; };
        gcp   = { provider = "Google";    gehuurd = true; };
      };
    };

    # Proces kostenbewaking schema
    procesSchema = {
      process_ulid = { type = "string"; formaat = "ULID"; };
      start_unix   = { type = "int";    formaat = "unix-seconden"; };
      end_unix     = { type = "int";    formaat = "unix-seconden"; };
      tokens_used  = { type = "int";    formaat = "aantal"; };
      valuta       = "niet-opgeslagen";
    };

    # Mandaat systeem regels
    mandaatRegels = {
      hiërarchie = [ "cuiper" "deva" "kantoorpersoneel" "klanten" "ai-personeel" ];
      klantZichtbaarheid = {
        verboden = [
          "interne-economie"
          "werkstructuur"
          "codebase"
          "mandaat-details-anderen"
        ];
        toegestaan = [ "eigen-mandaten" "eigen-processen" ];
      };
    };

    # Agent types
    agentTypes = {
      design = {
        rol = "co-ontwerper";
        schrijftCode = false;
        maxOutput = "1-A4";
        outputFormaat = [ "opties" "voor-nadelen" "aanbeveling" "open-vragen" ];
      };
      implementatie = {
        rol = "bouwt-ontwerpen";
        vereiste = "goedgekeurd-ontwerp";
        branchFormaat = "agent/{machine-id}/{issue-nummer}";
        claimtIssue = true;
        maaktPR = true;
      };
    };

  };
}
