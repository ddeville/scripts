.PHONY: install packages system-config stow tools shell-plugins

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

system-config:
ifeq ($(UNAME_S),Linux)
	@sudo ./arch/configure_system.sh
endif

stow:
	@../bin/common/.local/bin/stow-config

tools:
	@../bin/common/.local/bin/install-scripts-tools

shell-plugins:
	@../bin/common/.local/bin/update-shell-plugins
