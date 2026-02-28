#!/bin/bash

# Usage: ./new-app-framework.sh <app-name> <cluster-name> <type: operator|instance> [wave]
APP_NAME=$1
TARGET_CLUSTER_NAME=$2
TYPE=$3
WAVE=${4:-0}

# 0. Validation
if [[ -z "$APP_NAME" || -z "$TARGET_CLUSTER_NAME" || -z "$TYPE" ]]; then
    echo "Usage: ./new-app-framework.sh <app-name> <cluster-name> <operator|instance> [wave]"
    exit 1
fi

# Set Smart Namespacing
if [ "$TYPE" == "operator" ]; then
    DEST_NS="open-cluster-management-policies"
    APP_NS="open-cluster-management-policies"
else
    # Simple logic to derive namespace from app name
    APP_NS="${APP_NAME%-instance}" 
    DEST_NS="$APP_NS"
fi

TARGET_DIR="clusters/$TARGET_CLUSTER_NAME/$APP_NAME"
COMPONENT_DIR="components/$APP_NAME"
APP_YAML_PATH="clusters/$TARGET_CLUSTER_NAME/$APP_NAME-app.yaml"
REPO_URL=$(git config --get remote.origin.url || echo "https://github.com/mmwillingham/gitops-standards-repo")

echo "--- Scaffolding $APP_NAME ($TYPE) for Cluster: $TARGET_CLUSTER_NAME ---"

# 1. Ensure the Component (Base) exists with Protected/Monitored Namespace
if [ ! -d "$COMPONENT_DIR" ]; then
    mkdir -p "$COMPONENT_DIR"
    
    MAIN_FILE=$([ "$TYPE" == "operator" ] && echo "operator-policy.yaml" || echo "instance.yaml")

    # Scaffolding the Namespace with Standards
    cat <<EOF > "$COMPONENT_DIR/namespace.yaml"
apiVersion: v1
kind: Namespace
metadata:
  name: $APP_NS
  annotations:
    argocd.argoproj.io/sync-options: Delete=false
  labels:
    openshift.io/cluster-monitoring: "true"
    argocd.argoproj.io/managed-by: openshift-gitops
EOF

    cat <<EOF > "$COMPONENT_DIR/kustomization.yaml"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - $MAIN_FILE
EOF
    touch "$COMPONENT_DIR/$MAIN_FILE"
fi

# 2. Create the Cluster Overlay
mkdir -p "$TARGET_DIR/patches"
cat <<EOF > "$TARGET_DIR/kustomization.yaml"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../../$COMPONENT_DIR
patches:
  - path: patches/custom-patch.yaml
EOF

# Starter Patches
if [ "$TYPE" == "operator" ]; then
    cat <<EOF > "$TARGET_DIR/patches/custom-patch.yaml"
apiVersion: policy.open-cluster-management.io/v1beta1
kind: OperatorPolicy
metadata:
  name: $APP_NAME
  namespace: open-cluster-management-policies
spec:
  remediationAction: enforce
  severity: high
  complianceType: musthave
  upgradeApproval: Manual
  subscription:
    channel: stable
    name: REPLACE_ME
    source: redhat-operators
    sourceNamespace: openshift-marketplace
    startingCSV: REPLACE_ME
EOF
else
    cat <<EOF > "$TARGET_DIR/patches/custom-patch.yaml"
apiVersion: v1
kind: ConfigMap
metadata:
  name: $APP_NAME
  namespace: $APP_NS
data:
  example: "true"
EOF
fi

# 3. Create the ArgoCD Application Tile
cat <<EOF > "$APP_YAML_PATH"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APP_NAME
  namespace: openshift-gitops
  annotations:
    argocd.argoproj.io/sync-wave: "$WAVE"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: $REPO_URL
    targetRevision: HEAD
    path: $TARGET_DIR
  destination:
    server: https://kubernetes.default.svc
    namespace: $DEST_NS
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF

# 4. Registration
CLUSTER_KUSTOMIZATION="clusters/$TARGET_CLUSTER_NAME/kustomization.yaml"
if [ -f "$CLUSTER_KUSTOMIZATION" ]; then
    if ! grep -q "$APP_NAME-app.yaml" "$CLUSTER_KUSTOMIZATION"; then
        sed -i '$a\' "$CLUSTER_KUSTOMIZATION"
        echo "  - $APP_NAME-app.yaml" >> "$CLUSTER_KUSTOMIZATION"
    fi
fi

echo "-------------------------------------------------------"
echo "✅ Scaffolding Complete!"
echo "-------------------------------------------------------"