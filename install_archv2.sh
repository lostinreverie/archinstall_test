#!/bin/bash
#################### VARIABLEN ####################
## Hostname
echo -n "Hostname: "
read hostname
: "${hostname:?"Missing hostname"}"                     # Überprüfen, ob der Hostname gesetzt wurde
## Passwort
echo -n "Password: "
read -s password1
echo
echo -n "Repeat Password: "
read -s password2
echo
[[ "$password1" == "$password2" ]] || ( echo "Passwords did not match"; exit 1; )  # Überprüfen, ob Passwörter übereinstimmen
echo
echo -n "Choose the Partition for your OS. (/dev/sda for Example): "
read device

#################### FESTPLATTE AUFSETZEN ####################
## Partitionen konfigurieren
echo
echo "CREATING PARTITIONS..."
parted -s "${device}" -- mklabel gpt \
##  mkpart PART-TYPE [FS-TYPE] START END        # Erstellt eine Partition. Optional mit Filesystem
    mkpart "EFI system partition" fat32 1MiB 301MiB \   # Boot-Partition 300 MiB
    set 1 esp on \
    mkpart primary linux-swap 301MiB 2349MiB \  # Swap-Partition 2048 MiB (Ablage-Ort auf der Festplatte für den RAM)
    mkpart primary ext4 2349MiB 100%            # Haupt-Partition

## Partitionen erstellen
mkfs.vfat -F32 "${device}1"
mkswap "${device}2"
mkfs.f2fs -f "${device}3"

## Partitionen mounten
swapon "${device}2"
mount "${device}3" /mnt
mkdir /mnt/boot
mount "${device}1" /mnt/boot
echo "PARTITIONS HAVE BEEN CREATED!"

#################### LINUX GRUNDSYSTEM UND BOOTLOADER INSTALLIEREN ####################
echo
echo "INSTALLING LINUX FIRMWARE"
pacstrap -i /mnt base linux linux-firmware vim nano
echo "FIRMWARE HAS BEEN INSTALLED!"
## Bootloader erstellen

genfstab -U /mnt >> /mnt/etc/fstab                  # genfstab erstellt eine fstab-Datei durchs automatische erkennen aller aktiven Mounts, beim angegebenen Mount-Point (/mnt).
                                                    # Anschließend werden diese in fstab-kompatiblen Format als Standard-Ausgabe deklariert.
arch-chroot /mnt                                    # System rooten
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime # Zeitzone setzen
hwclock --systohc                                   # Hardware-Uhr anpassen
locale-gen                                          # "Einheiten" setzen
echo LANG=de_DE.UTF8 > /etc/locale.conf
echo KEYMAP=de-latin1 > /etc/vconsole.conf
echo "${hostname}" > /mnt/etc/hostname
echo "127.0.0.1     localhost" >> /etc/hosts
echo "::1           localhost" >> /etc/hosts
echo "127.0.1.1     ${hostname}.localdomain ${hostname}" >> /etc/hosts
pacman -S networkmanager     # Network-Manager installieren
systemctl enable NetworkManager # System-Links erstellen
passwd 
pacman -S grub efibootmgr
grub-install --target=x86_64-efi --bootloader=GRUB --efi-directory=/efi --removable
grub-mkconfig -o /boot/grub/grub.cfg
exit
umount -R /mnt
reboot
