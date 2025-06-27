certificates for https etc

# contents:
1. [vocab](#vocab)
2. [CA](#CA)
   1. [create CA key](#create-ca-key)
   2. [create CA certificate](#create-ca-certificate)
3. [signed server certificate](#signed-server-certificate)
   1. [create a key for server](#create-a-key-for-server)
   2. [create a csr](#create-a-csr)
   3. [sign the csr](#sign-the-csr)
      1. [Intermediate CA](#intermediate-ca)
4. [Install the CA cert](#install-the-ca-cert)
   1. [chrome](#chrome)
   2. [firefox](#firefox)
   3. [edge](#edge)



# vocab
`CA`: certifying authority, entity that signs certificates
    and is trusted, once CA is installed on a device
    the device will see any certificate signed by the CA
    as trustworthy

`server`: server that clients will use, need a certificate saying
    the server is indeed that server. certificate should be
    signed by a CA, otherwise there will be a security error
    saying the site is untrustworthy

`csr`: certificate signing request
    a request that a CA signs. The result of the signing
    is the certificate that a server uses to identify itself
    as trustworthy

# CA

## create CA key
This is the private key that the CA would use.
```
openssl genrsa -des3 -out CA_KEY_NAME.key 2048
```
note: create a passphrase to prevent someone from using your key to sign
      certificates without your permission)

## create CA certificate
This is the certificate that the will be imported as "trusted" by the clients' browsers.
```
openssl req -x509 -new -nodes -key CA_KEY_NAME.key -sha256 -days NDAYS -out CA.pem
```

You will be prompted to answer some questions.  Most are optional.  The
`Common Name` is required.

`NDAYS`: number of days before certificate expires (non-expiring certificates not supported)

`CA_KEY_NAME.key`: [The key file](#create-ca-key)


# signed server certificate

## create a key for server
This is the private key for the server.
```
openssl genrsa -out SERVER_KEY.key 2048
```

## create a csr
This is a request to an existing CA to give you a certificate.
```
openssl req -new -key SERVER_KEY.key -out SERVER_CSR.csr
```

## sign the csr:
create a config file: `SERVER_CSR_CONFIG.txt`
```
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = name1 of server
DNS.2 = name2 of server
...
IP.1 = ip1 of server
IP.2 = ip2 of server
...
```

At least one of IP or DNS values must match the actual server ip/name (ex: some.name.com)
Otherwise, the browser will give a warning.

command:
```
openssl x509 -req -in SERVER_CSR.csr -CA CA.pem \
    -CAkey CA_KEY_NAME.key -CAcreateserial -out SERVER_CERT_NAME.pem \
    -days NUMDAYS -sha256 -extfile SERVER_CSR_CONFIG.txt
```

`SERVER_CERT_NAME.pem` is the certificate to be used for the server.

### Intermediate CA
Often times, a CA does not sign the server certificate directly.  Instead, they give
an intermediate certificate.  You can then use the intermediate certificate to sign
any certificate that you need.

To create an intermediate certificate, in the `SERVER_CSR_CONFIG.txt`
add `keyCertSign` to `keyUsage` list and change `basicConstarints` value
from `CA:FALSE` to `CA:TRUE`

# Install the CA cert
Browsers need to have the CA.pem file to trust anything that was signed
with the CA.pem file.

NOTE: you might need to convert the CA.pem file to a CA.crt file (?just
change the extension?) when adding CA certificate to windows.  Not sure though.

## chrome
1. settings
2. advanced
3. manage certificates
4. choose trusted root certification authorities tab
5. click import

## firefox
1. preferences
2. privacy & security
3. security
4. certificates
5. view certificates
6. import cert

## edge
1. settings
2. privacy, search, services
3. security
4. manage certificates
5. custom
6. trusted certificates
7. import
