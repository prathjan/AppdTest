#get the data from the app VM WS
data "terraform_remote_state" "appvm" {
  backend = "remote"
  config = {
    organization = "Lab14"
    workspaces = {
      name = var.appvmwsname
    }
  }
}

data "terraform_remote_state" "global" {
  backend = "remote"
  config = {
    organization = "Lab14"
    workspaces = {
      name = var.globalwsname
    }
  }
}



locals {
  #appvmip = data.terraform_remote_state.appvm.outputs.vm_deploy[0]
  appport = data.terraform_remote_state.global.outputs.appport
  appvmip = data.terraform_remote_state.appvm.outputs.vm_ip[0]
}

# Configure the VMware vSphere Provider
provider "vsphere" {
  user           = var.vsphere_user
  password       = var.vsphere_password
  vsphere_server = var.vsphere_server

  # If you have a self-signed cert
  allow_unverified_ssl = true
}


data "vsphere_datacenter" "dc" {
  name = var.datacenter
}

data "vsphere_datastore" "datastore" {
  name          = var.datastore_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  name          = var.resource_pool
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = var.network_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.template_name
  datacenter_id = data.vsphere_datacenter.dc.id
}


resource "random_string" "folder_name_prefix" {
  length    = 10
  min_lower = 10
  special   = false
  lower     = true

}


resource "vsphere_folder" "vm_folder" {
  path          =  "${var.vm_folder}-${random_string.folder_name_prefix.id}"
  type          = "vm"
  datacenter_id = data.vsphere_datacenter.dc.id
}


resource "vsphere_virtual_machine" "vm_deploy" {
  name             = "${var.vm_prefix}-${random_string.folder_name_prefix.id}-testvm"
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = vsphere_folder.vm_folder.path
  firmware = "bios"


  num_cpus = var.vm_cpu
  memory   = var.vm_memory
  guest_id = data.vsphere_virtual_machine.template.guest_id

  scsi_type = data.vsphere_virtual_machine.template.scsi_type

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = data.vsphere_virtual_machine.template.disks.0.size
    eagerly_scrub    = data.vsphere_virtual_machine.template.disks.0.eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.template.disks.0.thin_provisioned
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
    customize {
      linux_options {
        host_name = "${var.vm_prefix}-${random_string.folder_name_prefix.id}-testvm"
        domain    = var.vm_domain
      }
      network_interface {}
    }
  }

}


resource "null_resource" "vm_node_init" {
  provisioner "file" {
    source = "scripts/"
    destination = "/tmp/"
    connection {
      type = "ssh"
      host = "${vsphere_virtual_machine.vm_deploy.default_ip_address}"
      user = "root"
      password = "${var.root_password}"
      port = "22"
      agent = false
    }
  }

  provisioner "remote-exec" {
    inline = [
        "chmod +x /tmp/initjmeter.sh",
        "/tmp/initjmeter.sh" 
    ]
    connection {
      type = "ssh"
      host = "${vsphere_virtual_machine.vm_deploy.default_ip_address}"
      user = "root"
      password = "${var.root_password}"
      port = "22"
      agent = false
    }
  }

}

resource "null_resource" "vm_starttraffic" {
  depends_on = [
    null_resource.vm_node_init,
  ]
  triggers = {
        trig = var.trigcount
  }
  provisioner "file" {
    source = "scripts/"
    destination = "/tmp/"
    connection {
      type = "ssh"
      host = "${vsphere_virtual_machine.vm_deploy.default_ip_address}"
      user = "root"
      password = "${var.root_password}"
      port = "22"
      agent = false
    }
  }

  provisioner "remote-exec" {
    inline = [
        "chmod +x /tmp/gentraffic.sh",
        "/tmp/gentraffic.sh ${local.appvmip} ${local.appport}"
    ]
    connection {
      type = "ssh"
      host = "${vsphere_virtual_machine.vm_deploy.default_ip_address}"
      user = "root"
      password = "${var.root_password}"
      port = "22"
      agent = false
    }
  }

}

output "vm_name" {
  value = vsphere_virtual_machine.vm_deploy.*.name
}

output "vm_ip" {
  value = vsphere_virtual_machine.vm_deploy.*.default_ip_address
}

locals {
  mysql_pass = yamldecode(data.terraform_remote_state.global.outputs.mysql_pass)
}

