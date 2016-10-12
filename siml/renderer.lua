local ext = require "haml.ext"
local stringutil   = require "siml.stringutil"
local _G           = _G
local assert       = assert
local error        = error
local getfenv      = getfenv
local loadstring   = loadstring
local open         = io.open
local pairs        = pairs
local pcall        = pcall
local require      = require
local setfenv      = setfenv
local setmetatable = setmetatable
local sorted_pairs = ext.sorted_pairs
local tostring     = tostring
local string       = string
local type         = type
local rawset       = rawset
local ipairs       = ipairs
local table        = table
local join         = stringutil.join
local split        = stringutil.split
local interpolate_value = stringutil.interpolate_value

module "siml.renderer"

local methods = {}

--- Does Ruby-style string interpolation.
-- e.g.: in "hello #{var}!"
function methods:interp(str)
  if self.options.suppress_eval then return str end
  if type(str) ~= "string" then return str end
  -- match position, then "#" followed by balanced "{}"

  return str:gsub('([\\]*)#()(%b{})', function(a, b, c)
    -- if the character before the match is backslash...
    if a:match "\\" then
      -- then don't interpolate...
      if #a == 1 then
        return '#' .. c
      -- unless the backslash is also escaped by another backslash
      elseif #a % 2 == 0 then
        return a:sub(1, #a / 2) .. interpolate_value(c, self.env.locals)
      -- otherwise remove the escapes before outputting
      else
        local prefix = #a == 1 and "" or a:sub(0, #a / 2)
        return prefix .. '#' .. c
      end
    end
    return interpolate_value(c, self.env.locals)
  end)
end

function methods:escape_html(...)
  return ext.escape_html(..., self.options.html_escapes)
end

local function escape_newlines(a, b, c)
  return a .. b:gsub("\n", "&#x000A;") .. c
end

local function relative_filename(pname, options)
  return join({options.rootdir, options.dir, pname}, options.dirsep)
end

function methods:preserve_html(html)
  local htmls  = html
  for tag, _ in pairs(self.options.preserve) do
    htmls = htmls:gsub(("(<%s>)(.*)(</%s>)"):format(tag, tag), escape_newlines)
  end
  return htmls
end

function methods:attr(attr)
  return ext.render_attributes(attr, self.options)
end

function methods:at(pos)
  self.current_pos = pos
end

function methods:f(file)
  self.current_file = file
end

function methods:b(string)
  table.insert(self.buffer, string)
end

function methods:make_partial_func()
  local renderer = self
  local siml = require "siml"
  return function(pname, locals)
    local engine   = siml.new(renderer.options)
    local rendered = engine:render_file(relative_filename(pname, renderer.options), locals or renderer.env.locals)
    -- if we're in a partial, by definition the last entry added to the buffer
    -- will be the current spaces
    return rendered:gsub("\n", "\n" .. self.buffer[#self.buffer])
  end
end

function methods:make_include_func()
  local renderer = self
  local siml = require "siml"
  return function(pname, locals)
    render.options.siml = "simi"
    local engine   = siml.new(renderer.options)
    return engine:include_file(relative_filename(pname, renderer.options), locals or renderer.env.locals)
  end
end

function methods:make_include_raw_func()
  local renderer = self
  local siml = require "siml"
  return function(pname, locals)
    local fh = assert(open(relative_filename(pname, renderer.options)))
    local raw_string = fh:read '*a'
    fh:close()
    return raw_string
  end
end

function methods:make_yield_func()
  return function(content)
    return ext.strip(content:gsub("\n", "\n" .. self.buffer[#self.buffer]))
  end
end

function methods:render_func(renderer, func, locals)
  local locals      = locals or {}
  renderer.buffer       = {}
  renderer.current_pos  = 0
  renderer.current_file = nil
  renderer.env.locals   = locals or {}

  setmetatable(renderer.env, {__index = function(table, key)
    return locals[key] or _G[key]
  end,
  __newindex = function(table, key, val) rawset(locals, key, val) end
  })

  local succeeded, err = pcall(func)
  if not succeeded then

    local line_number

    if renderer.current_file then
      local file = assert(open(renderer.current_file, "r"))
      local str = file:read(renderer.current_pos)
      line_number = #str - #str:gsub("\n", "") + 1
    end

    error(
      ("\nError in %s at line %s (offset %d):"):format(
        renderer.current_file or "<unknown>",
        line_number or "<unknown>",
        renderer.current_pos - 1) ..
      tostring(err):gsub('%[.*:', '')
    )
  end
  -- strip trailing spaces
  if #renderer.buffer > 0 then
    renderer.buffer[#renderer.buffer] = renderer.buffer[#renderer.buffer]:gsub("%s*$", "")
  end
  return renderer.buffer
end

function methods:render(locals)
  local stack = {}
  local purestack = {}
  local newstrings
  local purestrings = {}
  local data
  local s

  for ifunc, func in ipairs(self.funcs) do
    newstrings = self:render_func(self, func, locals)
    table.insert(stack, {newstrings, 1})

    while #stack > 0 do
      data = table.remove(stack)
      newstrings = data[1]
      si = data[2]
      s = newstrings[si]

      if #purestack > 0 and type(s) == "function" then
        table.insert(purestack, s(table.remove(purestack)))
        si = si + 1
      end

      for i = si, #newstrings do
        s = newstrings[i]
        if type(s) == "string" then
          table.insert(purestrings, s)
        elseif type(s) == "function" then
          table.insert(purestack, table.concat(purestrings))
          purestrings = {}
          table.insert(stack, {newstrings, i})
          break
        end
      end

      if #purestrings > 0 then
        table.insert(purestack, table.concat(purestrings))
        purestrings = {}
      else
        break
      end
    end
  end

  return table.concat(purestack)
end

function new(precompiled, options)
  local compiledfuncs = {}
  local code
  local err

  for i, pre in ipairs(precompiled) do
    code, err = loadstring(pre)
    if not err then
      table.insert(compiledfuncs, code)
    else
      return {error="Parse error: " .. err, chunk=i}
    end
  end

  local renderer = {
    options = options or {},
    -- TODO: capture compile errors here and determine line number
    funcs    = compiledfuncs,
    env     = {}
  }

  setmetatable(renderer, {__index = methods})
  renderer.env = {
    include = renderer:make_include_func(),
    partial = renderer:make_partial_func(),
    r       = renderer,
    verbatim= renderer:make_include_raw_func(),
    yield   = renderer:make_yield_func()
  }

  for i, func in ipairs(renderer.funcs) do
    setfenv(func, renderer.env)
  end
  return renderer
end
