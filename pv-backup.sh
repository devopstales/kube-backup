#!/bin/bash
set -e

echo "setting context..."
kubectl config set-context gke_local-terminus-246808_europe-west1-b_prod-cluster

echo "getting pvc..."
pvcs=$(kubectl get pvc | awk '{if(NR>1)print $1}')
 
echo "compressing pv..."
for pvc in ${pvcs}
do
	echo "starting rescue pod..."
cat <<EOF | kubectl create -f -
kind: Pod
apiVersion: v1
metadata:
  name: rescue-pod-${pvc}
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
      - mountPath: "/storage-${pvc}"
        name: rescue-storage
EOF

sleep 5
kubectl exec rescue-pod-${pvc} -- tar -zcvf ${pvc}.tar.gz /storage-${pvc}
rm -f ${pvc}.tar.gz
kubectl cp rescue-pod-${pvc}:${pvc}.tar.gz ${pvc}.tar.gz
kubectl delete pod rescue-pod-${pvc}

# aws s3 cp ${pvc}.tar.gz s3://nextek-site-web/

done
