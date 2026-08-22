# Lokales Setup (Prerequisites)

Werkzeuge, die auf der Arbeitsmaschine gebraucht werden, um mit diesem Repo zu
arbeiten. Getestet auf **Ubuntu 26.04**.

> Reproduzierbare Tool-Versionen (mise/asdf via `.tool-versions`) folgen in
> Schritt 2. Dieses Dokument sammelt die einmalige Installation der Basis-CLIs.

## GitHub CLI (`gh`) — optional

`gh` ist **nicht zwingend**: Ein Repo anlegen und pushen geht auch mit reinem
`git` plus Browser. `gh` ist Komfort und wird vor allem später nützlich
(Pull Requests, Issues, das Setzen von Actions-Secrets im CI/CD-Teil).

### Warum die offizielle apt-Quelle – nicht Snap, nicht das Ubuntu-Paket

- **Snap:** Von den `gh`-Maintainern ausdrücklich abgeraten. Die Sandbox
  blockiert unter anderem den Zugriff auf lokale SSH-Keys und die
  Git-Konfiguration – genau das, was man mit `gh` braucht.
- **Ubuntu-Paket (`apt install gh`, 2.46.x):** veraltet und wegen deprecateter
  GitHub-APIs teils defekt.
- **Offizielle GitHub-apt-Quelle:** aktuelle Version, Updates über das normale
  `apt upgrade`, keine Sandbox. Eine Quelle, funktioniert auf 26.04 unverändert.

### Installation (Ubuntu 26.04, DEB822-Stil)

Signaturschlüssel nach `/etc/apt/keyrings/` ablegen (der vorgesehene Ort für
manuell hinzugefügte Drittanbieter-Keys):

```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
```

Paketquelle im DEB822-Format (`.sources` – der neue Standard, ersetzt die alte
`.list`-Einzeilersyntax):

```bash
sudo tee /etc/apt/sources.list.d/github-cli.sources > /dev/null <<EOF
Types: deb
URIs: https://cli.github.com/packages
Suites: stable
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/githubcli-archive-keyring.gpg
EOF
```

Installieren und prüfen:

```bash
sudo apt update
sudo apt install gh
gh --version
```

> Feldzuordnung alt → DEB822, falls du eine `.list`-Anleitung übersetzen musst:
> `deb` → `Types`, URL → `URIs`, `stable` → `Suites`, `main` → `Components`,
> `[signed-by=…]` → `Signed-By`.

### Anmeldung (SSH)

```bash
gh auth login   # GitHub.com  ->  SSH  ->  vorhandenen Key nutzen
```

Zwei getrennte Ebenen, die hier zusammenkommen: `gh` gegenüber der GitHub-API
(um z. B. ein Repo anzulegen) und der SSH-Key gegenüber Git (um zu pushen).
`gh auth login` mit SSH-Protokoll verdrahtet beides in einem Schritt.


## OpenTofu via mise

Werkzeugversionen sind über [mise](https://mise.jdx.dev) gepinnt (`mise.toml`),
damit lokal und in CI exakt dieselbe Version läuft.

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
mise install             # installiert die in mise.toml gepinnten Versionen
tofu version             # Kontrolle
```

Beim ersten Betreten nach dem Klonen fragt mise nach Vertrauen: `mise trust`.


---

## Weitere Werkzeuge

_Folgt in Schritt 2 (Tooling): OpenTofu, mise + `.tool-versions`, kubectl._
