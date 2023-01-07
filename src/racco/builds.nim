import env
import logs
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

proc parseSettings (path: string): tuple[overview: string, thumbnail: int, published: bool] =
  let toml = parsetoml.parseFile(path)
  result.overview = toml["blog"]["overview"].getStr()
  result.thumbnail = toml["blog"]["thumbnail"].getInt()
  result.published = toml["blog"]["published"].getBool()

proc initPage (name, overview, date, href, thumbnail: string, tags: seq[string], published: bool, env: EnvKind): Option[Page] =
  if env == ekProduction and (not published):
    result = none[Page]()
  else:
    result = some((name, overview, date, href, thumbnail, tags, published))

proc initDaily (dir: Path, env: EnvKind, year, month, day: string): Option[Page] =
  let
    (overview, thumbnail, published) = parseSettings(dir.path / "settings.toml")
    name = &"{year}.{month}.{day}"
  result = initPage(name, overview, &"{year}-{month}-{day}", &"{year}/{month}/{day}/daily.html", &"{thumbnail}.png", newSeq[string](), published, env)

proc initWeekly (dir: Path, env: EnvKind, year, month: string, weekNo: int): Option[Page] =
  let
    (overview, thumbnail, published) = parseSettings(dir.path / "settings.toml")
    name = &"{year}.{month} Week0{weekNo}"
    day = if weekNo < 3: $((weekNo+1) * 7)
          else: $getDaysInMonth(Month(month.parseInt), year.parseInt)
  result = initPage(name, overview, &"{year}-{month}-{day}", &"{year}/{month}/week0{weekNo}/weekly.html", &"{thumbnail}.png", newSeq[string](), published, env)

proc initMonthly (dir: Path, env: EnvKind, year, month: string): Option[Page] =
  let
    (overview, thumbnail, published) = parseSettings(dir.path / "settings.toml")
    name = &"{year}.{month} ふりかえり"
    day = getDaysInMonth(Month(month.parseInt), year.parseInt)
  result = initPage(name, overview, &"{year}-{month}-{day}", &"{year}/{month}/monthly.html", &"{thumbnail}.png", newSeq[string](), published, env)

proc buildDailes (env: EnvKind): seq[Page] =
  let currentDir = getCurrentDir()
  for (dir, year, month, day) in dateInDir(currentDir / "dailies"):
    let daily = initDaily(dir, env, year, month, day)
    if Some(@daily) ?= daily:
      createDir(currentDir / &"dist/daily/{year}/{month}/{day}/")
      for assets in walkDir(dir.path / "assets/"):
        let name = $assets.path.split('/')[^1]
        copyFile(assets.path, currentDir / &"dist/daily/{year}/{month}/{day}/{name}")
      var outputFile = open(currentDir / "dist/daily" / daily.href, FileMode.fmWrite)
      defer: outputFile.close()
      let parsed = tokenize(dir.path & "/index.[]").parse()
      outputFile.write(generateXlyHtml(parsed.expand().generate(), daily, xkDaily))
      result.add daily

proc buildWeeklies (env: EnvKind): seq[Page] =
  let currentDir = getCurrentDir()
  for (dir, year, month, weekNo) in walkWeeklies(currentDir / "weeklies"):
    let weekly = initWeekly(dir, env, year, month, weekNo)
    if Some(@weekly) ?= weekly:
      createDir(currentDir / &"dist/weekly/{year}/{month}/week0{weekNo}/")
      for assets in walkDir(dir.path / "assets/"):
        let name = $assets.path.split('/')[^1]
        copyFile(assets.path, currentDir / &"dist/weekly/{year}/{month}/week0{weekNo}/{name}")
      var outputFile = open(currentDir / "dist/weekly" / weekly.href, FileMode.fmWrite)
      defer: outputFile.close()
      let parsed = tokenize(dir.path & "/index.[]").parse()
      outputFile.write(generateXlyHtml(parsed.expand().generate(), weekly, xkWeekly))
      result.add weekly

proc buildMonthlies (env: EnvKind): seq[Page] =
  let currentDir = getCurrentDir()
  for (dir, year, month) in walkMonthlies(currentDir / "monthlies"):
    let weekly = initMonthly(dir, env, year, month)
    if Some(@weekly) ?= weekly:
      createDir(currentDir / &"dist/monthly/{year}/{month}/")
      for assets in walkDir(dir.path / "assets/"):
        let name = $assets.path.split('/')[^1]
        copyFile(assets.path, currentDir / &"dist/monthly/{year}/{month}/{name}")
      var outputFile = open(currentDir / "dist/monthly" / weekly.href, FileMode.fmWrite)
      defer: outputFile.close()
      let parsed = tokenize(dir.path & "/index.[]").parse()
      outputFile.write(generateXlyHtml(parsed.expand().generate(), weekly, xkWeekly))
      result.add weekly

proc build* (env: EnvKind) =
  let
    currentDir = getCurrentDir()
    appDir = getAppDir()
  createDir(currentDir / "dist")
  os.copyFile(appDir / "css/style.css", currentDir / "dist/style.css")
  os.copyDir(appDir / "assets/", currentDir / "dist/assets/")

  let
    articles = buildArticles(env)
    dailies = buildDailes(env)
    weeklies = buildWeeklies(env)
    monthlies = buildMonthlies(env)

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

  successBuild()
