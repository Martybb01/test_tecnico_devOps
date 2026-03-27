#!/usr/bin/env bash
# deploy.sh — Deploy dello stack su ambiente di test
# Uso: ./deploy.sh
# Prerequisiti: helm, kubectl configurato sul cluster target

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }
info() { echo -e "  --> $*"; }

NAMESPACE="app-try"
RELEASE_MYSQL="mysql"
RELEASE_REDIS="redis"
RELEASE_BACKEND="app-backend"
RELEASE_FRONTEND="frontend"

# In prod ci/cd questi vengono passati da -->
#   --set secrets.DB_PASSWORD=$DB_PASSWORD --set secrets.JWT_SECRET=$JWT_SECRET
BACKEND_EXTRA_ARGS=""

echo ""
echo "=== STEP 1: helm lint ==="

for chart in charts/mysql charts/redis charts/app-backend charts/frontend; do
  info "Linting $chart..."
  helm lint "$chart" --quiet || fail "helm lint fallito su $chart"
done
ok "Tutti i charts sono validi"

echo ""
echo "=== STEP 2: Namespace ==="

if kubectl get namespace "$NAMESPACE" &>/dev/null; then
  info "Namespace '$NAMESPACE' già esistente"
else
  kubectl create namespace "$NAMESPACE"
  ok "Namespace '$NAMESPACE' creato"
fi

echo ""
echo "=== STEP 3: Deploy ==="

info "Deploying MySQL..."
helm upgrade --install "$RELEASE_MYSQL" charts/mysql \
  --namespace "$NAMESPACE" \
  --values charts/mysql/values-staging.yaml

ok "MySQL deployato"

info "Deploying Redis..."
helm upgrade --install "$RELEASE_REDIS" charts/redis \
  --namespace "$NAMESPACE" \
  --values charts/redis/values-staging.yaml

ok "Redis deployato"

info "Deploying app-backend..."
helm upgrade --install "$RELEASE_BACKEND" charts/app-backend \
  --namespace "$NAMESPACE" \
  --values charts/app-backend/values-staging.yaml \
  $BACKEND_EXTRA_ARGS

ok "app-backend deployato"

info "Deploying frontend..."
helm upgrade --install "$RELEASE_FRONTEND" charts/frontend \
  --namespace "$NAMESPACE" \
  --values charts/frontend/values-staging.yaml 

ok "frontend deployato"

echo ""
echo "=== STEP 4: Verifica rollout ==="

info "StatefulSet mysql..."
kubectl rollout status statefulset/"$RELEASE_MYSQL" -n "$NAMESPACE" --timeout=2m
ok "mysql rollout completato"

info "StatefulSet redis..."
kubectl rollout status statefulset/"$RELEASE_REDIS" -n "$NAMESPACE" --timeout=2m
ok "redis rollout completato"

info "Deployment app-backend..."
kubectl rollout status deployment/"$RELEASE_BACKEND" -n "$NAMESPACE" --timeout=2m
ok "app-backend rollout completato"

info "DaemonSet frontend..."
kubectl rollout status daemonset/"$RELEASE_FRONTEND" -n "$NAMESPACE" --timeout=2m
ok "frontend rollout completato"

echo ""
echo "=== STEP 5: Smoke tests ==="
SMOKE_PASS=0
SMOKE_FAIL=0

info "Verifica pods Running..."
NOT_RUNNING=$(kubectl get pods -n "$NAMESPACE" --field-selector='status.phase!=Running' \
  --no-headers 2>/dev/null | { grep -v "Completed" || true; } | wc -l | tr -d ' ')

if [ "$NOT_RUNNING" -eq 0 ]; then
  ok "Tutti i pod sono Running"
  SMOKE_PASS=$((SMOKE_PASS + 1))
else
  warn "$NOT_RUNNING pod non sono in stato Running"
  kubectl get pods -n "$NAMESPACE" | grep -v "Running\|Completed"
  SMOKE_FAIL=$((SMOKE_FAIL + 1))
fi

