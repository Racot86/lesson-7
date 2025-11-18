resource "helm_release" "jenkins" {
  name             = "jenkins"
  repository       = "https://charts.jenkins.io"
  chart            = "jenkins"
  namespace        = var.namespace
  create_namespace = true
  values           = [file("${path.module}/values.yaml")]

  set {
    name  = "controller.image.repository"
    value = "jenkins/jenkins"
  }

  set {
    name  = "controller.image.tag"
    value = "2.462.3-jdk17"
  }

  wait    = false
  timeout = 1800
}

output "jenkins_service_url" {
  value = "http://jenkins.${var.namespace}.svc.cluster.local:8080"
}
