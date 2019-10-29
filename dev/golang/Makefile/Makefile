REGISTRY_TAG?=test
REGISTRY?=liupeng0518/hello

ARCH?=$(shell go env GOARCH)
OSARCH=$(ARCH)
TEMP_DIR:=$(shell mktemp -d)

# Set default base image dynamically for each arch
ifeq ($(ARCH),arm64)
	OSARCH?=aarch64
	BASEIMAGE?=arm64v8/debian-slim
endif
ifeq ($(ARCH),amd64)
	OSARCH?=amd64
	BASEIMAGE?=debian-slim
endif
ifeq ($(ARCH),mips64le)
        OSARCH?=mips64le
        BASEIMAGE?=liupeng0518/debian-debootstrap:mips64el-buster

endif

build:
	cp -r .  $(TEMP_DIR)
	# Replace BASEIMAGE with the real base image
	cd $(TEMP_DIR) && pwd && sed -i.bak 's|BASEIMAGE|$(BASEIMAGE)|g' Dockerfile && sed -i.bak 's|OSARCH|$(OSARCH)|g' Dockerfile

	docker build -t $(REGISTRY):$(REGISTRY_TAG) $(TEMP_DIR)

push:
	docker push $(REGISTRY):$(REGISTRY_TAG)

all: build push
