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

### 4.2 Monitoring & Logging

Il monitoring è implementato nel chart `app-backend` tramite un sidecar container e un ServiceMonitor CRD.

**Sidecar `prometheus-metrics`**

`prom/node-exporter` gira come side container nel pod affianco al backend ed espone metriche di processo e di sistema su `:9100/metrics`. Tre collector sono disabilitati esplicitamente (`filesystem`, `netstat`, `sockstat`) perché operando nel namespace isolato del pod, produrrebbero dati parziali.

Se l'app Node.js espone metriche applicative via `prom-client` è possibile aggiungere un secondo endpoint al ServiceMonitor puntando alla porta dell'app.

**ServiceMonitor**

CRD del Prometheus Operator che dice a Prometheus di scrapare `:9100/metrics` ogni 30s. Richiede `kube-prometheus-stack` installato nel cluster. Disabilitato in `values-staging.yaml` per ambienti locali senza Operator.

### 4.3 Disaster Recovery

Lo script di backup è in [backup/backup-mysql.sh](backup/backup-mysql.sh). Esegue `mysqldump`, comprime il dump con gzip e lo carica su S3 con SSE-KMS. Le variabili di connessione e le credenziali vengono iniettate tramite env, in Kubernetes tramite Secret.

In produzione lo script viene schedulato da un **CronJob Kubernetes** (es. `0 2 * * *`).

La procedura completa di restore da un backup S3 è documentata in [backup/disaster-recovery.md](backup/disaster-recovery.md).

---

## Parte 5 — Serverless Architecture (Lambda & EventBridge)

L'architettura event-driven è implementata via **OpenTofu** nella folder `infrastructure/`. Il diagramma è in [lambda_architecture.svg](lambda_architecture.svg).

**Componenti IaC creati:**
- Modulo Lambda riusabile (`modules/lambda/`) con supporto a VPC, X-Ray, ephemeral storage, concurrency riservata
- Custom EventBridge bus `order-events` con archive (30gg) e schema registry OpenAPI per l'evento `OrderCreated`
- SQS DLQ per i fallimenti dell'email-notifier (retention 14gg), con policy che autorizza EventBridge a scriverci sopra
- IAM policies granulari per ogni funzione: EventBridge publish, DynamoDB write, S3/KMS write, SES send, SQS trigger

**Orchestrazione (`main.tf`):** il root module istanzia i quattro moduli Lambda con i parametri specifici, la concurrency provisionata sull'`order-processor` (alias `live`, 5 istanze), il modulo SQS e infine il modulo EventBridge che riceve gli ARN delle Lambda e della DLQ. L'`event_source_mapping` tra DLQ e `dlq-processor` è dichiarata nel root per evitare la dipendenza circolare tra i due moduli (lambda e sqs).

> **Nota:** il codice delle Lambda non è stato implementato.

**Cosa andrebbe in ciascun handler:**

| Lambda | Logica core |
|---|---|
| `order-processor` | Validazione payload, `PutItem` su DynamoDB, `PutEvents` su EventBridge con `source: myapp.orders` / `detail-type: OrderCreated` |
| `email-notifier` | Parsing dell'evento da EventBridge, composizione template email, `SendEmail` via SES con retry gestito dal runtime |
| `data-sync` | Query su RDS, compressione gzip del risultato, `PutObject` su S3 con SSE-KMS, `Publish` su SNS a completamento |
| `dlq-processor` | Lettura batch dalla SQS DLQ, log strutturato su CloudWatch con `orderId` e causa del fallimento |
