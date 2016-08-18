local parser       = require "siml.parser"
local precompiler  = require "siml.precompiler"
local renderer     = require "siml.renderer"
local ext          = require "haml.ext"
local libgen       = require "posix.libgen"
local pretty       = require "pl.pretty"
local print        = print

local assert       = assert
local merge_tables = ext.merge_tables
local open         = io.open
local setmetatable = setmetatable
local ipairs       = ipairs
local type         = type

--- An implementation of the Slim markup language for Lua.
-- <p>
-- For more information on Slim, please see <a href="http://slim-lang.info">The Slim website</a>
-- and the <a href="http://www.rubydoc.info/gems/slim/frames">Slim language reference</a>.
-- </p>
module "siml"

--- Default Siml options.
-- @field format The output format. Can be xhtml, html4 or html5. Defaults to xhtml.
-- @field encoding The output encoding. Defaults to utf-8. Note that this is merely informative; no recoding is done.
-- @field newline The string value to use for newlines. Defaults to "\n".
-- @field space The string value to use for spaces. Defaults to " ".
default_siml_options = {
  adapter           = "lua",
  attribute_wrapper = "'",
  auto_close        = true,
  rootdir           = "",
  dir               = "",
  dirsep            = "/",
  escape_html       = false,
  encoding          = "utf-8",
  format            = "xhtml",
  indent            = "  ",
  newline           = "\n",
  preserve          = {pre = true, textarea = true},
  siml              = "siml",
  space             = "  ",
  suppress_eval     = false,
  -- provided for compatiblity; does nothing
  ugly              = false,
  html_escapes      = {
    ["'"] = '&#039;',
    ['"'] = '&quot;',
    ['&'] = '&amp;',
    ['<'] = '&lt;',
    ['>'] = '&gt;'
  },
  --- These tags will be auto-closed if the output format is XHTML (the default).
  auto_closing_tags = {
    area  = true,
    base  = true,
    br    = true,
    col   = true,
    hr    = true,
    img   = true,
    input = true,
    link  = true,
    meta  = true,
    param = true
  }
}

local methods = {}

function methods:render_worker(siml_data, locals, parse)
  local siml_strings

  if type(siml_data) == 'string' then
    siml_strings = {siml_data}
  else
    siml_strings = siml_data
  end

  local compiled = {}
  for i, siml_string in ipairs(siml_strings) do
    local parsed   = parse(siml_string)
    local cm = self:compile(parsed)
    compiled[i] = cm
  end

  local r = renderer.new(compiled, self.options)
  if r.error then
    print(r.error)
    print(compiled[r.chunk])
    return nil
  end
  local rendered = r:render(locals)
  return rendered

end

--- Render a Siml string.
-- @param siml_string The Siml string
-- @param locals Local variable values to set for the rendered template
function methods:render(siml_data, locals)
  return self:render_worker(siml_data, locals, parser.tokenize)
end

--- Render a SimI string.
-- @param siml_string The Siml string
-- @param locals Local variable values to set for the rendered template
function methods:render_simple(simi_data, locals)
  return self:render_worker(simi_data, locals, parser.tokenize_simpl)
end

--- Render a Siml file.
-- @param file The Siml file
-- @param locals Local variable values to set for the rendered template
function methods:render_file(file, locals)
  local fh = assert(open(file))
  local siml_string = fh:read '*a'
  fh:close()
  self.options.file = file
  self.options.dir = libgen.dirname(file)
  return self:render(siml_string, locals)
end

--- Include a file.
-- @param simi_string The filename
-- @param locals Local variable values to set for the rendered template
function methods:include_file(file, locals)
  local fh = assert(open(file))
  local siml_string = fh:read '*a'
  fh:close()
  self.options.file = file
  self.options.dir = libgen.dirname(file)
  return self:render_simple(siml_string, locals)
end

function methods:parse(siml_string)
  return parser.tokenize(siml_string)
end

function methods:parse_simple(simi_string)
  return parser.tokenize_simple(simi_string)
end

function methods:compile(parsed)
  return precompiler.new(self.options):precompile(parsed)
end

function new(options)
  local engine = {}
  engine.options = merge_tables(default_siml_options, options or {})
  return setmetatable(engine, {__index = methods})
end
