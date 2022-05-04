#!/bin/bash
# Deutsche Tastaturbelegung einstellen und Zeit/Datum über NTP abrufen
echo "SET ROOT-PASSWORD"
read rootpasswd
echo "\nSETTING KEYBOARD LAYOUT TO de-latin1\n"
loadkeys de-latin1
echo "\nSET NTP AS TRUE\n"
timedatectl set-ntp true
# FESTPLATTEN
echo "\nYOUR DRIVES:\n"
sfdisk -l -uM
echo '\nTYPE THE NAME OF YOUR MAIN DRIVE: "sda"\n'
read driveName
sfdisk /dev/$driveName -uM << EOF   # Start, Größe, Type_ID (82=swap, EF=EFI System)
,1024,82
,512, EF
;
EOF
echo "\nCREATING FILESYSTEMS\n"
echo "creating partitions..."
mkfs.ext4 /dev/${driveName}3
mkfs.fat -F32 //dev/${driveName}2   # Boot Partition
mkswap /dev/${driveName}1           # Swap Partition
echo "partitions have been created!"
echo "\nMOUNTING PARTITIONS\n"
echo "mounting partitions..."
mount /dev/${driveName}3 /mnt
mkdir /mnt/efi
mount /dev/${driveName}2 /mnt/efi
swapon /dev/${driveName}1
echo "partitions have been mounted"
# LINUX GRUNDSYSTEM INSTALLIEREN
echo "\nINSTALLING LINUX FIRMWARE\n"
pacstrap -i /mnt base linux linux-firmware vim
echo "\nCONFIGURING SYSTEM\n"
genfstab -U /mnt >> /mnt/etc/fstab  # System mounten
arch-chroot /mnt                    # System rooten
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime # Zeitzone setzen
hwclock --systohc   # Hardware-Uhr anpassen
locale-gen  #"Einheiten" setzen
echo LANG=de_DE.UTF8 > /etc/locale.conf
echo KEYMAP=de-latin1 > /etc/vconsole.conf
echo "SET HOSTNAME:"
read hostname
echo $hostname > /etc/hostname
echo "127.0.0.1     localhost" >> /etc/hosts
echo "::1           localhost" >> /etc/hosts
echo "127.0.1.1     ${hostname}.localdomain ${hostname}" >> /etc/hosts
pacman -S networkmanager     # Network-Manager installieren
systemctl enable NetworkManager # System-Links erstellen
passwd 
$rootpasswd
$rootpasswd
# GRUB INSTALLIEREN (BOOTMANAGER)
pacman -S grub efibootmgr
grub-install --target=x86_64-efi --bootloader=GRUB --efi-directory=/efi --removable
grub-mkconfig -o /boot/grub/grub.cfg
exit
umount -R /mnt
reboot