## ModuleLoader
Another implementation of require for the browser.
# Run. For your life.


#### It's pretty easy to set up a server
    
    pathname = require("path")
    ModuleLoader = require("./module_loader")
    new ModuleLoader 
        # env: "production"
        # server: require("express").createServer()
        module_root: pathname.resolve("./node_modules")
        packages: ["underscore", "underscore.string", "jquery", "jwerty", "socket.io-client", "share", "alpha_simprini"]

#### There are options

* `module_root`: (REQUIRED) A fully resolved path which is the node_modules directory to load code from.

* `packages`: (REQUIRED) A list of npm package names. They will be looked up in ./node_modules

* `ignorepath`: (RECCOMENDED) A path to a .stitchignore file, with patterns of files to ignore when packing and requiring.

* `env`: `production` or `development` (default is development)

* `server`: Uses the express server api. If you don't provide one one will be made for you at port 2334.

#### Ignore files you don't want!

* `ignorepath: ./.moduleignore`

  Sort of like .gitiginore, but without any fancy matching. 
  SOME packages will have files that MUST be ignored in the browser.
  MOST packages will have files that SHOULD be ignored in the browser.
  
#### Using it 

Load the  node_modules.js script:

    <script type="text/javascript" src="//localhost:2334/node_modules.js"></script>

And require your modules:

    _ = require("underscore")

#### KNOWN ISSUES

* `jquery` - You can't do the equivalent of window.$ = require("jquery"); $ is overwritten as undefined before you can get to it.

# Changelog

#### 0.2.0

* added module_root option. This allows the loader to see the node_modules you want it to, otherwise it was just loading from the node_modules of module_loader, which wasn't what you wanted it to do at all.
* documented and reccomending 
* added CORS for development mode script loading

#### 0.1.1

* added an overview of loaded packages at /node_modules
* turned off /node_modules in production mode
* fixed example servemodules.coffee

#### 0.1.0

* Instition of changelog.