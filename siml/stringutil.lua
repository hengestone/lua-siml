local table        = table
local string       = string
local ipairs       = ipairs

module "siml.stringutil"

function join(t, sep)
  local joined = {}
  for i,val in ipairs(t) do
    if #val > 0 then
      if #joined > 0 then
        table.insert(joined, sep)
      end
      table.insert(joined, val)
    end
  end

  return table.concat(joined)
end

function split(str, sep)
  local fields = {}
  local pattern = string.format("([^%s]+)", sep)

  str:gsub(pattern,
      function(c)
        fields[#fields+1] = c
      end
    )
  return fields
end

function interpolate_value(str, locals)
  local locals = locals or {}

  -- load stuff between braces
  local code = str:sub(2, str:len()-1)

  -- avoid doing an eval if we're simply returning a value that's in scope
  if locals[code] then return locals[code] end
  local func = loadstring("return " .. code)
  local env = getfenv()
  setmetatable(env, {__index = function(table, key)
    return locals[key] or _G[key]
  end})
  setfenv(func, env)
  return assert(func)()
end
