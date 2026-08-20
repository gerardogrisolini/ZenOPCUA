#### Self signed certificate

Il file `opcua_cert.conf` contiene la configurazione openssl usata per generare il certificato client, inclusa la sezione `subjectAltName` (SAN):

```
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
    -keyout opcua-client-key.pem -out opcua-client-cert.pem -config opcua_cert.conf
openssl rsa -in opcua-client-key.pem -out opcua-client-key-rsa.pem
```

#### SAN (Subject Alternative Name)

Il SAN e' obbligatorio per l'autenticazione OPC UA: i server verificano che l'`ApplicationUri` del client corrisponda a una `URI.*` dichiarata nel SAN del certificato, e che l'hostname dell'endpoint sia presente come `DNS.*` o `IP.*`. La sezione `[alt_names]` di `opcua_cert.conf` dichiara:

- `URI.1 = urn:Gerardo:ZenOPCUA:Client` — application URI del client
- `DNS.1 = Gerardos-MacBook-Pro.local`, `DNS.2 = localhost`, `IP.1 = 127.0.0.1` — endpoint accettati

Senza SAN coerente con `ApplicationUri` e hostname del server, la connessione sicura viene rifiutata con `BadCertificateUriInvalid` o `BadCertificateHostNameInvalid`.

#### File presenti

- `opcua-client-cert.pem` — certificato client (usato dagli integration test)
- `opcua-client-key.pem` — chiave privata PKCS#8
- `opcua-client-key-rsa.pem` — variante RSA della chiave privata (usata dagli integration test)
- `opcua_cert.conf` — configurazione openssl con SAN
- `server-ca.pem` — CA del server di test
