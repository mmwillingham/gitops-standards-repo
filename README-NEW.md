# 🚀 Cluster GitOps Management Guide

This repository uses OpenShift GitOps (ArgoCD) and Kustomize to manage cluster configurations, operators, and policies.

## 🏗 Repository Structure

* .bootstrap/: Contains the manual "starter motor" manifest used to link a new cluster to this repository.
* components/: The Blueprints. These are generic, golden-image versions of operators and policies. Do not edit files here directly.
* clusters/: The Workspace. Each folder represents a specific cluster's configuration.
    * kustomization.yaml: The Shopping List. This file controls which applications are active on the cluster.
    * appprojects.yaml: Defines security boundaries (cluster-config, virt, hub).

---

## 🛠 Adding a New Application

We use a helper script to ensure the folder structure and paths are always correct.

### Step 1: Run the Framework Script
From the root of the repository, run:
./new-app-framework.sh <app-name>

Example: ./new-app-framework.sh compliance-operator

### Step 2: Choose Your Path
The script creates two things in your clusters/<cluster-name>/ folder:
1. A Folder (<app-name>/): Use this if you need to patch (change) values like a channel, version, or severity.
2. A Tile Manifest (<app-name>-app.yaml): This is the ArgoCD configuration.

### Step 3: Configure Your App
* To Patch: Open clusters/<cluster-name>/<app-name>/patches/custom-patch.yaml and add your cluster-specific overrides.
* To Change Project: Open clusters/<cluster-name>/<app-name>-app.yaml and change the project: field (e.g., from cluster-config to virt).

### Step 4: Update the Shopping List
Open clusters/<cluster-name>/kustomization.yaml and add your new app file to the resources list:
resources:
  - appprojects.yaml
  - external-secrets-app.yaml
  - compliance-operator-app.yaml  # <--- Add your new app here

### Step 5: Push to Git
Once you git commit and push, ArgoCD will automatically detect the new file and spawn a new tile on your dashboard.

---

## 🔗 The App-of-Apps Hierarchy

This repository uses a parent-child relationship to make management easy:

1. The Root Tile (cluster-root): This is managed by the file in .bootstrap/. It watches your clusters/<cluster-name>/ folder.
2. The Child Tiles: Any Application manifest found in your cluster folder becomes its own independent tile in the ArgoCD console.

---

## 🔐 Projects and Permissions
* cluster-config: Core infrastructure and cluster-wide operators.
* virt: Resources specifically for Virtualization admins.
* hub: Management tools and central grouping.

---

## 🔍 Troubleshooting

| Issue | Solution |
| :--- | :--- |
| New tile not appearing | Ensure the -app.yaml file is listed in the cluster's kustomization.yaml. |
| Project not found | Ensure appprojects.yaml is listed first in the kustomization.yaml. |
| Patch not applying (No matches for Id) | Ensure the 'namespace' and 'kind' in your patch match the base component EXACTLY. |
| Sync Timeout / Namespace Error | DO NOT use a global 'namespace:' in the app's kustomization.yaml. Let the individual manifests define their own namespace. |
| Component path error | Check the ../../../ path in the app folder's kustomization.yaml. |

---

## 🚀 Bootstrap a New Cluster
To connect a brand new cluster to this repo:
1. export CLUSTER_NAME="your-cluster-id"
2. envsubst < .bootstrap/root-application.yaml | oc apply -f -