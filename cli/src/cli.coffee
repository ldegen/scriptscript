module.exports = (process)->
  parseArgs = require "minimist"
  path = require "path"
  argv = parseArgs process.argv.slice 2
  Shell = require "scriptscript-shell"
  builtins = require "scriptscript-builtins"
  shell = Shell
    commands: builtins
  scriptFile = path.resolve argv._[0]
  shell( require scriptFile)
  .then (outcome)->
    # this may not be the "real" process object...
    process.exit(outcome) if typeof process.exit == "function"

    outcome
