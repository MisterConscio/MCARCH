#!/usr/bin/env sh

# This script is supposed to be executed as the root user

# pkg_list_url="https://raw.githubusercontent.com/MisterConscio/dotfiles/main/pkglist.txt"
pkg_list="pkglist.txt"
aur_list="aurlist.txt"
dotfiles_repo="https://github.com/MisterConscio/dotfiles.git"
aurhelper="yay"
aurhelper_git="https://aur.archlinux.org/yay.git"
falsename="conscio"

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
  echo -e "\n${bold}Bem vindo${normal}\n"
  sleep 2
  echo "Irá começar o script de instalação"
  sleep 2
  echo "Esse script é destinado para sistemas ${bold}Arch Linux${normal}"
  sleep 2
  read -p "Antes de começar, por farvor ${bold}informe seu usuário${normal}: " name
  [[ ! $(id -u "$name") ]] && error "O usuário ${name} não existe"
  echo "${bold}Vamos-lá ${name} :)${normal}"
  sleep 1
}

mkfilestruct() {
  message "Estrutura de arquivos"
  sudo -u "$name" mkdir -pv /home/$name/.config/{mpd,ncmpcpp,zsh} \
    /home/$name/.cache/zsh \
    /home/$name/.local/{src,share/{gnupg,npm}} \
    /home/$name/media/{pic/screenshot,vid,mus,samp,proj} \
    /home/$name/{dev,doc}
  mkdir -pv /mnt/{externo,ssd,usb1,usb2,usb3}
  cd /mnt && chown -v -R $name:$name *
  message "Finalizada"
}

setpacman() {
  message "Configuração do pacman e sudoers"
  pacman --noconfirm --needed -S pacman-contrib

  sed -Ei "s/^#(ParallelDownloads).*/\1 = 5/;/^#Color$/s/#//;/^#VerbosePkgLists$/s/#//" /etc/pacman.conf
  sed -i "s/-j2/-j$(nproc)/;/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf

  cp -v /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
  echo "Testando velocidade dos repositórios..."
  rankmirrors -n 6 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist

  sudo pacman --noconfirm -Syy
  message "Finalizada"
}

dotfiles() {
  message "Repositório dos dotfiles"
  dotdir="/home/$name/dotfiles"
  pacman --noconfirm --needed -S stow git
  echo -e "\nClonando o repositório dos dotfiles..."
  sudo -u "$name" git clone "$dotfiles_repo" $dotdir
  cd $dotdir
  sudo -u "$name" stow -v */
    # i3 alacritty x11 zsh \
    # polybar xdg scripts gtk \
    # dircolors mpd ncmpcpp dunst \
    # lf fontconfig rofi nvim \
    # zathura tmux bspwm npm
  # nvim -c "PlugInstall|q|q"
  message "Finalizada"
}

pacinstall() {
  message "Instalação de programas"
  [[ ! -e "$dotdir/$pkglist" ]] && error "O arquivo $pkg_list não existe"
  echo "${bold}Iniciando a instalação...${normal}"
  pacman --noconfirm --needed -S - < "$pkg_list"
  message "Finalizada"
}

aurinstall() {
  message "Instalação do Yay"
  echo "Instalando ${aurhelper} como AUR helper..."
  local aurdir="/home/$name/.local/src/$aurhelper"
  sudo -u "$name" git clone "$aurhelper_git" $aurdir
  cd $aurdir
  sudo -u "$name" makepkg -sirc --noconfirm || error
  message "Finalizada"
}

aurpkg() {
  message "Instalação de pacotes AUR"
  echo "Instalando pacotes do AUR..."
  cd "$dotdir"
  sudo -u "$name" yay -S --removemake --noconfirm - < "$aur_list"
  message "Finalizada"
}

vimplug() {
  message "Instalação dos plugins do vim"
  sudo -u "$name" mkdir -pv /home/$name/.local/share/nvim/site/autoload
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
  message "APA 8: Adcionando ao usuário grupos"
  usermod -aG wheel,video,audio,lp,network,kvm,storage,i2c "$name"
  echo "command: usermod -aG wheel,video,audio,lp,network,kvm,storage,i2c $name"
  message "Finalizada"
}

cleanup() {
  message "Limpeza"
  rm -rfv /home/$name/{muhinstall.sh,.bash_logout,.bashrc,.bash_profile,go,.gnupg}
  message "Finalizada"
}

# Atualização de sistema inicial
pacman --noconfirm -Syyu ||
  error "Você não está rodando o script como root ou não possui acesso à internet"

# Mesangem de boas vindas e informação do usuário
hello || error

# Some export for building a few packages
# GNUPGHOME="/home/$name/.local/share/gnupg"
# NPM_CONFIG_USERCONFIG="/home/$name/.config/npm/npmrc"
# GOPATH="/home/$name/.local/share/go"

# Estrutura de arquivos pessoal
mkfilestruct || error

# Configuração do pacman e arquivo temporário sudoers
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/09_sudotemp
trap 'rm -f /etc/sudoers.d/09_sudotemp' QUIT EXIT
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

[ ! -e /etc/security/limits.d/00-audio.conf ] &&
  mkdir -pv /etc/security/limits.d/ &&
  cat << EOF > /etc/security/limits.d/00-audio.conf
# Realtime Scheduling for jack server
@audio   -  rtprio     95
@audio   -  memlock    unlimited
EOF

echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/00-sudo-wheel
echo -e "Defaults timestamp_timeout=30\nDefaults timestamp_type=global" > /etc/sudoers.d/01-sudo-time

echo "PROMPT='%F{red}%B%1~%b%f %(!.#.>>) '" > /root/.zshrc

echo -e "\n${bold}Parece que tudo ocorreu bem, por favor, reinicie o sistema${normal}"
