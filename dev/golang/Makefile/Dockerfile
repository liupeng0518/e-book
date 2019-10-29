FROM golang:1.13.3-buster AS builder

COPY . /go
WORKDIR /go

RUN GOARCH=OSARCH go build hello.go

# for test
RUN mkdir -p /root/.helm \
  && touch /usr/local/bin/helm


FROM BASEIMAGE
USER root

COPY --from=builder /root/.helm /root/.helm
COPY --from=builder /usr/local/bin/helm /usr/local/bin/
# COPY --from=builder /go/ipaas/iapps-go/iapps-go /go/ipaas/iapps-go/conf  /go/ipaas/iapps-go/db  /go/ipaas/iapps-go/i18n /
WORKDIR /
CMD ["/iapps-go"]
