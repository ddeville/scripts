.PHONY: install

UNAME_S := $(shell uname -s)

install:
ifeq ($(UNAME_S),Linux)
	./arch/install.sh
endif
ifeq ($(UNAME_S),Darwin)
	./macos/install.sh
endif
