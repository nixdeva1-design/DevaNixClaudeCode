# CuiperAGINixOSHandleiding
<!-- ─── CuiperHeader ───────────────────────────────────────────────────────────
     ULID:          01COMP048HANDLEIDING000000
     Naam:          docs/CuiperAGINixOSHandleiding.md
     Erft via:      CuiperCore → CuiperDonut → nixos/flake.nix
     Aangemaakt:    CuiperStapNr 55
     Gewijzigd:     CuiperStapNr 55 — 2026-04-08
     ─────────────────────────────────────────────────────────────────────────── -->

## NixOS op USB — Fysieke Installatie voor Kantoor
### Versie: CuiperStapNr 55 — 2026-04-08

> **Wet:** Elk probleem dat je tegenkomt schrijf je op in het Probleemlogboek (Deel 9).
> Niets gaat naar /dev/null. Fouten zijn informatie.

---

## DEEL 0 — INSTALLATIERAPPORT (Scaffolding: nu invullen, bijhouden tijdens installatie)

> Druk dit deel af of open het in een editor. Vul elk veld in op het moment dat je de informatie hebt.

```
╔══════════════════════════════════════════════════════════════════════╗
║  CUIPER USB INSTALLATIERAPPORT                                       ║
╠══════════════════════════════════════════════════════════════════════╣
║  Datum:              ________________________________                 ║
║  Installateur:       ________________________________                 ║
║  Locatie (kantoor):  ________________________________                 ║
╠══════════════════════════════════════════════════════════════════════╣
║  USB DOELSCHIJF                                                      ║
║  Merk/model:         ________________________________                 ║
║  Capaciteit:         ________________________________  GB             ║
║  Serienummer:        ________________________________                 ║
║  Linux schijfnaam:   /dev/sd_    ← invullen bij stap 10              ║
╠══════════════════════════════════════════════════════════════════════╣
║  PARTITIES (invullen bij stap 14)                                    ║
║  BOOT partitie:      /dev/sd_1   UUID: ___________________________   ║
║  NIXOS partitie:     /dev/sd_2   UUID: ___________________________   ║
╠══════════════════════════════════════════════════════════════════════╣
║  LIVE ISO MEDIUM                                                     ║
║  Type (USB2/USB3/CD):________________________________                 ║
║  NixOS versie:       ________________________________                 ║
╠══════════════════════════════════════════════════════════════════════╣
║  INSTALLATIE COMPUTER                                                ║
║  Merk/model:         ________________________________                 ║
║  EFI / Legacy BIOS:  ________________________________                 ║
║  Boot volgorde:      ________________________________                 ║
╠══════════════════════════════════════════════════════════════════════╣
║  NETWERK (invullen bij stap 22)                                      ║
║  IP adres (live):    ________________________________                 ║
║  Verbindingstype:    WiFi / Ethernet (omcirkel)                      ║
╠══════════════════════════════════════════════════════════════════════╣
║  INSTALLATIE RESULTAAT                                               ║
║  nixos-install exit: ___  (0 = succes)   Tijdstip: ___________      ║
║  Eerste boot:        succes / fout (omcirkel)                        ║
║  API key ingevuld:   ja / nee (omcirkel)                             ║
║  SSH key aangemaakt: ja / nee (omcirkel)                             ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

## DEEL 1 — BENODIGDHEDEN (Controleer voor je begint)

- [ ] **1.** USB doelschijf ≥ 64 GB (USB 3.0 of sneller aanbevolen)
- [ ] **2.** Tweede USB of andere bootmedia met NixOS 24.11 ISO
      Download: `https://nixos.org/download` → Minimal ISO → x86_64-linux
- [ ] **3.** Computer met EFI (UEFI) boot support — geen legacy BIOS
- [ ] **4.** Stabiele internetverbinding (tijdens installatie downloadt NixOS pakketten)
- [ ] **5.** Dit document — afgedrukt of open in aparte editor
- [ ] **6.** Git installatie beschikbaar op live systeem (standaard aanwezig in NixOS ISO)
- [ ] **7.** Jouw `ANTHROPIC_API_KEY` bij de hand (voor ClaudeCode na installatie)

