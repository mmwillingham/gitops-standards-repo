# This repo has been simplified to use only kustomize.
## NOTE: This configuration assumes a ArgoCD pull method. i.e. GitOps will be running on each cluster and pulling from repo.

# TL/DR
```
# Prepare environment
oc login -u <USERNAME> -p <PASSWORD> https://api.<CLUSTER FQDN>:6443
git clone https://github.com/mmwillingham/gitops-standards-repo.git
cd gitops-standards-repo.git
export gitops_repo=https://github.com/mmwillingham/gitops-standards-repo.git
export cluster_name=<clustername>
export cluster_base_domain=$(oc get ingress.config.openshift.io cluster --template={{.spec.domain}} | sed -e "s/^apps.//")
export platform_base_domain=${cluster_base_domain#*.}

# Validate variables
echo $gitops_repo
echo $cluster_name
echo $cluster_base_domain
echo $platform_base_domain

# Install GitOps
oc apply -f .bootstrap/subscription.yaml
oc apply -f .bootstrap/cluster-rolebinding.yaml
sleep 60
oc get pods -n openshift-gitops
oc get pods -n openshift-gitops-operator
oc get argocd -A
envsubst < .bootstrap/argocd.yaml | oc apply -f -
sleep 30
oc apply -f .bootstrap/appprojects.yaml

# Install root-application
envsubst < .bootstrap/root-application.yaml | oc apply -f -

```


