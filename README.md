Daily Stars
===========

Daily Stars is a motivational daily rewards programme for kids (and parents)!

It has:
* A backend (with Dockerfile) and CLI tool (itsself a full client, plus admin tool), written in [V](http://vlang.io).
* a web/mobile frontend, written in [React](https://react.dev/) (coming soon!)

Screenshots
-----------

<img width="659" alt="Screenshot 2023-10-22 at 7 37 08 pm" src="https://github.com/edam/stars/assets/3274122/fa921b0c-63bc-411a-a0bb-40a93cb140e8">

Install/Run
-----------

``` Shell
$ v install edam.ggetopt
$ make
$ src/starsd --db-file=stars.db --create # start backend
$ src/stars --host=localhost admin # run cli tool
```