**Tijdsinschatting:** 45–90 minuten afhankelijk van USB-schrijfsnelheid en internetverbinding.

---

## DEEL 2 — LIVE ISO VOORBEREIDEN (op een apart systeem)

- [ ] **8.** Download het NixOS minimal ISO (x86_64-linux, nixos-24.11.x)
- [ ] **9.** Schrijf de ISO naar een tweede USB stick:
      ```bash
      # Linux:
      sudo dd if=nixos-minimal-24.11.x86_64-linux.iso of=/dev/sdX bs=4M status=progress
      # Windows: gebruik Rufus (mode: DD Image)
      # macOS:  sudo dd if=nixos-*.iso of=/dev/diskN bs=4m
      ```
      > Schrijf hier de naam van het live-medium op: `________________________`

---

## DEEL 3 — BIOS INSTELLEN

- [ ] **10.** Steek BEIDE USB sticks in de computer (live ISO + doelschijf)
- [ ] **11.** Herstart de computer
- [ ] **12.** Open BIOS/UEFI setup (meist **F2**, **F10**, **Del** of **Esc** bij opstarten)
        > Knop om BIOS te openen op deze computer: `__________`
- [ ] **13.** Zet **Secure Boot = Disabled**
- [ ] **14.** Zet boot volgorde: eerste = live ISO USB
- [ ] **15.** Sla op en herstart (F10 of "Save & Exit")

---

## DEEL 4 — BOOT VAN NIXOS LIVE

- [ ] **16.** Kies in het boot menu de NixOS live USB
- [ ] **17.** Wacht tot de NixOS prompt verschijnt: `[nixos@nixos:~]$`
        > Noteer eventuele foutmeldingen bij boot: `__________________________`
- [ ] **18.** Stel toetsenbord in op Nederlands (optioneel):
        ```bash
        sudo loadkeys nl
        ```

---

## DEEL 5 — NETWERK VERBINDEN

- [ ] **19.** Controleer of ethernet werkt:
        ```bash
        ip link
        ```
        Zie je een interface (bijv. `eth0`, `enp3s0`) met status `UP`? → ga naar stap 22

- [ ] **20.** WiFi verbinden (als ethernet niet beschikbaar is):
        ```bash
        sudo systemctl start wpa_supplicant
        wpa_cli
        ```
        In de wpa_cli shell:
        ```
        add_network
        set_network 0 ssid "NAAM_VAN_WIFI"
        set_network 0 psk "WACHTWOORD"
        enable_network 0
        quit
        ```

- [ ] **21.** Wacht op IP adres:
        ```bash
        ip addr show
        ```

- [ ] **22.** Test verbinding:
        ```bash
        ping -c 3 1.1.1.1
        ```
        > IP adres: `____________________` → schrijf in installatierapport (Deel 0)

---

## DEEL 6 — DOELSCHIJF IDENTIFICEREN

- [ ] **23.** Lijst alle schijven op:
        ```bash
        lsblk -o NAME,SIZE,MODEL,TRAN
        ```

- [ ] **24.** Identificeer de doelschijf (jouw grote USB):
        Zoek op grootte en model. Noteer de naam (bijv. `sdb`, `sdc`):
        > Doelschijf: `/dev/______` → schrijf ook in installatierapport (Deel 0)

        ⚠️ **WAARSCHUWING:** De volgende stappen wissen ALLES op deze schijf.
        Controleer dubbel dat je de juiste schijf hebt.

---

## DEEL 7 — SCHIJF PARTITIONEREN

Vervang `sdX` door jouw schijfnaam uit stap 24.

- [ ] **25.** Maak GPT partitietabel:
        ```bash
        sudo parted /dev/sdX -- mklabel gpt
        ```

- [ ] **26.** Maak EFI boot partitie (512 MB):
        ```bash
        sudo parted /dev/sdX -- mkpart ESP fat32 1MiB 512MiB
        sudo parted /dev/sdX -- set 1 esp on
        ```

