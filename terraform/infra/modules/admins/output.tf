output "admin_group_id" {
  value       = azuread_group.azuread_group.id
  description = "Azure AD admin group resource ID"
}