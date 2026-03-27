# Test Tecnico DevOps — Multi-Tier App su AWS EKS

Deploy di un'applicazione multi-tier in produzione su Kubernetes (EKS) con IaC, Helm charts, script di deployment automatizzato e pipeline CI/CD.

**Stack applicativo:** Backend Node.js API · MySQL (StatefulSet) · Redis (StatefulSet) · Frontend Nginx (DaemonSet)

---

## Parte 1 — Infrastruttura as Code (Terraform/OpenTofu)

L'infrastruttura AWS è gestita tramite **OpenTofu (Terraform)** con struttura modulare. Il remote state è salvato su **S3** con locking nativo.

**Componenti creati:**
- VPC `10.0.0.0/16` con subnet pubbliche e private su 2 AZ
- Internet Gateway + NAT Gateway per egress dei nodi
- EKS cluster v1.34 con node group autoscalante (min 2, max 4 × `t3a.large`)
- Add-ons EKS: `kube-proxy`, `coredns`, `vpc-cni`, `aws-ebs-csi-driver`
- IAM roles e security groups per control plane e worker nodes
- Namespace Kubernetes `app-{environment}` creato via provider Kubernetes

### Prerequisiti

- Terraform / OpenTofu ≥ 1.6
- AWS CLI configurato con credenziali valide
- Bucket S3 `app-tfstate-prod` esistente nella region target (per il remote state)

### Deploy

```bash
cd terraform

tofu init
tofu init --backend=false # testing senza S3 backend

tofu validate # valida l'infra

tofu plan -var-file=terraform.tfvars

tofu apply -var-file=terraform.tfvars
```

Al termine, aggiorna il kubeconfig locale:

```bash
aws eks update-kubeconfig --region eu-south-1 --name app-prod
```

Per abilitare l'RDS Proxy (opzionale, richiede un'istanza RDS esistente), impostare in `terraform.tfvars`:

```hcl
enable_rds_proxy = true
rds_secret_arn   = "<arn-del-secret-in-secrets-manager>"
```

---

## Parte 2 — Helm Charts

Ogni chart segue la stessa struttura con `values.yaml`, `values-prod.yaml`, `values-staging.yaml` e i template Kubernetes corrispondenti. I file sono annotati inline per i dettagli implementativi.

| Chart | Tipo |
|---|---|
| `app-backend` | Deployment |
| `mysql` | StatefulSet |
| `redis` | StatefulSet |
| `frontend` | DaemonSet |

**NetworkPolicy:** il traffico è isolato per design — solo il backend raggiunge MySQL e Redis, solo il frontend raggiunge il backend.

Il deployment dell'intero stack avviene tramite `deploy.sh` (vedi Parte 3) configurato per staging ossia per l'ambiente di test.

---

## Parte 3 — Deployment & Troubleshooting

### Script di Deploy (`deploy.sh`)

Lo script automatizza l'intero ciclo di deployment e test:

1. `helm lint` su tutti i chart
2. Creazione del namespace target
3. Deploy ordinato: MySQL → Redis → Backend → Frontend (via `helm upgrade --install`)
4. Attesa rollout completo per ogni componente
5. Smoke tests automatici
6. Output dello stato finale

```bash
chmod +x deploy.sh
./deploy.sh
```

**Smoke tests inclusi:**
- Tutti i pod in stato `Running`
- Ingress con IP/DNS assegnato
- Backend `/health` risponde HTTP 200 (via port-forward)
- MySQL risponde a `SELECT 1`
- Redis risponde a `PING`

### Debugging Scenarios

Le risposte ai tre scenari di troubleshooting richiesti (CrashLoopBackOff, Ingress senza traffico, MySQL irraggiungibile) sono documentate in [debugging_scenario.md](debugging_scenario.md).

---

## Parte 4 — CI/CD

### Pipeline Bitbucket (`bitbucket.pipelines.yaml`)

La pipeline è strutturata in tre step eseguiti in sequenza su push al branch `main`:

1. **Build & Push** — Builda l'immagine Docker del backend e la pusha su DockerHub con tag `{branch}-{commit}`
2. **Helm Deploy** — `helm upgrade --install` sul cluster con `values-prod.yaml` e il tag immagine passato dallo step precedente
3. **Smoke Tests post-deploy** — Verifica che le repliche siano `READY == DESIRED`

**Scelte adottate:**
- Il tag immagine viene passato tra step tramite artifact (`deploy.env`), evitando dipendenza da variabili d'ambiente esterne fragili
- La flag `--atomic` garantisce rollback automatico in caso di fallimento
- Il kubeconfig è iniettato come variabile base64-encoded (`KUBECONFIG_B64`), senza file su disco

**Variabili repository richieste (Bitbucket > Repository Settings > Pipelines > Repository variables):**

| Variabile | Descrizione |
|---|---|
| `DOCKERHUB_USERNAME` | Username DockerHub |
| `DOCKERHUB_PASSWORD` | Token DockerHub (secret) |
| `KUBE_NAMESPACE` | Namespace target (es. `app-prod`) |
| `KUBECONFIG_B64` | Kubeconfig codificato in base64 (secret) |
