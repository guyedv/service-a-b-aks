variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
provider "template" {
  # Add any provider configuration options if necessary.
}


variable "prefix" {
  description = "Prefix of the application (used for naming resources like ACR, RG, and AKS)"
  type        = string
}

variable "tag" {
  description = "Docker image tag (e.g., v1.0 or latest)"
  type        = string
}

variable "location" {
  default = "westeurope"
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-rg"
  location = var.location
}

resource "azurerm_container_registry" "main" {
  name                = "${var.prefix}acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.prefix}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix = "${var.prefix}-cluster"

  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  role_based_access_control_enabled = true
  
    # Enable Container Insights (Azure Monitor)
  monitor_metrics {}
   
  network_profile {
    network_plugin = "azure"
    load_balancer_sku = "standard"
  }
    # Enable Container Insights
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }
}

# Create Log Analytics Workspace for Container Insights
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.prefix}-law"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# Create Azure Monitor Managed Prometheus
resource "azurerm_monitor_workspace" "main" {
  name                = "${var.prefix}-prometheus"
  resource_group_name = azurerm_resource_group.main.name
  location    = azurerm_resource_group.main.location
}

resource "azurerm_dashboard_grafana" "main" {
  name                = "${var.prefix}-grafana"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  grafana_major_version = 10
  sku      = "Standard"
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  depends_on = [azurerm_kubernetes_cluster.main]
}

data "local_file" "service_yaml" {
  filename = "service-a.yaml"
}

resource "local_file" "updated_service_yaml" {
  filename = "service-a.yaml"
  content = replace(
    data.local_file.service_yaml.content, 
    regex("image:.*", data.local_file.service_yaml.content), 
    "image: ${azurerm_container_registry.main.login_server}/service-a:${var.tag}"
  )
  depends_on = [azurerm_role_assignment.aks_acr_pull]
}

resource "null_resource" "acr_login" {
  provisioner "local-exec" {
    command = "az acr login --name ${azurerm_container_registry.main.name} || exit 1"
  }
  depends_on = [local_file.updated_service_yaml]
}

resource "null_resource" "docker_build" {
  provisioner "local-exec" {
    command = "docker build --no-cache -t ${azurerm_container_registry.main.login_server}/service-a:${var.tag} ./service-a || exit 1"
  }
  depends_on = [null_resource.acr_login]
}

resource "null_resource" "docker_push" {
  provisioner "local-exec" {
    command = "docker push ${azurerm_container_registry.main.login_server}/service-a:${var.tag} || exit 1"
  }
  depends_on = [null_resource.docker_build]
}

resource "null_resource" "get_aks_credentials" {
  provisioner "local-exec" {
    command = "az aks get-credentials --resource-group ${var.prefix}-rg --name ${var.prefix}-aks --overwrite-existing"
  }
  depends_on = [null_resource.docker_push]
}

resource "null_resource" "apply_service_a_yaml" {
  provisioner "local-exec" {
    command = "kubectl apply -f ./service-a.yaml"
  }
  depends_on = [null_resource.get_aks_credentials]
}

resource "null_resource" "apply_service_b_yaml" {
  provisioner "local-exec" {
    command = "kubectl apply -f ./service-b.yaml"
  }
  depends_on = [null_resource.apply_service_a_yaml]
}

resource "null_resource" "apply_ingress_yaml" {
  provisioner "local-exec" {
    command = "kubectl apply -f ./ingress.yaml"
  }
  depends_on = [null_resource.apply_service_b_yaml]
}

resource "null_resource" "apply_nginx_ingress" {
  provisioner "local-exec" {
    command = "kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml"
  }
  depends_on = [null_resource.apply_ingress_yaml]
}

resource "null_resource" "apply_network_poliicy" {
  provisioner "local-exec" {
    command = "kubectl apply -f ./network-policy.yaml"
  }
  depends_on = [null_resource.apply_nginx_ingress]
}







