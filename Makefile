STARSD = src/starsd
STARS = src/stars

all: starsd stars webapp

starsd: $(STARSD)

stars: $(STARS)

$(STARSD) $(STARS):
	make -C src starsd

$(STARS):
	make -C src stars

build: $(STARSD)
	docker build -f ci/Dockerfile -t stars .

dev-starsd:
	cd src && v -d trace_orm -d trace_vweb -d vweb_livereload watch run cmd/starsd --db-file=test.db

dev-webapp:
	cd webapp && npm run dev

clean:
	rm -f $(STARS) $(STARSD)
