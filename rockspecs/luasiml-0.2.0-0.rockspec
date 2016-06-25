package = "luasiml"
version = "0.2.0-0"
source = {
   url = "git://github.com/hengestone/lua-siml.git"
}
description = {
   summary = "An implementation of the Slim markup language for Lua."
   detailed = [[
      Lua Siml is an implementation of the Slim markup language for Lua.
   ]],
   license = "MIT/X11",
   homepage = "http://github.com/hengestone/lua-siml"
}
dependencies = {
   "lua >= 5.1",
   "luahaml >= 0.2.0",
   "lpeg"
}

build = {
  type = "none",
  install = {
    lua = {
      "siml.lua",
      ["siml.parser"]        = "siml/parser.lua",
    },
    bin = {
      ["luasiml"] = "bin/luasiml"
    }
  }
}
