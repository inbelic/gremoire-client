ODIN=odin

SRC=src

MAIN=$(SRC)/main.odin
ODINCFLAGS=-file -out:build/gremoire

ODIR=build/

build:
	$(ODIN) build $(MAIN) $(ODINCFLAGS)

run:
	$(ODIN) run $(MAIN) $(ODINCFLAGS)

clean:
	rm -rf build/*

.PHONY: build clean
