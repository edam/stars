STARSD = src/starsd
STARS = src/stars

all: starsd stars webapp

starsd: $(STARSD)

stars: $(STARS)

.PHONY: phony build dev-starsd dev-starsd-create dev-webapp clean

$(STARSD) $(STARS): phony
	make -C src $(notdir $@)

build: $(STARSD)
	docker build -f ci/Dockerfile -t stars .

dev-starsd:
	cd src && v -d trace_orm -d trace_vweb -d vweb_livereload watch run cmd/starsd --db-file=test.db

dev-starsd-reset:
	rm -f src/test.db
	cd src && v -d trace_orm -d trace_vweb -d vweb_livereload watch run cmd/starsd --db-file=test.db --create

dev-webapp:
	cd webapp && npm run dev

clean:
	rm -f $(STARS) $(STARSD)