- [ ] **27.** Maak hoofd NixOS partitie (rest van schijf):
        ```bash
        sudo parted /dev/sdX -- mkpart primary 512MiB 100%
        ```

- [ ] **28.** Controleer partities:
        ```bash
        lsblk /dev/sdX
        ```
        Verwacht: `sdX1` (512M) en `sdX2` (rest)

---

## DEEL 8 — BESTANDSSYSTEMEN AANMAKEN

- [ ] **29.** Formatteer boot partitie (FAT32, label BOOT):
        ```bash
        sudo mkfs.fat -F 32 -n BOOT /dev/sdX1
        ```

- [ ] **30.** Formatteer NixOS partitie (btrfs, label NIXOS):
        ```bash
        sudo mkfs.btrfs -L NIXOS -f /dev/sdX2
        ```

- [ ] **31.** Noteer de UUIDs (voor verificatie later):
        ```bash
        sudo blkid /dev/sdX1 /dev/sdX2
        ```
        > BOOT UUID: `____________________________________`
        > NIXOS UUID: `____________________________________`
        Schrijf deze ook in het installatierapport (Deel 0).

---

## DEEL 9 — BTRFS SUBVOLUMES AANMAKEN

- [ ] **32.** Mount de btrfs partitie tijdelijk:
        ```bash
        sudo mount /dev/sdX2 /mnt
        ```

- [ ] **33.** Maak alle subvolumes aan:
        ```bash
        sudo btrfs subvolume create /mnt/@
        sudo btrfs subvolume create /mnt/@home
        sudo btrfs subvolume create /mnt/@nix
        sudo btrfs subvolume create /mnt/@data
        sudo btrfs subvolume create /mnt/@projects
        sudo btrfs subvolume create /mnt/@snapshots
        ```

- [ ] **34.** Controleer subvolumes:
        ```bash
        sudo btrfs subvolume list /mnt
        ```
        Verwacht: 6 subvolumes (@, @home, @nix, @data, @projects, @snapshots)

- [ ] **35.** Ontkoppel tijdelijke mount:
        ```bash
        sudo umount /mnt
        ```

---

## DEEL 10 — BESTANDSSYSTEMEN KOPPELEN VOOR INSTALLATIE

- [ ] **36.** Mount hoofdvolume:
        ```bash
        sudo mount -o subvol=@,compress=zstd,noatime,ssd_spread /dev/sdX2 /mnt
        ```

- [ ] **37.** Maak koppelpunten aan:
        ```bash
        sudo mkdir -p /mnt/{boot,home,nix,data,projects,.snapshots}
        ```

- [ ] **38.** Koppel alle subvolumes:
        ```bash
        sudo mount /dev/sdX1 /mnt/boot
        sudo mount -o subvol=@home,compress=zstd,noatime /dev/sdX2 /mnt/home
        sudo mount -o subvol=@nix,compress=zstd,noatime /dev/sdX2 /mnt/nix
        sudo mount -o subvol=@data,compress=zstd,noatime /dev/sdX2 /mnt/data
        sudo mount -o subvol=@projects,compress=zstd,noatime /dev/sdX2 /mnt/projects
        sudo mount -o subvol=@snapshots,noatime /dev/sdX2 /mnt/.snapshots
        ```

- [ ] **39.** Controleer alle mounts:
        ```bash
        findmnt /mnt
        ```
        Verwacht: 6 koppelpunten actief

---

## DEEL 11 — NIXOS CONFIGURATIE OPHALEN

- [ ] **40.** Maak config map aan:
        ```bash
        sudo mkdir -p /mnt/home/reparateur/.config
        ```

