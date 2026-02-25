# This repo has been simplified to use only kustomize.
## NOTE: This configuration assumes a ArgoCD pull method. i.e. GitOps will be running on each cluster and pulling from repo.

### Prerequisites
```
1. Create cluster config folder: ./clusters/<clustername>/kustomization.yaml
2. Import cluster into ACM. Some operators are deployed with OperatorPolicies instead of subscriptions. Operator Policies are part of open-cluster-management. To get these, the cluster needs to be an ACM hub or managed cluster.
```

### TL/DR steps
```
# Prepare environment file (prepare.env)
cat << EOF > prepare.env
# Replace with your values
export CLUSTER_NAME="cluster-8x88q"
#echo $CLUSTER_NAME
export PLATFORM_BASE_DOMAIN="8x88q.sandbox232.opentlc.com"
#echo $PLATFORM_BASE_DOMAIN
export CLUSTER_BASE_DOMAIN=$CLUSTER_NAME.$PLATFORM_BASE_DOMAIN
#echo $CLUSTER_BASE_DOMAIN
export USERNAME="kubeadmin"
export PASSWORD="dEJrn-rcTji-z2uVx-kgpgv"
export GITOPS_REPO="https://github.com/mmwillingham/gitops-standards-repo.git"
export GITOPS_REPO_PATH="gitops-standards-repo"
# export cluster_base_domain=$(oc get ingress.config.openshift.io cluster --template={{.spec.domain}} | sed -e "s/^apps.//")
#export PLATFORM_BASE_DOMAIN=${CLUSTER_BASE_DOMAIN#*.}
EOF
cat prepare.env

# Adjust environment file and execute
source prepare.env

# Validate variables and login
echo CLUSTER_NAME: ${CLUSTER_NAME}
echo CLUSTER_BASE_DOMAIN: ${CLUSTER_BASE_DOMAIN}
echo USERNAME: ${USERNAME}
echo PASSWORD: ${PASSWORD}
echo GITOPS_REPO: ${GITOPS_REPO}
echo GITOPS_REPO_PATH: ${GITOPS_REPO_PATH}
echo PLATFORM_BASE_DOMAIN: ${PLATFORM_BASE_DOMAIN}

# Validate login
oc login -u ${USERNAME} -p ${PASSWORD} https://api.${CLUSTER_BASE_DOMAIN}:6443
oc whoami

# Clone repo
git clone ${GITOPS_REPO}
cd ${GITOPS_REPO_PATH}

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


