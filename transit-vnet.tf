locals {
  prefix-hub         = "transit"
  hub-location       = "australiaeast"
  hub-resource-group = "transit-vnet-rg"
}

resource "azurerm_resource_group" "transit-vnet-rg" { #Resource group for transit vnet
  name     = local.hub-resource-group
  location = local.hub-location
}

#VNets

resource "azurerm_virtual_network" "transit-vnet" { #Transit VNet 
  name                = "${local.prefix-hub}-vnet"
  location            = azurerm_resource_group.transit-vnet-rg.location
  resource_group_name = azurerm_resource_group.transit-vnet-rg.name
  address_space       = ["10.110.0.0/16"]

  tags = {
    environment = "Production"
  }
}

#Subnets

resource "azurerm_subnet" "public-transit-subnet" { #Subnet for public facing load balancer
  name                 = "PublicSubnet"
  resource_group_name  = azurerm_resource_group.transit-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.transit-vnet.name
  address_prefixes     = ["10.110.129.0/24"]
}

resource "azurerm_subnet" "private-transit-subnet" { #Subnet for internal load balancer
  name                 = "PrivateSubnet"
  resource_group_name  = azurerm_resource_group.transit-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.transit-vnet.name
  address_prefixes     = ["10.110.0.0/24"]
}

resource "azurerm_subnet" "mgmt-subnet" { #Subnet for firewall management
  name                 = "MgmtSubnet"
  resource_group_name  = azurerm_resource_group.transit-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.transit-vnet.name
  address_prefixes     = ["10.110.255.0/24"]
}

#Load Balancers

resource "azurerm_public_ip" "public-lb-ip" { #Public IP address for the public facing load balancer 
  name                = "PublicLBIP"
  location            = azurerm_resource_group.transit-vnet-rg.location
  resource_group_name = azurerm_resource_group.transit-vnet-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "public-lb" { #Public facing load balancer 
  name                = "PublicLoadBalancer"
  location            = azurerm_resource_group.transit-vnet-rg.location
  resource_group_name = azurerm_resource_group.transit-vnet-rg.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.public-lb-ip.id
  }
}

#Firewalls and firewall resources (NICs)

resource "azurerm_public_ip" "vmseries-1-public-ip" { #Public IP address for vmseries-1 firewall 
  name                = "vmseries-1-public-ip"
  location            = azurerm_resource_group.transit-vnet-rg.location
  resource_group_name = azurerm_resource_group.transit-vnet-rg.name
  allocation_method   = "Static"
  domain_name_label   = "testvmseries-1"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "vmseries-2-public-ip" { #Public IP address for vmseries-2 firewall 
  name                = "vmseries-2-public-ip"
  location            = azurerm_resource_group.transit-vnet-rg.location
  resource_group_name = azurerm_resource_group.transit-vnet-rg.name
  allocation_method   = "Static"
  domain_name_label   = "testvmseries-2"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "fw1-public-nic" { #NIC for fw1 public transit interface
  name                 = "fw1-public-nic"
  location             = azurerm_resource_group.transit-vnet-rg.location
  resource_group_name  = azurerm_resource_group.transit-vnet-rg.name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public-transit-subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.110.129.4"
  }
}

resource "azurerm_network_interface" "fw1-private-nic" { #NIC for fw1 private transit interface
  name                 = "fw1-private-nic"
  location             = azurerm_resource_group.transit-vnet-rg.location
  resource_group_name  = azurerm_resource_group.transit-vnet-rg.name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private-transit-subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.110.0.4"
  }

}
resource "azurerm_network_interface" "fw2-public-nic" { #NIC for fw2 public transit interface
  name                 = "fw2-public-nic"
  location             = azurerm_resource_group.transit-vnet-rg.location
  resource_group_name  = azurerm_resource_group.transit-vnet-rg.name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public-transit-subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.110.129.5"
  }
}

resource "azurerm_network_interface" "fw2-private-nic" { #NIC for fw2 private transit interface
  name                 = "fw2-private-nic"
  location             = azurerm_resource_group.transit-vnet-rg.location
  resource_group_name  = azurerm_resource_group.transit-vnet-rg.name
  enable_ip_forwarding = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.private-transit-subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.110.0.5"
  }
}

#Network security groups and associations

resource "azurerm_network_security_group" "allow-mgmt-subnet-nsg" { #NSG for management subnet
  name                = "AllowManagementSubnet"
  location            = azurerm_resource_group.transit-vnet-rg.location
  resource_group_name = azurerm_resource_group.transit-vnet-rg.name

  security_rule {
    name                       = "AllowHTTPS-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH-Inbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_subnet_network_security_group_association" "mgmtsubnet-to-mgmtnsg" { #associates the management subnet and the management subnet NSG
  subnet_id                 = azurerm_subnet.mgmt-subnet.id
  network_security_group_id = azurerm_network_security_group.allow-mgmt-subnet-nsg.id
}

resource "azurerm_network_security_group" "allow-list-nsg" { #Allow-list NSG for dataplane subnets
  name                = "AllowAll-Subnet"
  location            = azurerm_resource_group.transit-vnet-rg.location
  resource_group_name = azurerm_resource_group.transit-vnet-rg.name

  security_rule {
    name                       = "AllowAll-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_subnet_network_security_group_association" "publicsubnet-to-allowlistnsg" { #associates the public-transit-subnet and the allow all NSG
  subnet_id                 = azurerm_subnet.public-transit-subnet.id
  network_security_group_id = azurerm_network_security_group.allow-list-nsg.id
}

resource "azurerm_subnet_network_security_group_association" "privatesubnet-to-allowlistnsg" { #associates the private-transit-subnet and the allow all NSG
  subnet_id                 = azurerm_subnet.private-transit-subnet.id
  network_security_group_id = azurerm_network_security_group.allow-list-nsg.id
}