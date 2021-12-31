variable "headless" {
  type = bool
  default = false
}

variable "disk_password" {
  type = string
  default = "packer"
}

variable "ssh_username" {
  type = string
  default = "packer"
}

variable "ssh_password" {
  type = string
  default = "packer"
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
  vm_name = "alpine-3-15-0-stage0"
  accelerator = "kvm"
  headless = var.headless
  disk_size = var.disk_size
  disk_interface = "ide"
  memory = var.memory
  output_directory = "output/stage0"

  iso_urls = [
    "iso/alpine-standard-3.15.0-x86_64.iso",
    "https://dl-cdn.alpinelinux.org/alpine/v3.15/releases/x86_64/alpine-standard-3.15.0-x86_64.iso",
  ]
  iso_checksum = "sha512:95fffc9939294af0871b6e70fe86459ba60db88a4bd4de06658bc1feb324bba6683f664bba4fa6cda35c462af779229dfa7f8d925b90e7eee7fabef5e036fef2"

  communicator = "none"

  http_directory = "."

  boot_wait = "10s"
  boot_key_interval = "20ms"
  boot_command = [
    "root<enter><wait5>",

    # The use of `USERANSERFILE=1` is explained at https://gitlab.alpinelinux.org/alpine/alpine-conf/-/issues/10494
    "export USERANSERFILE=1<enter><wait>",

    # Network needs to be up so setup-alpine-answers can be fetch via http
    "ifconfig eth0 up && udhcpc -i eth0",

    " && setup-alpine -e -f http://{{ .HTTPIP }}:{{ .HTTPPort }}/setup-alpine-answers",
    "<enter>",


    # Answer installation questions
    ##########################################################################

    # Erase the above disk and continue?
    "<wait20>y<enter><wait>",

    # Enter passphrase
    var.disk_password,
    "<enter><wait3>",

    # Verify passphrase
    var.disk_password,
    "<enter><wait15>",

    # Enter passphrase again to unlock disk for installation 
    var.disk_password,
    "<enter>",


    # Wait installation and reboot
    ##########################################################################

    "<wait1m15s>",
    "reboot<enter>",


    # Boot, install sudo, create user and start sshd
    ##########################################################################

    "<wait20>",

    # Unlock disk
    var.disk_password,
    "<enter>",
    "<wait20>",

    # Login as root
    "root",
    "<enter>",
    "<wait5>",

    "apk add sudo",
    " && adduser -D ", var.ssh_username,
    " && adduser ", var.ssh_username, " wheel",
    " && echo \" ", var.ssh_username, " ALL=(ALL) NOPASSWD: ALL\"  > /etc/sudoers.d/", var.ssh_username, " && chmod 0440 /etc/sudoers.d/", var.ssh_username,
    " && echo ", var.ssh_username, ":", var.ssh_password, " | chpasswd",
    " && poweroff",
    "<enter>",
  ]
}

source "qemu" "stage1" {
  vm_name = "alpine-3-15-0-stage1"
  accelerator = "kvm"
  headless = var.headless
  disk_size = var.disk_size
  disk_interface = "ide"
  memory = var.memory
  output_directory = "output/stage1"

  iso_urls = [
    "output/stage0/alpine-3-15-0-stage0",
  ]
  iso_checksum = "none"
  disk_image = true
  use_backing_file = true

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_pty = true
  ssh_timeout = "20m"
  ssh_handshake_attempts = 10

  boot_wait = "10s"
  boot_key_interval = "20ms"
  boot_command = [
    var.disk_password,
    "<enter>",
  ]

  shutdown_command = "sudo poweroff"
}

build {
  sources = [
    "qemu.stage0",
    "qemu.stage1",
  ]

  provisioner "file" {
    only = [
      "qemu.stage1",
    ]
    destination = "/tmp/"
    source = "../setup-alpine-daily-use"
  }

  ##############################################################################

  # STAGE 1 - Install

  provisioner "shell" {
    only = [
      "qemu.stage1",
    ]
    inline = [
      "set -e",
      "sudo mv /tmp/setup-alpine-daily-use /usr/sbin/setup-alpine-daily-use",
      "sudo setup-alpine-daily-use -d -u yokomizor -r https://github.com/yokomizor/dotfiles -l /home/yokomizor/.config/dotfiles",
    ]
  }

  ##############################################################################

  post-processor "manifest" {
    output = "output/manifest.json"
    strip_path = true
  }
}
