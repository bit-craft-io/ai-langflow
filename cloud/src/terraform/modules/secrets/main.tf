# ADR-0009（平文.envでのシークレット管理）を Secrets Manager へ置き換える。
# Terraformはシークレットの「箱」のみを作成し、値は含めない。
# apply後に以下のようなコマンドで値を投入すること:
#   aws secretsmanager put-secret-value --secret-id <name_prefix>/<secret_name> --secret-string '...'

resource "aws_secretsmanager_secret" "this" {
  for_each = toset(var.secret_names)

  name                    = "${var.name_prefix}/${each.value}"
  description             = "on-premisesの.envから移行したシークレット: ${each.value}（値はTerraform管理外、apply後に別途投入すること）"
  recovery_window_in_days = var.recovery_window_in_days

  tags = var.tags
}

# 値未投入のままterraform applyが失敗しないよう、プレースホルダ値を1回だけ書き込む。
# 以降のterraform apply実行時に実値を上書きしてしまわないよう、lifecycle.ignore_changesで無視する。
resource "aws_secretsmanager_secret_version" "placeholder" {
  for_each = aws_secretsmanager_secret.this

  secret_id     = each.value.id
  secret_string = "CHANGE_ME"

  lifecycle {
    ignore_changes = [secret_string]
  }
}
