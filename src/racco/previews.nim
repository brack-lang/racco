import env
import logs
import builds

import std/os
import std/json
import std/times
import std/strutils
import std/strformat
import std/asyncdispatch
import std/asynchttpserver

import nwatchdog

proc listenAvoidsUsedPort (server: AsyncHttpServer, defaultPort: uint16) =
  var port = defaultPort
  while true:
    try:
      server.listen(Port(port))
      return
    except OSError:
      msgPortAlreadyInUse(port)
      port += 1

proc preview* (env: EnvKind = ekUser) =
  var clients: seq[Request] = @[]
  let currentDir = getCurrentDir()
  build(env)

  proc serve () {.async.} =
    proc cb(req: Request) {.async.} =
      if req.url.path == "/poll":
        clients.add req
        return
      let
        headers = case $req.url.path.split('.')[^1]
                  of "html": {"Content-type": "text/html; charset=utf-8"}
                  of "css": {"Content-type": "text/css; charset=utf-8"}
                  else: {"Content-type": "text/plain; charset=utf-8"}
        currentDir = getCurrentDir()
        html = block:
          let f = open(currentDir / "dist" & req.url.path)
          defer: f.close()
          f.readAll
      await req.respond(Http200, html, headers.newHttpHeaders())

    var server = newAsyncHttpServer()
    server.listenAvoidsUsedPort(3000)
    successServes("http://localhost", server.getPort.uint16)
    while true:
      if server.shouldAcceptRequest():
        await server.acceptRequest(cb)
      else:
        await sleepAsync(500)

  let wd = NWatchDog[string](interval: 100)
  proc callback (file: string, evt: NWatchEvent, param: string) {.gcsafe async.} =
    build(env)
    for client in clients:
      let headers = {"Content-type": "application/json; charset=utf-8"}
      await client.respond(Http200, $(%*{ "status": "ok" }), headers.newHttpHeaders())
    clients = @[]

  wd.add(
    currentDir / "dailies",
    r"[\w\W]*\.(\[\]|toml)",
    callback,
    "transpiled brack"
  )
  wd.add(
    currentDir / "weeklies",
    r"[\w\W]*\.(\[\]|toml)",
    callback,
    "transpiled brack"
  )
  wd.add(
    currentDir / "monthlies",
    r"[\w\W]*\.(\[\]|toml)",
    callback,
    "transpiled brack"
  )
  wd.add(
    currentDir / "articles",
    r"[\w\W]*\.(\[\]|toml)",
    callback,
    "transpiled brack"
  )

  var occuredError = false
  while true:
    try:
      if occuredError:
        waitFor wd.watch
      else:
        waitFor wd.watch or serve()
    except ValueError:
      occuredError = true
