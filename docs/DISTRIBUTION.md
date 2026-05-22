# Distribution

## 1) GitHub Release Automation

A tag push (example `v3.0.1`) triggers `.github/workflows/release.yml`.

Produced assets:

- `gitss_<version>_linux_amd64.tar.gz`
- `gitss_<version>_linux_amd64.tar.gz.sha256`
- `gitss_<version>_linux_amd64.deb`
- `checksums.txt`

## 2) Homebrew Tap

Create a dedicated tap repository, for example:

- `previraza/homebrew-gitss`

Then for each release:

1. Get SHA256 of the tarball from release assets.
2. Update formula locally:

```bash
./scripts/update-homebrew-formula.sh 3.0.0 <sha256>
```

3. Publish into your tap repo:

```bash
./scripts/publish-homebrew-formula.sh 3.0.0 <sha256> /path/to/homebrew-gitss
```

4. In tap repo, commit and push `Formula/gitss.rb`.

User install command:

```bash
brew tap previraza/gitss
brew install gitss
```

## 3) Debian Package (.deb)

`nfpm` config is in `packaging/nfpm.yaml`.

Local build example:

```bash
VERSION=3.0.0 nfpm package --config packaging/nfpm.yaml --packager deb --target dist/gitss_3.0.0_linux_amd64.deb
```

Install:

```bash
sudo dpkg -i dist/gitss_3.0.0_linux_amd64.deb
```
