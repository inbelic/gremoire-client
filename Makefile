ODIN=odin

SRC=src

MAIN=main.odin
ODINCFLAGS=-file -out:build/gremoire

ODIR=build/

run: build
	$(ODIN) run . $(ODINCFLAGS)

build: assets
	$(ODIN) build . $(ODINCFLAGS)
	
assets: assets.zip
	unzip -qo -d build/assets assets.zip

reload-assets:
	rm assets.zip
	cd assets
	zip ../assets.zip *.png

debug: ODINCFLAGS += -define:DEBUG=true
debug: build

debug-run: ODINCFLAGS += -define:DEBUG=true
debug-run: run

clean:
	rm -rf build/*

.PHONY: build clean
