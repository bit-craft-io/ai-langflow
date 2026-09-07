# ADR-0012: `cloud/terraform/envs/dev` のEC2インスタンスタイプはt3.smallとする

## Status
Accepted

## Context
- `cloud/terraform/envs/dev`（AWS移行構成のコスト最小構成、[cloud/docs/assumptions.md](../../cloud/docs/assumptions.md)「D.」〜「F.」参照）は、
  本番相当の負荷ではなく動作確認・検証用途のみを想定している。
- コストを極力抑えたいという要望があり、EC2インスタンスタイプもデフォルトの`t3.medium`から見直すことになった。
- EC2上ではvoicevox/langflow/bridge/opensearch/opensearch-uiの5コンテナが同居する
  （[ADR-0001](0001-docker-compose-microservices.md)、[cloud/README.md](../../cloud/README.md)「アーキテクチャ概要」参照）。
  OpenSearchは`OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m`でヒープを確保するため、`t3.micro`（1 vCPU / 1 GiB RAM）は
  メモリ不足のリスクが高いと判断し見送った。

## Decision
- `cloud/terraform/envs/dev/variables.tf`の`instance_type`変数のデフォルトを`t3.small`（2 vCPU / 2 GiB RAM）にする。
- `envs/prod`（デフォルト`t3.large`）には影響しない。`modules/ec2_docker_host`モジュール自体のデフォルトも変更しない。

## Consequences
- `t3.small`は本来のサイジング目安（`cloud/docs/assumptions.md`「C.」）より小さく、5サービス同時稼働時にOOMする
  リスクは残る。動作確認の内容次第では個別サービスを止めて検証する、または`terraform.tfvars`で
  `instance_type`を`t3.medium`/`t3.large`へ一時的に引き上げる運用が必要になる場合がある。
- 実際の負荷に基づくサイジング検証は行っていない（`cloud/docs/assumptions.md`「C.」参照）。
