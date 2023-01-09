#!/usr/bin/env bash

BOLD="\e[1m"
GREEN="\e[32m"
RED="\e[31m"
NORMAL="\e[0m"

error() {
  printf "${RED}==>${NORMAL}${BOLD} %s${NORMAL}\n" "${1:-Aconteceu algum erro}" >&2
  exit 1
}

message() {
  printf "${GREEN}==>${NORMAL}${BOLD} %s${NORMAL}\n" "$1"
}

hello() {
  clear
  printf "\n${BOLD}Bem vindo${NORMAL}\n"
  printf "Irá começar o script de instalação\n"
  printf "Esse script é destinado para sistemas ${BOLD}Arch Linux${NORMAL}\n"

  read -rp "Antes de começar, por farvor ${BOLD}informe seu usuário${NORMAL}: " name
  [ ! "$(id -u "$name")" ] && error "O usuário ${name} não existe"

  read -rp "Por farvor, ${BOLD}informe qual é sua placa de vídeo${NORMAL} [nvidia/intel/amd]: " video
  printf "${BOLD}Vamos-lá ${name} :)${NORMAL}\n"

  sleep 1
}

mkfilestruct() {
  message "Estrutura de arquivos"

  sudo -u "$name" mkdir -pv /home/"$name"/.config/{mpd,ncmpcpp,zsh} \
    /home/"$name"/.cache/zsh \
    /home/"$name"/.local/{src,state,share/{npm,backgrounds}} \
    /home/"$name"/media/{pic/screenshot,vid,mus,samp,proj,emu} \
    /home/"$name"/{dev,doc}

  mkdir -pv /mnt/{externo,ssd,usb1,usb2,usb3}
  cd /mnt && chown -v -R "$name":"$name" ./*
}

setpacman() {
  message "Configuração do pacman e sudoers"

  pacman --noconfirm --needed -S pacman-contrib

  sed -E -i "s/^#(ParallelDownloads).*/\1 = 5/;/^#Color$/s/#//;/^#VerbosePkgLists$/s/#//;/\[multilib\]/,/Include/s/#//" /etc/pacman.conf
  sed -i "s/-j2/-j$(nproc)/;/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf

  cp -v /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
  echo "Testando velocidade dos repositórios..."
  rankmirrors -n 10 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist

  sudo pacman --noconfirm -Syy
}

dotfiles() {
  message "Repositório dos dotfiles"

  dotfiles_repo="https://github.com/MisterConscio/dotfiles.git"
  dotdir="/home/$name/dotfiles"

  pacman --noconfirm --needed -S stow git

  sudo -u "$name" git clone "$dotfiles_repo" "$dotdir"
  cd "$dotdir" || error "cd failed"
  sudo -u "$name" stow -v */
}

pacinstall() {
  message "Instalação de programas"

  pkg_list="/tmp/pkglist.txt"
  aur_list="/tmp/aurlist.txt"

  cd /home/"$name" || error "cd failed"

  curl -L "https://raw.githubusercontent.com/MisterConscio/mcarch/main/pkglist.txt" -o "$pkg_list"
  curl -L "https://raw.githubusercontent.com/MisterConscio/mcarch/main/aurlist.txt" -o "$aur_list"

  [ ! -f "$pkg_list" ] && error "O arquivo $pkg_list não existe"

  pacman --noconfirm --needed -S - < "$pkg_list"

  case "$video" in
    intel) pacman --noconfirm --needed -S xf86-video-intel lib32-mesa;;
    amd) pacman --noconfirm --needed -S xf86-video-amdgpu xf86-video-ati lib32-mesa;;
    nvidia) pacman --noconfirm --needed -S nvidia nvidia-utils lib32-nvidia-utils;;
    *) echo "Placa de vídeo incorreta ou não especificada";;
  esac
}

aurinstall() {
  message "Instalação do Yay"

  aurhelper="yay"
  aurhelper_git="https://aur.archlinux.org/yay.git"
  aurdir="/home/$name/.local/src/$aurhelper"

  sudo -u "$name" git clone "$aurhelper_git" "$aurdir"

  cd "$aurdir" || error "cd failed"

  sudo -u "$name" makepkg -sirc --noconfirm || error
}

aurpkg() {
  message "Instalação de pacotes AUR"

  cd /home/"$name" || error "cd failed"

  [ ! -f "$aur_list" ] && error "O arquivo $aur_list não existe"

  sudo -u "$name" yay -S --removemake --noconfirm - < "$aur_list"
}

final_setup() {
  message "Mundança de shell para zsh"

  chsh -s /usr/bin/zsh "$name"
  chsh -s /usr/bin/zsh root

  echo "PROMPT='%F{red}%B%1~%b%f %(!.#.>>) '" > /root/.zshrc

  # Adição de grupos ao usuário
  message "Adcionando ao usuário grupos"

  usermod -aG wheel,video,audio,lp,network,kvm,storage,i2c "$name"
  echo "command: usermod -aG wheel,video,audio,lp,network,kvm,storage,i2c $name"

  # Configuração do servidor de áudio Jack para uso do Realtime Scheduling
  [ ! -e /etc/security/limits.d/00-audio.conf ] &&
    mkdir -pv /etc/security/limits.d/ &&
    cat << EOF > /etc/security/limits.d/00-audio.conf
# Realtime Scheduling for jack server
@audio   -  rtprio     95
@audio   -  memlock    unlimited
EOF

  # Configuração do teclado no xorg
  [ ! -f "/etc/X11/xorg.conf.d/00-keyboard.conf" ] &&
    mkdir -pv /etc/X11/xorg.conf.d &&
    cat << EOF > /etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "br"
        Option "XkbModel" "abnt2"
        Option "XkbOptions" "terminate:ctrl_alt_bksp"
EndSection
EOF

  echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/00-sudo-wheel
  echo -e "Defaults timestamp_timeout=30\nDefaults timestamp_type=global" > /etc/sudoers.d/01-sudo-time
  echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/poweroff,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/mount,/usr/bin/umount" > /etc/sudoers.d/02-cmd-nopasswd
  echo "Defaults editor=/usr/bin/nvim" > /etc/sudoers.d/03-visudo-editor

  # Cleanup
  message "Limpeza"

  rm -rfv /home/"$name"/.bash* /home/"$name"/.go
  mv -v /home/"$name"/.gnupg /home/"$name"/.local/share/gnupg
}

# Atualização de sistema inicial (Script starts here)
pacman --noconfirm -Syyu ||
  error "Você não está rodando o script como root ou não possui acesso à internet"

# Mesangem de boas vindas e informação do usuário
hello || error

# Estrutura de arquivos pessoal
mkfilestruct || error

# Configuração do pacman e arquivo temporário sudoers
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/99_sudotemp
trap 'rm -f /etc/sudoers.d/99_sudotemp' QUIT EXIT
setpacman || error

# Repositório dos dotfiles
dotfiles || error

# Instalação dos programas
pacinstall || error

# Instalação do yay
aurinstall || error

# Instalação de pacotes AUR
aurpkg || error

# Últimas configurações
final_setup || error

echo -e "\n${BOLD}Parece que tudo ocorreu bem, por favor, reinicie o sistema${NORMAL}\n"
