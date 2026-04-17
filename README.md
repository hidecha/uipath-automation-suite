# UiPath Automation Suite - Infrastructure as Code

UiPath Automation Suite を AWS (EKS) または Azure (AKS) にデプロイするための Terraform コードです。

## 前提条件

- [Terraform](https://developer.hashicorp.com/terraform/install) v1.5 以上
- 対象クラウドの CLI がインストール・認証済みであること
  - AWS: [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) (`aws configure` 完了済み)
  - Azure: [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (`az login` 完了済み)

## リポジトリ構成

```
.
├── eks/                          # AWS (EKS) 環境
│   ├── main.tf                   # Provider 定義
│   ├── variables.tf              # 変数定義
│   ├── network.tf                # VPC / Subnet / Security Group
│   ├── compute.tf                # Bastion VM / Client VM / Key Pair
│   ├── eks.tf                    # EKS クラスタ / IAM / DNS / EFS
│   ├── sql.tf                    # RDS SQL Server
│   ├── postgres.tf               # RDS PostgreSQL
│   ├── redis.tf                  # ElastiCache Redis
│   ├── storage.tf                # SQS Queues
│   ├── outputs.tf                # 出力値
│   └── terraform.tfvars.template # パラメータテンプレート
│
├── aks/                          # Azure (AKS) 環境
│   ├── main.tf                   # Provider 定義
│   ├── variables.tf              # 変数定義
│   ├── network.tf                # VNet / Subnet / NSG
│   ├── compute.tf                # Bastion VM / Client VM
│   ├── aks.tf                    # AKS クラスタ / DNS
│   ├── sql.tf                    # Azure SQL Server
│   ├── postgres.tf               # Azure Database for PostgreSQL
│   ├── redis.tf                  # Azure Cache for Redis
│   ├── storage.tf                # Storage Account / Queues / Blob
│   ├── outputs.tf                # 出力値
│   └── terraform.tfvars.template # パラメータテンプレート
│
├── .gitignore
└── README.md
```

## デプロイされるリソース

| リソース | EKS (AWS) | AKS (Azure) |
|---|---|---|
| ネットワーク | VPC, Public/Private Subnet, IGW, NAT GW | VNet, Subnet |
| セキュリティ | Security Group (Bastion/Internal) | NSG |
| Bastion | Windows Server EC2 + EIP | Windows Server VM + Public IP |
| Client | Amazon Linux 2023 EC2 | RHEL VM |
| Kubernetes | EKS (CPU/GPU/ASRobot Node Group) | AKS (Default/ASRobot Node Pool) |
| SQL Server | RDS SQL Server SE | Azure SQL Server |
| PostgreSQL | RDS PostgreSQL | Azure Database for PostgreSQL Flexible Server |
| Redis | ElastiCache Redis | Azure Cache for Redis |
| ストレージ | EFS + SQS | Storage Account + Queue + Blob |
| DNS | Route 53 Private Hosted Zone | Private DNS Zone |

---

## EKS (AWS) 環境

### 1. パラメータファイルの作成

```bash
cd eks
cp terraform.tfvars.template terraform.tfvars
```

`terraform.tfvars` を編集し、環境に合わせて値を設定します。

主な設定項目:

| パラメータ | 説明 | 例 |
|---|---|---|
| `res_prefix` | リソース名のプレフィックス | `myeks01` |
| `region` | AWS リージョン | `ap-northeast-1` |
| `vpc_address` | VPC CIDR | `10.1.0.0/16` |
| `my_ip` | Bastion RDP 接続元 IP | `203.0.113.1` |
| `sql_username` / `sql_password` | SQL Server 管理者認証情報 | - |
| `redis_password` | Redis 認証トークン (16文字以上) | - |
| `eks_fqdn` | Automation Suite の FQDN | `as.example.com` |
| `kubernetes_version` | EKS バージョン | `1.34` |
| `number_of_cpu_nodes` | CPU ノード数 | `3` |
| `enable_public_access` | EKS パブリックアクセスの有効化 | `false` |
| `number_of_gpu_nodes` | GPU ノード数 (不要なら `0`) | `0` |
| `number_of_asrobot_nodes` | AS Robot ノード数 (不要なら `0`) | `0` |
| `postgres_username` / `postgres_password` | PostgreSQL 管理者認証情報 | - |
| `s3_bucket_name` | S3 バケット名パターン | `myeks01-*` |

### 2. 初期化

```bash
terraform init
```

### 3. 実行計画の確認

```bash
terraform plan
```

### 4. デプロイ

```bash
terraform apply
```

### 5. 出力値の確認

デプロイ完了後、以下の値が出力されます:

| 出力 | 説明 |
|---|---|
| `bastion_public_ip_address` | Bastion VM のパブリック IP (RDP 接続先) |
| `client_private_ip_address` | Client VM のプライベート IP |
| `sqlserver_hostname` | RDS SQL Server のエンドポイント |
| `postgres_hostname` | RDS PostgreSQL のエンドポイント |
| `postgres_port` | PostgreSQL のポート番号 |
| `redis_endpoint` | ElastiCache Redis のエンドポイント |
| `private_subnet_ip_ids` | プライベートサブネット ID 一覧 |

```bash
terraform output
```

### 6. EKS クラスタへの接続

```bash
aws eks update-kubeconfig --name <res_prefix>-cluster --region <region>
kubectl get nodes
```

### 7. リソースの削除

```bash
terraform destroy
```

---

## AKS (Azure) 環境

### 1. パラメータファイルの作成

```bash
cd aks
cp terraform.tfvars.template terraform.tfvars
```

`terraform.tfvars` を編集し、環境に合わせて値を設定します。

主な設定項目:

| パラメータ | 説明 | 例 |
|---|---|---|
| `res_prefix` | リソース名のプレフィックス | `myaks01` |
| `rg_name` | リソースグループ名 | `myaks01-rg` |
| `location` | Azure リージョン | `Japan East` |
| `vnet_address` | VNet CIDR | `10.1.0.0/16` |
| `subnet_address` | サブネット CIDR | `10.1.0.0/20` |
| `my_ip` | Bastion RDP 接続元 IP | `203.0.113.1` |
| `enable_public_access` | AKS パブリックアクセスの有効化 | `false` |
| `aks_internal_lb_ip` | 内部 LB の静的 IP (`enable_public_access=false` 時必須) | `10.1.0.100` |
| `vm_username` / `vm_password` | VM 管理者認証情報 | - |
| `client_hostname` | Client VM ホスト名 | `client01` |
| `sql_hostname` | Azure SQL Server ホスト名 (グローバル一意) | `myakssql01` |
| `sql_username` / `sql_password` | SQL Server 管理者認証情報 | - |
| `storage_account` | Storage Account 名 (グローバル一意) | `myaksstr01` |
| `redis_hostname` | Redis Cache 名 (グローバル一意) | `myaksredis01` |
| `aks_fqdn` | Automation Suite の FQDN | `aks.example.com` |
| `aks_subnet_address` | AKS サービス CIDR | `10.2.0.0/16` |
| `aks_dns_ip` | AKS DNS サービス IP | `10.2.0.10` |
| `aks_node_size` | AKS ノード VM サイズ | `Standard_F32s_v2` |
| `number_of_cpu_nodes` | CPU ノード数 | `3` |
| `number_of_asrobot_nodes` | AS Robot ノード数 (不要なら `0`) | `0` |
| `postgres_hostname` | PostgreSQL サーバー名 (グローバル一意) | `myakspg01` |
| `postgres_username` / `postgres_password` | PostgreSQL 管理者認証情報 | - |
| `postgres_subnet_address` | PostgreSQL 委任サブネット CIDR | `10.1.16.0/24` |

### 2. 初期化

```bash
terraform init
```

### 3. 実行計画の確認

```bash
terraform plan
```

### 4. デプロイ

```bash
terraform apply
```

### 5. 出力値の確認

デプロイ完了後、以下の値が出力されます:

| 出力 | 説明 |
|---|---|
| `bastion_public_ip_address` | Bastion VM のパブリック IP (RDP 接続先) |
| `client_private_ip_address` | Client VM のプライベート IP |
| `sqlserver_hostname` | Azure SQL Server の FQDN |
| `postgres_hostname` | PostgreSQL Flexible Server の FQDN |
| `postgres_port` | PostgreSQL のポート番号 |
| `AKS_public_ip_address` | AKS Load Balancer のパブリック IP (`enable_public_access=true` 時) |
| `AKS_internal_lb_ip` | AKS 内部 Load Balancer の IP (`enable_public_access=false` 時) |

```bash
terraform output
```

### 6. AKS クラスタへの接続

```bash
az aks get-credentials --resource-group <rg_name> --name <res_prefix>-cluster
kubectl get nodes
```

### 7. リソースの削除

```bash
terraform destroy
```

---

## セキュリティに関する注意事項

- **`terraform.tfvars` をリポジトリにコミットしないでください。** パスワード等の機密情報が含まれます。`.gitignore` で除外済みです。
- **`input.json` をリポジトリにコミットしないでください。** Automation Suite の設定ファイルには認証情報が含まれます。
- **`terraform.tfstate` にはすべてのリソース属性がパスワードを含め平文で記録されます。** 本番利用時は S3 + DynamoDB (AWS) や Azure Storage (Azure) によるリモートバックエンドを設定してください。
- パスワード変数には `sensitive = true` が設定されているため、`plan`/`apply` のコンソール出力にはマスクされて表示されます。
