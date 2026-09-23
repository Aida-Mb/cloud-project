module "storage" {
  source = "./modules/storage"

  name = "${local.resource_prefix}-bucket"
}

module "database" {
  source = "./modules/database"

  name = "${local.resource_prefix}-table"
}