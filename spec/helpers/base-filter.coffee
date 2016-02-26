module.exports = class BaseFilter
  resolve=reject=promise=undefined
  streams={}
  constructor: (input,output,error)->
    streams.input=input
    streams.output=output
    streams.error=error
    promise = new Promise (resolve0, reject0)->
      resolve = resolve0
      reject = reject0
    

  error: (e)->
    streams.error.end(e.stack)
    streams.output.end()
    reject e
  end: (chunk) -> 
    streams.output.end(chunk)
    streams.error.end()
    resolve()
  data: (chunk)->
    streams.output.write chunk
  
  register: (events0)->
    events = events0 ? ["error","data","end"]
    for event in events
      streams.input.on event, this[event].bind this 
    streams.input.resume()
    promise
