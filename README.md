Daily Stars
===========

Daily Stars is a motivational daily rewards programme for kids (and parents)!

It has:
* A backend (with Dockerfile) and CLI tool (itsself a full client, plus admin tool), written in [V](http://vlang.io).
* a web/mobile frontend, written in [React](https://react.dev/) (coming soon!)

Screenshots
-----------
<img width="684" alt="screenshot" src="https://github.com/edam/stars/assets/3274122/7e76ddcb-57ff-4edb-8786-70a58c7f2e78">

Build and Install
=================

Build
-----

First install [v](vlang.io).

Then install dependencies:

``` Shell
$ v install edam.ggetopt
$ ( cd webapp && npm install )
```

Then build

``` Shell
$ make
```

Output:
* `src/starsd` -- backend
* `src/stars` -- CLI tool

Running Backend
---------------

First initialise database with `--create`, which also adds a defalt "admin"
user.

``` Shell
$ src/starsd --db-file=stars.db --create
```

(Note: other database options exist too; the above uses local sqlite3 DB. See
`--help` for other options, including PostgreSQL.)

Then start backend normally:

``` Shell
$ src/starsd --db-file=stars.db
```

You can add/remove other users with the CLI tool.  And if you even lose access,
you can re-add and reset the admin user:

``` Shell
$ src/starsd --db-file=stars.db --reset-admin
```

Running CLI Tool
----------------

Copy `starsrc.example` to `~/starsrc` and edit config to specify the server and
user credentials.

Then run:

``` Shell
$ stars
```

Also, for help/options, go:

``` Shell
$ stars --help
```

And for the admin menu, to set up prizes/stars:

``` Shell
$ stars admin
```

Running WebApp
--------------

TBD

Development
===========

Install project dependencies, as per Build seciton.

Backend
-------

To run a local test server with a local test database:

``` Shell
$ make dev-starsd
```

And to recreate the local test database:

``` Shell
$ make dev-starsd-reset
```

CLI Tool
--------

``` Shell
$ cd src
$ v run cmd/cli --host=localhost admin
```

To see network activity:

``` Shell
$ v -d trace_stars run cmd/cli --host=localhost admin
```

WebApp
------

``` Shell
$ make dev-webapp
```

This connects to the local test server (above) by default.
