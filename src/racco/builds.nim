import env
import racco

import std/os
import std/times
import std/options
import std/strformat
import std/strutils
import std/sequtils
import std/algorithm
import std/sugar

import utils
import parsetoml
import fusion/matching

import brack
import brack/api
initExpander(Html)
initGenerator(Html)

type
  Path = tuple[kind: PathComponent, path: string]
  XlyKind = enum
    xkDaily = "daily"
    xkWeekly = "weekly"
    xkMonthly = "monthly"

include "../scfs/index.html.nimf"
include "../scfs/article.html.nimf"
include "../scfs/xly_index.html.nimf"
include "../scfs/xly.html.nimf"

func toPlural (kind: XlyKind): string =
  result = ($kind)[0..^2]
  result.add "ies"

proc initArticle (dir: Path, env: EnvKind, year, month, day: string): Option[Page] =
  let
    name = dir.path.split('/')[^1]
    toml = parsetoml.parseFile(dir.path / "settings.toml")
    title = toml["blog"]["title"].getStr()
    overview = toml["blog"]["overview"].getStr()
    tags = toml["blog"]["tags"].getElems().map(t => t.getStr())
    thumbnail = toml["blog"]["thumbnail"].getInt()
    published = toml["blog"]["published"].getBool()
  if env == ekProduction and (not published):
    result = none[Page]()
  else:
    result = some((title, overview, &"{year}-{month}-{day}", &"{year}/{month}/{day}/{name}.html", &"{thumbnail}.png", tags, published))

proc buildArticles (env: EnvKind): seq[Page] =
  let currentDir = getCurrentDir()
  for (dayInDir, year, month, day) in dateInDir(currentDir / "articles"):
    for dir in walkDir(dayInDir.path):
      let
        name = dir.path.split('/')[^1]
        article = initArticle(dir, env, year, month, day)
      if Some(@article) ?= article:
        createDir(currentDir / &"dist/{year}/{month}/{day}/")
        for assets in walkDir(dir.path / "assets/"):
          let name = $assets.path.split('/')[^1]
          copyFile(assets.path, currentDir / &"dist/{year}/{month}/{day}/{name}")
        var outputFile = open(currentDir / &"dist/{year}/{month}/{day}/{name}.html", FileMode.fmWrite)
        defer: outputFile.close()
        let parsed = tokenize(dir.path / "index.[]").parse()
        outputFile.write(
          generateArticleHtml(
            parsed.expand().generate(),
            article
          )
        )
        result.add article

proc initXly (dir: Path, env: EnvKind, year, month, day: string, kind: XlyKind): Option[Page] =
  let
    toml = parsetoml.parseFile(dir.path / "settings.toml")
    overview = toml["blog"]["overview"].getStr()
    thumbnail = toml["blog"]["thumbnail"].getInt()
    published = toml["blog"]["published"].getBool()
  if env == ekProduction and (not published):
    result = none[Page]()
  else:
    result = some((&"{year}.{month}.{day}", overview, &"{year}-{month}-{day}", &"{year}/{month}/{day}/{$kind}.html", &"{thumbnail}.png", newSeq[string](), published))

proc buildXlies (env: EnvKind, kind: XlyKind): seq[Page] =
  let currentDir = getCurrentDir()
  for (dir, year, month, day) in dateInDir(currentDir / kind.toPlural):
    let xly = initXly(dir, env, year, month, day, kind)
    if Some(@xly) ?= xly:
      createDir(currentDir / &"dist/{$kind}/{year}/{month}/{day}/")
      for assets in walkDir(dir.path / "assets/"):
        let name = $assets.path.split('/')[^1]
        copyFile(assets.path, currentDir / &"dist/{$kind}/{year}/{month}/{day}/{name}")
      var outputFile = open(currentDir / &"dist/{$kind}/{year}/{month}/{day}/{$kind}.html", FileMode.fmWrite)
      defer: outputFile.close()
      let parsed = tokenize(dir.path & "/index.[]").parse()
      outputFile.write(generateXlyHtml(parsed.expand().generate(), xly, kind))
      result.add xly

proc build* (env: EnvKind) =
  let
    currentDir = getCurrentDir()
    appDir = getAppDir()
  createDir(currentDir / "dist")
  os.copyFile(appDir / "css/style.css", currentDir / "dist/style.css")
  os.copyDir(appDir / "assets/", currentDir / "dist/assets/")

  let
    articles = buildArticles(env)
    dailies = buildXlies(env, xkDaily)
    weeklies = buildXlies(env, xkWeekly)
    monthlies = buildXlies(env, xkMonthly)

  block:
    var outputFile = open(currentDir / &"dist/index.html", FileMode.fmWrite)
    defer: outputFile.close()
    outputFile.write(generateIndexHtml(articles.sorted.reversed))
  
  for (kind, xlies) in [(xkDaily, dailies), (xkWeekly, weeklies), (xkMonthly, monthlies)]:
    block:
      createDir(currentDir / &"dist/{$kind}/")
      var outputFile = open(currentDir / &"dist/{$kind}/index.html", FileMode.fmWrite)
      defer: outputFile.close()
      outputFile.write(generateXliesIndexHtml(xlies.sorted.reversed, kind))

  let now = now().format("yyyy-MM-dd HH:mm:ss")
  echo &"[{now}] 🎉 Success to build!"
