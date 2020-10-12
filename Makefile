SHELL := $(shell which bash)
SELF  := $(patsubst %/,%,$(dir $(abspath $(firstword $(MAKEFILE_LIST)))))
CACHE := $(SELF)/.cache
MOUNT := $(CACHE)/mount

DISK_NAME ?= Catalina.qcow2
DISK_SIZE ?= 128G

NBD_DEV ?= /dev/nbd0

define BUILD_BOOT_QCOW2
sudo modprobe nbd max_part=8
qemu-img create -f qcow2 $(1) 256M
sudo qemu-nbd --connect $(NBD_DEV) $(1)
sudo sgdisk $(NBD_DEV) -o
sudo sgdisk $(NBD_DEV) -n 1:: -t 1:ef00
sudo mkfs.fat -F 32 -n EFI $(NBD_DEV)p1
install -d $(MOUNT)/
sudo mount $(NBD_DEV)p1 $(MOUNT)/
sudo cp -r $(CACHE)/EFI/ $(MOUNT)/
sudo tee $(MOUNT)/startup.nsh <<< 'fs0:\EFI\BOOT\BOOTx64.efi'
sudo umount $(NBD_DEV)p1
sudo qemu-nbd --disconnect $(NBD_DEV)
endef

define RUN_QEMU_KVM
qemu-kvm \
-enable-kvm \
-m 8192 \
-smp 4,cores=2,sockets=1 \
-cpu host,vendor=GenuineIntel,+hypervisor,+invtsc,kvm=on,+fma,+avx,+avx2,+aes,+ssse3,+sse4_2,+popcnt,+sse4a,+bmi1,+bmi2 \
-machine pc-q35-2.9 \
-smbios type=2 \
-device ich9-intel-hda -device hda-output \
-audiodev driver=pa,id=sound1,server=localhost \
-usb -device usb-kbd -device usb-mouse \
-netdev user,id=net0 \
-device vmxnet3,netdev=net0,id=net0,mac=52:54:00:09:49:17 \
-vga qxl \
-device isa-applesmc,osk="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc" \
-drive if=pflash,format=raw,readonly,file=$(CACHE)/OVMF_CODE.fd \
-drive if=pflash,format=raw,file=$(CACHE)/OVMF_VARS.fd \
-device ich9-ahci,id=sata \
-drive id=BootImage,if=none,format=qcow2,file=$(1) \
-device ide-hd,bus=sata.2,drive=BootImage \
-drive id=InstallMedia,format=raw,if=none,file=$(CACHE)/BaseSystem.img \
-device ide-hd,bus=sata.3,drive=InstallMedia \
-drive id=SystemDisk,if=virtio,file=$(CACHE)/$(DISK_NAME)
endef

export

.PHONY: all

all: prereq run

.PHONY: prereq

prereq: needs-install \
        needs-touch \
        needs-tee \
        needs-curl \
        needs-unzip \
        needs-tar \
        needs-xz \
        needs-ar \
        needs-sudo \
        needs-modprobe \
        needs-sgdisk \
        needs-mkfs.fat \
        needs-mount \
        needs-umount \
        needs-dmg2img \
        needs-qemu-img \
        needs-qemu-nbd \
        needs-qemu-kvm

needs-%:
	@which $*

.PHONY: run

run: $(CACHE)/Boot.qcow2 $(CACHE)/$(DISK_NAME) $(CACHE)/OVMF_CODE.fd $(CACHE)/OVMF_VARS.fd $(CACHE)/BaseSystem.img
	$(call RUN_QEMU_KVM,$<)

$(CACHE)/Boot.qcow2: $(CACHE)/EFI/
	install -d $(dir $@)
	$(call BUILD_BOOT_QCOW2,$@)

$(CACHE)/EFI/: $(CACHE)/OpenCoreEFIFolder.zip
	install -d $(CACHE)/
	unzip $< -d $(CACHE)/ && touch $@

$(CACHE)/OpenCoreEFIFolder.zip:
	install -d $(dir $@)
	curl -fSL -o $@ https://github.com/thenickdude/KVM-Opencore/releases/download/v5/$(notdir $@)

$(CACHE)/$(DISK_NAME):
	install -d $(dir $@)
	qemu-img create -f qcow2 $@ $(DISK_SIZE)

$(CACHE)/OVMF_CODE.fd: $(CACHE)/data.tar.xz
	tar xf $< -C $(dir $@) --strip-components=4 ./usr/share/pve-edk2-firmware/$(notdir $@)

$(CACHE)/OVMF_VARS.fd: $(CACHE)/data.tar.xz
	tar xf $< -C $(dir $@) --strip-components=4 ./usr/share/pve-edk2-firmware/$(notdir $@)

$(CACHE)/data.tar.xz: $(CACHE)/pve-edk2-firmware_2.20200531-1_all.deb
	cd $(CACHE)/ && ar x $< $(notdir $@)

$(CACHE)/pve-edk2-firmware_2.20200531-1_all.deb:
	install -d $(dir $@)
	curl -fSL -o $@ http://download.proxmox.com/debian/pve/dists/buster/pve-no-subscription/binary-amd64/$(notdir $@)

$(CACHE)/BaseSystem.img: $(CACHE)/BaseSystem.dmg
	install -d $(dir $@)
	cd $(dir $@) && dmg2img $< $@

$(CACHE)/BaseSystem.dmg:
	install -d $(dir $@)
	curl -fSL -o $@ http://swcdn.apple.com/content/downloads/01/28/061-86291-A_JPEIWIOZES/enpozvvbmj3mj2dhulhevlt8b429qd5kw0/$(notdir $@)
