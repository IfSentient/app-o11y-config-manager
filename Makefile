# FIXME: This Makefile was generated by `grafana-app-sdk project init`,
# With all possible pre-made make targets, and should be customized to your project based on your needs.

SOURCES   := $(shell find . -type f -name "*.go")
MOD_FILES := go.mod go.sum
VENDOR    := vendor
COVOUT    := coverage.out

OPERATOR_DOCKERIMAGE := "app-o11y-config-manager"

.PHONY: all
all: deps lint test build

.PHONY: deps
deps: $(VENDOR)

.PHONY: lint
lint:
	golangci-lint run --max-same-issues=0 --max-issues-per-linter=0 --exclude-use-default=false

.PHONY: test
test:
	go test -count=1 -cover -covermode=atomic -coverprofile=$(COVOUT) ./...

.PHONY: coverage
coverage: test
	go tool cover -html=$(COVOUT)

.PHONY: build
build: build/plugin build/operator

.PHONY: build/plugin
build/plugin: build/plugin-backend build/plugin-frontend

.PHONY: build/plugin-frontend
build/plugin-frontend:
ifeq ("$(wildcard plugin/src/plugin.json)","plugin/src/plugin.json")
	@cd plugin && yarn install && yarn build
else
	@echo "No plugin.json found, skipping frontend build"
endif

.PHONY: build/plugin-backend
build/plugin-backend:
ifeq ("$(wildcard plugin/Magefile.go)","plugin/Magefile.go")
	@cd plugin && mage -v
else
	@echo "No Magefile.go found, skipping backend build"
endif

.PHONY: build/operator
build/operator:
	docker build -t $(OPERATOR_DOCKERIMAGE) -f cmd/operator/Dockerfile .

.PHONY: compile/operator
compile/operator:
	@go build cmd/operator -o target/operator

.PHONY: generate
generate:
	@grafana-app-sdk generate -c kinds

.PHONY: local/up
local/up: local/generate
	@local/scripts/cluster.sh create "local/generated/k3d-config.json"
	@cd local && tilt up

.PHONY: local/generate
local/generate:
	@grafana-app-sdk project local generate

.PHONY: local/down
local/down:
	@cd local && tilt down

.PHONY: local/deploy_plugin
local/deploy_plugin:
	-tilt disable grafana
	cp -R plugin/dist local/mounted-files/plugin/dist
	-tilt enable grafana

.PHONY: local/push_operator
local/push_operator:
	# Tag the docker image as part of localhost, which is what the generated k8s uses to avoid confusion with the real operator image
	@docker tag "$(OPERATOR_DOCKERIMAGE):latest" "localhost/$(OPERATOR_DOCKERIMAGE):latest"
	@local/scripts/push_image.sh "localhost/$(OPERATOR_DOCKERIMAGE):latest"

.PHONY: local/clean
local/clean: local/down
	@local/scripts/cluster.sh delete

.PHONY: clean
clean:
	@rm -f $(COVOUT)
	@rm -rf $(VENDOR)

.PHONY: $(VENDOR)
$(VENDOR): $(SOURCES) $(MOD_FILES)
	@go mod tidy
	@go mod vendor
	@touch $@