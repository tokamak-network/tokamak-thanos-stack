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

# EFS StorageClass for monitoring
resource "kubernetes_storage_class" "monitoring_efs_sc" {
  count = var.enable_monitoring_persistence ? 1 : 0
  
  metadata {
    name = "monitoring-efs-sc"
    labels = {
      component = "monitoring"
      managed-by = "terraform"
    }
  }
  
  storage_provisioner = "efs.csi.aws.com"
  
  parameters = {
    provisioningMode = "efs-utils"
    fileSystemId     = var.efs_file_system_id
    directoryPerms   = "0755"
  }
  
  reclaim_policy         = "Retain"
  allow_volume_expansion = true
  volume_binding_mode    = "Immediate"
}

# Monitoring Persistent Volumes
resource "kubernetes_persistent_volume" "monitoring_prometheus" {
  count = var.enable_monitoring_persistence ? 1 : 0
  
  metadata {
    name = "${var.monitoring_stack_name}-prometheus-pv"
    labels = {
      app            = "prometheus"
      monitoring-stack = var.monitoring_stack_name
      component      = "monitoring"
      managed-by     = "terraform"
    }
  }
  
  spec {
    capacity = {
      storage = var.prometheus_storage_size
    }
    
    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name              = kubernetes_storage_class.monitoring_efs_sc[0].metadata[0].name
    
    persistent_volume_source {
      csi {
        driver        = "efs.csi.aws.com"
        volume_handle = var.efs_file_system_id
        volume_attributes = {
          path = "/monitoring/prometheus"
        }
      }
    }
  }

  depends_on = [kubernetes_storage_class.monitoring_efs_sc]
}

resource "kubernetes_persistent_volume" "monitoring_grafana" {
  count = var.enable_monitoring_persistence ? 1 : 0
  
  metadata {
    name = "${var.monitoring_stack_name}-grafana-pv"
    labels = {
      app            = "grafana"
      monitoring-stack = var.monitoring_stack_name
      component      = "monitoring"
      managed-by     = "terraform"
    }
  }
  
  spec {
    capacity = {
      storage = var.grafana_storage_size
    }
    
    access_modes                     = ["ReadWriteMany"]
    persistent_volume_reclaim_policy = "Retain"
    storage_class_name              = kubernetes_storage_class.monitoring_efs_sc[0].metadata[0].name
    
    persistent_volume_source {
      csi {
        driver        = "efs.csi.aws.com"
        volume_handle = var.efs_file_system_id
        volume_attributes = {
          path = "/monitoring/grafana"
        }
      }
    }
  }

  depends_on = [kubernetes_storage_class.monitoring_efs_sc]
} 