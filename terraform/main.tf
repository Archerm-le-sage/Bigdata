resource "google_compute_network" "spark_network" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "spark_subnet" {
  name          = "${var.network_name}-subnet"
  ip_cidr_range = var.subnet_cidr
  network       = google_compute_network.spark_network.id
  region        = var.region
}

resource "google_compute_firewall" "spark_fw" {
  name    = "spark-allow"
  network = google_compute_network.spark_network.name

  allow {
    protocol = "tcp"
    ports    = ["22","7077","8080","4040"]
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_project_metadata" "default" {
  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
  }
}

# ❌ Suppression du Service Account (incompatible avec tes IAM)
# ❌ Suppression du IAM binding

resource "google_compute_instance" "spark_master" {
  name         = "spark-master"
  machine_type = "e2-medium"
  zone         = "europe-west1-b"

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
    }
  }

  # 🔥 IMPORTANT : Ajout obligatoire
  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
  }

  metadata_startup_script = file("${path.module}/startup.sh")

  network_interface {
    network    = google_compute_network.spark_network.id
    subnetwork = google_compute_subnetwork.spark_subnet.id
    access_config {}
  }

  service_account {
    email  = "default"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

resource "google_compute_instance" "spark_worker" {
  count        = var.worker_count
  name         = "spark-worker-${count.index + 1}"
  machine_type = var.worker_machine_type
  zone         = var.zone

  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
    }
  }

  # 🔥 Ajouter ceci pour corriger l’erreur SSH
  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key_path)}"
  }

  network_interface {
    network    = google_compute_network.spark_network.id
    subnetwork = google_compute_subnetwork.spark_subnet.id
    access_config {}
  }

  service_account {
    email  = "default"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

