# accounts table
resource "aws_dynamodb_table" "account_table" {
  name = "account"
  read_capacity = 2
  write_capacity = 2

  hash_key = "account_no"
  // range_key      = "shard"

  attribute {
    name = "account_no"
    type = "N"
  }

  /*
  attribute {
    name = "shard"
    type = "N"
  }

  attribute {
    name = "admin_sub"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }
  */
  point_in_time_recovery {
    enabled = false
  }

  server_side_encryption {
    enabled = false
  }

  ttl {
    enabled = false
    attribute_name = ""
  }

  tags = {
    Name = "Account-Table"
    Environment = var.app_environment
  }
}

resource "aws_dynamodb_table" "bundle_status" {
  name = "bundle_status"
  read_capacity = 2
  write_capacity = 2

  hash_key = "name"
  range_key = "account_no"

  attribute {
    name = "name"
    type = "S"
  }

  attribute {
    name = "account_no"
    type = "N"
  }

  point_in_time_recovery {
    enabled = false
  }

  server_side_encryption {
    enabled = false
  }

  ttl {
    enabled = false
    attribute_name = ""
  }

  tags = {
    Name = "Bundle Status Table"
    Environment = var.app_environment
  }
}


resource "aws_dynamodb_table" "api_client" {
  name = "api_client"
  read_capacity = 1
  write_capacity = 1

  hash_key = "client_id"
  range_key = "account_no"


  attribute {
    name = "client_id"
    type = "S"
  }

  attribute {
    name = "account_no"
    type = "N"
  }
}
