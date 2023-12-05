Daily Stars
===========

Daily Stars is a motivational daily rewards programme for kids (and parents)!

It has:
* A backend (with Dockerfile) and CLI tool (itsself a full client, plus admin tool), written in [V](http://vlang.io).
* a web/mobile frontend, written in [React](https://react.dev/) (coming soon!)

Screenshots
-----------
<img width="684" alt="screenshot" src="https://github.com/edam/stars/assets/3274122/7e76ddcb-57ff-4edb-8786-70a58c7f2e78">

Install/Run
-----------

``` Shell
$ v install edam.ggetopt
$ make
$ src/starsd --db-file=stars.db --create # start backend
$ src/stars --host=localhost admin # run cli tool
```
