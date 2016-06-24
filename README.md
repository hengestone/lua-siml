# Lua Siml

## About

Lua Siml is an implementation of the [Slim](http://slim-lang.info) markup
language for Lua. I't based on [Lua Haml](http://haml.info), hence the name. There may be some artifacts of Haml left in the code that are not quite compatible with the Slim language.

Slim language documentation can be found
[here](http://www.rubydoc.info/gems/slim/frames).

Lua Siml implements a template language that looks like Ruby Slim, with the following exceptions:

* Not all of the Haml-isms have been removed, and not all Slim-isms have been implemented.
* Your script blocks are in Lua rather than Ruby, obviously.
* No attribute methods. This feature would have to be added to Ruby-style
  attributes which are discouraged in Lua-Haml, or the creation of a
  Lua-specific attribute format, which I don't want to add.
* No object reference. This feature is idiomatic to the Rails framework and
  doesn't really apply to Lua.

Differences compared to Lua-Haml
* Tags do not start with `%`
* The header tag `!!!` is called `doctype`
* Support for ruby style attributes have been removed.

Here's a [Siml
template](http://github.com/hengestone/lua-siml/tree/master/sample.slim) that uses
most of Lua Siml's features.

## TODO

* Lua Siml works for simple documents, and is considered alpha quality.
* Partial rendering support.


## Getting it

In _future_ it would be available via LuaRocks:

    luarocks install luasiml

You can also always install the latest master branch from Git via Luarocks:

    luarocks install luasiml --from=http://luarocks.org/repositories/rocks-cvs

## Installing without Luarocks

If you do not wish to use Luarocks, just put `siml.lua` and the `siml` directories
somewhere on your package path, and place `luasiml` somewhere in your execution
path.

Here's one of many ways you could do this:

    git clone git://github.com/norman/lua-siml.git
    cd lua-siml
    cp bin/luasiml ~/bin
    cp -rp siml siml.lua /usr/local/my_lua_libs_dir
    export LUA_PATH=";;/usr/local/my_lua_libs_dir/?.lua"

Note that you can also download a .zip or .tar.gz from Github if you do not use
Git.


## Using it in your application

Here's a simple usage example:

    -- in file.slim
    %p= "Hello, " .. name .. "!"

    -- in your application
    local siml         = require "siml"
    local siml_options = {format = "html5"}
    local engine       = siml.new(options)
    local locals       = {name = "Joe"}
    local rendered     = engine:render_file("file.slim", locals)

    -- output
    <p>Hello, Joe!</p>

## Hacking it

The [Github repository](http://github.com/hengestone/lua-siml) is located at:

    git://github.com/norman/lua-siml.git

To run the specs, you should also install Telescope:

    luarocks install telescope

You can then run them using [Tlua](http://github.com/norman/tlua), or do

    tsc `find . -name '*_spec.lua'`

## Bug reports

Please report them on the [Github issue tracker](http://github.com/hengestone/lua-siml/issues).

## Author

Based on the original work by
[Norman Clarke](mailto://norman@njclarke.com)

## Thanks

Norman Clarke for writing Lua-Haml!

## License

The MIT License

Copyright (c) 2009-2010 Norman Clarke
Copyright (c) 2016 Conrad Steenberg

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
