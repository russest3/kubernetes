#!/bin/bash
#
# Author: Steve Russell
#
# Kubernetes-AWS-Jenkins Cluster Build Environment

wget -O kops https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64
chmod +x ./kops
sudo mv ./kops /usr/local/bin/
wget -O kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
aws iam create-group --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonRoute53FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/IAMFullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess --group-name kops
aws iam create-user --user-name kops
aws iam add-user-to-group --user-name kops --group-name kops
aws iam create-access-key --user-name kops
export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
#{
#    "AccessKey": {
#        "UserName": "kops",
#        "Status": "Active",
#        "CreateDate": "2017-12-31T00:05:38.188Z",
#        "SecretAccessKey": "WuDcZpWdKvKukxSjGcmE1ZadzaVyLKhIKb1uZ0Z7",
#        "AccessKeyId": "AKIAISGVNUWM2DWIKZDA"
#    }
#}
export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
aws configure set aws_access_key_id $(aws configure get aws_access_key_id)
aws configure set aws_secret_access_key $(aws configure get aws_secret_access_key)
aws configure set default.region us-east-1
aws s3api create-bucket --bucket phfsurplus-com-state-store --region us-east-1
aws s3api put-bucket-versioning --bucket phfsurplus-com-state-store --versioning-configuration Status=Enabled
export NAME=dev.phfsurplus.com
export KOPS_STATE_STORE=s3://phfsurplus-com-state-store
export S3_BUCKET_NAME=phfsurplus-com-state-store
kops create cluster --zones us-east-1d --ssh-public-key ~/.ssh/id_rsa.pub ${NAME}
kops create secret --name ${NAME} sshpublickey kops -i ~/.ssh/id_rsa.pub
aws s3api get-object --bucket $S3_BUCKET_NAME --key dev.phfsurplus.com/instancegroup/nodes nodes
sed -i s/.*machineType:.*/'  machineType: t2.micro'/g nodes
aws s3api put-object --bucket $S3_BUCKET_NAME --key dev.phfsurplus.com/instancegroup/nodes --body nodes
aws s3api get-object --bucket $S3_BUCKET_NAME --key dev.phfsurplus.com/instancegroup/master-us-east-1d master-us-east-1d
sed -i s/.*machineType:.*/'  machineType: t2.micro'/g master-us-east-1d
aws s3api put-object --bucket $S3_BUCKET_NAME --key dev.phfsurplus.com/instancegroup/master-us-east-1d --body master-us-east-1d
kops update cluster ${NAME} --yes
echo "Waiting 15m /n"
sleep 15m
kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
echo "Waiting 5m /n"
sleep 5m
echo "Here is the WebUI password: /n"
kubectl config view
#https://52.23.229.144/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/
#password: u9rGj8kf2aH1mtKWsYWLtJrGiEisqLb7
echo "Making persistent volume /n"
kubectl create -f kubernetes-persistent-volume.yml
kubectl create -f kubernetes-persistent-volume-claim.yml
# Jenkins:
echo "Making Jenkins Pod /n"
kubectl create -f kubernetes-jenkins-deployment.yml
#Password = bebc4893a8514bfaa65e62247397b72a
echo "Exposing port 8080 on Jenkins Pod /n"
kubectl expose rs jenkins-f9ffdd679 --type="LoadBalancer" --name="jenkins-service"
## Need to fix above, will this work with expose deployment?
## Need to further script the Jenkins deployment to auto update, install required plugins