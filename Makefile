PLATFORMS= \
	freebsd-386 \
	freebsd-amd64 \
	freebsd-arm \
	linux-386 \
	linux-amd64 \
	linux-arm \
	openbsd-386 \
	openbsd-amd64 \
	windows-386 \
	windows-amd64 \
	darwin-386 \
	darwin-amd64 \
	$(NULL)

DIST=$(shell pwd)/dist

export GOPATH=$(shell pwd)

GOBIN ?= $(shell pwd)
NAME=jira

BIN ?= $(GOBIN)/$(NAME)

CURVER ?= $(shell [ -d .git ] && git describe --abbrev=0 --tags || grep ^\#\# CHANGELOG.md | awk '{print $$2; exit}')
LDFLAGS:=-X jira.VERSION=$(patsubst v%,%,$(CURVER)) -w

# use make DEBUG=1 and you can get a debuggable golang binary
# see https://github.com/mailgun/godebug
ifneq ($(DEBUG),)
	GOBUILD=go get -v github.com/mailgun/godebug && ./bin/godebug build
else
	GOBUILD=go build -v -ldflags "$(LDFLAGS) -s"
endif

build: src/github.com/Netflix-Skunkworks/go-jira
	$(GOBUILD) -o $(BIN) main/main.go

src/%:
	mkdir -p $(@D)
	test -L $@ || ln -sf ../../.. $@
	go get -v $* $*/main

cross-setup:
	for p in $(PLATFORMS); do \
        echo "Building for $$p"; \
		cd $(GOROOT)/src && sudo GOROOT_BOOTSTRAP=$(GOROOT) GOOS=$${p/-*/} GOARCH=$${p/*-/} bash ./make.bash --no-clean; \
   done

all:
	rm -rf $(DIST); \
	mkdir -p $(DIST); \
	for p in $(PLATFORMS); do \
        echo "Building for $$p"; \
        ${MAKE} build GOOS=$${p/-*/} GOARCH=$${p/*-/} BIN=$(DIST)/$(NAME)-$$p; \
    done

fmt:
	gofmt -s -w main/*.go *.go

install:
	${MAKE} GOBIN=~/bin build

NEWVER ?= $(shell echo $(CURVER) | awk -F. '{print $$1"."$$2"."$$3+1}')
TODAY  := $(shell date +%Y-%m-%d)

changes:
	@git log --pretty=format:"* %s [%cn] [%h]" --no-merges ^$(CURVER) HEAD main/*.go *.go | grep -vE 'gofmt|go fmt'

update-changelog:
	@echo "# Changelog" > CHANGELOG.md.new; \
	echo >> CHANGELOG.md.new; \
	echo "## $(NEWVER) - $(TODAY)" >> CHANGELOG.md.new; \
	echo >> CHANGELOG.md.new; \
	$(MAKE) --no-print-directory --silent changes | \
	perl -pe 's{\[([a-f0-9]+)\]}{[[$$1](https://github.com/Netflix-Skunkworks/go-jira/commit/$$1)]}g' | \
	perl -pe 's{\#(\d+)}{[#$$1](https://github.com/Netflix-Skunkworks/go-jira/issues/$$1)}g' >> CHANGELOG.md.new; \
	tail -n +2 CHANGELOG.md >> CHANGELOG.md.new; \
	mv CHANGELOG.md.new CHANGELOG.md; \
	git commit -m "Updated Changelog" CHANGELOG.md; \
	git tag v$(NEWVER)

version:
	@echo $(patsubst v%,%,$(CURVER))

clean:
	rm -rf pkg dist bin src ./$(NAME)
