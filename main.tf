terraform {
  required_providers {
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.54.0"
    }
    
    aws = {
      source = "hashicorp/aws"
      version = "4.30.0"
    }
  }
}

provider "hcp" {}

provider "aws" {
  region = var.region
}

#PACKER ITERATION
data "hcp_packer_iteration" "hashicat" {
  bucket_name = "hashicat-demo"
  channel     = "latest"
}

#PACKER IMAGE
data "hcp_packer_image" "ubuntu_us_east_1" {
  bucket_name    = "hashicat-demo"
  cloud_provider = "aws"
  iteration_id   = data.hcp_packer_iteration.hashicat.ulid
  region         = "us-east-1"
}

module "hashicat" {
  source  = "app.terraform.io/cesteban-tfc/hashicat/aws"
  version = "1.9.1"
  instance_type = var.instance_type
  region = var.region
  instance_ami = data.hcp_packer_image.ubuntu_us_east_1.cloud_image_id
}

module "hashicat-2" {
  source  = "app.terraform.io/cesteban-tfc/hashicat/aws"
  version = "1.9.1"
  instance_type = var.instance_type
  region = var.region
  instance_ami = data.hcp_packer_image.ubuntu_us_east_1.cloud_image_id
}

check "health_check" {
  data "http" "hashicat_web" {
    url = module.hashicat.catapp_url
  }

  assert {
    condition = data.http.hashicat_web.status_code == 200
    error_message = "${data.http.hashicat_web.url} returned an unhealthy status code"
  }
}

check "ami_version_check" {
  data "aws_instance" "hashicat_current" {
    instance_tags = {
      Name = "demo-hashicat-instance"
    }
  }

  assert {
    condition = data.aws_instance.hashicat_current.ami == data.hcp_packer_image.ubuntu_us_east_1.cloud_image_id
    error_message = "Must use the latest available AMI, ${data.hcp_packer_image.ubuntu_us_east_1.cloud_image_id}."
  }
}
