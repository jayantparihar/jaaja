terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}


# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.do_token
}

data "digitalocean_ssh_key" "ACIT-4640" {
  name = "ACIT-4640"
}

data "digitalocean_project" "lab_project" {
  name = "first-project"
}


# Create a new tag 
# Use tag to create load balancer
resource "digitalocean_tag" "do_tag" {
  name = "Web"
}

# Create a new VPC
resource "digitalocean_vpc" "web_vpc" {
  name   = "web"
  region = var.region
}

# Create a new Web Droplet in the sfo3 region
resource "digitalocean_droplet" "web" {
  image    = "rockylinux-9-x64"
  count    = var.droplet_count
  name     = "web-${count.index + 1}"
  region   = var.region
  size     = "s-1vcpu-512mb-10gb"
  tags     = [digitalocean_tag.do_tag.id]
  ssh_keys = [data.digitalocean_ssh_key.ACIT-4640.id]
  vpc_uuid = digitalocean_vpc.web_vpc.id

  lifecycle {
    create_before_destroy = true
  }
}

# Add new web-1 droplet to existing 4640_Labs project
resource "digitalocean_project_resources" "project_attach" {
  project = data.digitalocean_project.lab_project.id
  resources = flatten([ digitalocean_droplet.web.*.urn ])
}

resource "digitalocean_loadbalancer" "public" {
  name = "loadbalancer-1"
  region = var.region

  forwarding_rule {
    entry_port = 80
    entry_protocol = "http"

    target_port = 80
    target_protocol = "http"
  }

  healthcheck {
    port = 22
    protocol = "tcp"
  }

  droplet_tag = "Web"
  vpc_uuid = digitalocean_vpc.web_vpc.id
}


output "server_ip" {
  value = digitalocean_droplet.web.*.ipv4_address
}
