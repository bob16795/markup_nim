# package

version      = "0.0.1"
author       = "bob16795"
description  = "Markup in nim"
license      = "MIT"
bin          = @["markup"]
installExt   = @["nim"]
srcDir       = "src"

# Deps

requires "nim >= 0.10.0"
requires "sdl2"
requires "tempfile"
requires: "nimPNG >= 0.1.0"

import distros

foreignDep "libsdl2-dev"

task test, "Run the Markup tester!":
  withDir "tests":
    echo "Compiling"
    exec "nim -w:off --hints:off --verbosity:0 c -r tester"
