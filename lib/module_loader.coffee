pathname = require "path"
minimatch = require "minimatch"
fs = require('fs')
_ = require "underscore"
CoffeeScript = require 'coffee-script'
connect = require("connect")

walkDirSync = (dir, cb, visited={}) ->
  return if minimatch(dir, "**/node_modules/*/node_modules/**")
  dir = pathname.resolve(dir)
  visited[dir] = true
  for path in fs.readdirSync(dir)
    path = dir+"/"+path
    continue if visited[path]
    try
      visited[path] = true
      if fs.lstatSync(path).isDirectory()
        cb(path+"/")
        walkDirSync(path, cb, visited)
      else
        cb(path)
    catch error

globSync = (base, pattern) ->
  matches = []
  walkDirSync base, (path) ->
    dir = path[path.length - 1] is "/"
    path = pathname.relative(base, path)
    path += "/" if dir
    unless path.match(/node_modules/)
      matches.push "#{base}/#{path}" if minimatch(path, pattern)
  matches

module.exports = class ModuleLoader
  constructor: (options={}) ->
    @server = options.server || @create_server()
    @env = options.env || "development"
    @ignorepath = options.ignorepath || "./.stitchignore"
    @extensions = _(options.extensions || "js coffee json".split(/\s+/))
    @packages = options.packages || []

    @mtime_cache = {}
    @compile_cache = {}
    
    @mains = {}
    @sources = {}
    @modules = {}
    @cache = {}
    
    if pathname.existsSync(@ignorepath)
      @ignores = _(fs.readFileSync(@ignorepath, "utf8").split(/\s+/)).compact()
    else
      @ignores = []
    
    
    @bind_server()
    
  create_server: ->
    server = require("express").createServer(connect.logger()).listen(2334||process.env.PORT)
    address = server.address()
    console.info "Serving modules at http://#{address.address}:#{address.port}/node_modules.js"
    server
  
  bind_server: ->
    @server.get "/node_modules", (req, res) =>
      res.send fs.readFileSync "./frameloader.html", "utf8"
      
    @server.get "/node_modules.js", (req, res) =>
      res.send @build_universe()
    
    @server.get "/node_modules/*", (req, res) =>
      res.send @cache["/"+req.params[0]]
  
  try_extensions: (path) ->
    if pathname.existsSync(path)
      return path 

    if extension = @extensions.detect((extension) -> 
      pathname.existsSync("#{path}.#{extension}"))
      return "#{path}.#{extension}"

  compilers:
    js: (path) -> fs.readFileSync path, 'utf8'
    coffee:(path) ->
        try
          content = CoffeeScript.compile fs.readFileSync path, 'utf8'
        catch err
          console.error "Error compiling #{path}."
          throw err

  compile: (path) ->
    mtime = fs.statSync(path).mtime.getTime()
    if @mtime_cache[path] is mtime
      return @compile_cache[path]
    else
      @mtime_cache[path] = mtime
  
      compiled = if path.match(/\.coffee$/)
        @compilers.coffee(path)
      else if path.match(/\.js$/)
        @compilers.js(path)
    
      return @compile_cache[path] = compiled 
  
  build_universe: ->
    # LOAD DEPENDENCY PACKAGES
    for module in @packages
      continue if module.match /^\s+$/
      try
        json = require "#{module}/package"
      catch err
        throw new Error "Error parsing package.json #{module}", err
      @mains[module] = @try_extensions pathname.normalize "./node_modules/#{module}/#{json.main}"
  
  
      paths = globSync "./node_modules/#{module}", "{lib,src}/**/*.{#{@extensions.join()}}"
      dirs = globSync "./node_modules/#{module}", "{lib,src}/**/*/"
  
      for dir in dirs
        @cache[dir.replace("./node_modules", "")] = link: dir.replace("./node_modules", "")
    
      @sources[module] = paths
    
    # COMPILE PACKAGE SOURCES
    for module, paths of @sources
      for path in paths
        if _(@ignores).detect((ignore) -> return path.indexOf(ignore) isnt -1)
          continue
      
        source_path = path
        source_path = "." + path[8..] if path.match(/^\/pasteup/)
        compiled = @compile(source_path)
        @cache[path.replace("./node_modules", "")] = compiled

    # COMPILE MAINS SOURCES
    for module, path of @mains
      @cache[module] = link: path.replace("node_modules", "")
      @cache[path.replace("node_modules", "")] = @compile(path)

    universe = """
      (function() {
        var modules = {}, 
            cache = {}, 
            process = {}, 
            ignores = new RegExp("#{@ignores.join('|')}");
    
        if (ignores.toString() === "/(?:)/") ignores = /^$/ 
  
        process.nextTick = function processNextTick (callback) {
          setTimeout(callback, 0);
        };

        function collapse_path (path) {
          return path.replace(/\\/([\\w]+\\/\\.\\.)/g, '');
        }
  
        function resolve_path (path, relative_to) {
          relative_to = relative_to || ""
          if (path[0] === "." && path[1] !== ".") {
            return collapse_path(relative_to + path.slice(1));
          }
          else {
            if (relative_to.length && relative_to[relative_to.length] !== "/") {
              return collapse_path(relative_to + "/" + path);
            }
            else {
              return collapse_path(relative_to + path);
            }
          }
        }
      
      window.require = function _require(path, relative_to, parent) {
        path = resolve_path(path.toLowerCase(), relative_to);
    
        if (path.match(ignores)) {
          console.warn("Ignoring request to require module at path: '"+path+"'.");
          return;      
        }

        if (cache[path]) {
          return cache[path].exports;
        }
    
        _module = modules[path] || modules[path+"/index"]
    
        if (typeof _module === "undefined") {
          console.error("No module found at path: '" + path + "'.");
          return;
        }
    
        if (_module.constructor !== Function) {
          return window.require(_module.link)
        }
      
        var module = {id: path, exports: {}, parent: parent || void 0};
        cache[path] = module;
        _module(module, process);
        return module.exports;
      }  
      
      require.modules = modules;
      require.cache = cache;
      require.ignores = ignores;
      window.process = process;
    
      modules['xmlhttprequest'] = function(module, process) {
        module.exports.XMLHttpRequest = window.XMLHttpRequest;
        return module.exports;
      }
    """
    
    if @env is "production"
      # PRODUCTION
      for path, object of @cache
        key = path.replace(/\.(coffee|json|js)$/, '')
        if _.isString object
          universe  += """
      
            modules["#{key}"] = function(module, process) {        
              function require (path) {
                if (path[0] === ".")
                  return window.require(path, "#{pathname.dirname(path)}", module);
                else
                  return window.require(path, void 0, module);
              }
        
              var __dirname = ".";
        
              (function(exports, require, module) {
                #{object}
              }(module.exports, require, module));
        
              return module.exports;
            }
      
          """
        else if object and object.link
          # console.error key, object
          universe += """  
          modules["#{key}"] = {link: "#{object.link.replace(/\.(coffee|json|js)$/, '')}"};
          """
        else 
          console.error "WTF IS object? #{path} #{object}"
    else if @env is "development"
      # DEVELOPMENT
  
      for path, object of @cache
        key = path.replace(/\.(coffee|json|js)$/, '')
        if _.isString object
          universe  += """
      
            modules["#{key}"] = function(module, process) {
              modules["#{key}"].module = module;
              modules["#{key}"].exports = module.exports;
              modules["#{key}"].require = function (path) {
                if (path[0] === ".")
                  return window.require(path, "#{pathname.dirname(key)}", module);
                else
                  return window.require(path, void 0, module);
              }
        
              var __dirname = ".";
              var href = window.location.href;

              var xhr = new XMLHttpRequest();
              xhr.open('GET', "/node_modules#{path}", false);
              xhr.send(null);
              var rawScript = xhr.responseText;
              script = document.createElement("script");
              script.type = "text/javascript";
              history.replaceState(null, null, "#{path}");
              
              window.module = module;
              window.exports = module.exports;
              
              var content = "";
              
              content += "(function (module, exports, require, __dirname) {";
              
              content += rawScript
              
              content += ";}(require.modules['#{key}'].module, require.modules['#{key}'].exports, require.modules['#{key}'].require, '.'));";
              
              script.innerHTML = content;
              document.head.appendChild(script);
              
              history.replaceState(null, null, href)
              
              delete window.module;
              delete window.exports;
              
              return module.exports;
            }
      
          """
        else if object and object.link
          # console.error key, object
          universe += """  
          modules["#{path}"] = {link: "#{object.link.replace(/\.(coffee|json|js)$/, '')}"};
          """
        else 
          console.error "WTF IS object? #{path} #{object}"
    
  
    universe += """
    }())            
                """

    return universe