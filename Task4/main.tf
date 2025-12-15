terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.100"
    }
  }
}

# Provider configuration: подключение к Yandex Cloud через service account key JSON
provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}

# -------------------------------
# Networking
# -------------------------------

# Создание VPC сети
resource "yandex_vpc_network" "main" {
  name = "${var.project_name}-network"
}

# Публичная подсеть (с NAT доступом в интернет)
resource "yandex_vpc_subnet" "public" {
  name           = "${var.project_name}-public-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [var.public_subnet_cidr]
}

# Приватная подсеть (без прямого доступа в интернет)
resource "yandex_vpc_subnet" "private" {
  name           = "${var.project_name}-private-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [var.private_subnet_cidr]
}

# NAT Gateway для выхода приватных ресурсов в интернет
resource "yandex_vpc_gateway" "nat_gateway" {
  name = "${var.project_name}-nat-gateway"
}

# -------------------------------
# Compute resources
# -------------------------------

# Отдельный диск для виртуальной машины
resource "yandex_compute_disk" "vm_disk" {
  name = "${var.project_name}-disk"
  size = var.disk_size
  type = "network-hdd"
  zone = var.zone
}

# Виртуальная машина (Ubuntu)
resource "yandex_compute_instance" "vm" {
  name        = "${var.project_name}-vm"
  platform_id = "standard-v1"
  zone        = var.zone

  # Конфигурация ресурсов (CPU и RAM)
  resources {
    cores  = var.vm_cores
    memory = var.vm_memory
  }

  # Загрузочный диск с образом Ubuntu
  boot_disk {
    initialize_params {
      image_id = var.ubuntu_image_id
      size     = var.disk_size
    }
  }

  # Сетевой интерфейс: подключение к публичной подсети с NAT
  network_interface {
    subnet_id = yandex_vpc_subnet.public.id
    nat       = true
  }

  # Метаданные: добавляем SSH ключ для доступа
  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
  }
}