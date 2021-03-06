PACKAGE := github.com/travis-ci/artifacts
SUBPACKAGES := $(PACKAGE)/path $(PACKAGE)/upload $(PACKAGE)/env $(PACKAGE)/upload

VERSION_VAR := main.VersionString
REPO_VERSION := $(shell git describe --always --dirty --tags)

REV_VAR := main.RevisionString
REPO_REV := $(shell git rev-parse --sq HEAD)

GO ?= go
GOX ?= gox
GODEP ?= godep
GOBUILD_LDFLAGS := -ldflags "-X $(VERSION_VAR) $(REPO_VERSION) -X $(REV_VAR) $(REPO_REV)"
GOBUILD_FLAGS ?=
GOX_OSARCH ?= linux/amd64 darwin/amd64 windows/amd64
GOX_FLAGS ?= -output="build/{{.OS}}/{{.Arch}}/{{.Dir}}" -osarch="$(GOX_OSARCH)"

.PHONY: all
all: clean test save USAGE.txt UPLOAD_USAGE.txt USAGE.md

.PHONY: test
test: build fmtpolice test-deps test-race coverage.html

.PHONY: test-deps
test-deps:
	$(GO) test -i $(GOBUILD_LDFLAGS) $(PACKAGE) $(SUBPACKAGES)

.PHONY: test-race
test-race:
	$(GO) test -race $(GOBUILD_LDFLAGS) $(PACKAGE) $(SUBPACKAGES)

coverage.html: coverage.out
	$(GO) tool cover -html=$^ -o $@

coverage.out: path-coverage.out upload-coverage.out env-coverage.out logging-coverage.out artifact-coverage.out
	$(GO) test -covermode=count -coverprofile=$@.tmp $(GOBUILD_LDFLAGS) $(PACKAGE)
	echo 'mode: count' > $@
	grep -h -v 'mode: count' $@.tmp >> $@
	rm -f $@.tmp
	grep -h -v 'mode: count' $^ >> $@
	$(GO) tool cover -func=$@

path-coverage.out:
	$(GO) test -covermode=count -coverprofile=$@ $(GOBUILD_LDFLAGS) $(PACKAGE)/path

upload-coverage.out:
	$(GO) test -covermode=count -coverprofile=$@ $(GOBUILD_LDFLAGS) $(PACKAGE)/upload

env-coverage.out:
	$(GO) test -covermode=count -coverprofile=$@ $(GOBUILD_LDFLAGS) $(PACKAGE)/env

logging-coverage.out:
	$(GO) test -covermode=count -coverprofile=$@ $(GOBUILD_LDFLAGS) $(PACKAGE)/logging

artifact-coverage.out:
	$(GO) test -covermode=count -coverprofile=$@ $(GOBUILD_LDFLAGS) $(PACKAGE)/artifact

USAGE.txt: build
	$${GOPATH%%:*}/bin/artifacts help | grep -v -E '^(VERSION|\s+v[0-9]\.[0-9]\.[0-9])' > $@

UPLOAD_USAGE.txt: build
	$${GOPATH%%:*}/bin/artifacts help upload > $@

USAGE.md: USAGE.txt UPLOAD_USAGE.txt $(shell git ls-files '*.go')
	./markdownify-usage < USAGE.in.md > USAGE.md

.gox-bootstrap:
	$(GOX) -build-toolchain -osarch="$(GOX_OSARCH)" -verbose 2>&1 | tee $@

.PHONY: build
build: deps
	$(GO) install $(GOBUILD_FLAGS) $(GOBUILD_LDFLAGS) $(PACKAGE)

.PHONY: crossbuild
crossbuild: deps .gox-bootstrap
	$(GOX) $(GOX_FLAGS) $(GOBUILD_FLAGS) $(GOBUILD_LDFLAGS) $(PACKAGE)

.PHONY: deps
deps:
	$(GODEP) restore
	$(GO) get github.com/mitchellh/gox

.PHONY: clean
clean:
	rm -vf $${GOPATH%%:*}/bin/artifacts
	rm -vf coverage.html *coverage.out
	$(GO) clean $(PACKAGE) $(SUBPACKAGES) || true
	if [ -d $${GOPATH%%:*}/pkg ] ; then \
		find $${GOPATH%%:*}/pkg -wholename '*travis-ci/artifacts*.a' | xargs rm -rfv || true; \
	fi
	rm -rvf ./build

.PHONY: save
save:
	$(GODEP) save -copy=false

.PHONY: fmtpolice
fmtpolice:
	set -e; for f in $(shell git ls-files '*.go'); do gofmt $$f | diff -u $$f - ; done
