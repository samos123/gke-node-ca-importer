# GKE self-signed docker registry: Node CA importer
Let's assume your company has a private CA that's not trusted by default.
All internal services such as on-prem docker registry have their certs signed
by this private CA. This would cause GKE to prevent pulling from the on-prem
registry since it's not trusted. In this guide we assume the private CA is
stored in a file called `myCA.pem`.


## Using the setup script

You can use the helper script to create configmap, secret and DaemonSet:
```sh
./setup.sh registry.samos-it.com myCA.pem
```
In this case the private CA file `myCA.pem` located in your current directora
will be used for the secret.

You should now have the following newly generated files:
```sh
# contains the configmap which has the script
load-certs-cm.yaml
# contains the contents of myCA.pem
registry-pem-secret.yaml
# the DS that runs the script to load the CA is run on each node
daemonset.yaml
```

The DaemonSet should work for both Docker and Containerd

## (Optional) Creating a root CA and deploying a registry with self-signed cert
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
openssl req -new -key registry.samos-it.com.key -out registry.samos-it.com.csr-subj "/CN=registry.samos-it.com" \
    -addext "subjectAltName = DNS:registry.samos-it.com"
openssl req -new -key registry.samos-it.com.key -out registry.samos-it.com.csr
openssl x509 -req -in registry.samos-it.com.csr -CA myCA.pem -CAkey myCA.key -CAcreateserial \
  -out registry.samos-it.com.crt -days 1825 -sha256 -extfile <(printf "subjectAltName=DNS:registry.samos-it.com")
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
