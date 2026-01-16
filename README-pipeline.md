# Pipeline CI/CD AWS per Terraform (Dev/Prod)

Guida passo-passo per una pipeline CodePipeline + CodeBuild che usa **buildspec separati** per Plan e Apply, e decide se lavorare su Dev o Prod in base ai file modificati.

## Architettura
- **CodePipeline**: trigger su `main`, orchestrazione degli stage.
- **CodeBuild**: un progetto unico, riutilizzato per Plan e Apply con **buildspec diversi**.
- **IAM**: ruoli per CodePipeline e CodeBuild.
- **S3**: bucket artifact CodePipeline (per passare il file `tfplan` tra stage).
- **SNS (opzionale)**: per notifiche di approvazione manuale.

## File Buildspec

Il repository contiene **due buildspec separati**:

- **`buildspec-plan.yml`**: esegue `terraform init`, `validate`, `plan` e genera `tfplan`
- **`buildspec-apply.yml`**: esegue `terraform apply` usando il `tfplan` generato nello stage precedente

## Ruoli IAM (minimo)

### CodePipeline Role
- **Trust**: `codepipeline.amazonaws.com`
- **Permessi**:
  - `codebuild:StartBuild`
  - `codebuild:BatchGetBuilds`
  - `iam:PassRole` (per il ruolo CodeBuild)
  - `s3:PutObject`, `s3:GetObject` (bucket artifact)
  - `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`

### CodeBuild Role
- **Trust**: `codebuild.amazonaws.com`
- **Permessi**:
  - Permessi per risorse Terraform (EC2, VPC, IAM, ecc.)
  - `s3:PutObject`, `s3:GetObject` (bucket artifact)
  - `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`
  - `kms:Decrypt` (se usi SSE-KMS per S3)
  - Opzionale: `ssm:GetParameter`, `secretsmanager:GetSecretValue` (per variabili sensibili)

## Configurazione CodeBuild

### Creare il Progetto CodeBuild

1. Vai su **CodeBuild** → **Create build project**
2. **Nome progetto**: `terraform-pipeline` (o nome a scelta)
3. **Source**: Non necessario (CodePipeline passerà il codice)
4. **Environment**:
   - **Image**: `aws/codebuild/standard:7.0` (Ubuntu con Docker)
   - **Service role**: seleziona il ruolo CodeBuild creato sopra
5. **Buildspec**: 
   - **Use a buildspec file**: `buildspec-plan.yml` (default, verrà override da CodePipeline)
6. **Artifacts**: 
   - **Type**: CodePipeline
   - **Artifact packaging**: Zip

## Configurazione CodePipeline

### Stage 1: Source
- **Source provider**: GitHub (o CodeCommit/Bitbucket)
- **Repository**: il tuo repository
- **Branch**: `main`
- **Output artifact**: `SourceOutput`

### Stage 2: Plan (CodeBuild)
- **Action type**: Build
- **Action name**: `TerraformPlan`
- **Provider**: AWS CodeBuild
- **Input artifacts**: `SourceOutput`
- **Project name**: `terraform-pipeline` (il progetto creato sopra)
- **Buildspec override**: `buildspec-plan.yml` ⚠️ **IMPORTANTE**
- **Output artifacts**: `PlanArtifacts`

**Come configurare il buildspec override**:
- Nella console CodePipeline, quando aggiungi l'action CodeBuild:
  - Espandi **Advanced**
  - In **Buildspec override**, inserisci: `buildspec-plan.yml`

### Stage 3: Manual Approval
- **Action type**: Manual approval
- **Action name**: `ApproveDeployment`
- **SNS topic** (opzionale): per ricevere notifiche email

### Stage 4: Apply (CodeBuild)
- **Action type**: Build
- **Action name**: `TerraformApply`
- **Provider**: AWS CodeBuild
- **Input artifacts**: `PlanArtifacts` (contiene il `tfplan` generato nello stage Plan)
- **Project name**: `terraform-pipeline` (stesso progetto)
- **Buildspec override**: `buildspec-apply.yml` ⚠️ **IMPORTANTE**

**Come configurare il buildspec override**:
- Nella console CodePipeline, quando aggiungi l'action CodeBuild:
  - Espandi **Advanced**
  - In **Buildspec override**, inserisci: `buildspec-apply.yml`

## Come funziona la rilevazione ambiente

### Nel buildspec-plan.yml:
1. Usa `git diff --name-only HEAD~1 HEAD` per vedere i file modificati
2. Controlla se i path iniziano con `Infrastructure/Environments/Dev/` o `Infrastructure/Environments/Prod/`
3. Se trova modifiche in **Dev** → esegue `terraform plan` solo in `Infrastructure/Environments/Dev/`
4. Se trova modifiche in **Prod** → esegue `terraform plan` solo in `Infrastructure/Environments/Prod/`
5. Se trova modifiche in **entrambi** → **ERRORE** (non permette deploy simultanei)
6. Se **nessuna modifica** → **ERRORE** (niente da fare)

### Nel buildspec-apply.yml:
1. Cerca il file `tfplan` in `Infrastructure/Environments/Dev/` o `Infrastructure/Environments/Prod/`
2. Se trova `Dev/tfplan` → esegue `terraform apply` in Dev
3. Se trova `Prod/tfplan` → esegue `terraform apply` in Prod
4. Il file `tfplan` viene passato tramite gli **artifacts** di CodePipeline

