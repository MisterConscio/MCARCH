#!/usr/bin/env bash

pkg_list="pkglist.txt"
aur_list="aurlist.txt"

bold=$(tput bold)
normal=$(tput sgr0)

error() {
  echo -e "\n${bold}${1:-Ocorreu algum erro}${normal}\n"
  sleep 2
  exit 1
}

message() {
  echo -e "\n${bold}$1${normal}\n" >&2
  sleep 1
}

hello() {
  clear
  echo -e "\n${bold}Bem vindo${normal}\n"
  sleep 2
  echo "Irá começar o script de instalação"
  sleep 2
  echo "Esse script é destinado para sistemas ${bold}Arch Linux${normal}"
  sleep 2
  read -rp "Antes de começar, por farvor ${bold}informe seu usuário${normal}: " name
  [ ! "$(id -u "$name")" ] && error "O usuário ${name} não existe"
  read -rp "Por farvor, ${bold}informe qual é sua placa de vídeo${normal} [nvidia/intel/amd]: " video
  echo "${bold}Vamos-lá ${name} :)${normal}"
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
  message "Finalizada"
}

setpacman() {
  message "Configuração do pacman e sudoers"
  pacman --noconfirm --needed -S pacman-contrib

  sed -E -i "s/^#(ParallelDownloads).*/\1 = 5/" \
    -i "/^#Color$/s/#//;/^#VerbosePkgLists$/s/#//" \
    -i "/\[multilib\]/,/Include/s/#//" /etc/pacman.conf
  sed -i "s/-j2/-j$(nproc)/;/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf

  cp -v /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
  echo "Testando velocidade dos repositórios..."
  rankmirrors -n 10 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist

  sudo pacman --noconfirm -Syy
  message "Finalizada"
}

dotfiles() {
  dotfiles_repo="https://github.com/MisterConscio/dotfiles.git"
  message "Repositório dos dotfiles"
  dotdir="/home/$name/dotfiles"
  pacman --noconfirm --needed -S stow git
  echo -e "\nClonando o repositório dos dotfiles..."
  sudo -u "$name" git clone "$dotfiles_repo" "$dotdir"
  cd "$dotdir" || error "cd failed"
  sudo -u "$name" stow -v */
  message "Finalizada"
}

pacinstall() {
  message "Instalação de programas"
  cd /home/"$name" || error "cd failed"
  curl -LO "https://raw.githubusercontent.com/MisterConscio/MCARCH/main/pkglist.txt"
  curl -LO "https://raw.githubusercontent.com/MisterConscio/MCARCH/main/aurlist.txt"
  [ ! -e "/home/$name/$pkg_list" ] && error "O arquivo $pkg_list não existe"
  echo "${bold}Iniciando a instalação...${normal}"
  pacman --noconfirm --needed -S - < "$pkg_list"
  case "$video" in
    intel) pacman --noconfirm --needed -S xf86-video-intel lib32-mesa;;
    amd) pacman --noconfirm --needed -S xf86-video-amdgpu xf86-video-ati lib32-mesa;;
    nvidia) pacman --noconfirm --needed -S nvidia nvidia-utils lib32-nvidia-utils;;
    *) echo "Placa de vídeo incorreta ou não especificada";;
  esac
  message "Finalizada"
}

aurinstall() {
  aurhelper="yay"
  aurhelper_git="https://aur.archlinux.org/yay.git"
  message "Instalação do Yay"
  echo "Instalando ${aurhelper} como AUR helper..."
  aurdir="/home/$name/.local/src/$aurhelper"
  sudo -u "$name" git clone "$aurhelper_git" "$aurdir"
  cd "$aurdir" || error "cd failed"
  sudo -u "$name" makepkg -sirc --noconfirm || error
  message "Finalizada"
}

aurpkg() {
  message "Instalação de pacotes AUR"
  echo "Instalando pacotes do AUR..."
  cd /home/"$name" || error "cd failed"
  [ ! -e "/home/$name/$aur_list" ] && error "O arquivo $aur_list não existe"
  # cd "$dotdir"
  sudo -u "$name" yay -S --removemake --noconfirm - < "$aur_list"
  message "Finalizada"
}

vimplug() {
  message "Instalação dos plugins do vim"
  sudo -u "$name" mkdir -pv /home/"$name"/.local/share/nvim/site/autoload
  curl -Ls \
    "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim" > \
    "/home/$name/.local/share/nvim/site/autoload/plug.vim"
  sudo -u "$name" nvim -c "PlugInstall|q|q"
  message "Finalizada"
}

changeshell() {
  message "Mundança de shell para zsh"
  echo "Mudando o shell para zsh..."
  chsh -s /usr/bin/zsh "$name"
  chsh -s /usr/bin/zsh root
  message "Finalizada"
}

addgroups() {
  message "Adcionando ao usuário grupos"
  usermod -aG wheel,video,audio,lp,network,kvm,storage,i2c "$name"
  echo "command: usermod -aG wheel,video,audio,lp,network,kvm,storage,i2c $name"
  message "Finalizada"
}

cleanup() {
  message "Limpeza"
  rm -rfv /home/"${name:?}"/{mcarch.sh,"${pkg_list}","${aur_list}",.bash_logout,.bashrc,.bash_profile,go}
  mv -v /home/"${name:?}"/.gnupg /home/"$name"/.local/share/gnupg
  message "Finalizada"
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

# Vimplug install
vimplug || error

# Mudança de shell para zsh
changeshell || error

# Gerenciamento de grupos
addgroups || error

# Limpeza
cleanup || error

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
echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/mount,/usr/bin/umount" > /etc/sudoers.d/02-cmd-nopasswd
echo "Defaults editor=/usr/bin/nvim" > /etc/sudoers.d/03-visudo-editor

echo "PROMPT='%F{red}%B%1~%b%f %(!.#.>>) '" > /root/.zshrc

echo -e "\n${bold}Parece que tudo ocorreu bem, por favor, reinicie o sistema${normal}\n"
