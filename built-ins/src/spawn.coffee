module.exports = ->
  class NonZeroExitCodeError extends Error
    constructor: (@exitCode)->
      super "Non-zero exit code: #{@exitCode}"

  class SignalReceivedError extends Error
    constructor: (@signal)->
      super "child process received #{@signal}"

  Promise = require "promise"
  spawn = require("child_process").spawn
  opts0 = arguments[0]
  if typeof arguments[0] != "object"
    opts0 =
      commandLine:Array.prototype.slice.call arguments

  args = Array.prototype.slice.call opts0.commandLine
  handleExitCode = opts0.handleExitCode ? (code)->
    if code != 0
      throw new NonZeroExitCodeError code
    code
  executable = args.shift()
  opts = {}
  opts.env = opts0.env if opts0.env?
  opts.cwd = opts0.cwd if opts0.cwd?
  (stdin,stdout,stderr)->
    new Promise (resolve,reject)->
      cp = spawn executable,args,opts
      cp.stdout.pipe stdout
      cp.stderr.pipe stderr
      stdin.pipe cp.stdin
      cp.on "error", (e)->
        stderr.end()
        stdout.end()
        reject e
      cp.on "exit", (code,signal)->
        if typeof signal == "string"
          reject new SignalReceivedError signal
        else
          resolve code
    .then handleExitCode
