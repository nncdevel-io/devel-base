# Route 53 パブリックホストゾーンと 4 サブドメインの A レコード。
# 要件書 8.4 と 9.1 の FQDN 表（gitlab/jenkins/redmine/sonarqube）を実装。
#
# 上位ドメイン（例: example.com）からは NS 委任を受ける前提。
# 出力 `name_servers` を上位ゾーンの NS レコードに登録すること。

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

resource "aws_route53_zone" "this" {
  name = var.zone_name

  tags = merge(
    var.tags,
    {
      Name = var.zone_name
    },
  )
}

resource "aws_route53_record" "service" {
  for_each = toset(var.service_subdomains)

  zone_id = aws_route53_zone.this.zone_id
  name    = "${each.value}.${var.zone_name}"
  type    = "A"
  ttl     = var.record_ttl
  records = [var.eip_public_ip]
}
