pathname = require("path")
ModuleLoader = require("../lib/module_loader")
new ModuleLoader 
  # env: "production"
  module_root: pathname.resolve("./node_modules")
  packages: ["underscore", "underscore.string"]
