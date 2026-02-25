# This repo has been simplified to use only kustomize.
## NOTE: This configuration assumes a ArgoCD pull method. i.e. GitOps will be running on each cluster and pulling from repo.

### Prerequisites
```
1. Create cluster config folder: ./clusters/<clustername>/kustomization.yaml
2. Import cluster into ACM. Some operators are deployed with OperatorPolicies instead of subscriptions. Operator Policies are part of open-cluster-management. To get these, the cluster needs to be an ACM hub or managed cluster.
```

### TL/DR steps
```
# Prepare environment
cat << EOF > prepare.env
# Replace with your values
export CLUSTER_NAME=cluster-8x88q
export CLUSTER_BASE_DOMAIN=cluster-8x88q.8x88q.sandbox232.opentlc.com
export USERNAME=kubeadmin
export PASSWORD=<redacted>
export REPO=https://github.com/mmwillingham/gitops-standards-repo.git
export REPO_PATH=gitops-standards-repo
# export cluster_base_domain=$(oc get ingress.config.openshift.io cluster --template={{.spec.domain}} | sed -e "s/^apps.//")
export PLATFORM_BASE_DOMAIN=${CLUSTER_BASE_DOMAIN#*.}


# Validate variables
echo CLUSTER_NAME ${CLUSTER_NAME}
echo CLUSTER_BASE_DOMAIN ${CLUSTER_BASE_DOMAIN}
echo USERNAME ${USERNAME}
echo PASSWORD ${PASSWORD}
echo REPO ${REPO}
echo REPO_PATH ${REPO_PATH}
echo PLATFORM_BASE_DOMAIN ${PLATFORM_BASE_DOMAIN}

# Validate login
oc login -u ${USERNAME} -p ${PASSWORD} https://api.${CLUSTER_BASE_DOMAIN}:6443

EOF

# Execute the sourced file after adjusting with actual values
source prepare.env

# Clone repo
git clone ${REPO}
cd ${REPO_PATH}

# Install GitOps
oc apply -f .bootstrap/subscription.yaml
oc apply -f .bootstrap/cluster-rolebinding.yaml
sleep 60
oc get pods -n openshift-gitops
oc get pods -n openshift-gitops-operator
oc get argocd -n openshift-gitops
envsubst < .bootstrap/argocd.yaml | oc apply -f -
sleep 30
oc apply -f .bootstrap/appprojects.yaml

# Install root-application
envsubst < .bootstrap/root-application.yaml | oc apply -f -

```


