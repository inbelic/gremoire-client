ODIN=odin

SRC=src

MAIN=main.odin
ODINCFLAGS=-file -out:build/gremoire

ODIR=build/

run:
	$(ODIN) run $(MAIN) $(ODINCFLAGS)

build:
	$(ODIN) build $(MAIN) $(ODINCFLAGS)

debug: ODINCFLAGS += -define:DEBUG=true
debug: build

debug-run: ODINCFLAGS += -define:DEBUG=true
debug-run: run

clean:
	rm -rf build/*

.PHONY: build clean
