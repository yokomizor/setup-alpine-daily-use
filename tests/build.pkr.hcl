variable "headless" {
  type = bool
  default = false
}

variable "disk_password" {
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
  vm_name = "alpine-3-17-1-stage0"
  accelerator = "kvm"
  headless = var.headless
  disk_size = var.disk_size
  disk_interface = "ide"
  memory = var.memory
  output_directory = "output/stage0"

  iso_urls = [
    "iso/alpine-standard-3.17.1-x86_64.iso",
    "https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/x86_64/alpine-standard-3.17.1-x86_64.iso",
  ]
  iso_checksum = "sha256:4d2fe571ccac10049a0c2e5c7a54ee27f792a6f182d61068c98ddb2ddaecda88"

  communicator = "none"

  http_directory = "."

  boot_wait = "10s"
  boot_key_interval = "20ms"
  boot_command = [
    "root<enter><wait5>",

    # Network needs to be up so setup-alpine-answers can be fetch via http
    "ifconfig eth0 up && udhcpc -i eth0",
    "<enter>",

    # https://gitlab.alpinelinux.org/alpine/alpine-conf/-/issues/10547
    # "setup-alpine -e -f http://{{ .HTTPIP }}:{{ .HTTPPort }}/setup-alpine-answers",
    "wget -q http://{{ .HTTPIP }}:{{ .HTTPPort }}/setup-alpine-answers",
    "<enter>",
    "setup-alpine -e -f setup-alpine-answers",
    " && poweroff",
    "<enter>",


    # Answer installation questions
    ##########################################################################

    # Erase the above disk and continue?
    "<wait20>y<enter><wait3>",

    # Enter passphrase
    var.disk_password,
    "<enter><wait3>",

    # Verify passphrase
    var.disk_password,
    "<enter><wait15>",

    # Enter passphrase again to unlock disk for installation 
    var.disk_password,
    "<enter>",

  ]
}

source "qemu" "stage1" {
  vm_name = "alpine-3-17-1-stage1"
  accelerator = "kvm"
  headless = var.headless
  disk_size = var.disk_size
  disk_interface = "ide"
  memory = var.memory
  output_directory = "output/stage1"

  iso_urls = [ "output/stage0/alpine-3-17-1-stage0" ]
  iso_checksum = "none"
  disk_image = true
  use_backing_file = true

  ssh_username = "root"
  ssh_private_key_file = "id_ed25519_root"
  ssh_pty = true
  ssh_timeout = "20m"
  ssh_handshake_attempts = 10

  boot_wait = "10s"
  boot_key_interval = "20ms"
  boot_command = [ var.disk_password, "<enter>" ]

  shutdown_command = "poweroff"
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
      "/tmp/setup-alpine-daily-use -d -u yokomizor -r https://github.com/yokomizor/dotfiles -l /home/yokomizor/.config/dotfiles",
    ]
  }

  ##############################################################################

  post-processor "manifest" {
    output = "output/manifest.json"
    strip_path = true
  }
}
