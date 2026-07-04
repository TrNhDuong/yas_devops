#!/usr/bin/env bash
# setup-yas-local-dns.sh
# Configure CoreDNS so Pods in the cluster can resolve YAS local domains.

set -euo pipefail

echo "=== YAS CoreDNS Setup ==="
echo ""

echo "[1/5] Getting ClusterIP of ingress-nginx-controller..."
INGRESS_SVC_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)

if [ -z "${INGRESS_SVC_IP}" ]; then
  echo "ERROR: ingress-nginx-controller service was not found in namespace ingress-nginx."
  echo "Make sure ingress-nginx is installed/enabled first. For Minikube:"
  echo "  minikube addons enable ingress"
  exit 1
fi

echo "Ingress ClusterIP: ${INGRESS_SVC_IP}"
echo ""

echo "[2/5] Backing up CoreDNS ConfigMap..."
BACKUP_FILE="$HOME/coredns-backup-$(date +%Y%m%d-%H%M%S).yaml"
kubectl get configmap coredns -n kube-system -o yaml > "${BACKUP_FILE}"
echo "Backup saved to: ${BACKUP_FILE}"
echo ""

echo "[3/5] Reading current CoreDNS Corefile..."
CURRENT_COREFILE=$(kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}')

echo "[4/5] Patching CoreDNS hosts block..."
PATCHED_COREFILE=$(COREFILE="${CURRENT_COREFILE}" INGRESS_SVC_IP="${INGRESS_SVC_IP}" python3 - <<'PY'
import os
import re
import sys

corefile = os.environ["COREFILE"]
ip = os.environ["INGRESS_SVC_IP"]

hosts_block = f"""    hosts {{
      {ip} identity.yas.local.com
      {ip} storefront.dev.yas.local.com
      {ip} api.dev.yas.local.com
      {ip} storefront.staging.yas.local.com
      {ip} api.staging.yas.local.com
      fallthrough
    }}
"""

# Remove an old CoreDNS hosts block if it contains any yas.local.com entry.
pattern = re.compile(r"(?ms)^    hosts \{\n.*?yas\.local\.com.*?^    \}\n?")
corefile = pattern.sub("", corefile)

needle = "    forward ."
if needle not in corefile:
    print("ERROR: cannot find '    forward .' in CoreDNS Corefile", file=sys.stderr)
    sys.exit(1)

corefile = corefile.replace(needle, hosts_block + "\n" + needle, 1)
print(corefile, end="")
PY
)

PATCH_JSON=$(PATCHED_COREFILE="${PATCHED_COREFILE}" python3 - <<'PY'
import json
import os
print(json.dumps({"data": {"Corefile": os.environ["PATCHED_COREFILE"]}}))
PY
)

kubectl patch configmap coredns -n kube-system --type merge -p "${PATCH_JSON}"
echo "CoreDNS ConfigMap patched."
echo ""

echo "[5/5] Restarting CoreDNS..."
kubectl rollout restart deployment coredns -n kube-system
kubectl rollout status deployment coredns -n kube-system --timeout=60s

echo ""
echo "=== Done ==="
echo ""
echo "Test DNS:"
echo "  kubectl run dns-test -n yas-dev --rm -it --restart=Never \\\n    --image=busybox:1.36 -- nslookup identity.yas.local.com"
echo ""
echo "Test Keycloak issuer:"
echo "  kubectl run curl-test -n yas-dev --rm -it --restart=Never \\\n    --image=curlimages/curl -- \\\n    curl -i http://identity.yas.local.com/realms/Yas/.well-known/openid-configuration"
