terraform {
  required_providers {
    helm = "~> 1.0"
  }

  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "tecnoly"

    workspaces {
      name = "portafolio-yamile"
    }
  }
}

data "terraform_remote_state" "cluster" {
  backend = "remote"

  config = {
    hostname     = "app.terraform.io"
    organization = "tecnoly"

    workspaces = {
      name = "gke-cluster"
    }
  }
}

data "google_client_config" "current" {}

provider "kubernetes" {
  load_config_file       = false
  host                   = "https://${data.terraform_remote_state.cluster.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode(data.terraform_remote_state.cluster.outputs.cluster_ca_certificate)
  token                  = data.google_client_config.current.access_token
}

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = "portafolio-yamile"
  }
}

provider "helm" {
  kubernetes {
    load_config_file       = false
    host                   = "https://${data.terraform_remote_state.cluster.outputs.cluster_endpoint}"
    cluster_ca_certificate = base64decode(data.terraform_remote_state.cluster.outputs.cluster_ca_certificate)
    token                  = data.google_client_config.current.access_token
  }
}

data "helm_repository" "stable" {
  name = "stable"
  url  = "https://kubernetes-charts.storage.googleapis.com"
}

resource "helm_release" "wordpress" {
  name          = "portafolio-yamile"
  repository    = data.helm_repository.stable.metadata[0].name
  chart         = "wordpress"
  version       = "9.0.0"
  namespace     = kubernetes_namespace.namespace.id

  values = [
    file("${path.module}/values.yaml"),
  ]
}