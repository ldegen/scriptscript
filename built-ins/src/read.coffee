module.exports = (path,opts0)->
  fs = require "fs"
  sprintf = require( "sprintf-js").sprintf
  Promise = require "promise"
  stat = Promise.denodeify fs.stat

  opts = {}
  opts.highWaterMark = opts0.highWaterMark if opts0?.highWaterMark?
  
  renderProgress = (current,total)->
    totalWidth = opts0?.progressBar?.lineWidth ? process.stderr?.columns ? 25
    barWidth = totalWidth - 9 # thats two brackets, one extra space the 
                              # formatted percentage and the percent sign
    p = if total then 100*current/total else 0
    doneWidth =Math.ceil( p*barWidth/100)
    b = new Array( 1 +doneWidth ).join '#'
    sprintf "\r[%'--#{barWidth}s] %5.1f%%", b,p
    

  (stdin,stdout,stderr)->
    stat(path).then (stats)->
      new Promise (resolve,reject)->
        
        stream = fs.createReadStream path,opts
        stream.on "end", ->
          resolve()
        stream.on "error", (e)->
          reject e
        if opts0?.progressBar?
          total = stats.size
          done = 0
          stderr.write renderProgress done,total
          stream.on "data", (chunk)->
            done += chunk.length
            stderr.write renderProgress done,total
          stream.on "end", (chunk)->
            if chunk?
              done += chunk.length
              stderr.write renderProgress done,total
            stderr.write '\n'
            stderr.end()
        else
          stderr.end()
        stream.pipe stdout
        stream.resume()
