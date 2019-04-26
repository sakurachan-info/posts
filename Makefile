.PHONY: build run
all: build

build:
	HUGO_ENV=production hugo

run:
	hugo server -D
