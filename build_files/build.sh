#!/bin/bash

set -ouex pipefail

# Copy Files to Container
rsync -rvKl /ctx/system_files/shared/ /

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# Add Flathub to the image for eventual application
mkdir -p /etc/flatpak/remotes.d/
curl --retry 3 -Lo /etc/flatpak/remotes.d/flathub.flatpakrepo https://dl.flathub.org/repo/flathub.flatpakrepo

# this installs a package from fedora repos
dnf5 install -y niri alacritty nwg-launchers waybar mako xwayland-satellite swaybg network-manager-applet nautilus gvfs gvfs-fuse pavucontrol xfce-polkit

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

dnf5 -y copr enable sed4906/compositv
dnf5 -y install wvkbd
dnf5 -y copr disable sed4906/compositv

# TODO: remove me on next flatpak release when preinstall landed in Fedora
dnf5 -y copr enable ublue-os/flatpak-test
dnf5 -y --repo=copr:copr.fedorainfracloud.org:ublue-os:flatpak-test swap flatpak flatpak
dnf5 -y --repo=copr:copr.fedorainfracloud.org:ublue-os:flatpak-test swap flatpak-libs flatpak-libs
dnf5 -y --repo=copr:copr.fedorainfracloud.org:ublue-os:flatpak-test swap flatpak-session-helper flatpak-session-helper
dnf5 -y --repo=copr:copr.fedorainfracloud.org:ublue-os:flatpak-test install flatpak-debuginfo flatpak-libs-debuginfo flatpak-session-helper-debuginfo
dnf5 -y copr disable ublue-os/flatpak-test

echo "application/vnd.flatpak.ref=io.github.kolunmi.Bazaar.desktop" >> /usr/share/applications/mimeapps.list

#### Example for enabling a System Unit File

systemctl enable podman.socket
systemctl enable flatpak-preinstall.service
systemctl enable flatpak-nuke-fedora.service
systemctl disable flatpak-add-fedora-repos.service
systemctl --global enable niri.service
systemctl --global add-wants niri.service mako.service
systemctl --global add-wants niri.service waybar.service
systemctl --global add-wants niri.service swaybg.service

IMAGE_PRETTY_NAME="ter"
VERSION="${VERSION:-00.00000000}"
CODE_NAME="1, 1 bis, 1 ter"

sed -i "s|^PRETTY_NAME=.*|PRETTY_NAME=\"${IMAGE_PRETTY_NAME}\"|" /usr/lib/os-release
sed -i "s|^NAME=.*|NAME=\"$IMAGE_PRETTY_NAME\"|" /usr/lib/os-release
sed -i "s|^VERSION_CODENAME=.*|VERSION_CODENAME=\"$CODE_NAME\"|" /usr/lib/os-release

KERNEL_VERSION=$(rpm -q --queryformat="%{evr}.%{arch}" kernel-core)

# Ensure Initramfs is generated
export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "${KERNEL_VERSION}" --reproducible -v --add "ostree fido2 tpm2-tss pkcs11 pcsc" -f "/lib/modules/${KERNEL_VERSION}/initramfs.img"
chmod 0600 "/lib/modules/${KERNEL_VERSION}/initramfs.img"

rm -r /usr/share/doc
