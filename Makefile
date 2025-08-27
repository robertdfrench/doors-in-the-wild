ORIGIN=https://github.com/illumos/illumos-gate.git
SRC=../illumos-gate
CLONE=../illumos-gate/.git/description
MASTER=$(SRC)/.git/refs/heads/master
NOTES=$(wildcard notes/*.md)

.PHONY: help
help: #: Display this help menu
	@echo "USAGE:\n"
	@cat $(MAKEFILE_LIST) \
		| grep -v grep \
		| grep '#:' \
		| awk -F':' '{OFS=":"; print "make "$$1,$$3}' \
		| sort \
		| column -s':' -t

$(CLONE):
	git clone $(ORIGIN) $(SRC)

.PHONY: pull
pull: $(CLONE) #: Pull the latest illumos code
	git -C $(SRC) pull origin master

.PHONY: index
index: build/index.txt #: Rebuild the index file

build/index.txt: build/.dir $(MASTER)
	rg -ls -e door $(SRC) \
		| sed 's,^$(SRC)/,,' > $@
	wc -l $@

build/coverage.txt: build/.dir $(NOTES)
	rg --no-line-number --no-filename '^\.Pa' notes \
		| cut -d' ' -f2 > $@

build/%.sorted: build/%.txt
	sort $< > $@

build/remaining.txt: build/index.sorted build/coverage.sorted
	comm -23 $^ > $@
	wc -l $@

build/.dir:
	mkdir -p build
	touch $@

.PHONY: clean
clean: #: Clean up Local Work
	rm -rf build

.PHONY: clean_all
clean_all: clean #: Remove Source Code as Well
	rm -rf $(SRC)
