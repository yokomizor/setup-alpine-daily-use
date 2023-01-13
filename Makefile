builddir := target
PACKER_CACHE_DIR := $(builddir)/packer_cache

alpine_path := alpine-standard-3.17.1-x86_64.iso
alpine_download_uri := https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/x86_64/$(alpine_path)

download-iso:
	mkdir -p $(builddir)/iso
	wget -P $(builddir)/iso $(alpine_download_uri)
	wget -P $(builddir)/iso $(alpine_download_uri).sha256
	wget -P $(builddir)/iso $(alpine_download_uri).asc

verify-iso:
	cd $(builddir)/iso && sha256sum -c $(alpine_path).sha256
	cd $(builddir)/iso && gpg --verify $(alpine_path).asc $(alpine_path)

flashdrive: download-iso verify-iso
	read -p "Target device (e.g /dev/sda): " target_device; sudo dd if=$(builddir)/iso/$(alpine_path) of=$$target_device bs=4M oflag=sync status=progress; sudo eject $$target_device

test-stage0:
	packer build -force -only qemu.stage0 .

test-stage1:
	packer build -force -only qemu.stage1 .

qemu-stage0:
	qemu-system-x86_64 \
		-machine type=q35,accel=kvm \
		-m 1024M \
		-cpu host \
		-object rng-random,id=rng0,filename=/dev/urandom \
		-device virtio-rng-pci,rng=rng0 \
		-usb \
		-device usb-host,hostbus=03,hostport=2.2.1 \
		$(builddir)/output/stage0/alpine-3-17-1-stage0

qemu-stage1:
	qemu-system-x86_64 \
		-machine type=q35,accel=kvm \
		-display gtk,gl=on \
		-m 1024M \
		-cpu host \
		-device virtio-vga-gl \
		-object rng-random,id=rng0,filename=/dev/urandom \
		-device virtio-rng-pci,rng=rng0 \
		-usb \
		-device usb-host,hostbus=03,hostport=2.2.1 \
		$(builddir)/output/stage1/alpine-3-17-1-stage1

.PHONY: download-iso verify-iso flashdrive test-stage1 qemu-stage1
