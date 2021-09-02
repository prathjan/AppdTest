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


resource "null_resource" "genapptraffic" {
  provisioner "local-exec" {
    	command = "/bin/bash ./scripts/gentraffic.sh ${local.appvmip} ${local.appport}"
  }
}


locals {
  #appvmip = data.terraform_remote_state.appvm.outputs.vm_deploy[0]
  appport = data.terraform_remote_state.global.outputs.appport
  appvmip = data.terraform_remote_state.appvm.outputs.vm_ip[0]
}

