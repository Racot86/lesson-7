resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.namespace
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_version
  create_namespace = true

  values = [file("${path.module}/values.yaml")]
}

resource "helm_release" "argocd_apps" {
  name      = "argocd-apps"
  namespace = var.namespace
  chart     = "${path.module}/charts"

  values = [
    yamlencode({
      repoURL  = var.app_repo_url
      revision = var.app_revision
      path     = var.app_path
    })
  ]

  depends_on = [helm_release.argocd]
}

output "argocd_namespace" {
  value = var.namespace
}
