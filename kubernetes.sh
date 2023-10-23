#!/bin/bash
AMESPACE=default
NAME=lcr

cat <<EOF | kubectl apply -n $NAMESPACE -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $NAME
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 20G
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $NAME
  labels:
    app: $NAME
spec:
  replicas: 3
  selector:
    matchLabels:
      app: $NAME
  template:
    metadata:
      labels:
        app: $NAME
    spec:
      containers:
      - name: $NAME
        image: registry:2
        ports:
        - name: tcp5000
          containerPort: 5000
        volumeMounts:
        - name: $NAME
          mountPath: /var/lib/registry
      volumes:
      - name: $NAME
        persistentVolumeClaim:
          claimName: $NAME
---
apiVersion: v1
kind: Service
metadata:
  name: $NAME
spec:
  selector:
    app: $NAME
  ports:
    - name: tcp5000
      protocol: TCP
      port: 5000
      targetPort: 5000
EOF