#!/bin/bash

# Usage: ./new-app-framework.sh <app-name> <cluster-name> <type: operator|instance> [wave]
APP_NAME=$1
TARGET_CLUSTER_NAME=$2
TYPE=$3
WAVE=${4:-0}

if [[ -z "$APP_NAME" || -z "$TARGET_CLUSTER_NAME" || -z "$TYPE" ]]; then
    echo "Usage: ./new-app-framework.sh <app-name> <cluster-name> <operator|instance> [wave]"
    exit 1
fi

# Set Smart Destination Namespace
if [ "$TYPE" == "operator" ]; then
    DEST_NS="open-cluster-management-policies"
else
    # Logic for instances: attempt to strip '-instance' to guess the namespace, 
    # or default to a safe value.
    DEST_NS="openshift-gitops" 
fi

TARGET_DIR="clusters/$TARGET_CLUSTER_NAME/$APP_NAME"
COMPONENT_DIR="components/$APP_NAME"
APP_YAML_PATH="clusters/$TARGET_CLUSTER_NAME/$APP_NAME-app.yaml"
REPO_URL=$(git config --get remote.origin.url || echo "https://github.com/mmwillingham/gitops-standards-repo")

# ... [Scaffolding logic from previous version remains the same] ...

# 3. Create the ArgoCD Application Tile (With Smart Destination)
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

# ... [Registration and Summary logic] ...