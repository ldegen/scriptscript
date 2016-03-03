module.exports = (path)->
  fs = require "fs"
  Promise = require "promise"

  (stdin,stdout,stderr)->
    new Promise (resolve,reject)->
      stderr.end()
      stream = fs.createReadStream path
      stream.on "end", ->
        resolve()
      stream.on "error", (e)->
        reject e
      stream.pipe stdout
      stream.resume()
