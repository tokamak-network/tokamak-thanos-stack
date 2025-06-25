terraform {
  required_version = ">= 1.0"
  
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

# Data sources to get existing cluster information
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

# Kubernetes provider configuration
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "kubectl" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Get existing efs-sc StorageClass used by op-geth/op-node
data "kubernetes_storage_class" "efs_sc" {
  metadata {
    name = "efs-sc"
  }
}

# Monitoring Persistent Volumes using existing efs-sc StorageClass
resource "kubernetes_persistent_volume" "monitoring_prometheus" {
  count = var.enable_monitoring_persistence ? 1 : 0
  
  metadata {
    name = "${var.monitoring_stack_name}-prometheus-pv"
    labels = {
      app              = "prometheus"
      monitoring-stack = var.monitoring_stack_name
      component        = "monitoring"
      managed-by       = "terraform"
    }
  }
  
  spec {
    capacity = {
      storage = var.prometheus_storage_size
    }
    
    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name              = "efs-sc"  # Use existing StorageClass
    
    persistent_volume_source {
      csi {
        driver        = "efs.csi.aws.com"
        volume_handle = "${var.efs_file_system_id}:/prometheus"
      }
    }
  }
}

resource "kubernetes_persistent_volume" "monitoring_grafana" {
  count = var.enable_monitoring_persistence ? 1 : 0
  
  metadata {
    name = "${var.monitoring_stack_name}-grafana-pv"
    labels = {
      app              = "grafana"
      monitoring-stack = var.monitoring_stack_name
      component        = "monitoring"
      managed-by       = "terraform"
    }
  }
  
  spec {
    capacity = {
      storage = var.grafana_storage_size
    }
    
    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name              = "efs-sc"  # Use existing StorageClass
    
    persistent_volume_source {
      csi {
        driver        = "efs.csi.aws.com"
        volume_handle = "${var.efs_file_system_id}:/grafana"
      }
    }
  }
} 