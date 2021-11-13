#!/bin/bash
TGTDEV=/dev/sda
# to create the partitions programatically (rather than manually)
# we're going to simulate the manual input to fdisk
# The sed script strips off all the comments so that we can 
# document what we're doing in-line with the actual commands
# Note that a blank line (commented as "defualt" will send a empty
# line terminated with a newline to take the fdisk default.
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${TGTDEV}
  o # clear the in memory partition table
  n # new partition
  p # primary partition
  1 # partition number 1
    # default - start at beginning of disk 
  +500M # 500 MB boot parttion
  n # new partition
  p # primary partition
  2 # partion number 2
    # default, start immediately after preceding partition
    # default, extend partition to end of disk
  t # Change partition format
  2 # Select Partition
  8e #use lvm partition
  a # make a partition bootable
  1 # bootable partition is partition 1 -- /dev/sda1
  p # print the in-memory partition table
  w # write the partition table
  q # and we're done
EOF

pvcreate /dev/sda2
vgcreate vg00 /dev/sda2
lvcreate -L 5G -n root vg00 
lvcreate -L 5G -n usr vg00 
lvcreate -L 3G -n home vg00 
lvcreate -L 1G -n var vg00 
lvcreate -L 1G -n log vg00 
lvcreate -L 1G -n tmp vg00 
lvcreate -L 2G -n pacman vg00
lvcreate -L 1G -n swap vg00

mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/vg00/root
mkfs.ext4 /dev/vg00/usr
mkfs.ext4 /dev/vg00/home
mkfs.ext4 /dev/vg00/var
mkfs.ext4 /dev/vg00/log
mkfs.ext4 /dev/vg00/tmp
mkfs.ext4 /dev/vg00/pacman
mkswap /dev/vg00/swap

mount /dev/vg00/root /mnt
mkdir -p /mnt/boot /mnt/usr /mnt/var /mnt/home /mnt/tmp
swapon /dev/vg00/swap
mount /dev/sda1 /mnt/boot
mount /dev/vg00/home /mnt/home
mount /dev/vg00/usr /mnt/usr
mount /dev/vg00/var /mnt/var
mkdir -p /mnt/var/log
mount /dev/vg00/log /mnt/var/log
mkdir -p /mnt/var/cache/pacman
mount /dev/vg00/pacman /mnt/var/cache/pacman
mount /dev/vg00/tmp /mnt/tmp

pacstrap /mnt base linux linux-firmware git dhcpcd dhclient vim firefox sudo wget xorg-server xorg-xinit grub lvm2 virtualbox-guest-utils dmenu alacritty alsa-utils rsync reflector archlinux-wallpaper bash-completion lxappearance neofetch htop xdg-user-dirs picom networkmanager network-manager-applet zsh
genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc
sed -i '177s/.//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "KEYMAP=fr" >> /etc/vconsole.conf
echo "void" >> /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 void.localdomain void" >> /etc/hosts
echo root:root | chpasswd
pacman -Syy archlinux-keyring --noconfirm
pacman -Syy duf bpytop --noconfirm
sed -i 's/fsck)/fsck systemd lvm2)/' /etc/mkinitcpio.conf
mkinitcpio -P
grub-install --target=i386-pc /dev/sda # replace sdx with your disk name, not the partition
sed -i -e s/#GRUB_COLOR_/GRUB_COLOR_/g -e s/GRUB_GFXMODE=.*/GRUB_GFXMODE=1920x1080/ -e s/quiet/quiet video=1920x1080/ /etc/default/grub
sed -i -e s@#GRUB_BACKGROUND=.*@GRUB_BACKGROUND=/usr/share/backgrounds/archlinux/simple.png@ /etc/default/grub 
sed -i -e s@GRUB_COLOR_HIGHLIGHT="light-cyan/blue"@GRUB_COLOR_HIGHLIGHT="light-green/light-blue"@ /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
systemctl enable dhcpcd.service
systemctl enable systemd-timesyncd.service
systemctl enable systemd-time-wait-sync.service
systemctl enable vboxservice
systemctl enable NetworkManager
reflector -c France -a 6 --sort rate --save /etc/pacman.d/mirrorlist
localectl set-x11-keymap fr
useradd -m zac
echo zac:root | chpasswd
echo "zac ALL=(ALL) ALL" >> /etc/sudoers.d/zac
xdg-user-dirs-update
EOF

shutdown -h now