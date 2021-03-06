.PHONY: spec test clean
DIST_NAME = $(shell lua -e 'v=io.open("VERSION"):read();print("lua-siml-" .. v .. "-0")')

test:
	@tsc spec/*_spec.lua

spec:
	@tsc -f spec/*_spec.lua

package: clean
	mkdir -p pkg
	git clone . pkg/$(DIST_NAME)
	rm -rf  pkg/$(DIST_NAME)/.git
	cd pkg && tar czfp "$(DIST_NAME).tar.gz" $(DIST_NAME)
	rm -rf pkg/$(DIST_NAME)
	md5 pkg/$(DIST_NAME).tar.gz

clean:
	rm -rf pkg
