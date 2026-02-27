# 🚀 Cluster GitOps Management Guide

This repository uses OpenShift GitOps (ArgoCD) and Kustomize to manage cluster configurations, operators, and policies.

## 📋 Prerequisites
* The managed cluster MUST be imported into Advanced Cluster Management (ACM).
* The 'policy-framework' add-on must be healthy on the managed cluster to support OperatorPolicies.

## 🏗 Repository Structure
* .bootstrap/: Manual manifest to link a new cluster.
* components/: Generic blueprints (Do not edit directly).
* clusters/: Cluster-specific configurations and application lists.

---

## 🛠 Adding a New Application
1. Run: ./new-app-framework.sh <app-name>
2. Configure patches in clusters/<cluster-name>/<app-name>/patches/
3. Add the app to clusters/<cluster-name>/kustomization.yaml
4. Git Push.

---

## 🔍 Troubleshooting

| Issue | Solution |
| :--- | :--- |
| CRD "OperatorPolicy" not found | Cluster is not in ACM or Policy Add-on is not installed. |
| Sync Timeout / Namespace Error | Remove global 'namespace:' from the app's kustomization.yaml. |
| Patch not applying | Ensure 'namespace' and 'kind' in the patch match the component exactly. |