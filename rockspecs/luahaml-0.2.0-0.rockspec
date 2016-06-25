package = "luasiml"
version = "0.2.0-0"
source = {
   url = "http://cloud.github.com/downloads/norman/lua-siml/lua-siml-0.2.0-0.tar.gz",
   md5 = "8e487ba87011657c6b9b75a109c0f90e"
}
description = {
   summary = "An implementation of the Slim markup language for Lua.",
   detailed = [[
      Lua Siml is an implementation of the Slim markup language for Lua.
   ]],
   license = "MIT/X11",
   homepage = "http://github.com/norman/lua-siml"
}
dependencies = {
   "lua >= 5.1",
   "lpeg"
}

build = {
  type = "none",
  install = {
    lua = {
      "siml.lua",
      ["siml.ext"]           = "siml/ext.lua",
      ["siml.parser"]        = "siml/parser.lua",
      ["siml.precompiler"]   = "siml/precompiler.lua",
      ["siml.renderer"]      = "siml/renderer.lua",
      ["siml.tag"]           = "siml/tag.lua",
      ["siml.header"]        = "siml/header.lua",
      ["siml.code"]          = "siml/code.lua",
      ["siml.filter"]        = "siml/filter.lua",
      ["siml.comment"]       = "siml/comment.lua",
      ["siml.lua_adapter"]   = "siml/lua_adapter.lua",
      ["siml.string_buffer"] = "siml/string_buffer.lua",
      ["siml.end_stack"]     = "siml/end_stack.lua"
    },
    bin = {
      ["luasiml"] = "bin/luasiml"
    }
  }
}
