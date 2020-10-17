### Build layer
FROM golang:1 AS builder

# Pin the Terraform version.
ENV TERRAFORM_VERSION 0.13.4

# Enable Go modules.
ENV GO111MODULE on

# https://golang.org/cmd/go/#hdr-Module_configuration_for_non_public_modules
ENV GOPRIVATE github.com/cloudreach ##TODO

# Disabling cgo means we get fully statically linked binaries.
ENV CGO_ENABLED 0

# Set options for all subsequent 'shell form' RUN commands.
SHELL [ "/bin/bash", "-o", "pipefail", "-c" ]

# Get various tools and prerequisites.
RUN apt-get update \
    && apt-get install --assume-yes --no-install-recommends \
    curl \
    unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Get Terraform.
WORKDIR /tmp
RUN curl --location --remote-name --silent \
    https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
    && unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/bin \
    && rm -rf /tmp/*

# Run Mage setup.
RUN git clone https://github.com/magefile/mage /build/mage
WORKDIR /build/mage
RUN go run bootstrap.go

# Get dependencies.
WORKDIR /build
COPY go.mod go.sum /build/

# Get the clz-mage DRY package.
# Note for relative references: the build context is running from the root of this repo, which is the direct parent of
# the './dry/' sub-directory.
# Running this as a COPY rather than via 'go get' so that the Go code comes from this same branch along with the Docker
# container/file itself.
COPY ./dry/*.go ./dry/go.mod ./dry/go.sum /build/dry/

# We use the 'replace' directive in the 'dry' module's go.mod file to redirect to a local relative directory:
# https://github.com/golang/go/wiki/Modules#when-should-i-use-the-replace-directive
# This, in tandem with the COPY line directly above, makes sure that our current branch's copy of these files is in
# use, rather than 'go get'ing from the 'master' branch.
RUN go mod download

# Compile all of the necessary test logic into a static binary that is fully portable and has no external dependencies.
# Reference: https://magefile.org/compiling/
WORKDIR /build/static
COPY ./*.go /build/static/
RUN mage --compile /build/static/static-magefile

### Execute layer
FROM golang:1-alpine

# Bring over necessary binaries.
COPY --from=builder /build/static/static-magefile /
COPY --from=builder /usr/bin/terraform /

# Bring over downloaded Go dependencies, so that we don't need to download them each and every time this image runs.
COPY --from=builder /go/pkg/mod/ /go/pkg/mod/

# Make sure the environment knows where to look, for the above binaries.
ENV PATH="${PATH}:/"

# See previous instance of this.
ENV CGO_ENABLED 0

# Enable Go modules.
ENV GO111MODULE on

# https://golang.org/cmd/go/#hdr-Module_configuration_for_non_public_modules
ENV GOPRIVATE github.com/cloudreach ##TODO

# Run more tests in parallel.
ENV GOMAXPROCS 10

# Make Mage default to noisy.
ENV MAGEFILE_VERBOSE 1

# https://learn.hashicorp.com/terraform/development/running-terraform-in-automation
ENV TF_IN_AUTOMATION 1

# Get git.
RUN apk update \
    && apk add --no-cache git

# This directory will be mounted as a volume by the build task.
WORKDIR /gitrepo

# Execute tests.
COPY ./scripts/entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]