info "Verifica Ingress configurazione..."
INGRESS_ADDRESS=$(kubectl get ingress -n "$NAMESPACE" \
  -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
INGRESS_HOST=$(kubectl get ingress -n "$NAMESPACE" \
  -o jsonpath='{.items[0].spec.rules[0].host}' 2>/dev/null || true)
INGRESS_PATH=$(kubectl get ingress -n "$NAMESPACE" \
  -o jsonpath='{.items[0].spec.rules[0].http.paths[0].path}' 2>/dev/null || true)
INGRESS_BACKEND=$(kubectl get ingress -n "$NAMESPACE" \
  -o jsonpath='{.items[0].spec.rules[0].http.paths[0].backend.service.name}' 2>/dev/null || true)

if [ -n "$INGRESS_HOST" ]; then
  ok "Ingress configurato: host=$INGRESS_HOST path=$INGRESS_PATH backend=$INGRESS_BACKEND"
  if [ -n "$INGRESS_ADDRESS" ]; then
    info "ADDRESS: $INGRESS_ADDRESS"
  else
    info "ADDRESS vuoto — atteso in locale senza ALB controller, presente su EKS"
  fi
  SMOKE_PASS=$((SMOKE_PASS + 1))
else
  warn "Nessun Ingress trovato"
  SMOKE_FAIL=$((SMOKE_FAIL + 1))
fi

# Porta locale 4200 → Service port 80 → container port 3000 (prod)/80 (test)
info "Test curl /health su app-backend..."
kubectl port-forward svc/"$RELEASE_BACKEND" 4200:80 -n "$NAMESPACE" &>/dev/null &
PF_PID=$!
sleep 2

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:4200/health 2>/dev/null || echo "000")
kill $PF_PID 2>/dev/null || true

if [ "$HTTP_STATUS" = "200" ]; then
  ok "/health risponde HTTP $HTTP_STATUS"
  SMOKE_PASS=$((SMOKE_PASS + 1))
else
  warn "/health ha risposto HTTP $HTTP_STATUS (atteso 200)"
  SMOKE_FAIL=$((SMOKE_FAIL + 1))
fi

info "Test MySQL SELECT 1..."
MYSQL_POD=$(kubectl get pod -n "$NAMESPACE" \
  -l "app.kubernetes.io/name=mysql" \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [ -n "$MYSQL_POD" ]; then
  MYSQL_RESULT=$(kubectl exec "$MYSQL_POD" -n "$NAMESPACE" -- \
    mysql -u root -pchangeme-root -e "SELECT 1" --silent 2>/dev/null || echo "ERROR")

  if echo "$MYSQL_RESULT" | grep -q "1"; then
    ok "MySQL: SELECT 1 OK"
    SMOKE_PASS=$((SMOKE_PASS + 1))
  else
    warn "MySQL: SELECT 1 fallito"
    SMOKE_FAIL=$((SMOKE_FAIL + 1))
  fi
else
  warn "Nessun pod MySQL trovato, skip test"
  SMOKE_FAIL=$((SMOKE_FAIL + 1))
fi

info "Test Redis PING..."
REDIS_POD=$(kubectl get pod -n "$NAMESPACE" \
  -l "app.kubernetes.io/name=redis" \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [ -n "$REDIS_POD" ]; then
  REDIS_RESULT=$(kubectl exec "$REDIS_POD" -n "$NAMESPACE" -- \
    redis-cli PING 2>/dev/null || echo "ERROR")

  if echo "$REDIS_RESULT" | grep -q "PONG"; then
    ok "Redis: PONG ricevuto"
    SMOKE_PASS=$((SMOKE_PASS + 1))
  else
    warn "Redis PING fallito: $REDIS_RESULT"
    SMOKE_FAIL=$((SMOKE_FAIL + 1))
  fi
else
  warn "Nessun pod Redis trovato, skip test"
  SMOKE_FAIL=$((SMOKE_FAIL + 1))
fi

echo ""
echo "=== STEP 6: Status deployment ==="
kubectl get pods,services,ingress -n "$NAMESPACE"

echo ""
echo "──────────────────────────────────────"
echo "Smoke tests: ${SMOKE_PASS}/5 passati, ${SMOKE_FAIL}/5 falliti"

if [ "$SMOKE_FAIL" -eq 0 ]; then
  ok "Deploy completato con successo"
  exit 0
else
  warn "Deploy completato con $SMOKE_FAIL warning (vedi log sopra)"
  exit 1
fi
