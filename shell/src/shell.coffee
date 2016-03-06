module.exports = (opts0 )->
  stream = (require "stream")
  Promise = (require "promise")

  
  # This is used to keep the shells output and error
  # from beeing ended before the *whole* script is done.
  wrapWriteable = (w)->
    p = new stream.PassThrough
    p.endFoReals = p.end
    p.end = (chunk)->
      if chunk?
        p.write(chunk)
    p.pipe w
    p.resume()
    p

  opts=
    streams:
      in:opts0?.streams?.in ? process.stdin
      out:wrapWriteable (opts0?.streams?.out ? process.stdout)
      err:wrapWriteable (opts0?.streams?.err ? process.stderr)
    commands:opts0.commands

  commands={}
  
  # The commands-Property in the options contains a hash with all
  # filter factories. These factories need to be lifted to become 
  # "commands", i.e. functions that create and apply filters but return
  # new context objects which in turn can then be used to chain together commands
  # into pipelines, or create sequences of pipelines by using the fact that each context
  # has a Promise/A+ -conformant 'then' method... yielding yet a new context.
  buildCommand = (name,factory)->
    ->
      cx0 = this
      filter = factory.apply null,arguments
      # By default, the input is patched through to the output to
      # gracefully handle the "ends" of a pipeline.
      # Thinking in this metaphor, we are not just appending a filter, but
      # we are actually *inserting* one. So we need to disconnect the input
      # from the output first.
      input = cx0.streams.in
      input.unpipe(cx0.streams.out)
      

      # Next, we create a new piece of pipe which we connect to the output (see
      # above).
      output = new stream.PassThrough
      output.pipe cx0.streams.out

      # We do the same for the error stream
      error = new stream.PassThrough
      error.pipe cx0.streams.err

      p = Promise.resolve filter input, output, error
       
      nextCxOpts =
        streams:
          in: output
          out: cx0.streams.out
          err: cx0.streams.err
          prevErr: error
        script:cx0.script # same script is original context
        pipeline:cx0.pipeline # same pipeline aswell
      makeContext nextCxOpts, p

  for name,factory of opts.commands
    commands[name] = (buildCommand name,factory)

  makeContext = (cxOpts, p0)->
    cx = Object.create commands
    cx.streams=cxOpts.streams
    cx.script = cxOpts.script
    cx.pipeline = cxOpts.pipeline
    if p0?
      cxOpts.script.promises.push(p0)
      cxOpts.pipeline.promises.push(p0)
      # add  a function to wait for the outcome of the previous filter (if there is any)
      # The promise is resolved with a new context that is *not connected* to the current one.
      # This new context will carry a property 'outcome' with the resolution of the promise returned by the
      # previous filter.
      cx.then = (resolveBody,rejectBody) ->
        p = p0
          .then (previousOutcome)->
            nextOpts =
              streams: opts.streams  # new context always starts with the streams of the shell
              script: cxOpts.script  # it belongs to the same script instance as the original context
              pipeline: promises: [] # but it starts with a fresh pipeline
            cxNext = makeContext nextOpts
            cxNext.outcome=previousOutcome
            cxNext
          .then(resolveBody,rejectBody)
        cx.script.promises.push p
        p


    # add a function that creates a promise by collecting all promises from the current pipeline.
    # Defer collection until the next tick so that we really cover all filters created synchronously
    # within this pipeline
    cx.allFinished = ->
      then: (resolveBody,rejectBody)->
        p = new Promise (resolve,reject)->
            process.nextTick resolve
          .then -> #careful! we cannot simply call Promise.all synchonously, remember?
            Promise.all cxOpts.pipeline.promises
          .then (outcomes)->
            nextOpts =
              streams: opts.streams  # new context always starts with the streams of the shell
              script: cxOpts.script  # same script as original context
              pipeline: promises: [] # but new pipeline
            cxNext = makeContext nextOpts
            cxNext.outcome  = outcomes
            cxNext
          .then(resolveBody,rejectBody)
        cx.script.promises.push p
        p


    

    # add syntactic sugar for passing the context to a javascript function
    cx.call= (f)->f(cx)


    # add a method to attach filters to the error stream of the
    # previous filter. But only do this, if there *is* a
    # previous filter to begin with. 
    if cxOpts.streams.prevErr?
      cx.stderr = ()->
        # previous output is current input.
        # By default it is patched through to current output, 
        # nothing to do about that.
        # But we need to disconnect previous error from current error
        # and instead also pipe it into current output.
        cxOpts.streams.prevErr.unpipe cxOpts.streams.err
        cxOpts.streams.prevErr.pipe cxOpts.streams.out
        
        # Now we can create a context with a modified stream triple
        # that uses the previous error as input.
        cxErrOpts=
          streams :
            in:cxOpts.streams.prevErr
            out:cxOpts.streams.out
            err:cxOpts.streams.err
          script: cxOpts.script     # same script
          pipeline: cxOpts.pipeline # and same pipeline
        makeContext cxErrOpts, p0
    cx

  tearDown = (outcome)->
    #console.log "teardown called"
    opts.streams.out.endFoReals()
    opts.streams.err.endFoReals()
    outcome
  handleError = (e)->
    #console.log "errorHandler called"
    console.error(e.stack)
    opts.streams.out.endFoReals()
    opts.streams.err.endFoReals()
    throw e
  
  (body)->
    script =
      promises:[]
    Promise
      .resolve opts
      .then (opts) -> 
        makeContext 
          streams:opts.streams
          script: script
          pipeline: promises: []

      .then body
      .then (outcome)->
        Promise
          .all script.promises
          .then ->
            outcome
      .then tearDown,handleError
