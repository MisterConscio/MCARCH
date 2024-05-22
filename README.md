# Bootstrap Arch (bsarch)

My way to setup my Arch Linux environment.

## Guide

Implying that you already have arch installed in your system, specifically
choosing the minimal install(or using
[archinstall](https://wiki.archlinux.org/title/Archinstall) with the minimal
profile type), follow these steps:

1. Login as the root user
2. Install curl and run the following command

```sh
curl -O "https://raw.githubusercontent.com/linvegas/bsarch/main/bsarch.sh" && bash bsarch.sh
```

Or

```sh
bash <(curl -s "https://raw.githubusercontent.com/linvegas/bsarch/main/bsarch.sh")
```

3. After the script is finished, reboot your system
