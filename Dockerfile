FROM alpine:latest AS builder

WORKDIR /tmp
RUN apk add clang
RUN wget https://github.com/odin-lang/Odin/releases/download/dev-2025-10/odin-linux-amd64-dev-2025-10-05.tar.gz
RUN tar -xf odin-linux-amd64-dev-2025-10-05.tar.gz
WORKDIR /app
COPY . .
RUN /tmp/odin-linux-amd64-nightly+2025-10-05/odin build server -out:boaz

FROM alpine:latest

WORKDIR /app
COPY --from=builder /app/boaz /app/boaz

# Mount your site on /var/site
CMD "./boaz" "--serve-dir" "/var/site/"
