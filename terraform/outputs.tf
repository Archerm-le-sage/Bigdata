output "master_ip" {
  value = google_compute_instance.spark_master.network_interface[0].access_config[0].nat_ip
}

output "worker1_ip" {
  value = google_compute_instance.spark_worker[0].network_interface[0].access_config[0].nat_ip
}

output "worker2_ip" {
  value = google_compute_instance.spark_worker[1].network_interface[0].access_config[0].nat_ip
}
