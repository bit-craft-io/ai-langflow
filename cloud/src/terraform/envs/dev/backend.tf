# tfstateのリモート管理用。S3バケット・DynamoDBロックテーブルは事前に手動作成しておくこと
# （このTerraform構成自体では管理しない。state管理用リソースをstate自身で管理すると鶏卵問題になるため）。
# prodとは別のkeyを使うこと（同じバケットを共用してもよいが、tfstateファイル自体は分離する）。
#
# 値を埋めて有効化すること。バケット名・テーブル名は環境に合わせて変更する。
#
# terraform {
#   backend "s3" {
#     bucket         = "CHANGE_ME-agent-dev-tfstate"
#     key            = "cloud/envs/dev/terraform.tfstate"
#     region         = "ap-northeast-1"
#     dynamodb_table = "CHANGE_ME-agent-dev-tfstate-lock"
#     encrypt        = true
#   }
# }
