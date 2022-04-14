resource "local_file" "kubeconfig" {
  depends_on = [azurerm_kubernetes_cluster.cluster1]
  filename   = "kubeconfig"
  content    = azurerm_kubernetes_cluster.cluster1.kube_config_raw
}