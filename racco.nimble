# Package

version       = "0.1.0"
author        = "Mutsuha Asada"
description   = "the blog generator and manager"
license       = "Apache-2.0"
srcDir        = "src"
binDir        = "bin"
bin           = @["racco"]


# Dependencies

requires "nim >= 1.6.6"
requires "cligen == 1.5.32"
requires "nwatchdog == 0.0.8"
requires "https://github.com/brack-lang/brack/archive/refs/tags/v0.0.1"
requires "parsetoml == 0.6.0"
requires "fusion == 1.2"
