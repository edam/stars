STARSD = starsd/starsd

all: starsd

starsd: $(STARSD)

$(STARSD): $(STARSD_SRCS)
	v starsd

build: $(STARSD)
	docker build -f ci/Dockerfile -t stars .

dev-starsd:
	v -d trace_orm -d trace_vweb -d vweb_livereload watch run starsd --db=test.db

dev-webapp:
	cd webapp && npm run dev
