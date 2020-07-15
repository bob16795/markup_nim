# package

version      = "0.0.1"
author       = "bob16795"
description  = "Markup in nim"
license      = "MIT"
bin          = @["markup"]
srcDir       = "src"

# Deps

requires "nim >= 0.10.0"
requires "sdl2"

import distros

foreignDep "libsdl2-dev"

task test, "Run the Markup tester!":
  withDir "tests":
    exec "nim c -r tester"
