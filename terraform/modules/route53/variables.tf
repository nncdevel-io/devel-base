variable "zone_name" {
  description = "ホストゾーン名（例: devel-base.example.com）。FQDN は <service>.<zone_name> で構成"
  type        = string
}

variable "service_subdomains" {
  description = "ホストゾーン直下に A レコードを作成するサブドメイン名の集合"
  type        = set(string)
  default = [
    "gitlab",
    "jenkins",
    "redmine",
    "sonarqube",
  ]
}

variable "eip_public_ip" {
  description = "サブドメイン A レコードの向き先となる EC2 ホストの EIP"
  type        = string
}

variable "record_ttl" {
  description = "A レコードの TTL（秒）。EIP 切り替え時の伝播速度を考慮し短めに設定"
  type        = number
  default     = 300
}

variable "tags" {
  description = "ホストゾーンに付与する共通タグ"
  type        = map(string)
  default     = {}
}
