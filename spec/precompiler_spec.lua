require "haml"
require "siml"

describe("The LuaSiml Precompiler:", function()

  local engine = siml.new()

  describe("conditional blocks", function()
    it("should handle single if", function()
      assert.are.equal("<p>a</p>", engine:render("- if true then\n  p a"):gsub("%s", ""))
    end)

    it("should handle if/else", function()
      assert.are.equal("<p>a</p>", engine:render("- if true then\n  p a\n- else\n  p b"):gsub("%s", ""))
    end)

    it("should handle if/elseif", function()
      assert.are.equal("<p>a</p>", engine:render("- if true then\n  p a\n- elseif false then\n  p b"):gsub("%s", ""))
    end)

    it("should handle if/elseif/else", function()
      assert.are.equal("<p>a</p>", engine:render("- if true then\n  p a\n- elseif false then\n  p b\n- else\n  p c"):gsub("%s", ""))
    end)
  end)

  describe("the endstack", function()

    local es
    before_each(function()
      es = haml.end_stack.new()
    end)

    it("should have an initial indent level of 0", function()
      assert.are.equal(es:indent_level(), 0)
    end)

    it("should add an HTML tag and increase the indent level", function()
      es:push("</p>")
      assert.are.equal(es:indent_level(), 1)
    end)

    it("should not increase the indent level for code endings", function()
      es:push("end")
      assert.are.equal(es:indent_level(), 0)
    end)

    it("should pop an HTML tag an decrease the indent level", function()
      es:push("</html>")
      es:push("</body>")
      assert.are.equal(es:indent_level(), 2)
      es:pop()
      assert.are.equal(es:indent_level(), 1)
    end)

    it("should not decrease indent level when popping code endings", function()
      es:push("</html>")
      es:push("end")
      assert.are.equal(es:indent_level(), 1)
      es:pop()
      assert.are.equal(es:indent_level(), 1)
    end)

    it("should return nil when popping an empty stack", function()
      assert.are.equal(es:pop(), nil)
    end)

  end)
end)
