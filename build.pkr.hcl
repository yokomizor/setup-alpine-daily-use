variable "headless" {
  type = bool
  default = false
}

variable "disk_size" {
  type = string
  default = "8G"
}

variable "memory" {
  type = number
  default = 1024
}

source "qemu" "stage0" {
  vm_name = "alpine-3-17-1-stage0"
  accelerator = "kvm"
  headless = var.headless
  disk_size = var.disk_size
  disk_interface = "ide"
  memory = var.memory
  output_directory = "target/output/stage0"

  iso_urls = [
    "target/iso/alpine-standard-3.17.1-x86_64.iso",
    "https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/x86_64/alpine-standard-3.17.1-x86_64.iso",
  ]
  iso_checksum = "sha256:4d2fe571ccac10049a0c2e5c7a54ee27f792a6f182d61068c98ddb2ddaecda88"

  communicator = "none"

  http_directory = "."

  boot_wait = "10s"
  boot_key_interval = "10ms"
  boot_command = [
    "root<enter><wait3>",

    # Network needs to be up so setup-alpine-answers can be fetch via http
    "ifconfig eth0 up && udhcpc -i eth0",
    "<enter>",

    # https://gitlab.alpinelinux.org/alpine/alpine-conf/-/issues/10547
    # "setup-alpine -e -f http://{{ .HTTPIP }}:{{ .HTTPPort }}/setup-alpine-answers",
    "wget -q http://{{ .HTTPIP }}:{{ .HTTPPort }}/setup-alpine-answers",
    "<enter>",

    # Disable disk encryption to make `setup-alpine` fully non-interactive.
    "sed -i -e \"s:-Le:-L:\" setup-alpine-answers",
    "<enter>",

    # Dummy ed25519 key so packer can ssh in.
    # The private key is created on ./target using a provisioner shell-local script.
    "export ROOTSSHKEY=\"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEA9dM5TE9fcTVxIv+dQa4NcYG4+OmzFD978xR7TZjdF root\"",
    "<enter>",

    "ERASE_DISKS=\"/dev/sda\" setup-alpine -e -f setup-alpine-answers && poweroff",
    "<enter>",
  ]
}

source "qemu" "stage1" {
  vm_name = "alpine-3-17-1-stage1"
  accelerator = "kvm"
  headless = true
  disk_size = var.disk_size
  disk_interface = "ide"
  memory = var.memory
  output_directory = "target/output/stage1"

  iso_urls = [ "target/output/stage0/alpine-3-17-1-stage0" ]
  iso_checksum = "none"
  disk_image = true
  use_backing_file = true

  ssh_username = "root"
  ssh_private_key_file = "target/id_ed25519_root" # from stage0 provisioner shell-local script
  ssh_pty = true
  ssh_timeout = "20m"
  ssh_handshake_attempts = 10

  shutdown_command = "poweroff"
}

build {
  sources = [
    "qemu.stage0",
    "qemu.stage1",
  ]

  provisioner "shell-local" {
    only = [
      "qemu.stage0",
    ]
    inline = [
      "cat <<-__EOF__ >> target/id_ed25519_root",
      "-----BEGIN OPENSSH PRIVATE KEY-----",
      "b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW",
      "QyNTUxOQAAACBAPXTOUxPX3E1cSL/nUGuDXGBuPjpsxQ/e/MUe02Y3RQAAAIhEAdhZRAHY",
      "WQAAAAtzc2gtZWQyNTUxOQAAACBAPXTOUxPX3E1cSL/nUGuDXGBuPjpsxQ/e/MUe02Y3RQ",
      "AAAED1x4hbjKFeSIKrZUOi+/3LJsGZKnG7qPVmGZPG8Xk5DEA9dM5TE9fcTVxIv+dQa4Nc",
      "YG4+OmzFD978xR7TZjdFAAAABHJvb3QB",
      "-----END OPENSSH PRIVATE KEY-----",
      "__EOF__",
    ]
  }

  provisioner "file" {
    only = [
      "qemu.stage1",
    ]
    destination = "/tmp/"
    source = "./setup-alpine-daily-use"
  }

  provisioner "shell" {
    only = [
      "qemu.stage1",
    ]
    inline = [
      "set -e",
      "/tmp/setup-alpine-daily-use -d -u pc1 -r https://github.com/yokomizor/dotfiles -l /home/yokomizor/.config/dotfiles",
    ]
  }

  post-processor "manifest" {
    output = "target/output/manifest.json"
    strip_path = true
  }
}
