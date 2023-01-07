import std/os
import std/times
import std/strformat
import std/strutils
import std/random
import std/json

import racco/env
import racco/logs
import racco/builds
import racco/previews

include "scfs/article.settings.toml.nimf"
include "scfs/xly.settings.toml.nimf"

proc today (): string =
  result = now().format("yyyy-MM-dd")

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

proc newDaily (date: string = today(), force: bool = false): int =
  let
    (year, month, day) = splitDate(date)
    path = &"{getCurrentDir()}/dailies/{year}/{month}/{day}"
  
  if dirExists(path) and not force:
    errorDailyAlreadyExists(year, month, day, path)
    return 1
  
  createDir(path)
  block:
    var brack = open(&"{path}/index.[]", fmReadWrite)
    brack.close()
  block:
    var setting = open(&"{path}/settings.toml", fmReadWrite)
    setting.write(xlySettingsToml(rand(1..16)))
    setting.close()

  if force:
    warningUsedForceOption()
  successCreateDaily(year, month, day)

proc newWeekly (date: string = today(), force: bool = false): int =
  let
    (year, month, day) = splitDate(date)
    weekNo = (day.parseInt-1) div 7 + 1
    path = &"{getCurrentDir()}/weeklies/{year}/{month}/week0{weekNo}"
  
  if dirExists(path) and not force:
    errorWeeklyAlreadyExists(year, month, $weekNo, path)
    return 1

  createDir(path)
  block:
    var brack = open(&"{path}/index.[]", fmReadWrite)
    brack.write("{* 今週の日報}\n")
    let weekRange = if weekNo == 3: getDaysInMonth(Month(month.parseInt), year.parseInt)
                    else: 7
    brack.write("{list\n")
    for index in 1 .. weekRange:
      let
        day = block:
          let day = (weekNo - 1) * 7 + index
          if day < 10: "0" & $day
          else: $day
        comma = if index == weekRange: ""
                else: ","
      brack.write(&"  [@ {year}.{month}.{day}, /daily/{year}/{month}/{day}/daily.html]{comma}\n")
    brack.write("}")
    brack.close()
  block:
    var setting = open(&"{path}/settings.toml", fmReadWrite)
    setting.write(xlySettingsToml(rand(1..16)))

  if force:
    warningUsedForceOption()
  successCreateWeekly(year, month, $weekNo)

proc newMonthly (date: string = today(), force: bool = false): int =
  let
    (year, month, _) = splitDate(date)
    path = &"{getCurrentDir()}/monthlies/{year}/{month}"
  
  if dirExists(path) and not force:
    errorMonthlyAlreadyExists(year, month, path)
    return 1
  createDir(path)
  block:
    var brack = open(&"{path}/index.[]", fmReadWrite)
    brack.close()
  block:
    var setting = open(&"{path}/settings.toml", fmReadWrite)
    setting.write(xlySettingsToml(rand(1..16)))
  
  if force:
    warningUsedForceOption()
  successCreateMonthly(year, month)

proc buildCommand (env: EnvKind = ekUser): int =
  build(env)

proc previewCommand (env: EnvKind = ekUser): int =
  preview(env)

when isMainModule:
  import cligen

  dispatchMulti(
    [newArticle, cmdName = "new:article"],
    [newDaily, cmdName = "new:daily"],
    [newWeekly, cmdName = "new:weekly"],
    [newMonthly, cmdName = "new:monthly"],
    [previewCommand, cmdName = "preview"],
    [buildCommand, cmdName = "build"]
  )
