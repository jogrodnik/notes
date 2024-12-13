We know the cause of the error. We need to implement a new Nginx proxy configuration, but we must be very cautious when deploying it to production. We will deploy this version at the beginning of January. The error stems from an incorrect configuration parameter: ssl_buffer_size.

If you're using Google BigQuery, for a Service Account to be able to read data from a view, you should assign at least the following roles:

BigQuery Data Viewer (roles/bigquery.dataViewer): This is a basic role that allows reading data in tables and views.
BigQuery Job User (roles/bigquery.jobUser): This allows running queries in BigQuery, which may be necessary if the view requires running an additional query.
Optionally, you can also assign the role BigQuery Read Session User (roles/bigquery.readSessionUser) if you're using the BigQuery Storage API.




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




# my_module/variables.tf
variable "example_var" {
  type = map(object({
    required_attr = string
    optional_attr = string  # Optional by providing default logic in locals
  }))
}

# my_module/main.tf
locals {
  # Set a default for the optional attribute if not provided
  processed_map = {
    for key, value in var.example_var : key => merge(
      { optional_attr = "default_value" },  # Default for the optional attribute
      value
    )
  }
}

output "processed_map_output" {
  value = local.processed_map
}

# Output the processed VM configuration
output "processed_vm_config" {
  value = local.processed_vms
}
Notes 