## Passaggio del tfplan tra stage

Il file `tfplan` viene salvato come **artifact** nello stage Plan e passato allo stage Apply:

1. **Stage Plan**: genera `Infrastructure/Environments/Dev/tfplan` (o Prod)
2. **Artifacts**: il buildspec-plan.yml include `**/*` negli artifacts, quindi `tfplan` viene incluso
3. **Stage Apply**: riceve gli artifacts e trova il file `tfplan` nella cartella corretta

## Configurazione tramite AWS CLI (alternativa)

Se preferisci configurare via CLI invece della console:

```bash
# Crea il progetto CodeBuild
aws codebuild create-project \
  --name terraform-pipeline \
  --service-role arn:aws:iam::ACCOUNT:role/CodeBuildRole \
  --artifacts type=CODEPIPELINE \
  --environment type=LINUX_CONTAINER,image=aws/codebuild/standard:7.0 \
  --source type=CODEPIPELINE

# Crea la pipeline (JSON config)
aws codepipeline create-pipeline --cli-input-json file://pipeline.json
```

Esempio `pipeline.json`:
```json
{
  "pipeline": {
    "name": "terraform-dev-prod-pipeline",
    "roleArn": "arn:aws:iam::ACCOUNT:role/CodePipelineRole",
    "stages": [
      {
        "name": "Source",
        "actions": [{
          "name": "Source",
          "actionTypeId": {
            "category": "Source",
            "owner": "AWS",
            "provider": "GitHub",
            "version": "1"
          },
          "outputArtifacts": [{"name": "SourceOutput"}]
        }]
      },
      {
        "name": "Plan",
        "actions": [{
          "name": "TerraformPlan",
          "actionTypeId": {
            "category": "Build",
            "owner": "AWS",
            "provider": "CodeBuild",
            "version": "1"
          },
          "inputArtifacts": [{"name": "SourceOutput"}],
          "outputArtifacts": [{"name": "PlanArtifacts"}],
          "configuration": {
            "ProjectName": "terraform-pipeline",
            "PrimarySource": "SourceOutput"
          },
          "runOrder": 1
        }]
      },
      {
        "name": "Approval",
        "actions": [{
          "name": "ApproveDeployment",
          "actionTypeId": {
            "category": "Approval",
            "owner": "AWS",
            "provider": "Manual",
            "version": "1"
          }
        }]
      },
      {
        "name": "Apply",
        "actions": [{
          "name": "TerraformApply",
          "actionTypeId": {
            "category": "Build",
            "owner": "AWS",
            "provider": "CodeBuild",
            "version": "1"
          },
          "inputArtifacts": [{"name": "PlanArtifacts"}],
          "configuration": {
            "ProjectName": "terraform-pipeline",
            "PrimarySource": "PlanArtifacts"
          },
          "runOrder": 1
        }]
      }
    ]
  }
}
```

**⚠️ NOTA**: Per il buildspec override nella CLI, usa il campo `BuildspecOverride` nell'action configuration.

## Flusso operativo completo

1. **Commit su `main`** → trigger automatico della pipeline
2. **Stage Source**: scarica il codice dal repository
3. **Stage Plan**:
   - Esegue `buildspec-plan.yml`
   - Rileva modifiche in Dev o Prod
   - Esegue `terraform init`, `validate`, `plan`
   - Genera `tfplan` e lo salva come artifact
4. **Stage Manual Approval**: 
   - Pipeline si ferma in attesa di approvazione
   - Ricevi notifica (se configurato SNS)
   - Approvi o rifiuti dalla console CodePipeline
5. **Stage Apply**:
   - Esegue `buildspec-apply.yml`
   - Trova il `tfplan` negli artifacts
   - Esegue `terraform apply` sull'ambiente corretto

## Troubleshooting

### Il buildspec non viene trovato
- Verifica che `buildspec-plan.yml` e `buildspec-apply.yml` siano nella **root del repository**
- Controlla che il path nel "Buildspec override" sia corretto (senza `/` iniziale)

### Il tfplan non viene trovato nello stage Apply
- Verifica che il buildspec-plan.yml includa `**/*` negli artifacts
- Controlla che lo stage Apply usi `PlanArtifacts` come input artifact
- Verifica i log di CodeBuild per vedere dove cerca il file

### Modifiche a entrambi gli ambienti
- La pipeline fallisce intenzionalmente se rileva modifiche a Dev e Prod insieme
- Modifica solo uno dei due ambienti per commit

## File richiesti nel repository

```
.
├── buildspec-plan.yml      # Buildspec per lo stage Plan
├── buildspec-apply.yml     # Buildspec per lo stage Apply
├── Infrastructure/
│   └── Environments/
│       ├── Dev/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   ├── provider.tf
│       │   └── outputs.tf
│       └── Prod/
│           ├── main.tf
│           ├── variables.tf
│           ├── provider.tf
│           └── outputs.tf
└── README-pipeline.md
```

## Variabili d'ambiente (opzionali)

Puoi aggiungere variabili d'ambiente nel progetto CodeBuild:
- `TF_VERSION`: versione di Terraform (default: 1.9.5)
- `DEV_DIR`: path cartella Dev (default: `Infrastructure/Environments/Dev`)
- `PROD_DIR`: path cartella Prod (default: `Infrastructure/Environments/Prod`)

Queste variabili sono già definite nei buildspec, ma puoi overridearle nel progetto CodeBuild se necessario.
