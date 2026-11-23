#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_REPO="pingdotgg/t3code"
GITHUB_API_HEADERS=(-H "Accept: application/vnd.github+json")
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  GITHUB_API_HEADERS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

fetch_release_json() {
  local channel="$1"
  if [[ "$channel" == "stable" ]]; then
    curl -fsSL "${GITHUB_API_HEADERS[@]}" \
      "https://api.github.com/repos/${UPSTREAM_REPO}/releases/latest"
  else
    curl -fsSL "${GITHUB_API_HEADERS[@]}" \
      "https://api.github.com/repos/${UPSTREAM_REPO}/releases?per_page=20" | jq -e '
      [.[] | select(.tag_name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+-nightly\\."))] | .[0]
    '
  fi
}

generate_one_spec() {
  local channel="$1"
  local pkgname desktop_name comment_text desktop_file icon_name bin_name alt_bin_name conflict_line

  if [[ "$channel" == "stable" ]]; then
    pkgname="t3code"
    desktop_name="T3 Code"
    comment_text="Desktop control surface for local coding agents"
    desktop_file="t3code.desktop"
    icon_name="t3code"
    bin_name="t3code"
    alt_bin_name="t3-code-desktop"
    conflict_line=""
  else
    pkgname="t3code-nightly"
    desktop_name="T3 Code Nightly"
    comment_text="Nightly desktop control surface for local coding agents"
    desktop_file="t3code-nightly.desktop"
    icon_name="t3code-nightly"
    bin_name="t3code-nightly"
    alt_bin_name="t3-code-nightly-desktop"
    conflict_line=""
  fi

  local rel_json tag raw_ver rpm_ver asset_name asset_url spec_file
  rel_json="$(fetch_release_json "$channel")"
  tag="$(jq -r '.tag_name' <<<"$rel_json")"
  if [[ -z "$tag" || "$tag" == "null" ]]; then
    echo "Failed to resolve latest ${channel} tag from ${UPSTREAM_REPO}" >&2
    return 1
  fi

  asset_name="$(jq -er '
    [.assets[] | select(.name | test("^T3-Code(-Nightly|-[0-9].*)?-x86_64\\.AppImage$"))]
    | .[0].name
  ' <<<"$rel_json")"
  asset_url="$(jq -er --arg name "$asset_name" '
    [.assets[] | select(.name == $name)] | .[0].browser_download_url
  ' <<<"$rel_json")"

  raw_ver="${tag#v}"
  # RPM treats '~' as pre-release (lower than final release), so 0.1.12~nightly.* < 0.1.12
  rpm_ver="${raw_ver//-nightly./~nightly.}"
  spec_file="${pkgname}.spec"

  cat <<EOF > "$spec_file"
%global debug_package %{nil}
%global _debugsource_packages 0
%global __strip /bin/true
%global __brp_check_rpaths %{nil}
%global _build_id_links none
%global __provides_exclude_from ^/opt/%{name}/.*$
%global __requires_exclude_from ^/opt/%{name}/.*$

%global upstream_tag ${tag}
%global package_version ${rpm_ver}

Name:           ${pkgname}
Version:        %{package_version}
Release:        1%{?dist}
Summary:        ${comment_text}

License:        MIT
URL:            https://github.com/${UPSTREAM_REPO}
Source0:        ${asset_url}#/%{name}-%{version}-x86_64.AppImage
Source1:        https://raw.githubusercontent.com/${UPSTREAM_REPO}/%{upstream_tag}/LICENSE#/%{name}-%{version}-LICENSE

ExclusiveArch:  x86_64

Requires:       alsa-lib
Requires:       at-spi2-core
Requires:       bash
Requires:       cairo
Requires:       cups-libs
Requires:       dbus-libs
Requires:       expat
Requires:       glib2
Requires:       gtk3
Requires:       hicolor-icon-theme
Requires:       libX11
Requires:       libXScrnSaver
Requires:       libXcomposite
Requires:       libXcursor
Requires:       libXdamage
Requires:       libXext
Requires:       libXfixes
Requires:       libXi
Requires:       libXrandr
Requires:       libXtst
Requires:       libdrm
Requires:       libnotify
Requires:       libsecret
Requires:       libxcb
Requires:       libxkbcommon
Requires:       mesa-libgbm
Requires:       nspr
Requires:       nss
Requires:       pango
Requires:       systemd-libs
Requires:       xdg-utils

%description
T3 Code is a minimal desktop GUI for local coding agents (Codex, Claude Code,
and more), repackaged into an RPM from the official Linux AppImage release.

%prep
rm -rf squashfs-root
cp -p %{SOURCE0} ./t3code.AppImage
cp -p %{SOURCE1} ./LICENSE
chmod +x ./t3code.AppImage
./t3code.AppImage --appimage-extract >/dev/null
test -x squashfs-root/AppRun
test -f squashfs-root/chrome-sandbox

%build
# Upstream ships prebuilt Electron/Node/Rust binaries inside the AppImage.

%install
install -dm0755 %{buildroot}/opt/%{name}
cp -a squashfs-root/. %{buildroot}/opt/%{name}/
chmod -R u=rwX,go=rX %{buildroot}/opt/%{name}

install -dm0755 %{buildroot}%{_bindir}
cat <<'LAUNCHER' > %{buildroot}%{_bindir}/${bin_name}
#!/bin/sh
# AppRun computes APPDIR but doesn't export it; T3 Code server needs APPDIR to scrub AppImage libs from agent shells.
exec env APPDIR=/opt/%{name} /opt/%{name}/AppRun "\$@"
LAUNCHER
chmod 0755 %{buildroot}%{_bindir}/${bin_name}
ln -s ${bin_name} %{buildroot}%{_bindir}/${alt_bin_name}

for icon in squashfs-root/usr/share/icons/hicolor/*/apps/t3code.png; do
  size_dir="\${icon%/apps/t3code.png}"
  size="\${size_dir##*/}"
  install -Dpm0644 "\$icon" \
    %{buildroot}%{_datadir}/icons/hicolor/\${size}/apps/${icon_name}.png
done

install -dm0755 %{buildroot}%{_datadir}/applications
cat <<'DESKTOP' > %{buildroot}%{_datadir}/applications/${desktop_file}
[Desktop Entry]
Name=${desktop_name}
Comment=${comment_text}
Exec=${bin_name} %U
TryExec=${bin_name}
Terminal=false
Type=Application
Icon=${icon_name}
StartupWMClass=com.t3tools.T3Code
Categories=Development;
MimeType=x-scheme-handler/t3code;
DESKTOP

%files
%license LICENSE
/opt/%{name}
%attr(4755,root,root) /opt/%{name}/chrome-sandbox
%{_bindir}/${bin_name}
%{_bindir}/${alt_bin_name}
%{_datadir}/applications/${desktop_file}
%{_datadir}/icons/hicolor/*/apps/${icon_name}.png

%changelog
* $(LC_ALL=C date "+%a %b %d %Y") Automation <actions@github.com> - ${rpm_ver}-1
- Repackage upstream ${tag}
EOF

  echo "Generated ${spec_file} for upstream ${tag} (RPM version: ${rpm_ver})"
}

generate_one_spec "stable"
generate_one_spec "nightly"
