#!/bin/bash
NAMESPACE=gitea-test
NAME=gitea
MODE=apply
DB_USERNAME=dbuser
DB_PASSWORD=dbpasswd

cat <<EOF | kubectl $MODE -n $NAMESPACE -f -
apiVersion: v1
kind: Secret
metadata:
  name: $NAME-config
type: Opaque
stringData:
  app.ini: |-
    APP_NAME = Gitea: Git with a cup of tea
    RUN_MODE = prod
    
    [repository]
    ROOT = /data/git/repositories
    
    [repository.local]
    LOCAL_COPY_PATH = /data/gitea/tmp/local-repo
    
    [repository.upload]
    TEMP_PATH = /data/gitea/uploads
    
    [server]
    APP_DATA_PATH = /data/gitea
    DOMAIN           = localhost
    SSH_DOMAIN       = localhost
    HTTP_PORT        = 3000
    ROOT_URL         =
    DISABLE_SSH      = false
    SSH_PORT         = 22
    SSH_LISTEN_PORT  = 22
    LFS_START_SERVER = false
    
    [database]
    PATH = /data/gitea/gitea.db
    DB_TYPE = mysql
    HOST = gitea-mariadb:3306
    NAME = database
    USER = $DB_USERNAME
    PASSWD = $DB_PASSWORD
    LOG_SQL = false
    SSL_MODE = disable
    
    [indexer]
    ISSUE_INDEXER_PATH = /data/gitea/indexers/issues.bleve
    
    [session]
    PROVIDER_CONFIG = /data/gitea/sessions
    
    [picture]
    AVATAR_UPLOAD_PATH = /data/gitea/avatars
    REPOSITORY_AVATAR_UPLOAD_PATH = /data/gitea/repo-avatars
    
    [attachment]
    PATH = /data/gitea/attachments
    
    [log]
    MODE = console
    LEVEL = info
    ROOT_PATH = /data/gitea/log
    
    [security]
    INSTALL_LOCK = false
    SECRET_KEY   =
    REVERSE_PROXY_LIMIT = 1
    REVERSE_PROXY_TRUSTED_PROXIES = *
    
    [service]
    DISABLE_REGISTRATION = false
    REQUIRE_SIGNIN_VIEW  = false
    
    [lfs]
    PATH = /data/git/lfs
---
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
        command: ["bash"]
        args:
        - -c
        - mkdir -p /data/gitea/conf/ && cp /tmp/app.ini /data/gitea/conf/ && /bin/s6-svscan /etc/s6/
        imagePullPolicy: Always
        ports:
        - name: tcp3000
          containerPort: 3000
        - name: tcp22
          containerPort: 22
        volumeMounts:
        - name: $NAME
          mountPath: /data
        - name: appinit
          mountPath: /tmp/app.ini
          subPath: app.ini
      volumes:
      - name: $NAME
        persistentVolumeClaim:
          claimName: $NAME
      - name: appinit
        secret:
          secretName: $NAME-config
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