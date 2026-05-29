output "zone_id" {
  description = "作成したパブリックホストゾーンの ID"
  value       = aws_route53_zone.this.zone_id
}

output "name_servers" {
  description = "上位ゾーンの NS レコードに登録する委任先ネームサーバ"
  value       = aws_route53_zone.this.name_servers
}

output "record_fqdns" {
  description = "作成された A レコードの FQDN 一覧"
  value       = [for r in aws_route53_record.service : r.fqdn]
}
