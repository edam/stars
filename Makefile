USR_BIN = /usr/local/bin

STARSD = starsd/starsd
STARSD_SRCS = $(shell find starsd -name '*_test.v' -prune -o -name '*.v' -print)

STARS = stars/stars
STARS_SRCS = $(shell find stars -name '*_test.v' -prune -o -name '*.v' -print)

all: starsd stars webapp

starsd: $(STARSD)

stars: $(STARS)

$(STARSD): $(STARSD_SRCS)
	v starsd

$(STARS): $(STARS_SRCS)
	v stars

build: $(STARSD)
	docker build -f ci/Dockerfile -t stars .

dev-starsd:
	v -d trace_orm -d trace_vweb -d vweb_livereload watch run starsd --db=test.db

dev-webapp:
	cd webapp && npm run dev

clean:
	rm -f $(STARS) $(STARSD)

install:
	cp $(STARS) $(USR_BIN)
