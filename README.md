# my_module/variables.tf
variable "vm_configurations" {
  type = map(object({
    name          = string                      # Required attribute
    instance_type = string                      # Required attribute
    disk_size     = number                      # Optional attribute, we'll provide default
    tags          = map(string)                 # Optional attribute, we'll provide default
  }))
}

# my_module/main.tf
locals {
  # Process the VM configurations, filling in defaults for optional attributes
  processed_vms = {
    for vm_key, vm_values in var.vm_configurations : vm_key => merge(
      {
        disk_size = 100,                        # Default disk size if not provided
        tags      = { "Environment" = "default" } # Default tags if not provided
      },
      vm_values
    )
  }
}

# Example of creating resources with the processed map
resource "aws_instance" "example" {
  for_each      = local.processed_vms
  instance_type = each.value.instance_type
  ami           = "ami-123456"                 # Static value for simplicity
  tags          = each.value.tags

  # Optional disk size management (example use case)
  root_block_device {
    volume_size = each.value.disk_size
  }
}

# Output the processed VM configuration
output "processed_vm_config" {
  value = local.processed_vms
}
Notes 


