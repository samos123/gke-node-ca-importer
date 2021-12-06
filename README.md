# GKE self-signed docker registry: Node CA importer
Let's assume your company has a private CA that's not trusted by default.
All internal services such as on-prem docker registry have their certs signed
by this private CA. This would cause GKE to prevent pulling from the on-prem
registry since it's not trusted. In this guide we assume the private CA is
stored in a file called `myCA.pem`.

The solution is to import the CA into the system bundle and restart docker.
However on GKE, COS is used which makes this harder. The following steps
are needed on GKE:
1. Create a docker image that that has `myCA.pem`, copies the myCA.pem 
   into /mnt/etc/ssl/certs/, runs `update-ca-certificates` and restart
   docker daemon.
2. Create a daemonset that runs this docker image on every node and mount
   the host /etc directory to the containers /mnt/etc directory

### 1. Creating the CA inserter docker image

The corresponding Dockerfile is seen here:
```dockerfile
FROM ubuntu
COPY myCA.pem /myCA.pem
COPY insert-ca.sh /usr/sbin/
CMD insert-ca.sh
```

This is the script `insert-ca.sh` that will be used in the Docker image:
```bash
#!/bin/bash

cp /myCA.pem /mnt/etc/ssl/certs

nsenter --target 1 --mount update-ca-certificates

nsenter --target 1 --mount bash -c "systemctl is-active --quiet docker && systemctl restart docker"
nsenter --target 1 --mount bash -c "systemctl is-active --quiet containerd && systemctl restart containerd"
```
Now build and push the image to GCR:
```
docker build -t gcr.io/$PROJECT_ID/custom-cert
docker push gcr.io/$PROJECT_ID/custom-cert
```

### 2. Deploy daemonset to insert CA on GKE nodes
Now that we've the insert CA docker image built we can run it on each node
using a DaemonSet. This will ensure that we add more nodes that the same
customization is applied.

Use the following DaemonSet `daemonset.yaml` to apply the insert CA container on all nodes:
```
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cert-customizations
  labels:
    app: cert-customizations
spec:
  selector:
    matchLabels:
      app: cert-customizations
  template:
    metadata:
      labels:
        app: cert-customizations
    spec:
      hostNetwork: true
      hostPID: true
      initContainers:
      - name: cert-customizations
        image: gcr.io/$PROJECT_ID/custom-cert
        volumeMounts:
          - name: etc
            mountPath: "/mnt/etc"
        securityContext:
          privileged: true
          capabilities:
            add: ["NET_ADMIN"]
      volumes:
      - name: etc
        hostPath:
          path: /etc
      containers:
      - name: pause
        image: gcr.io/google_containers/pause
```
Now apply with `kubectl apply -f daemonset.yaml`.

After the Pod has been run you will notice that you can pull from a self-signed
registry in GKE.

### 3. (Optional) Creating a root CA and deploying a registry with self-signed cert
You can skip this if you already have an internal registry that is self-signed.
These were the steps I used to test using a self-signed registry with GKE.

Create our root CA for testing:
```
openssl genrsa -des3 -out myCA.key 2048 # private key
openssl req -x509 -new -nodes -key myCA.key -sha256 -days 1825 -out myCA.pem # public root CA
```

Create a cert for docker registry
```
openssl genrsa -out registry.samos-it.com.key 2048
openssl req -new -key registry.samos-it.com.key -out registry.samos-it.com.csr
openssl x509 -req -in registry.samos-it.com.csr -CA myCA.pem -CAkey myCA.key -CAcreateserial \
  -out registry.samos-it.com.crt -days 1825 -sha256 -extfile registry.samos-it.com.ext
mkdir certs
mv registry.samos-it.com.crt certs/
mv registry.samos-it.com.key certs/
```

Deploy docker registry with the custom cert signed by the CA
```
docker run -d \
  --restart=always \
  --name registry \
  -v "$(pwd)"/certs:/certs \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.samos-it.com.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/registry.samos-it.com.key \
  -p 443:443 \
  registry:2
```

```
cp /custom-root-ca.pem /mnt/etc/ssl/certs/custom-root-ca.pem
update-ca-certificates
systemctl restart docker
```
