terraform {
  required_version = ">= 0.12"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

resource "cloudflare_zone" "zone" {
  for_each   = var.zones
  account_id = each.value.account_id
  zone       = each.value.zone
  type       = each.value.dns
  plan       = each.value.plan
}
data "cloudflare_zones" "zone" {
  for_each = var.zones
  filter {
    name        = each.value.zone
    lookup_type = "exact"
  }
  depends_on = [
    cloudflare_zone.zone
  ]
}

resource "cloudflare_zone_settings_override" "zone-overrides" {
  for_each = var.zones
  zone_id  = lookup(data.cloudflare_zones.zone[each.value.zone].zones[0], "id")
  lifecycle {
    ignore_changes = [
      # ignore chages to zone_id as it forces the zone to be recreated
      zone_id
    ]
  }
  settings {
    ssl              = each.value.ssl
    always_use_https = each.value.always_use_https
    min_tls_version  = each.value.min_tls_version
  }

  depends_on = [
    cloudflare_zone.zone
  ]
}

resource "cloudflare_record" "records_value" {
  lifecycle {
    ignore_changes = [
      # Ignore changes to zone_id as it forces cloudflare to remove and re-create zones
      zone_id
    ]
  }
  for_each = {
    for rec in local.value_records : "${rec.zone_key}.${rec.record_key}" => rec
  }
  name     = each.value.dns_name
  type     = each.value.dns_type
  proxied  = each.value.dns_proxied
  priority = each.value.dns_priority
  zone_id  = lookup(data.cloudflare_zones.zone[each.value.zone_key].zones[0], "id")
  depends_on = [
    cloudflare_zone.zone,
  ]
  content = each.value.dns_value == "SRV" ? null : each.value.dns_value
}

resource "cloudflare_record" "records_data" {
  lifecycle {
    ignore_changes = [
      # Ignore changes to zone_id as it forces cloudflare to remove and re-create zones
      zone_id
    ]
  }
  for_each = {
    for rec in local.data_records : "${rec.zone_key}.${rec.record_key}" => rec
  }
  name     = each.value.dns_name
  type     = each.value.dns_type
  proxied  = each.value.dns_proxied
  priority = each.value.dns_priority
  zone_id  = lookup(data.cloudflare_zones.zone[each.value.zone_key].zones[0], "id")
  depends_on = [
    cloudflare_zone.zone,
  ]
  data {
    service  = each.value.dns_data_service
    proto    = each.value.dns_data_proto
    name     = each.value.dns_data_name
    priority = each.value.dns_data_priority
    weight   = each.value.dns_data_weight
    port     = each.value.dns_data_port
    target   = each.value.dns_data_target
  }
}
