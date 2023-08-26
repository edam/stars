STARSD = starsd/starsd

all: starsd

starsd: $(STARSD)

$(STARSD): $(STARSD_SRCS)
	v starsd

build: $(STARSD)
	docker build -f ci/Dockerfile -t stars .
