local ext      = require "haml.ext"
local lpeg     = require "lpeg"
local lpeg     = require "lpeg"

local table   = table
local error    = error
local ipairs   = ipairs
local match    = lpeg.match
local next     = next
local pairs    = pairs
local rawset   = rawset
local tostring = tostring
local upper    = string.upper

--- Siml parser
module "siml.parser"

-- import lpeg feature functions into current module
for k, v in pairs(lpeg) do
  if #k <= 3 then
    _M[k] = v
  end
end

local alnum               = R("az", "AZ", "09")
local leading_whitespace  = Cg(S" \t"^0, "space")
local inline_whitespace   = S" \t"
local eol                 = P"\n" + "\r\n" + "\r"
local empty_line          = Cg(P"", "empty_line")
local continuation_line   = P"|"
local multiline_modifier  = Cg(P"|", "multiline_modifier")
local unparsed            = Cg((1 - eol - multiline_modifier)^1, "unparsed")
local content             = Cg((1 - eol - continuation_line)^1)
local default_tag         = "div"
local singlequoted_string = P("'" * ((1 - S "'\r\n\f\\") + (P'\\' * 1))^0 * "'")
local doublequoted_string = P('"' * ((1 - S '"\r\n\f\\') + (P'\\' * 1))^0 * '"')
local quoted_string       = singlequoted_string + doublequoted_string

local operator_symbols = {
  conditional_comment = P"/[",
  escape              = P"\\",
  filter              = P":",
  header              = P"doctype",
  markup_comment      = P"/",
  script              = P"=",
  silent_comment      = P"-#" + "--",
  silent_script       = P"-",
  escaped_script      = P"&=",
  unescaped_script    = P"!=",
  preserved_script    = P"~",
}

-- This builds a table of capture patterns that return the operator name rather
-- than the literal operator string.
local operators = {}
for k, v in pairs(operator_symbols) do
  operators[k] = Cg(v / function() return k end, "operator")
end

local script_operator = P(
  operators.silent_script +
  operators.script +
  operators.escaped_script +
  operators.unescaped_script +
  operators.preserved_script
)

-- (X)HTML Doctype or XML prolog
local  prolog             = Cg(P"XML" + P"xml" / upper, "prolog")
local  charset            = Cg((R("az", "AZ", "09") + S"-")^1, "charset")
local  version            = Cg(P"1.1" + "1.0", "version")
local  doctype            = Cg((R("az", "AZ")^1 + "5") / upper, "doctype")
local  prolog_and_charset = (prolog * (inline_whitespace^1 * charset^1)^0)
local  doctype_or_version = doctype + version
local header = operators.header * (inline_whitespace * (prolog_and_charset + doctype_or_version))^0

-- Modifiers that follow Haml markup tags
local modifiers = {
  self_closing     = Cg(P"/", "self_closing_modifier"),
  inner_whitespace = Cg(P"<", "inner_whitespace_modifier"),
  outer_whitespace = Cg(P">", "outer_whitespace_modifier")
}

-- Markup attributes
function parse_html_style_attributes(a)
  local name   = C((alnum + S".-:_")^1 )
  local value  = C(quoted_string + name)
  local sep    = (P" " + eol)^1
  local assign = P'='
  local pair   = Cg(name * assign * value) * sep^-1
  local list   = S("(") * Cf(Ct("") * pair^0, rawset) * S(")")
  return match(list, a) or error(("Could not parse attributes '%s'"):format(a))
end

local html_style_attributes = P{"(" * ((quoted_string + (P(1) - S"()")) + V(1))^0 * ")"} / parse_html_style_attributes
local attributes       = Cg(Ct((html_style_attributes * html_style_attributes^0)), "attributes")

-- Haml HTML elements
-- Character sequences for CSS and XML/HTML elements. Note that many invalid
-- names are allowed because of Haml's flexibility.
local function flatten_ids_and_classes(t)
  classes = {}
  ids = {}
  for _, t in pairs(t) do
    if t.id then
      table.insert(ids, t.id)
    else
      table.insert(classes, t.class)
    end
  end
  local out = {}
  if next(ids) then out.id = ("'%s'"):format(table.remove(ids)) end
  if next(classes) then out.class = ("'%s'"):format(table.concat(classes, " ")) end
  return out
end

local nested_content = Cg((Cmt(Cb("space"), function(subject, index, spaces)
  local buffer = {}
  local num_spaces = tostring(spaces or ""):len()
  local start = subject:sub(index)
  for _, line in ipairs(ext.psplit(start, "\n")) do
    if match(P" "^(num_spaces + 1), line) then
      table.insert(buffer, line)
    elseif line == "" then
      table.insert(buffer, line)
    else
      break
    end
  end
  local match = table.concat(buffer, "\n")
  return index + match:len(), match
end)), "content")

local  css_name     = S"-_" + alnum^1
local  class        = P"." * Ct(Cg(css_name^1, "class"))
local  id           = P"#" * Ct(Cg(css_name^1, "id"))
local  css          = P{(class + id) * V(1)^0}
local  html_name    = (alnum^1 * (alnum + S":-_")^0) - P("doctype")
local  explicit_tag = Cg(html_name^1, "tag")
local  implict_tag  = Cg(-S(1) * #css / function() return default_tag end, "tag")
local  haml_tag     = (explicit_tag + implict_tag) * Cg(Ct(css) / flatten_ids_and_classes, "css")^0
local inline_code = operators.script * inline_whitespace^0 * Cg(unparsed^0 * -multiline_modifier / function(a) return a:gsub("\\", "\\\\") end, "inline_code")
local multiline_code = operators.script * inline_whitespace^0 * Cg(((1 - multiline_modifier)^1 * multiline_modifier)^0 / function(a) return a:gsub("%s*|%s*", " ") end, "inline_code")
local multiline =  continuation_line * Cg(C(S" \t")^0 * content)
local multiline_content = Cg((Ct(multiline) * (eol^1 * Ct(multiline))^0)/table.concat, "content")
local inline_content = inline_whitespace^0 * Cg(content, "content")

local tag_modifiers = (modifiers.self_closing + (modifiers.inner_whitespace + modifiers.outer_whitespace))

-- Core Haml grammar
local haml_element = Cg(Cp(), "pos") * leading_whitespace * (
  -- Doctype or prolog
  (header) +
  -- Haml markup
  (haml_tag * attributes^0 * tag_modifiers^0 * (inline_code + multiline_code + inline_content)^0) +
  (multiline_content) +
  -- Silent comment
  (operators.silent_comment) * inline_whitespace^0 * Cg(unparsed^0, "comment") * nested_content +
  -- Script
  (script_operator) * inline_whitespace^1 * Cg(unparsed^0, "code") +
  -- IE conditional comments
  (operators.conditional_comment * Cg((P(1) - "]")^1, "condition")) * "]" +
  -- Markup comment
  (operators.markup_comment * inline_whitespace^0 * unparsed^0) +
  -- Filtered block
  (operators.filter * Cg((P(1) - eol)^0, "filter") * eol * nested_content) +
  -- Escaped
  (operators.escape * unparsed^0) +
  -- Unparsed content
  unparsed +
  -- Last resort
  empty_line
)

 haml_element = Cg(Cp(), "pos") * leading_whitespace * (
  (haml_tag * attributes^0 * tag_modifiers^0 * (inline_code + multiline_code + inline_content)^0) +
  (multiline_content) +
  unparsed +
  -- Last resort
  empty_line
)

local grammar = Ct(Ct(haml_element) * (eol^1 * Ct(haml_element))^0)

function tokenize(input)
  return match(grammar, input)
end