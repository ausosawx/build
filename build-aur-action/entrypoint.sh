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

pkgbuild_dir=../pkgname
if [ -d $pkgbuild_dir ]; then
	# fix directory permissions
	sudo chown -R build "$pkgbuild_dir"
	sudo chown -R build /github/home
	install_deps() {
		# install the package dependencies
		grep -E 'depends' .SRCINFO |
			sed -e 's/.*depends = //' -e 's/:.*//' |
			xargs paru -S --noconfirm
		# install the package make dependencies
		grep -E 'makedepends' .SRCINFO |
			sed -e 's/.*depends = //' -e 's/:.*//' |
			xargs paru -S --noconfirm
	}
	cd $pkgbuild_dir || exit
	## check PKGBUILD
	namcap PKGBUILD
	# install dependencies
	install_deps
	# just makepkg
	makepkg --syncdeps --noconfirm
else
	sudo --set-home -u builder paru -Sa --noconfirm --clonedir=./ "$pkgname"
fi