- [ ] **41.** Clone de CuiperHive configuratie:
        ```bash
        sudo git clone https://github.com/nixdeva1-design/DevaNixClaudeCode \
          /mnt/home/reparateur/.config/nixos
        ```
        > Clone geslaagd? ja / nee: `______`
        > Foutmelding (als nee): `__________________________`

        **Alternatief als geen internet beschikbaar:**
        ```bash
        # Kopieer van een derde USB stick waarop de repo staat:
        sudo rsync -av /media/usb/DevaNixClaudeCode/ \
          /mnt/home/reparateur/.config/nixos/
        ```

- [ ] **42.** Controleer dat flake.nix aanwezig is:
        ```bash
        ls /mnt/home/reparateur/.config/nixos/nixos/flake.nix
        ```

---

## DEEL 12 — NIXOS INSTALLEREN

- [ ] **43.** Kies het juiste klantprofiel:

        | Profiel       | Gebruik                                    | Commando               |
        |---------------|--------------------------------------------|------------------------|
        | `standaard`   | Volledige werkplek, alle services          | `#standaard`           |
        | `ai-werkstation` | Alleen AI/ML focus (Ollama, MindsDB)    | `#ai-werkstation`      |
        | `minimal`     | Alleen Gitea + PostgreSQL + Redis          | `#minimal`             |

        > Gekozen profiel: `____________________`

- [ ] **44.** Start de NixOS installatie:
        ```bash
        sudo nixos-install \
          --flake /mnt/home/reparateur/.config/nixos/nixos#standaard \
          --no-root-passwd
        ```
        Vervang `standaard` door jouw gekozen profiel uit stap 43.

        > ⏱ Dit duurt 10–45 minuten afhankelijk van internetsnelheid.
        > Pakketten worden gedownload. Normale output ziet er zo uit:
        > `building the system configuration...`
        > `copying path '/nix/store/...' from 'https://cache.nixos.org'...`

- [ ] **45.** Noteer het resultaat:
        > nixos-install exit code: `______` (0 = succes, iets anders = fout → zie Deel 9)
        > Tijdstip klaar: `______________`

---

## DEEL 13 — WACHTWOORD INSTELLEN

- [ ] **46.** Stel wachtwoord in voor gebruiker `reparateur`:
        ```bash
        sudo nixos-enter --root /mnt -c 'passwd reparateur'
        ```
        Voer een sterk wachtwoord in en herhaal.
        > Wachtwoord opgeslagen in wachtwoordmanager: ja / nee

---

## DEEL 14 — ONTKOPPELEN EN OPNIEUW OPSTARTEN

- [ ] **47.** Ontkoppel alles:
        ```bash
        sudo umount -R /mnt
        ```

- [ ] **48.** Verwijder de live ISO USB (niet de nieuwe NixOS USB)

- [ ] **49.** Herstart:
        ```bash
        sudo reboot
        ```

- [ ] **50.** Selecteer in BIOS de nieuwe NixOS USB als eerste bootoptie
        > Boot van nieuwe USB geslaagd: ja / nee

---

## DEEL 15 — EERSTE BOOT VERIFICATIE

Na inloggen als `reparateur` met het ingestelde wachtwoord:

- [ ] **51.** Controleer NixOS versie:
        ```bash
        nixos-version
        ```
        > Versie: `____________________`

- [ ] **52.** Controleer actieve services:
        ```bash
        systemctl --failed
        ```
        > Aantal gefaalde services: `______` (verwacht: 0)
        > Gefaalde services (als > 0): `__________________________`

- [ ] **53.** Controleer PostgreSQL:
        ```bash
        psql -U reparateur -c "SELECT datname FROM pg_database;"
        ```
        Verwacht: `reparateur`, `gitea`, `n8n`, `grafana`, `mlflow`, `postgres`, `template0`, `template1`

- [ ] **54.** Controleer Gitea:
        ```bash
        curl -s http://localhost:3001 | grep -i gitea
        ```
        > Antwoord ontvangen: ja / nee

- [ ] **55.** Controleer Ollama (als standaard profiel):
        ```bash
        curl -s http://localhost:11434/api/tags | head -c 100
        ```
        > Antwoord ontvangen: ja / nee

