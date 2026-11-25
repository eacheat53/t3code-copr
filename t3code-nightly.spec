%global debug_package %{nil}
%global _debugsource_packages 0
%global __strip /bin/true
%global __brp_check_rpaths %{nil}
%global _build_id_links none
%global __provides_exclude_from ^/opt/%{name}/.*$
%global __requires_exclude_from ^/opt/%{name}/.*$

%global upstream_tag v0.1.12-nightly.20261125.5230
%global package_version 0.1.12~nightly.20261125.5230

Name:           t3code-nightly
Version:        %{package_version}
Release:        1%{?dist}
Summary:        Nightly desktop control surface for local coding agents

License:        MIT
URL:            https://github.com/pingdotgg/t3code
Source0:        https://github.com/pingdotgg/t3code/releases/download/v0.1.12-nightly.20261125.5230/T3-Code-Nightly-x86_64.AppImage#/%{name}-%{version}-x86_64.AppImage
Source1:        https://raw.githubusercontent.com/pingdotgg/t3code/%{upstream_tag}/LICENSE#/%{name}-%{version}-LICENSE

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
cat <<'LAUNCHER' > %{buildroot}%{_bindir}/t3code-nightly
#!/bin/sh
# AppRun computes APPDIR but doesn't export it; T3 Code server needs APPDIR to scrub AppImage libs from agent shells.
exec env APPDIR=/opt/%{name} /opt/%{name}/AppRun "$@"
LAUNCHER
chmod 0755 %{buildroot}%{_bindir}/t3code-nightly
ln -s t3code-nightly %{buildroot}%{_bindir}/t3-code-nightly-desktop

for icon in squashfs-root/usr/share/icons/hicolor/*/apps/t3code.png; do
  size_dir="${icon%/apps/t3code.png}"
  size="${size_dir##*/}"
  install -Dpm0644 "$icon"     %{buildroot}%{_datadir}/icons/hicolor/${size}/apps/t3code-nightly.png
done

install -dm0755 %{buildroot}%{_datadir}/applications
cat <<'DESKTOP' > %{buildroot}%{_datadir}/applications/t3code-nightly.desktop
[Desktop Entry]
Name=T3 Code Nightly
Comment=Nightly desktop control surface for local coding agents
Exec=t3code-nightly %U
TryExec=t3code-nightly
Terminal=false
Type=Application
Icon=t3code-nightly
StartupWMClass=com.t3tools.T3Code
Categories=Development;
MimeType=x-scheme-handler/t3code;
DESKTOP

%files
%license LICENSE
/opt/%{name}
%attr(4755,root,root) /opt/%{name}/chrome-sandbox
%{_bindir}/t3code-nightly
%{_bindir}/t3-code-nightly-desktop
%{_datadir}/applications/t3code-nightly.desktop
%{_datadir}/icons/hicolor/*/apps/t3code-nightly.png

%changelog
* Wed Nov 25 2026 Automation <actions@github.com> - 0.1.12~nightly.20261125.5230-1
- Repackage upstream v0.1.12-nightly.20261125.5230
