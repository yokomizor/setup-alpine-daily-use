builddir := build

alpine_path := alpine-standard-3.15.0-x86_64.iso
alpine_download_uri := https://dl-cdn.alpinelinux.org/alpine/v3.15/releases/x86_64/$(alpine_path)

download-iso:
	wget -P tests/iso $(alpine_download_uri)
	wget -P tests/iso $(alpine_download_uri).sha256
	wget -P tests/iso $(alpine_download_uri).asc

verify-iso: download-iso
	cd tests/iso && sha256sum -c $(alpine_path).sha256
	cd tests/iso && gpg --verify $(alpine_path).asc $(alpine_path)

flashdrive: verify-iso
	read -p "Target device (e.g /dev/sda): " target_device; sudo dd if=tests/iso/$(alpine_path) of=$$target_device bs=4M oflag=sync status=progress; sudo eject $$target_device

test-stage0:
	cd tests && packer build -force -only qemu.stage0 .

test-stage1:
	cd tests && packer build -force -only qemu.stage1 .

qemu-stage1:
	cd tests && qemu-system-x86_64-spice \
		-machine type=q35,accel=kvm \
                -display gtk,gl=off \
		-m 1024M \
		-cpu host \
		-vga none \
                -device virtio-gpu,virgl=off \
		-object rng-random,id=rng0,filename=/dev/urandom \
		-device virtio-rng-pci,rng=rng0 \
		-usb \
		-device usb-host,hostbus=03,hostport=2.2.1 \
		output/stage1/alpine-3-15-0-stage1

.PHONY: download-iso verify-iso flashdrive test-stage1 qemu-stage1
