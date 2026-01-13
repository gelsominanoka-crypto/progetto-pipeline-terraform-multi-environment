# Pipeline CI/CD AWS per Terraform (Dev/Prod)

Guida passo-passo per una pipeline CodePipeline + CodeBuild che usa un unico `buildspec.yml` e decide se lavorare su Dev o Prod in base ai file modificati.

## Architettura
- **CodePipeline**: trigger su `main`, orchestrazione degli stage.
- **CodeBuild**: unico progetto, riutilizzato per Plan e Apply (override env var `PIPELINE_ACTION`).
- **IAM**: ruoli per CodePipeline e CodeBuild.
- **S3**: bucket artifact CodePipeline.
- **SNS (opzionale)**: per notifiche di approvazione manuale.

## Ruoli IAM (minimo)
- **CodePipeline role**: trust `codepipeline.amazonaws.com`; permessi `codebuild:StartBuild`, `codebuild:BatchGetBuilds`, `iam:PassRole` verso ruolo CodeBuild, S3 RW artifact, CloudWatch Logs put.
- **CodeBuild role**: trust `codebuild.amazonaws.com`; permessi per le risorse Terraform che crei (ec2, vpc, ecc.), S3 RW, CloudWatch Logs put, KMS decrypt se usi SSE-KMS; opzionale `ssm:GetParameter` / `secretsmanager:GetSecretValue` per variabili sensibili.

## CodeBuild
- Un solo progetto.
- Variabili d’ambiente consigliate: `DEV_DIR=Infrastructure/Environments/Dev`, `PROD_DIR=Infrastructure/Environments/Prod`, `TF_VERSION` (se vuoi pin di Terraform), `PIPELINE_ACTION` (override da CodePipeline: `plan` o `apply`).
- Immagine: Ubuntu standard; se Terraform non è presente, il buildspec lo installa.

## CodePipeline (stadi)
1) **Source**: GitHub branch `main` → artifact `SourceOutput`.
2) **Plan (CodeBuild)**: override env `PIPELINE_ACTION=plan`; esegue `init`, `validate`, `plan` solo su Dev **oppure** Prod a seconda del diff.
3) **Manual Approval**: blocca prima di applicare; opzionale SNS.
4) **Apply (CodeBuild)**: stesso progetto CodeBuild, override env `PIPELINE_ACTION=apply`; esegue `apply` solo sull’ambiente individuato nello stage plan.

## Come rileva l’ambiente
- In `pre_build`: `git fetch --depth=2 origin main` e `git diff --name-only HEAD~1 HEAD`.
- Se trova path con prefisso `Infrastructure/Environments/Dev/` → TARGET=Dev.
- Se trova path con prefisso `Infrastructure/Environments/Prod/` → TARGET=Prod.
- Se trova entrambi → errore (non esegue entrambi). Se nessuno → errore (niente da fare).

## Manual Approval
- Aggiungi stage “ManualApproval” tra Plan e Apply in CodePipeline.
- Opzionale: SNS topic per notifiche.

## File richiesti nel repo
- `buildspec.yml` (unico, vedi sotto) nella root del repo.
- Codice Terraform già presente in `Infrastructure/Environments/Dev` e `.../Prod`.

## Uso di variabili
- CodePipeline può fare override su `PIPELINE_ACTION` per distinguere Plan/Apply.
- Usa Param Store/Secrets Manager per valori sensibili; il ruolo CodeBuild deve avere permessi `Get*`.

## Comandi chiave (diff)
- `git diff --name-only HEAD~1 HEAD | grep "^Infrastructure/Environments/Dev/"`
- `git diff --name-only HEAD~1 HEAD | grep "^Infrastructure/Environments/Prod/"`

## Flusso operativo
1) Commit su `main`.
2) Stage Source → artifact.
3) Stage Plan (CodeBuild, `PIPELINE_ACTION=plan`) → `init`, `validate`, `plan` sull’ambiente individuato.
4) Manual Approval.
5) Stage Apply (CodeBuild, `PIPELINE_ACTION=apply`) → `apply` sullo stesso ambiente.
