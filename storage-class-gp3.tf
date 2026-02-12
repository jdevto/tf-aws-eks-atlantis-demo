# =============================================================================
# StorageClass "gp3" for EBS CSI driver
# =============================================================================
# Atlantis (and other workloads) request storageClassName = "gp3". The EBS CSI
# addon may create a default class with a different name. This ensures a
# StorageClass named "gp3" exists so PVCs can bind and pods can schedule.

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  depends_on = [module.eks]
}
