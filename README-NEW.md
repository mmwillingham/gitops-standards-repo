# Cluster GitOps Management Guide

This repository uses OpenShift GitOps (ArgoCD) and Kustomize to manage cluster configurations, operators, and policies.

## Prerequisites
* The managed cluster must be imported into Advanced Cluster Management (ACM).
* The policy-framework add-on must be healthy on the managed cluster to support OperatorPolicies.

## Repository Structure
* .bootstrap/: Contains the manual starter manifest used to link a new cluster to this repository.
* components/: Generic versions of operators and policies. Do not edit directly.
* clusters/: Each folder represents a specific cluster configuration.
    * kustomization.yaml: Controls which applications are active.
    * appprojects.yaml: Defines security boundaries (cluster-config, virt, hub).

---

## Adding a New Application

### Option A: Using the Framework Script
1. Run: ./new-app-framework.sh <app-name>
2. Configure patches in clusters/<cluster-name>/<app-name>/patches/
3. Add the app to clusters/<cluster-name>/kustomization.yaml
4. git commit and push.

### Option B: Manual Setup
1. Create Directory: Create clusters/<cluster-name>/<app-name>/.
2. Create Kustomization: Inside that folder, create a kustomization.yaml pointing to the base:
   resources:
     - ../../../components/<app-name>
3. Define Application: In the cluster root (clusters/<cluster-name>/), create <app-name>-app.yaml.
   - Ensure path points to your new directory.
   - Ensure project is set correctly.
4. Register: Add - <app-name>-app.yaml to the resources list in clusters/<cluster-name>/kustomization.yaml.

---

## Adding a New Cluster

To onboard a brand new cluster to this framework:

1. ACM Registration: Import the cluster into ACM
2. Create Directory: mkdir -p clusters/<new-cluster-name> # Alternately, copy/paste from similar cluster
3. Initialize AppProjects: Copy appprojects.yaml from an existing cluster into the new folder.
4.- Create Root Kustomization: Create clusters/<new-cluster-name>/kustomization.yaml:
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources:
     - appprojects.yaml

5. Bootstrap GitOps:
   export CLUSTER_NAME="<new-cluster-name>"
   envsubst < .bootstrap/root-application.yaml | oc apply -f -

---

## Troubleshooting

| Issue | Solution |
| :--- | :--- |
| OperatorPolicy not found | Cluster is not in ACM or Policy Add-on is not installed. |
| Sync Timeout / Namespace Error | DO NOT use a global namespace: in the app kustomization. |
| Patch not applying | Ensure namespace and kind in the patch match the component exactly. |
| New tile not appearing | Ensure the -app.yaml file is listed in the cluster kustomization. |