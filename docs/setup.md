# Lokales Setup (Prerequisites)

Werkzeuge, die auf der Arbeitsmaschine gebraucht werden, um mit diesem Repo zu
arbeiten. Getestet auf **Ubuntu 26.04**.

> Reproduzierbare Tool-Versionen sind über mise (`mise.toml`, siehe ADR-0004)
> gepinnt. Dieses Dokument sammelt die einmalige Installation der Basis-CLIs.

## mise (polyglotter Werkzeug-Manager)

Alle CLI-Tools dieses Projekts sind über [mise](https://mise.jdx.dev) gepinnt
– die vollständige, aktuelle Toolliste steht in [`mise.toml`](../../mise.toml)
(Repo-Wurzel), nicht in diesem Dokument. `mise install` holt immer exakt die
dort gepinnten Versionen, lokal wie in CI.

### mise installieren (Ubuntu 26.04)

```bash
sudo add-apt-repository -y ppa:jdxcode/mise
sudo apt update
sudo apt install -y mise
```

### Aktivieren und Tools holen

```bash
echo 'eval "$(mise activate bash)"' >> ~/.bashrc && source ~/.bashrc
mise use -g usage        # Tab-Vervollständigung (optional)
mise install             # installiert ALLE in mise.toml gepinnten Tools
tofu version              # Kontrolle
gh --version              # Kontrolle
```

Beim ersten Betreten nach dem Klonen fragt mise nach Vertrauen: `mise trust`.

## GitHub CLI (`gh`) — optional

`gh` ist **nicht zwingend**: Ein Repo anlegen und pushen geht auch mit reinem
`git` plus Browser. `gh` ist Komfort und wird vor allem später nützlich
(Pull Requests, Issues, das Setzen von Actions-Secrets im CI/CD-Teil). Wird
bereits durch `mise install` oben mitinstalliert.

### Anmeldung (SSH)

```bash
gh auth login   # GitHub.com  ->  SSH  ->  vorhandenen Key nutzen
```

Zwei getrennte Ebenen, die hier zusammenkommen: `gh` gegenüber der GitHub-API
(um z. B. ein Repo anzulegen) und der SSH-Key gegenüber Git (um zu pushen).
`gh auth login` mit SSH-Protokoll verdrahtet beides in einem Schritt.

## Secrets: SOPS + age

Geheimnisse werden mit [SOPS](https://github.com/getsops/sops) verschlüsselt
(nur die Werte, nicht die Struktur), Krypto-Backend ist [age](https://age-encryption.org).
`sops` und `age` sind ebenfalls über mise gepinnt (siehe `mise.toml`), bereits
durch `mise install` oben mitinstalliert.

### age-Schlüsselpaar erzeugen

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt   # SOPS findet diesen Pfad automatisch
chmod 600 ~/.config/sops/age/keys.txt
```

`age-keygen` gibt den **öffentlichen** Schlüssel aus (`age1…`); jederzeit erneut
abrufbar mit `age-keygen -y ~/.config/sops/age/keys.txt`. Er gehört in die
`.sops.yaml` (siehe Repo-Wurzel).

> **Privater Schlüssel** (`~/.config/sops/age/keys.txt`): nie ins Repo, außerhalb
> der Maschine sichern (Passwortmanager). Verlust = Secrets unwiderruflich weg.

### Secret bearbeiten

```bash
sops edit pfad/zur/datei.sops.yaml   # entschlüsselt zum Editieren, verschlüsselt beim Speichern
```

> **mise + SOPS:** mises eingebautes SOPS sucht den age-Schlüssel unter
> `~/.config/mise/age.txt`, nicht am Standard-SOPS-Pfad. Damit es (und das
> `sops`-CLI) denselben Schlüssel nutzen, in die Shell-RC aufnehmen:
> `export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"`.

---

## Weitere Werkzeuge

_Folgt in Phase 3 (k3s-Cluster): kubectl._
