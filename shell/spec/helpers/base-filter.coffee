module.exports = class BaseFilter
  Promise = require "promise"
  constructor: (input,output,error,@name)->
    @resolve=@reject=@promise=undefined
    @streams=
      input:input
      output:output
      error:error
    self=this
    @promise = new Promise (resolve0, reject0)->
      self.resolve = resolve0
      self.reject = reject0
      self.resolve.__name__=self.name

    

  error: (e)->
    @streams.error.end(e.stack)
    @streams.output.end()
    @reject e
  end: (chunk) -> 
    if chunk?
      @data chunk
    @streams.output.end()
    @streams.error.end()
    @resolve()
  data: (chunk)->
    @streams.output.write chunk
  
  register: (events0)->
    self=this
    @streams.output.on "error", (e)->
      self.reject e
    @streams.error.on "error", (e)->
      self.reject e
    events = events0 ? ["error","data","end"]
    for event in events
      @streams.input.on event, this[event].bind this 
    @streams.input.resume()
    @promise
