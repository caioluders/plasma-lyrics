ID      := $(shell sed -n 's/.*"Id": "\(.*\)".*/\1/p' package/metadata.json)
VERSION := $(shell sed -n 's/.*"Version": "\(.*\)".*/\1/p' package/metadata.json)
OUT     := synced-lyrics-$(VERSION).plasmoid

.PHONY: install uninstall run test package clean

# Install, or upgrade if already installed
install:
	kpackagetool6 -t Plasma/Applet -u package 2>/dev/null || kpackagetool6 -t Plasma/Applet -i package

uninstall:
	kpackagetool6 -t Plasma/Applet -r $(ID)

# Try it in a standalone window (errors go to: journalctl --user -f)
run: install
	plasmawindowed $(ID)

test:
	node tests/lyrics.test.js

# Build the file to upload to store.kde.org
package: clean
	cd package && zip -r ../$(OUT) . -x '*~'
	@echo "Built $(OUT)"

clean:
	rm -f *.plasmoid
