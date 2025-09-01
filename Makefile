PROJECT=https://github.com/illumos/illumos-gate
BLOB_URL=$(PROJECT)/blob/master
ORIGIN=$(PROJECT).git
SRC=../illumos-gate
CLONE=../illumos-gate/.git/description
MASTER=$(SRC)/.git/refs/heads/master
NOTES:=$(shell find docs -type f -name "*.md")

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

.PHONY: next
next: build/remaining.txt #: Next uncovered file
	@head -n1 $<

.PHONY: index
index: build/index.txt #: Rebuild the index file

.PHONY: progress
progress: build/index.txt build/remaining.txt #: How much has been covered
	@wc -l $^ \
		| awk '{ l[NR]=$$1 }; END { print(1.0 - l[2]/l[1])*100"%" }'

.PHONY: pathfix
pathfix: #: Adjust all .Pa paths to be markdown links
	find docs -type f -name "*.md" \
		| sed 's/\.md$$/.pathfix/' \
		| xargs make

build/index.txt: build/.dir $(MASTER)
	rg -ls -e door $(SRC) \
		| sed 's,^$(SRC)/,,' > $@

build/coverage.txt: build/.dir $(NOTES)
	rg --no-line-number --no-filename '^\* \[`' docs/ \
		| sed 's/^\* \[`//' \
		| sed 's/`\].*//' > $@

build/%.sorted: build/%.txt
	sort $< > $@

build/remaining.txt: build/index.sorted build/coverage.sorted
	comm -23 $^ > $@

build/.dir:
	mkdir -p build
	touch $@

%.pathfix: %.md
	$(eval TMP := $(shell mktemp))
	cat $< \
		| awk -f bin/pathfix.awk -v blob_url="$(BLOB_URL)" > $(TMP)
	mv $(TMP) $<

.PHONY: clean
clean: #: Clean up Local Work
	rm -rf build .venv site

.PHONY: clean_all
clean_all: clean #: Remove Source Code as Well
	rm -rf $(SRC)

venv=. .venv/bin/activate &&

serve: .venv/ready #: Serve the mkdocs website
	$(venv) mkdocs serve

.PHONY: serve


build: .venv/ready #: Build the website
	$(venv) mkdocs build -d public

.PHONY: build


.venv/ready: requirements.txt .venv/latest-pip
	$(venv) pip install -r $<
	touch $@

.venv/latest-pip: .venv/empty
	$(venv) pip install --upgrade pip
	touch $@

.venv/empty:
	python3 -m venv .venv
	touch $@
