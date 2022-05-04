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

#################### FESTPLATTE AUFSETZEN ####################
## Partitionen konfigurieren
echo
echo "CREATING PARTITIONS..."
parted -s "${device}" -- mklabel gpt \
##  mkpart PART-TYPE [FS-TYPE] START END        # Erstellt eine Partition. Optional mit Filesystem
    mkpart ESP "EFI system partition" fat32 1MiB 301MiB \   # Boot-Partition 300 MiB
    set 1 esp on \
    mkpart primary linux-swap 301MiB 2349MiB ${swap_end} \  # Swap-Partition 2048 MiB (Ablage-Ort auf der Festplatte für den RAM)
    mkpart primary ext4 ${swap_end} 100%                    # Haupt-Partition

## Erstellen einer Referenz, um die Partitionen zu formatieren.
## Hierebi gibt es zwei verschiedene Geräte-Typen, zwischen denen unterschieden werden muss.
## Es gibt ${device}1 oder ${device}p1
## Mit ls und grep kann der Geräte-Typ herausgefiltert werden
part_boot="$(ls ${device}* | grep -E "^${device}p?1$")"

## Partitionen erstellen
mkfs.vfat -F32 "${part_boot}"
mkswap "${part_swap}"
mkfs.ext4 "${part_root}"

## Partitionen mounten
swapon "${part_swap}"
mount "${part_root}" /mnt
mkdir /mnt/boot
mount "${part_boot}" /mnt/boot
echo "PARTITIONS HAVE BEEN CREATED!"

#################### LINUX GRUNDSYSTEM INSTALLIEREN ####################
echo
echo "INSTALLING LINUX FIRMWARE"
pacstrap -i /mnt base linux linux-firmware vim nano
echo "FIRMWARE HAS BEEN INSTALLED!"
## Bootloader erstellen
genfstab -U /mnt >> /mnt/etc/fstab      # genfstab erstellt eine fstab-Datei durchs automatische erkennen aller aktiven Mounts, beim angegebenen Mount-Point (/mnt).
                                        # Anschließend werden diese in fstab-kompatiblen Format als Standard-Ausgabe deklariert.
arch-chroot /mnt                        # System rooten
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime # Zeitzone setzen
hwclock --systohc                       # Hardware-Uhr anpassen
locale-gen                              #"Einheiten" setzen
echo LANG=de_DE.UTF8 > /etc/locale.conf
echo KEYMAP=de-latin1 > /etc/vconsole.conf
echo "${hostname}" > /mnt/etc/hostname
## Benutzer erstellen und Root-Passwort setzen
arch-chroot /mnt useradd -mU -s /usr/bin/zsh -G wheel,uucp,video,audio,storage,games,input "$user"
arch-chroot /mnt chsh -s /usr/bin/zsh

echo "$user:$password" | chpasswd --root /mnt
echo "root:$password" | chpasswd --root /mnt
