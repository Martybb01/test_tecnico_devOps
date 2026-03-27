# Disaster Recovery — MySQL

## Restore da backup S3

Situazione: dati corrotti o persi, cluster ancora operativo.

Blocco le scritture scalando le repliche a zero:
```bash
kubectl scale deployment app-backend --replicas=0 -n app-prod
```

Trovo il backup giusto su S3:
```bash
aws s3 ls s3://app-backups-prod/mysql/ --recursive | sort | tail -10
```

Scarico e ripristino sul pod MySQL:
```bash
aws s3 cp s3://app-backups-prod/mysql/<TIMESTAMP>/app.sql.gz - | \
  gunzip | kubectl exec -i mysql-0 -n app-prod -- \
  mysql -u root -p"${MYSQL_ROOT_PASSWORD}" app
```

Ripristino il backend:
```bash
kubectl scale deployment app-backend --replicas=2 -n app-prod
```
