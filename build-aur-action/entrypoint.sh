#!/bin/bash

pkgname=$1

useradd builder -m
echo "builder ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers
chmod -R a+rw .

cat <<EOM >>/etc/pacman.conf
[archlinuxcn]
Server = https://repo.archlinuxcn.org/x86_64
EOM

pacman-key --init
pacman -Sy --noconfirm && pacman -S --noconfirm archlinuxcn-keyring
pacman -Syu --noconfirm paru
if [ -n "$INPUT_PREINSTALLPKGS" ]; then
	pacman -Syu --noconfirm "$INPUT_PREINSTALLPKGS"
fi

if [ -d "$pkgname" ]; then
	echo '::warning:: This is a warning message, to demonstrate that commands are being processed.'
	cd "$pkgname" || exit
	chown -R builder .
	sudo --set-home -u builder paru -U --noconfirm
else
	sudo --set-home -u builder paru -Sa --noconfirm --clonedir=./ "$pkgname"
fi
