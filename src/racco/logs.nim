import std/times
import std/terminal
import std/strformat

proc now (): string =
  result = times.now().format("yyyy-MM-dd HH:mm:ss'.'ffffff")

proc successBuild* () =
  echo &"[{now()}] 🎉 Success to build!"

proc successCreateDaily* (year, month, day: string) =
  echo &"[{now()}] 🎉 Success to create daily for {year}/{month}/{day}."

proc successCreateWeekly* (year, month, weekNo: string) =
  echo &"[{now()}] 🎉 Success to create weekly for {year}/{month} Week0{weekNo}."

proc successCreateMonthly* (year, month: string) =
  echo &"[{now()}] 🎉 Success to create monthly for {year}/{month}."

proc successServes* (host: string, port: uint16) =
  echo &"[{now()}] 🚀 Serve {host}:{port}/index.html"

proc msgPortAlreadyInUse* (port: uint16) =
  echo &"[{now()}] 👮 Port {port} already in use."

proc warning (msg: string) =
  stderr.styledWriteLine(&"[{now()}] ", fgYellow, "Warning: ", resetStyle, msg)

proc warningUsedForceOption* () =
  warning("The force option overwrites existing files.")

proc error (msg: string) =
  stderr.styledWriteLine(&"[{now()}] ", fgRed, styleBright, "Error: ", resetStyle, msg)

proc errorDailyAlreadyExists* (year, month, day, path: string) =
  error(&"{year}/{month}/{day} already exists: {path}")

proc errorWeeklyAlreadyExists* (year, month, weekNo, path: string) =
  error(&"{year}/{month} Week0{weekNo} already exists: {path}")

proc errorMonthlyAlreadyExists* (year, month, path: string) =
  error(&"{year}/{month} already exists: {path}")