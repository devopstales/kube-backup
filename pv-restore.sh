#!/bin/bash
set -e
 
echo "getting pvc..."
pvcs=$(kubectl get pvc | awk '{if(NR>1)print $1}')
 
for pvc in ${pvcs}
do
echo "getting tar gz..."
aws s3 cp s3://nextek-site-web/${pvc}.tar.gz ${pvc}.tar.gz

echo "scaling down the deployment..."
deploy=$(kubectl get deploy | grep $(echo ${pvc} | cut -d'-' -f 1) |  awk '{print $1}')
kubectl scale deployment ${deploy} --replicas=0
	
echo "starting rescue pod..."
cat <<EOF | kubectl create -f -
kind: Pod
apiVersion: v1
metadata:
  name: rescue-pod
spec:
  volumes:
    - name: rescue-storage
      persistentVolumeClaim:
       claimName: ${pvc}
  containers:
    - name: rescue-container
      image: alpine
      command: [ "/bin/sh", "-c", "--" ]
      args: [ "while true; do sleep 30; done;" ]
      volumeMounts:
      - mountPath: "/storage"
        name: rescue-storage
EOF

sleep 5

echo "copying pvc..."
kubectl cp ${pvc}.tar.gz rescue-pod:/tmp

echo "deleting existing content..."
kubectl exec rescue-pod -it -- rm -rf /storage/*
 
echo "decompressing backup..."
kubectl exec rescue-pod -it -- tar -xzf /tmp/${pvc}.tar.gz --strip 1  -C  /storage
 
echo "deleting rescue pod..."
kubectl delete pod rescue-pod
 
echo "scaling up deployment..."
kubectl scale deploy/${deploy} --replicas=1

done
