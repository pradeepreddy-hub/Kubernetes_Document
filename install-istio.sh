#!/usr/bin/env bash
# ============================================================
# Istio Installation via Helm Charts
# Kubernetes: 1.30+ | Istio: 1.22.1
# ============================================================

set -euo pipefail

ISTIO_NAMESPACE="istio-system"
ISTIO_VERSION="1.22.1"

echo "======================================================"
echo " Installing Istio ${ISTIO_VERSION} via Helm"
echo "======================================================"

# -------------------------------------------------------
# STEP 0 — Pre-flight checks
# -------------------------------------------------------
echo ""
echo "[0/6] Checking prerequisites..."

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not installed"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "helm not installed"; exit 1; }

kubectl cluster-info >/dev/null

echo "✔ kubectl connected to cluster"
echo "✔ helm installed"

# -------------------------------------------------------
# STEP 1 — Add Istio Helm repo
# -------------------------------------------------------
echo ""
echo "[1/6] Adding Istio Helm repository..."

helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

echo ""
echo "Available Istio charts:"
helm search repo istio/ --versions | head -10

# -------------------------------------------------------
# STEP 2 — Create istio-system namespace
# -------------------------------------------------------
echo ""
echo "[2/6] Creating namespace ${ISTIO_NAMESPACE}..."

kubectl create namespace ${ISTIO_NAMESPACE} \
  --dry-run=client -o yaml | kubectl apply -f -

# -------------------------------------------------------
# STEP 3 — Install istio-base (CRDs)
# -------------------------------------------------------
echo ""
echo "[3/6] Installing istio-base (CRDs)..."

helm upgrade --install istio-base istio/base \
  -n ${ISTIO_NAMESPACE} \
  --version ${ISTIO_VERSION} \
  --wait

echo ""
echo "Installed Istio CRDs:"
kubectl get crd | grep istio.io || true

# -------------------------------------------------------
# STEP 4 — Install istiod (Control Plane)
# -------------------------------------------------------
echo ""
echo "[4/6] Installing istiod control plane..."

helm upgrade --install istiod istio/istiod \
  -n ${ISTIO_NAMESPACE} \
  --version ${ISTIO_VERSION} \
  --set pilot.resources.requests.cpu=100m \
  --set pilot.resources.requests.memory=256Mi \
  --set global.proxy.resources.requests.cpu=50m \
  --set global.proxy.resources.requests.memory=64Mi \
  --set meshConfig.accessLogFile=/dev/stdout \
  --wait

echo ""
echo "Waiting for istiod rollout..."
kubectl rollout status deployment/istiod -n ${ISTIO_NAMESPACE}

# -------------------------------------------------------
# STEP 5 — Install Ingress Gateway
# -------------------------------------------------------
echo ""
echo "[5/6] Installing Istio Ingress Gateway..."

helm upgrade --install istio-ingressgateway istio/gateway \
  -n ${ISTIO_NAMESPACE} \
  --version ${ISTIO_VERSION} \
  --set service.type=LoadBalancer \
  --set resources.requests.cpu=100m \
  --set resources.requests.memory=128Mi \
  --wait

# -------------------------------------------------------
# STEP 6 — Verification
# -------------------------------------------------------
echo ""
echo "[6/6] Verifying installation..."

echo ""
echo "------ Helm Releases ------"
helm list -n ${ISTIO_NAMESPACE}

echo ""
echo "------ Istio Pods ------"
kubectl get pods -n ${ISTIO_NAMESPACE}

echo ""
echo "------ Gateway Service ------"
kubectl get svc -n ${ISTIO_NAMESPACE} | grep ingress || true

echo ""
echo "======================================================"
echo " Istio installed successfully!"
echo ""
echo "Next steps:"
echo ""
echo "Enable sidecar injection in your app namespace:"
echo ""
echo "kubectl label namespace default istio-injection=enabled"
echo ""
echo "Example:"
echo "kubectl create namespace jenkins"
echo "kubectl label namespace jenkins istio-injection=enabled"
echo ""
echo "Then deploy your apps."
echo "======================================================"