- [ ] **56.** Controleer Jaeger UI:
        ```bash
        curl -s http://localhost:16686 | grep -i jaeger
        ```
        > Antwoord ontvangen: ja / nee

---

## DEEL 16 — CLAUDECODE INSTELLEN

- [ ] **57.** Controleer of claude-code CLI beschikbaar is:
        ```bash
        claude --version
        ```
        > Versie: `____________________`

- [ ] **58.** Maak API key bestand aan:
        ```bash
        cp ~/.config/claude/.env.template ~/.config/claude/.env
        nano ~/.config/claude/.env
        ```
        Vervang `sk-ant-JOUW_KEY_HIER` door jouw echte Anthropic API key.
        > API key ingevuld: ja / nee

- [ ] **59.** Test ClaudeCode verbinding:
        ```bash
        cd /projects
        claude --print "Bevestig dat je verbonden bent. Zeg: CuiperHive USB gereed."
        ```
        > Antwoord ontvangen: ja / nee
        > Eerste woorden van antwoord: `__________________________`

---

## DEEL 17 — SSH SLEUTEL AANMAKEN

- [ ] **60.** Genereer SSH sleutelpaar:
        ```bash
        ssh-keygen -t ed25519 -C "reparateur@cuiper-usb" -f ~/.ssh/id_ed25519
        ```

- [ ] **61.** Voeg SSH publieke sleutel toe aan `~/.ssh/authorized_keys` (voor remote toegang):
        ```bash
        cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
        ```

- [ ] **62.** Noteer de publieke sleutel (bewaar extern):
        ```bash
        cat ~/.ssh/id_ed25519.pub
        ```
        > Sla op in wachtwoordmanager of beveiligde map.

---

## DEEL 18 — MINDSDB INSTALLEREN (als standaard/ai-werkstation profiel)

MindsDB is niet in nixpkgs — handmatige installatie vereist.

- [ ] **63.** Maak Python venv aan:
        ```bash
        python3 -m venv /data/mindsdb/env
        ```

- [ ] **64.** Installeer MindsDB (neemt 5–15 minuten):
        ```bash
        /data/mindsdb/env/bin/pip install mindsdb
        ```

- [ ] **65.** Start MindsDB service:
        ```bash
        sudo systemctl start mindsdb
        sudo systemctl status mindsdb
        ```
        > Status: active / failed: `______________`

---

## DEEL 19 — NIXOS CONFIGURATIE ACTIVEREN OP USB

De configuratie staat in `/home/reparateur/.config/nixos/`. Bij toekomstige updates:

```bash
# Basis rebuild commando:
sudo nixos-rebuild switch --flake /home/reparateur/.config/nixos/nixos#standaard

# Alias (al ingesteld in Fish shell):
rebuild
```

- [ ] **66.** Test het rebuild commando (eerste keer na installatie):
        ```bash
        sudo nixos-rebuild switch --flake /home/reparateur/.config/nixos/nixos#standaard
        ```
        > Exit code: `______` (0 = succes)

---

## DEEL 20 — EINDCONTROLE INSTALLATIERAPPORT

Vul het installatierapport in Deel 0 volledig in. Controleer:

- [ ] **67.** Alle velden in Deel 0 ingevuld
- [ ] **68.** Probleemlogboek (Deel 9 hieronder) bijgewerkt
- [ ] **69.** Wachtwoord opgeslagen in wachtwoordmanager
- [ ] **70.** SSH publieke sleutel bewaard extern
- [ ] **71.** API key ingesteld en getest
- [ ] **72.** USB werkt op minimaal één kantoorcomputer

**Installatie gereed.** De USB is nu een volledig functioneel CuiperHive werkstation.

---

## DEEL 9 — PROBLEEMLOGBOEK (Scaffolding: invullen bij problemen)

> Elke fout hier opschrijven. Niets is te klein. Fouten zijn eerste-principes materiaal.

