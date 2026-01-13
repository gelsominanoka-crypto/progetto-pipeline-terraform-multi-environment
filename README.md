# Infrastructure AWS - Terraform Multi-Environment

Infrastruttura AWS semplice e identica per Dev e Prod, gestita con Terraform.

## Struttura del Progetto

```
Infrastructure/Environments/
    ├── Dev/
    │   ├── provider.tf      # Configurazione provider AWS
    │   ├── variables.tf     # Variabili di ambiente
    │   ├── main.tf          # Definizione risorse AWS
    │   └── outputs.tf       # Output delle risorse create
    └── Prod/
        ├── provider.tf      # Configurazione provider AWS
        ├── variables.tf     # Variabili di ambiente
        ├── main.tf          # Definizione risorse AWS
        └── outputs.tf       # Output delle risorse create
```

## Risorse Create

Ogni ambiente (Dev/Prod) crea:

- **1 VPC** (CIDR: 10.0.0.0/16)
- **1 Subnet Pubblica** (CIDR: 10.0.1.0/24)
- **1 Internet Gateway**
- **1 Route Table** con route verso Internet Gateway
- **1 Security Group** con porte 22 (SSH) e 80 (HTTP) aperte
- **1 EC2 Instance** (Amazon Linux 2, t2.micro)

## Prerequisiti

1. **Terraform** installato (versione >= 1.0)
2. **AWS CLI** configurato con credenziali valide
3. **Key Pair AWS** già creata nella regione di destinazione

## Utilizzo

### 1. Configurare le variabili

Prima di applicare, configurare la variabile `key_pair_name` in ogni ambiente.

**Opzione A: File terraform.tfvars**

Crea `Infrastructure/Environments/Dev/terraform.tfvars`:
```hcl
key_pair_name = "nome-tua-key-pair"
aws_region    = "us-east-1"
```

Crea `Infrastructure/Environments/Prod/terraform.tfvars`:
```hcl
key_pair_name = "nome-tua-key-pair"
aws_region    = "us-east-1"
```

**Opzione B: Variabili da linea di comando**

```bash
terraform apply -var="key_pair_name=nome-tua-key-pair"
```

### 2. Inizializzare Terraform

Per Dev:
```bash
cd Infrastructure/Environments/Dev
terraform init
```

Per Prod:
```bash
cd Infrastructure/Environments/Prod
terraform init
```

### 3. Pianificare le modifiche

```bash
terraform plan
```

### 4. Applicare l'infrastruttura

```bash
terraform apply
```

### 5. Visualizzare gli output

Dopo l'applicazione, visualizza gli output:
```bash
terraform output
```

Output disponibili:
- `vpc_id`: ID della VPC
- `subnet_id`: ID della subnet pubblica
- `ec2_public_ip`: IP pubblico dell'istanza EC2
- `ec2_instance_id`: ID dell'istanza EC2
- `security_group_id`: ID del security group

### 6. Distruggere l'infrastruttura

```bash
terraform destroy
```

## Variabili Disponibili

| Variabile | Descrizione | Default |
|-----------|-------------|---------|
| `aws_region` | Regione AWS | `us-east-1` |
| `environment` | Nome ambiente (Dev/Prod) | `Dev` o `Prod` |
| `instance_type` | Tipo istanza EC2 | `t2.micro` |
| `key_pair_name` | Nome della Key Pair AWS | **Richiesta** |
| `allowed_cidr` | CIDR consentito per SSH/HTTP | `0.0.0.0/0` |

## Note Importanti

- **Key Pair**: Assicurati che la Key Pair esista già in AWS prima di applicare Terraform
- **Costi**: L'infrastruttura utilizza risorse gratuite (t2.micro) ma potrebbero esserci costi per il traffico dati
- **Sicurezza**: Per produzione, considera di restringere `allowed_cidr` a IP specifici invece di `0.0.0.0/0`
- **Regioni**: Dev e Prod possono essere deployati in regioni diverse modificando `aws_region`

## Esempio Completo

```bash
# Setup Dev
cd Infrastructure/Environments/Dev
terraform init
terraform plan -var="key_pair_name=my-key-pair"
terraform apply -var="key_pair_name=my-key-pair"

# Setup Prod
cd ../Prod
terraform init
terraform plan -var="key_pair_name=my-key-pair"
terraform apply -var="key_pair_name=my-key-pair"
```

