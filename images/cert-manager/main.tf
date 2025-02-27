locals {
  components = toset(["acmesolver", "controller", "cainjector", "webhook"])
}

variable "target_repository" {
  description = "The docker repo into which the image and attestations should be published."
}

module "config" {
  for_each = local.components
  source   = "./configs"
  name     = each.key
}

module "latest" {
  for_each = local.components
  source   = "../../tflib/publisher"

  name = basename(path.module)

  target_repository = "${var.target_repository}-${each.key}"
  config            = module.config[each.key].config
}

module "dev" {
  source = "../../tflib/dev-subvariant"
}

module "latest-dev" {
  for_each = local.components
  source   = "../../tflib/publisher"

  name = basename(path.module)

  target_repository = "${var.target_repository}-${each.key}"
  config            = jsonencode(module.latest[each.key].config)
  extra_packages    = concat(module.dev.extra_packages, ["cmctl"])
}

module "version-tags" {
  for_each = local.components
  source   = "../../tflib/version-tags"

  package = "cert-manager-1.12-${each.key}"
  config  = module.latest[each.key].config
}

module "test-latest" {
  source = "./tests"

  digests = { for k, v in module.latest : k => v.image_ref }
}

module "tagger" {
  for_each = local.components
  source   = "../../tflib/tagger"

  depends_on = [
    module.test-latest,
  ]

  tags = merge(
    { for t in toset(concat(["latest"], module.version-tags[each.key].tag_list)) : t => module.latest[each.key].image_ref },
    { for t in toset(concat(["latest"], module.version-tags[each.key].tag_list)) : "${t}-dev" => module.latest-dev[each.key].image_ref },
  )
}
