# T3 Code COPR Repository

Automated RPM packaging for [pingdotgg/t3code](https://github.com/pingdotgg/t3code), synced daily via GitHub Actions and built on Fedora COPR.

[![Copr build status](https://copr.fedorainfracloud.org/coprs/frugally7417/t3code/package/t3code/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/frugally7417/t3code/)
[![Copr build status](https://copr.fedorainfracloud.org/coprs/frugally7417/t3code/package/t3code-nightly/status_image/last_build.png)](https://copr.fedorainfracloud.org/coprs/frugally7417/t3code/)

## Enable COPR

```sh
sudo dnf copr enable frugally7417/t3code
```

## Install

Stable channel (`t3code`):

```sh
sudo dnf install t3code
```

Nightly channel (`t3code-nightly`):

```sh
sudo dnf install t3code-nightly
```

## Automatic DNF Updates (Fedora 41+)

```sh
sudo dnf install dnf5-plugin-automatic
sudo systemctl enable --now dnf5-automatic.timer
```
