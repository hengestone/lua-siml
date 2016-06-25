require "luarocks.require"
require "orbit"
require "siml"
module("hello", package.seeall, orbit.new)

local views = {}

views.index = [[
doctype XML
doctype Strict
html(xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en")
  head
    meta(http-equiv="Content-Type" content="text/html" charset="utf-8")
    title Siml time!
  body
    h1 Lua Siml
      p
        This is the first web page ever rendered with Lua Haml.
      p= "The time is currently " .. os.date()
]]

function render_siml(str)
  return siml.render(str)
end

function index(web)
  content = views.index
  return render_siml(views.index)
end

hello:dispatch_get(index, "/", "/index")
return _M
