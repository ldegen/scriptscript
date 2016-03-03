module.exports = (path,opts)->
  fs = require "fs" 
  Promise = require "promise"
  options = {}
  options.flags="a" if opts?.append
  (stdin,stdout,stderr)->
    new Promise (resolve,reject)->
      stderr.end()
      stdin.on "end", ->
        stdout.end()
      stdin.on "error", (e)->
        stdout.end()
        reject e
      stream = fs.createWriteStream path, options
      stream.on "finish", ->
        resolve()
      stream.on "error", (e)->
        stdout.end()
        reject e
      if opts?.copy
        stdin.pipe stdout
      else
        stdout.end()
      stdin.pipe stream
      stdin.resume()
