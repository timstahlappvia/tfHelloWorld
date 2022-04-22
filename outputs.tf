resource "local_file" "kubeconfig" {
  depends_on = [azurerm_kubernetes_cluster.cluster1]
  filename   = "kubeconfig"
  content    = azurerm_kubernetes_cluster.cluster1.kube_config_raw
}

resource "local_file" "externalip" {
  depends_on = [data.kubernetes_service.ingress-controller]
  filename   = "externalip"
  content    = data.kubernetes_service.ingress-controller.status[0].load_balancer[0].ingress[0].ip
}