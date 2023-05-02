output "oidc_issuer_url" {
    value = azurerm_kubernetes_cluster.aks.oidc_issuer_url  
}

output "cluster_name" {
    value = azurerm_kubernetes_cluster.aks.name
}

output "cluster_fqdn" {
    value = azurerm_kubernetes_cluster.aks.fqdn
}

# output "client_certificate" {
#     value = azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_certificate  
# }

# output "client_key" {
#     value = azurerm_kubernetes_cluster.aks.kube_admin_config.0.client_key  
# }

# output "cluster_ca_certificate" {
#     value = azurerm_kubernetes_cluster.aks.kube_admin_config.0.cluster_ca_certificate
# }