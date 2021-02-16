### EKS Cluster Creation

Set default region

```
export AWS_REGION=<region-name>
```

Create key-pair

```
aws ec2 create-key-pair --key-name <keypair-name>
```

Create EKS cluster - Refer to cluster-mng.yaml file

```
eksctl create cluster -f deployment/cluster-mng.yaml
```

Get cluster config

```
aws eks update-kubeconfig --name <cluster-name>
```

Test cluster config

```
kubectl get svc
```

### Install Helm

Download Helm

```
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

Add Helm stable repo

```
helm repo add stable https://charts.helm.sh/stable
```

Verify repo

```
helm repo list
```

### Add IAM users as cluster admin

Get configMap

```
kubectl -n kube-system get cm
```

Export config map as YAML

```
kubectl -n kube-system get configmap aws-auth -o yaml > aws-auth.yaml
```

Add user to the mapUsers section of the aws-auth.yaml

```
mapUsers: |
  - userarn: <user-arn>
    username: <username>
    groups:
      - system:masters
```

Apply the changes

kubectl apply -f aws-auth-configmap.yaml -n kube-system

Verify RBAC changes

```
kubectl -n kube-system get cm aws-auth
kubectl -n kube-system describe cm aws-auth
```

### Add ALB Service

_Reference: https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html_

View your cluster's OIDC provider URL

```
aws eks describe-cluster --name <cluster-name> --query "cluster.identity.oidc.issuer" --output text
```

List the IAM OIDC providers in your account

```
aws iam list-open-id-connect-providers | grep <oidc-issuer>
```

Create an IAM OIDC identity provider for your cluster

```
eksctl utils associate-iam-oidc-provider --cluster <cluster-name> --approve
```

### AWS Load Balancer Controller (take note of ARN)

Download an IAM policy for the AWS Load Balancer Controller that allows it to make calls to AWS APIs on your behalf

```
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.1.2/docs/install/iam_policy.json
```

Create an IAM policy using the policy downloaded in the previous step

```
aws iam create-policy --policy-name <alb-policy-name> --policy-document file://iam_policy.json
```

Create an IAM role and annotate the Kubernetes service account named aws-load-balancer-controller in the kube-system namespace for the AWS Load Balancer Controller using eksctl or the AWS Management Console and kubectl

```
eksctl create iamserviceaccount \
--cluster=<cluster-name> \
--namespace=kube-system \
--name=<service-account-name> \
--attach-policy-arn=arn:aws:iam::<account-id>:policy/<alb-policy-name> \
--override-existing-serviceaccounts \
--approve
```

Install the TargetGroupBinding custom resource definitions.

```
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
```

Add the eks-charts repository

```
helm repo add eks https://aws.github.io/eks-charts
```

Install the AWS Load Balancer Controller using the command that corresponds to the Region that your cluster is in.

```
helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
 --set clusterName=<cluster-name> \
 --set serviceAccount.create=false \
 --set serviceAccount.name=<service-account-name> \
 -n kube-system
```

Verify that the controller is installed

```
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### Deploy application

Deploy sample workload

```
kubectl apply -f deployment/app-2048.yaml
```

Verify ingress resource creation

```
kubectl get ingress/ingress-2048 -n game-2048
```
