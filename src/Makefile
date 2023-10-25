STARSD_DIRS = cmd/starsd util api
CLI_DIRS = cmd/cli util api

STARSD_SRCS = $(foreach dir, $(STARSD_DIRS), $(shell find $(dir) -name '*.v'))
CLI_SRCS = $(foreach dir, $(CLI_DIRS), $(shell find $(dir) -name '*.v'))

.PHONY: all cli clean

all: stars starsd

cli: stars

starsd: $(STARSD_SRCS)
	v -o $@ cmd/starsd

stars: $(CLI_SRCS)
	v -o $@ cmd/cli

clean:
	rm stars starsd
