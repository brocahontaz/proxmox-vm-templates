# Variable Definitions
variable "proxmox_api_url" {
    type = string
    default = env("PROXMOX_API_URL")
}

variable "proxmox_api_token_id" {
    type = string
    default = env("PROXMOX_API_TOKEN_ID")
}

variable "proxmox_api_token_secret" {
    type = string
    default = env("PROXMOX_API_TOKEN_SECRET")
    sensitive = true
}

source "proxmox-iso" "ubuntu-jammy" {
  # Proxmox Connection Settings
  proxmox_url = "${var.proxmox_api_url}"
  username = "${var.proxmox_api_token_id}"
  token = "${var.proxmox_api_token_secret}"
  insecure_skip_tls_verify = true

  # VM Settings
  node = "eldton"
  vm_id = "9000"
  vm_name = "ubuntu-jammy-22.04"
  template_description = "Ubuntu Jammy Server Image"

  iso_file = "local:iso/ubuntu-22.04.2-live-server-amd64.iso"
  iso_storage_pool = "local"
  unmount_iso = true
  os = "l26"

  qemu_agent = true

  scsi_controller = "virtio-scsi-pci"

  disks {
    disk_size = "20G"
    format = "raw"
    storage_pool = "local-lvm"
    storage_pool_type = "lvm"
    type = "virtio"
  }

  cores = "1"
  memory = "4096"

  network_adapters {
    model = "virtio"
    bridge = "vmbr0"
    firewall = "false"
  } 

  cloud_init = true
  cloud_init_storage_pool = "local-lvm"

  additional_iso_files {
    cd_files = [
      "./http/meta-data",
      "./http/user-data"
    ]
    cd_label         = "cidata"
    iso_storage_pool = "local"
  }

  boot = "c"
  boot_wait = "5s"
  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    "<bs><bs><bs><bs><wait>",
    "autoinstall ds=nocloud-net;s=/cidata/ ---<wait>",
    "<f10><wait>"
  ]

  ssh_username = "ubuntu"
  ssh_password = "ubuntu"
  ssh_timeout = "20m"
}

build {
  name = "ubuntu-jammy"
  sources = ["source.proxmox-iso.ubuntu-jammy"]

  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "sudo rm /etc/ssh/ssh_host_*",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo apt -y autoremove --purge",
      "sudo apt -y clean",
      "sudo apt -y autoclean",
      "sudo cloud-init clean",
      "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
      "sudo sync"
    ]
  }

  provisioner "file" {
    source = "files/99-pve.cfg"
    destination = "/tmp/99-pve.cfg"
  }

  provisioner "shell" {
    inline = [ "sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg" ]
  }
}
