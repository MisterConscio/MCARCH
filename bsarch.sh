#!/usr/bin/env bash

YELLOW="\e[33m"
RED="\e[31m"
END="\e[0m"

error() {
    local msg=$1
    printf "%bERROR:%b %s\n" "$RED" "$msg" "$END"
}

fatal() {
    error "$1"
    exit 1
}

info() {
    local msg=$1
    printf "%b:: %s ::%b\n" "$YELLOW" "$msg" "$END"
}

check_username() {
    echo -ne "Type your ${YELLOW}username${END}: "
    read -r username

    if [ ! "$(id -u "$username")" ]; then
        error "user '${username}' doesn't exist"
        check_username
    fi
}

clear

check_username

info "Making file tree"
sudo -u "$username" mkdir --parents --verbose \
    /home/"$username"/.cache/zsh \
    /home/"$username"/.local/{state,share/{npm,backgrounds}} \
    /home/"$username"/media/{pic/screenshot,mus,vid,samp,proj,emu,mang} \
    /home/"$username"/{repo,dev,docx} \

mkdir --parents --verbose /mnt/{usb1,usb2,usb3}
cd /mnt && chown --verbose --recursive "${username}:${username}" ./*

info "Pacman configuration"
sed --regexp-extended -i "s/^#(ParallelDownloads).*/\1 = 5/;/^#Color$/s/#//;/^#VerbosePkgLists$/s/#//;/\[multilib\]/,/Include/s/#//" /etc/pacman.conf
sed -i "s/-j2/-j$(nproc)/;/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf

pacman --noconfirm -Syyu

info "Dotfiles setup"

dots_dir="/home/$username/dotfiles"

pacman --noconfirm --needed -S stow git
sudo -u "$username" \
    git clone "https://github.com/linvegas/dotfiles.git" "$dots_dir"
cd "$dots_dir" && sudo -u "$username" stow -v */

echo "%wheel ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/99_sudotemp
trap 'rm -f /etc/sudoers.d/99_sudotemp' QUIT EXIT

info "Installing programs"

pkg_file="/tmp/pkglist"
curl --verbose -L "https://raw.githubusercontent.com/linvegas/bsarch/main/pkglist" -o "$pkg_file"
[ ! -f "$pkg_file" ] && error "file '$pkg_file' doesn't exist"

# shellcheck source=pkglist
source "$pkg_file"

pacman --noconfirm --needed -S "${pac_list[@]}"

yay_dir="/home/$username/repo/yay"

sudo -u "$username" \
    git clone https://aur.archlinux.org/yay.git "$yay_dir"

cd "$yay_dir" &&
    sudo -u "$username" makepkg -sirc --noconfirm

sudo -u "$username" yay -S --removemake --noconfirm "${aur_list[@]}"

info "Final changes"

chsh --shell /usr/bin/zsh "$username"
chsh --shell /usr/bin/zsh root

echo "PROMPT='%F{red}%B%1~%b%f %(!.#.>>) '" > /root/.zshrc

usermod -aG wheel,video,audio,lp,network,kvm,storage,i2c "$username"

if [ ! -e "/etc/security/limits.d/00-audio.conf" ]; then
    mkdir --parents --verbose /etc/security/limits.d/
    curl -L "https://raw.githubusercontent.com/linvegas/bsarch/main/resources/00-audio.conf" \
        -o "/etc/security/limits.d/00-audio.conf"
fi

if [ ! -f "/etc/X11/xorg.conf.d/00-keyboard.conf" ]; then
    mkdir --parents --verbose /etc/X11/xorg.conf.d
    curl -L "https://raw.githubusercontent.com/linvegas/bsarch/main/resources/00-keyboard.conf" \
        -o "/etc/X11/xorg.conf.d/00-keyboard.conf"
fi

if [ ! -f "/etc/X11/xorg.conf.d/20-touchpad.conf" ]; then
    mkdir --parents --verbose /etc/X11/xorg.conf.d
    curl -L "https://raw.githubusercontent.com/linvegas/bsarch/main/resources/20-touchpad.conf" \
        -o "/etc/X11/xorg.conf.d/20-touchpad.conf"
fi

echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/00-sudo-wheel
echo -e "Defaults timestamp_timeout=30\nDefaults timestamp_type=global" > /etc/sudoers.d/01-sudo-time
echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/poweroff,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/mount,/usr/bin/umount" > /etc/sudoers.d/02-cmd-nopasswd
echo "Defaults editor=/usr/bin/nvim" > /etc/sudoers.d/03-visudo-editor

rm --recursive --verbose /home/"$username"/.bash*

info "The end"
