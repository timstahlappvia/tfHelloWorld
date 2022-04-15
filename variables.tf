variable "source_registry" {
    type = string
}

variable "controller_image" {
    type = string
}

variable "controller_tag" {
    type = string
}

variable "patch_image" {
    type = string
}

variable "patch_tag"{
    type = string
}

variable "defaultbackend_image" {
    type = string
}

variable "defaultbackend_tag" {
    type = string
}

variable "cert_manager_registry" {
    type = string
}

variable "cert_manager_tag" {
    type = string
}

variable "cert_manager_image_controller" {
    type = string
}

variable "cert_manager_image_webhook" {
    type = string
}

variable "cert_manager_cainjector" {
    type = string
}