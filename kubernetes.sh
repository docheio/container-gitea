#!/bin/bash
NAMESPACE=gitea-test
NAME=gitea
MODE=apply
DB_USERNAME=dbuser
DB_PASSWORD=dbpasswd

cat <<EOF | kubectl $MODE -n $NAMESPACE -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $NAME
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10G
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $NAME
  labels:
    app: $NAME
spec:
  replicas: 1
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
        image: gitea/gitea:latest
        imagePullPolicy: Always
        ports:
        - name: tcp3000
          containerPort: 3000
        - name: tcp22
          containerPort: 22
        volumeMounts:
        - name: $NAME
          mountPath: /data
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
  type: LoadBalancer
  ports:
  - name: tcp3000
    protocol: TCP
    port: 3000
    targetPort: 3000
  - name: tcp22
    protocol: TCP
    port: 22
    targetPort: 22
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $NAME-mariadb
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
  name: $NAME-mariadb
  labels:
    app: $NAME-mariadb
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $NAME-mariadb
  template:
    metadata:
      labels:
        app: $NAME-mariadb
    spec:
      containers:
      - name: $NAME-mariadb
        image: mariadb:latest
        imagePullPolicy: Always
        env:
        - name: MARIADB_ROOT_PASSWORD
          value: $DB_PASSWORD
        - name: MARIADB_DATABASE
          value: database
        - name: MARIADB_USER
          value: $DB_USERNAME
        - name: MARIADB_PASSWORD
          value: $DB_PASSWORD
        - name: TZ
          value: Asia/Tokyo
        ports:
        - name: tcp3306
          containerPort: 3306
        volumeMounts:
        - name: $NAME-mariadb
          mountPath: /var/lib/mysql
        args:
        - --default-authentication-plugin=mysql_native_password
        - --character-set-server=utf8mb4
        - --collation-server=utf8mb4_unicode_ci
      volumes:
      - name: $NAME-mariadb
        persistentVolumeClaim:
          claimName: $NAME-mariadb
---
apiVersion: v1
kind: Service
metadata:
  name: $NAME-mariadb
spec:
  selector:
    app: $NAME-mariadb
  type: ClusterIP
  ports:
  - name: tcp3306
    protocol: TCP
    port: 3306
    targetPort: 3306
EOF