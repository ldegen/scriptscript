module.exports = (opts0 )->
  stream = (require "stream")
  merge = (require "deepmerge")
  Promise = (require "promise")

  opts=
    streams:
      in:opts0?.streams?.in ? process.stdin
      out:opts0?.streams?.out ? process.stdout
      err:opts0?.streams?.err ? process.stderr
    commands:opts0.commands

  commands={}
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
      nextStreams =
        in: output
        out: cx0.streams.out
        err: cx0.streams.err
      makeContext nextStreams, p

  for name,factory of opts.commands
    commands[name] = (buildCommand name,factory)

  makeContext = (streams, p)->
    cx = Object.create commands
    cx.streams=streams
    (cx.then = p.then.bind p) if p?
    cx

  tearDown = (outcome)->
    console.log "teardown called"
    outcome
  handleError = (e)->
    console.log "errorHandler called"
    console.error(e.stack)
    throw e
  
  (body)->
    Promise
      .resolve opts
      .then (opts) -> makeContext opts.streams
      .then body
      .then tearDown,handleError
