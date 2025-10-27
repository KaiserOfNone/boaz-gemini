#!/bin/sh

if [ ! -f "gemini.key" ] || [ ! -f "gemini.crt" ]; then
	openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out gemini.key
	openssl req -new -x509 -days 365 -key gemini.key -out gemini.crt \
  -subj "/C=US/ST=New York/L=Brooklyn/O=Acme Co/OU=IT/CN=kaiserofnone.xyz"
fi
odin run ./server
