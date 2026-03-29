# Debugging Scenario

## 1. Pod in CrashLoopBackOff

**Quali comandi usi per investigare?**

Controllo stato ed eventi del pod:
```bash
kubectl describe pod <pod-name> -n <namespace>
```

Controllo i log:
```bash
# Container corrente
kubectl logs <pod-name> -n <namespace>

# Crash precedente (se il container è già stato riavviato)
kubectl logs <pod-name> -n <namespace> --previous

# Init container specifico
kubectl logs <pod-name> -n <namespace> -c <container-name>
```

**Quali sono le possibili cause per un'API backend in CrashLoopBackOff?**

- Secrets sbagliati o mancanti
- Liveness probe troppo aggressiva (timeout troppo basso che non dà tempo al backend di avviarsi) o con porta sbagliata
- Init container fallito — il main container non parte mai finché tutti gli init container non completano con successo
- Resource limit troppo basso — il kernel uccide il processo (OOMKilled)

---

## 2. Ingress non riceve traffico

**Come verifichi la configurazione?**

```bash
kubectl describe ingress <ingress-name> -n <namespace>
```

Verifica degli endpoint:
```bash
kubectl get endpointslice -n <namespace>
kubectl describe endpointslice <endpointslice-name> -n <namespace>
```

**Come testi il routing?**

In produzione con ALB e address assegnato:
```bash
curl -k -H "Host: api.example.com" https://<ALB-ADDRESS>/api/health
```

---

## 3. MySQL non si connette

**Come verifichi la connettività dal backend pod?**

```bash
kubectl exec -it <backend-pod> -n <namespace> -- nc -zv mysql-headless 3306
```

Se `nc` non è disponibile nell'immagine (container minimale), si lancia un pod temporaneo con la label corretta per rispettare la NetworkPolicy.

**Quali network policies potrebbero bloccare?**

Nel setup attuale la NetworkPolicy su MySQL permette esplicitamente traffico in ingresso dalla label `app.kubernetes.io/name: app-backend` sulla porta 3306 — il flusso backend → MySQL non viene bloccato.

Potrebbero bloccare:
- Una policy **default-deny** senza eccezioni esplicite per questo flusso
- Una policy **Egress** restrittiva sul pod backend verso la porta 3306 --> una regola engress sul backend sarebbe sufficiente a bloccare la connessione anche se quella su MySQL la permette in ingresso
