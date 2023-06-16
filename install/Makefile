.PHONY: install packages stow shell-plugins

all: install

UNAME_S := $(shell uname -s)

install:
ifeq ($(UNAME_S),Linux)
	@./arch/install.sh
endif
ifeq ($(UNAME_S),Darwin)
	@./macos/install.sh
endif

packages:
ifeq ($(UNAME_S),Linux)
	@./arch/install_packages.sh
endif
ifeq ($(UNAME_S),Darwin)
	@./macos/install_packages.sh
endif

stow:
	@../bin/common/.local/bin/stow-config

shell-plugins:
	@../bin/common/.local/bin/update-shell-plugins