```
╔══════════════════════════════════════════════════════════════════════════╗
║  PROBLEEMLOGBOEK                                                         ║
╠══════════════════════════════════════════════════════════════════════════╣
║  Nr  │ Stap │ Foutcode/melding                │ Oplossing / status       ║
╠══════════════════════════════════════════════════════════════════════════╣
║   1  │      │                                 │                          ║
║   2  │      │                                 │                          ║
║   3  │      │                                 │                          ║
║   4  │      │                                 │                          ║
║   5  │      │                                 │                          ║
╚══════════════════════════════════════════════════════════════════════════╝
```

### Bekende foutcodes en oplossingen

| Symptoom | Oorzaak | Oplossing |
|----------|---------|-----------|
| `nixos-install` faalt met `error: ... is not a valid flake` | Verkeerd pad naar flake | Controleer stap 41 en 44 — pad moet eindigen op `.../nixos#profiel` |
| `error: getting status of '/nix/store/...'` tijdens install | Onvoldoende schijfruimte | USB te klein of te vol. Gebruik ≥ 64 GB |
| `fatal: repository not found` bij git clone | Geen internettoegang of verkeerde URL | Controleer netwerk (stap 22). Gebruik rsync alternatief (stap 41) |
| Service `failed` na eerste boot | Database ontbreekt | Voer uit: `psql -U reparateur -c "CREATE DATABASE <naam>;"` |
| `claude: command not found` | Node.js pakketten niet gebuild | `nix-env -iA nixos.nodePackages.claude-code` of `rebuild` uitvoeren |
| Boot blijft hangen op `Loading initial ramdisk` | USB te traag voor live ISO | Gebruik een snellere USB voor live ISO. Doelschijf kan langzamer |
| `mkfs.btrfs: /dev/sdX2 is apparently in use` | Partitie gemount | `sudo umount /dev/sdX2` en opnieuw proberen |
| `parted` geeft `Device or resource busy` | Schijf gemount | `sudo umount -R /dev/sdX*` dan opnieuw stap 25 |
| MindsDB start niet | Venv niet aangemaakt | Voer stap 63–65 uit |
| Gitea niet bereikbaar op poort 3001 | PostgreSQL db `gitea` ontbreekt | `psql -U reparateur -c "CREATE DATABASE gitea OWNER reparateur;"` |

---

## BIJLAGE A — SNELREFERENTIE COMMANDO'S (na installatie)

```bash
# NixOS herladen na config wijziging
sudo nixos-rebuild switch --flake ~/.config/nixos/nixos#standaard

# Services bekijken
systemctl list-units --type=service --state=running

# PostgreSQL databases tonen
psql -U reparateur -c "\l"

# Logs van een service
journalctl -u gitea -f

# Btrfs snapshot maken
sudo btrfs subvolume snapshot /data /data/.snapshots/$(date +%Y%m%d)

# ClaudeCode starten in project
cd /projects && claude
```

---

## BIJLAGE B — KANTOOR GEBRUIK OP MEERDERE COMPUTERS

De USB USB werkt op iedere UEFI-computer. Procedure:

1. Steek USB in computer
2. Herstart → BIOS → boot volgorde: USB eerst
3. Log in als `reparateur`
4. Werk in `/projects` voor klantwerk of `/lab` voor experimenten
5. Commit en push voor afsluiten

**Opmerking:** Elke computer kan een andere schijfnaam geven aan de USB (`sdb`, `sdc`, `nvme0n1`). Dit is normaal — de partities worden herkend via label (`NIXOS`, `BOOT`), niet via schijfnaam.

---

## BIJLAGE C — PROFIEL WISSELEN

```bash
# Van standaard naar ai-werkstation:
sudo nixos-rebuild switch --flake ~/.config/nixos/nixos#ai-werkstation

# Van standaard naar minimal (bijv. voor een snelle client demo):
sudo nixos-rebuild switch --flake ~/.config/nixos/nixos#minimal
```

---

*CuiperAGINixOSHandleiding — CuiperStapNr 55 — ULID: 01COMP048HANDLEIDING000000*
*Erft via: CuiperCore → CuiperDonut → nixos/flake.nix*
