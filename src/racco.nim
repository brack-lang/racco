import std/os
import std/times
import std/strformat
import std/strutils
import std/random
import std/asyncdispatch
import std/asynchttpserver
import std/json
import nwatchdog

import racco/builder
import racco/env

include "scfs/article.settings.toml.nimf"
include "scfs/daily.settings.toml.nimf"

proc today (): string =
  let now = now()
  result = &"{$now.year}-{$(now.month.int)}-{$now.monthday}"

proc splitDate (date: string): tuple[year: string, month: string, day: string] =
  let s = date.split("-")
  result = (s[0], s[1], s[2])

proc newArticle (slug: string, date: string = today()): int =
  let
    (year, month, day) = splitDate(date)
    path = &"{getCurrentDir()}/articles/{year}/{month}/{day}/{slug}"
  createDir(path)
  block:
    var brack = open(&"{path}/index.[]", fmReadWrite)
    brack.close()
  block:
    var setting = open(&"{path}/settings.toml", fmReadWrite)
    setting.write(articleSettingsToml(rand(1..16)))
    setting.close()

proc newDaily (date: string = today()): int =
  let
    (year, month, day) = splitDate(date)
    path = &"{getCurrentDir()}/dailies/{year}/{month}/{day}"
  createDir(path)
  block:
    var brack = open(&"{path}/index.[]", fmReadWrite)
    brack.close()
  block:
    var setting = open(&"{path}/settings.toml", fmReadWrite)
    setting.write(dailySettingsToml(rand(1..16)))
    setting.close()

proc buildBlog (env: EnvKind = ekUser): int =
  builder.build(env)

proc preview (env: EnvKind = ekUser) =
  var clients: seq[Request] = @[]
  let currentDir = getCurrentDir()
  discard buildBlog()
  proc serve {.async.} =
    var server = newAsyncHttpServer()
    proc cb(req: Request) {.async.} =
      if req.url.path == "/poll":
        clients.add req
        return
      let headers = case $req.url.path.split('.')[^1]
                    of "html": {"Content-type": "text/html; charset=utf-8"}
                    of "css": {"Content-type": "text/css; charset=utf-8"}
                    else: {"Content-type": "text/plain; charset=utf-8"}
      let html = block:
        let f = open(currentDir / "dist" & req.url.path)
        defer: f.close()
        f.readAll
      await req.respond(Http200, html, headers.newHttpHeaders())

    var port = 3000
    while true:
      try:
        server.listen(Port(port))
        break
      except OSError:
        echo &"Port {port} already in use"
        port += 1

    echo "Serve http://localhost:" & $port.uint16 & "/index.html"
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
    "[\\w\\W]*\\.(\\[\\]|toml)",
    callback,
    "transpiled brack"
  )
  wd.add(
    currentDir / "articles",
    "[\\w\\W]*\\.(\\[\\]|toml)",
    callback,
    "transpiled brack"
  )

  waitFor serve() and wd.watch

when isMainModule:
  import cligen

  dispatchMulti(
    [newArticle, cmdName = "new:article"],
    [newDaily, cmdName = "new:daily"],
    [preview],
    [buildBlog, cmdName = "build"]
  )
