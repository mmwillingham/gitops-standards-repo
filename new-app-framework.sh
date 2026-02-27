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

if [[ "$TYPE" != "operator" && "$TYPE" != "instance" ]]; then
    echo "Error: Type must be 'operator' or 'instance'."
    exit 1
fi

if [ ! -d "clusters/$TARGET_CLUSTER_NAME" ]; then
    echo "Error: Directory 'clusters/$TARGET_CLUSTER_NAME' not found."
    exit 1
fi

TARGET_DIR="clusters/$TARGET_CLUSTER_NAME/$APP_NAME"
COMPONENT_DIR="components/$APP_NAME"
APP_YAML_FILE="$APP_NAME-app.yaml"
APP_YAML_PATH="clusters/$TARGET_CLUSTER_NAME/$APP_YAML_FILE"
REPO_URL=$(git config --get remote.origin.url || echo "https://github.com/mmwillingham/gitops-standards-repo")

echo "--- Scaffolding $APP_NAME ($TYPE) for Cluster: $TARGET_CLUSTER_NAME (Wave: $WAVE) ---"

# 1. Ensure the Component (Base) exists
if [ ! -d "$COMPONENT_DIR" ]; then
    mkdir -p "$COMPONENT_DIR"
    
    if [ "$TYPE" == "operator" ]; then
        MAIN_FILE="operator-policy.yaml"
    else
        MAIN_FILE="instance.yaml"
    fi

    cat <<EOF > "$COMPONENT_DIR/kustomization.yaml"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - $MAIN_FILE
EOF
    touch "$COMPONENT_DIR/namespace.yaml"
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
  upgradeApproval: Automatic
  subscription:
    installPlanApproval: Automatic # Force Automatic to avoid manual IP blocks
    channel: stable
    startingCSV: REPLACE_ME
EOF
else
    cat <<EOF > "$TARGET_DIR/patches/custom-patch.yaml"
apiVersion: v1
kind: ConfigMap
metadata:
  name: $APP_NAME
  namespace: default
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
  project: cluster-config
  source:
    repoURL: $REPO_URL
    targetRevision: HEAD
    path: $TARGET_DIR
  destination:
    server: https://kubernetes.default.svc
    namespace: openshift-gitops
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

# 4. Register in main kustomization
CLUSTER_KUSTOMIZATION="clusters/$TARGET_CLUSTER_NAME/kustomization.yaml"
if [ -f "$CLUSTER_KUSTOMIZATION" ]; then
    if ! grep -q "$APP_YAML_FILE" "$CLUSTER_KUSTOMIZATION"; then
        echo "Registering $APP_YAML_FILE in $CLUSTER_KUSTOMIZATION..."
        sed -i '$a\' "$CLUSTER_KUSTOMIZATION"
        echo "  - $APP_YAML_FILE" >> "$CLUSTER_KUSTOMIZATION"
    fi
fi

# Determine file name for summary
if [ "$TYPE" == "operator" ]; then BASE_FILE="operator-policy.yaml"; else BASE_FILE="instance.yaml"; fi

echo "-------------------------------------------------------"
echo "✅ Scaffolding & Registration Complete!"
echo "-------------------------------------------------------"
echo "THE FOLLOWING FILES WERE CREATED/UPDATED:"
echo "  [Folder] $COMPONENT_DIR"
echo "  [File]   $COMPONENT_DIR/kustomization.yaml"
echo "  [File]   $COMPONENT_DIR/namespace.yaml"
echo "  [File]   $COMPONENT_DIR/$BASE_FILE"
echo ""
echo "  [Folder] $TARGET_DIR"
echo "  [File]   $TARGET_DIR/kustomization.yaml"
echo "  [File]   $TARGET_DIR/patches/custom-patch.yaml"
echo ""
echo "  [File]   $APP_YAML_PATH (Wave: $WAVE)"
echo "  [Update] $CLUSTER_KUSTOMIZATION"
echo "-------------------------------------------------------"