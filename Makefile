ODIN=odin

SRC=src

MAIN=main.odin
ODINCFLAGS=-file -out:build/gremoire

ODIR=build/

ASSETS=$(wildcard assets/*.png)

run: build
	$(ODIN) run . $(ODINCFLAGS)

build: build/assets
	$(ODIN) build . $(ODINCFLAGS)

build/assets: assets.zip
	unzip -qo -d build assets.zip

assets.zip: $(ASSETS)
	zip -qr assets.zip assets/

debug: ODINCFLAGS += -define:DEBUG=true
debug: build

debug-run: ODINCFLAGS += -define:DEBUG=true
debug-run: run

clean:
	rm -rf build/* assets.zip

.PHONY: build clean
