import env
import racco

import std/os
import std/times
import std/strformat
import std/strutils
import std/sequtils
import std/algorithm
import std/sugar

import utils
import parsetoml

import brack
import brack/api
initExpander(Html)
initGenerator(Html)

include "../scfs/index.html.nimf"
include "../scfs/daily_index.html.nimf"
include "../scfs/article.html.nimf"
include "../scfs/daily.html.nimf"

proc build* (env: EnvKind) =
  let
    currentDir = getCurrentDir()
    appDir = getAppDir()
  createDir(currentDir / "dist")
  os.copyFile(appDir / "css/style.css", currentDir / "dist/style.css")
  os.copyDir(appDir / "assets/", currentDir / "dist/assets/")

  var pages: seq[Page] = @[]
  for (dayInDir, year, month, day) in dateInDir(currentDir / "articles"):
    for dir in walkDir(dayInDir.path):
      let
        name = dir.path.split('/')[^1]
        toml = parsetoml.parseFile(dir.path / "settings.toml")
        title = toml["blog"]["title"].getStr()
        overview = toml["blog"]["overview"].getStr()
        tags = toml["blog"]["tags"].getElems().map(t => t.getStr())
        thumbnail = toml["blog"]["thumbnail"].getInt()
        published = toml["blog"]["published"].getBool()
        page: Page = (
          title,
          overview,
          &"{year}-{month}-{day}",
          &"{year}/{month}/{day}/{name}.html",
          &"{thumbnail}.png",
          tags,
          published
        )
      
      if env == ekProduction and (not published):
        continue

      block:
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
            page
          )
        )

      pages.add page

  var dailies: seq[Page] = @[]
  for (dir, year, month, day) in dateInDir(currentDir / "dailies"):
    let
      toml = parsetoml.parseFile(dir.path / "settings.toml")
      overview = toml["blog"]["overview"].getStr()
      thumbnail = toml["blog"]["thumbnail"].getInt()
      published = toml["blog"]["published"].getBool()
      page: Page = (
        &"{year}.{month}.{day}",
        overview,
        &"{year}-{month}-{day}",
        &"{year}/{month}/{day}/daily.html",
        &"{thumbnail}.png",
        @[],
        published
      )

    if env == ekProduction and (not published):
      continue

    block:
      createDir(currentDir / &"dist/daily/{year}/{month}/{day}/")
      for assets in walkDir(dir.path / "assets/"):
        let name = $assets.path.split('/')[^1]
        copyFile(assets.path, currentDir / &"dist/daily/{year}/{month}/{day}/{name}")
      var outputFile = open(currentDir / &"dist/daily/{year}/{month}/{day}/daily.html", FileMode.fmWrite)
      defer: outputFile.close()
      let parsed = tokenize(dir.path & "/index.[]").parse()
      outputFile.write(
        generateDailyHtml(
          parsed.expand().generate(),
          page
        )
      )
    
    dailies.add page

  block:
    var outputFile = open(currentDir / &"dist/index.html", FileMode.fmWrite)
    defer: outputFile.close()
    outputFile.write(
      generateIndexHtml(pages.sorted.reversed)
    )

  block:
    createDir(currentDir / &"dist/daily/")
    var outputFile = open(currentDir / &"dist/daily/index.html", FileMode.fmWrite)
    defer: outputFile.close()
    outputFile.write(
      generateDailyIndexHtml(dailies.sorted.reversed)
    )

  let now = now().format("yyyy-MM-dd HH:mm:ss")
  echo &"[{now}] 🎉 Success to build!"
