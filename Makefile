.PHONY: build run
all: build

build:
	HUGO_ENV=production hugo -d docs

run:
	hugo server -D
