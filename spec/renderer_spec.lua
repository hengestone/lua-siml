require "siml"

-- This includes only LuaSiml-specific tests. Most other renderer tests
-- are provided by the siml-spec submodule.

local tests = {
  -- Script
  {'p="hello"', '<p>\n  hello\n</p>'},
  {"- a = 'b'\np=a", "<p>\n  b\n</p>"},
  {"- for k,v in pairs({a = 'a'}) do\n  p(class=k)=v", "<p class='a'>\n  a\n</p>"},

}

describe("The LuaSiml Renderer", function()
  local locals = {}
  for _, t in ipairs(tests) do
    test(string.format("should render '%s' as '%s'", string.gsub(t[1], "\n", "\\n"),
        string.gsub(t[2], "\n", "\\n")), function()
        local engine = siml.new()
        assert.are.equal(t[2], engine:render(t[1], locals))
    end)
  end

  test("should call attribute value if a function", function()
    local locals = {
      get_id = function()
        return "hello"
      end
    }
    local code = "p(id=get_id)"
    local html = "<p id='hello'></p>"
    local engine = siml.new()
    assert.are.equal(html, engine:render(code, locals))
  end)

  test("should suppress_eval with script operators", function()
    local code = "p\n  = 'hello'"
    local html = "<p>\n\n</p>"
    local engine = siml.new({suppress_eval = true})
    assert.are.equal(html, engine:render(code, locals))
  end)

  test("should suppress_eval with tag script operators", function()
    local code = "p= 'hello'"
    local html = "<p>\n\n</p>"
    local engine = siml.new({suppress_eval = true})
    assert.are.equal(html, engine:render(code, locals))
  end)

  test("should not interpolate when suppress_eval is set", function()
    local code = "p #{var}"
    local html = "<p>\n  #{var}\n</p>"
    local engine = siml.new({suppress_eval = true})
    assert.are.equal(html, engine:render(code, {var = "hello"}))
  end)

  test("should not interpolate locals in attributes", function()
    local code = "- local foo = \"bar\"\np(class=\"foo-#{foo}\")"
    local html = "<p class='foo-#{foo}'></p>"
    local engine = siml.new()
    assert.are.equal(html, engine:render(code))
  end)

  test("should not interpolate locals in script", function()
    local code = "- local foo = 'bar'\na= \"foo-#{foo}\""
    local html = "<a>\n  foo-#{foo}\n</a>"
    local engine = siml.new()
    assert.are.equal(html, engine:render(code))
  end)

  test("should interpolate globals in attributes", function()
    local code = "- foo = \"bar\"\np(class=\"foo-#{foo}\")"
    local html = "<p class='foo-bar'></p>"
    local engine = siml.new()
    assert.are.equal(html, engine:render(code))
  end)

  test("should not interpolate ruby style code", function()
    local code = "- foo = 'bar'\na= \"foo-#{foo}\""
    local html = "<a>\n  foo-#{foo}\n</a>"
    local engine = siml.new()
    assert.are.equal(html, engine:render(code))
  end)

  test("should not call function attributes when suppress_eval is set", function()
    local locals = {
      get_id = function()
        return "hello"
      end
    }
    local code = "p(id=get_id)"
    local html = "<p></p>"
    local engine = siml.new({suppress_eval = true})
    assert.are.equal(html, engine:render(code, locals))
  end)
end)