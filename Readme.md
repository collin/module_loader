# ModuleLoader
### Another implementation of require for the browser.
#### Run. For your life.


###### It's pretty easy to set up a server

    ModuleLoader = require("./module_loader")
    new ModuleLoader 
        # env: "production"
        # server: require("express").createServer()
        packages: ["underscore", "underscore.string", "jquery", "jwerty", "socket.io-client", "share", "alpha_simprini"]

###### There are three options

* `env`: `production` or `development` (default is development)

* `server`: Uses the express server api. If you don't provide one one will be made for you at port 2334.
  
* `packages`: A list of npm package names. They will be looked up in ./node_modules

###### Ignore files you don't want!

* `./.stitchignore`

  Sort of like .gitiginore, but without any fancy matching. 
  SOME packages will have files that MUST be ignored in the browser.
  MOST packages will have files that SHOULD be ignored in the browser.
  
###### Load the modules 

* `<!DOCTYPE html>`
    
    <script type="text/javascript" src="//localhost:2334/node_modules.js"></script>

* `use it`

    underscore = require("underscore")


#### KNOWN ISSUES

* `jquery` - You can't do the equivalent of window.$ = require("jquery"); $ is overwritten as undefined before you can get to it.


# Changelog

#### 0.1.0

* Instition of changelog.