
#!/bin/sh

export AWS_REGION=us-east-2

aws ec2 create-key-pair --key-name eks-test-kp

eksctl create cluster -f deployment/cluster-mng.yaml

aws eks update-kubeconfig --name eks-test-cluster

kubectl get svc

aws eks describe-cluster --name eks-test-cluster --query "cluster.identity.oidc.issuer" --output text
