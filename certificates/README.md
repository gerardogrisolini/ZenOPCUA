#### Self signed certificate
```
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout private.key -out certificate.crt
openssl rsa -in private.key -out private-rsa.key
```
