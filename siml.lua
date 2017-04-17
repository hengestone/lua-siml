local parser       = require "siml.parser"
local precompiler  = require "siml.precompiler"
local renderer     = require "siml.renderer"
local ext          = require "haml.ext"
local posix        = require "posix"
local dirent       = require "posix.dirent"
local libgen       = require "posix.libgen"
local posix_glob   = require "posix.glob"
local glob         = posix_glob.glob
local stat         = require "posix.sys.stat"
local pretty       = require "siml.pretty"
local string       = string
local io           = io
local math         = math

local assert       = assert
local merge_tables = ext.merge_tables
local open         = io.open
local setmetatable = setmetatable
local ipairs       = ipairs
local pairs        = pairs
local type         = type
local table        = table
local stringutil   = require "siml.stringutil"
local join         = stringutil.join
local split        = stringutil.split

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
  err_before        = 1,
  err_after        = 1,
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
  siml              = ".siml",
  simi              = ".simi",
  skip              = "_",
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
function makename(inputdir, outputdir, fullpath)
  local rawpath = fullpath:sub(#inputdir +1, -1)
  return outputdir .. rawpath:sub(1, -6)
end

function writefile(name, date)

end

function makedir(fullpath, options)
  local dir = ""
  local info
  for i, elem in ipairs(split(libgen.dirname(fullpath), options.dirsep)) do
    dir = join({dir, elem, options.dirsep})
    info, errmsg, n = stat.stat(dir)
    if info and stat.S_ISREG(info.st_mode) == 1 then
      break
    elseif not info then
      if posix.mkdir(dir) ~= 0 then
        io.stderr:write("Error creating directory " .. dir .. '\n')
        break
      end
    end
  end
end

function count_lines(str, pos)
  local _, count  = string.sub(str, 0, pos):gsub('\n', '\n')
  return count
end

function split_lines(str)
  local t = {}                   -- table to store the indices
  local i = 0
  while true do
    i = string.find(str, "\n", i+1)    -- find 'next' newline
    if i == nil then break end
    table.insert(t, i)
  end
  table.insert(t, -1)
  return t
end

function show_error(str, pos, pre_num, post_num)
  local endings = split_lines(str)
  local err_line = count_lines(str, pos)
  local start_line = math.max(err_line - pre_num, 0)
  local end_line = math.min(err_line + post_num, #endings)
  for i = start_line,end_line do
    if i == err_line then
      io.stderr:write("> ", i, " ")
    else
      io.stderr:write("  ", i, " ")
    end
    io.stderr:write(str.sub(str, endings[i]+1, endings[i+1]))
  end
end

function methods:handle_error(str, err, pos)
  io.stderr:write("Error " .. err .. " at " .. self.options.file .. '\n')
  show_error(str, pos, self.options.err_before, self.options.err_after)
end

function methods:render_worker(siml_data, locals, parse)
  local siml_strings

  if type(siml_data) == 'string' then
    siml_strings = {siml_data}
  else
    siml_strings = siml_data
  end

  local compiled = {}
  for i, siml_string in ipairs(siml_strings) do
    local parsed, err   = parse(siml_string)
    if err then
      self:handle_error(siml_string, err, parsed)
      return parsed, err
    end
    local cm, err = self:compile(parsed)
    if err then
      self:handle_error(siml_string, err, cm)
      return cm, err
    end
    compiled[i] = cm
  end

  local r = renderer.new(compiled, self.options)
  if r.error then
    stderr:write(r.error)
    stderr:write(compiled[r.chunk])
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

--- Render a Siml string.
-- @param siml_data The Siml string
-- @param locals Local variable values to set for the rendered template
function methods:render_simple(simi_data, locals)
  return self:render_worker(simi_data, locals, parser.tokenize_simpl)
end

--- Render a Siml file.
-- @param file The Siml filename
-- @param locals Local variable values to set for the rendered template
function methods:render_file(file, locals)
  local fh = assert(open(file))
  local siml_string = fh:read '*a'
  fh:close()
  self.options.file = file
  self.options.dir = libgen.dirname(file)
  return self:render(siml_string, locals)
end

--- Recursively render a tree
-- @param inputdir The input directory name
-- @param outputdir The output directory name
-- @param locals Local variable values to set for the rendered template
function methods:render_tree(inputdir, outputdir, locals)
  local todo = {inputdir}
  local i = 1
  local files

  while todo[i] do
    local dir = todo[i]
    i =  i + 1

    -- Check that the input is a file or a directory and set up table of names
    local info = stat.stat(dir)
    if stat.S_ISDIR(info.st_mode) == 1 then
      files = dirent.dir(dir)
    elseif stat.S_ISREG(info.st_mode) == 1 then
      files = {dir}
    else
      local error = 'Error: '.. dir .. 'must be a file or a directory'
      return nil, error
    end

    -- Process files
    for i, file in ipairs (files) do
      local fullpath = dir .. self.options.dirsep .. file
      local prefix = file:sub(1,1)
      local postfix = file:sub(-5, -1)

      info = stat.stat(fullpath)
      local isfile = (info and stat.S_ISREG(info.st_mode) == 1)
      local isdir = (info and stat.S_ISDIR(info.st_mode) == 1)

      local result

      if prefix ~= self.options.skip and prefix ~= "." and
          (isdir or (postfix == self.options.siml or postfix == self.options.simi)) then

        if isfile then
          local outputfile = makename(inputdir, outputdir, fullpath)
          io.stdout:write("Rendering " .. fullpath .. " --> " .. outputfile .. '\n')
          local fh = assert(open(fullpath))
          local siml_data = fh:read('*a')
          self.options.file = fullpath
          self.options.dir = dir
          fh:close()

          if postfix == self.options.siml then -- read file
            result, err = self:render(siml_data, locals)
          else
            result, err = self:render_simple(siml_data, locals)
          end
          if err then
            break
          end
          makedir(outputfile, self.options)
          fh = assert(open(outputfile, "w"))
          fh:write(result)
          fh:close()

        elseif isdir then
          io.stdout:write(" --> todo dir " .. fullpath .. '\n')
          table.insert(todo, fullpath)
        end
      else
        self.fullpath = nil
        io.stdout:write("Skipping " .. fullpath .. '\n')
      end
    end
  end
end

--- Include a file.
-- @param file string The filename
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
