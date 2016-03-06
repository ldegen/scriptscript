describe "The Shell", ->
  cmdStub = stdin = stdout = stderr = shell = undefined
  Shell = require "../src/shell"
  BaseFilter = require "./helpers/base-filter"
  Promise = require "promise"
  beforeEach ->
    stdin=Source [
      "first chunk\n"
      "second chunk"
      "third chunk\n"
    ], objectMode:false
    stdout = Sink objectMode:false
    stderr = Sink objectMode:false
    shell = Shell
      streams:
        in:stdin
        out:stdout
        err:stderr
      commands:
        write: (chunks)->
          (input,output,error)->
            new Promise (resolve, reject)->
              process.nextTick ->
                (output.write chunk) for chunk in chunks
                #console.log "written",chunks
                output.end()
                error.end()
                resolve()
        read: (buf,copy)->
          (input,output,error)->
            f=new BaseFilter input,output,error,"read"
            f.data = (chunk)->
              output.write chunk if copy
              buf.push(chunk.toString())
            f.register()
        upperCase: ->
          (input,output,error)->
            f=new BaseFilter input,output,error ,"upperCase"
            f.data = (chunk)->
              output.write(chunk.toString().toUpperCase())
            f.register()
        count: (copy)->
            (input,output,error)->
              counter = 0
              f=new BaseFilter input,output,error,"count"
              f.data = (chunk)->
                counter += chunk.length
                if copy
                  BaseFilter.prototype.data.call this,chunk
              f.end = (chunk)->
                if(chunk?)
                  @data chunk
                error.write "Got #{counter} bytes"
                error.end()
                output.end()
                @resolve counter
              f.register()



  it "allows connecting the output of one filter with the input of another", ->
    r=[]
    p=shell (cx)->
      cx
        .write(["foo","bar","baz"])
        .upperCase()
        .read(r,true)
    expect(p).to.be.fulfilled.then ->
      expect(stdout.promise).to.eventually.eql("FOOBARBAZ")
      expect(r).to.eql ["FOO","BAR","BAZ"]
  it "connects the first filter of a pipeline to the script's input", ->
    r=[]
    p = shell (cx)->cx.read(r)
    expect(p).to.be.fulfilled.then ->
      expect(r).to.eql  [
        "first chunk\n"
        "second chunk"
        "third chunk\n"
      ]

  it "allows connecting the error of one filter with the input of another", ->
    r=[]
    p = shell (cx)->
      cx.count(true).stderr().read(r)
    expect(p).to.be.fulfilled.then ->
      expect(r).to.eql  [
        "Got 36 bytes"
      ]

      expect(stdout.promise).to.eventually.eql """
                                               first chunk
                                               second chunkthird chunk
                                               """
  it "allows waiting for the termination of an individual filter, examine its outcome and start a new pipeline", ->
    p = shell (cx) ->
      cx
        .count(true)
        .then (cx)->
          cx.write ["The outcome was #{cx.outcome}"]
    expect(p).to.be.fulfilled.then ->
      expect(stdout.promise).to.eventually.eql """
                                               first chunk
                                               second chunkthird chunk
                                               The outcome was 36
                                               """

  it "allows waiting for the whole pipeline to finish, examine the outcomes of all filters and start a new pipeline", ->
    p = shell (cx)->
      cx
        .write(["foo","bar"])
        .upperCase()
        .count()
        .allFinished().then (cx)->
          outcomes = cx.outcome.map (o)->
            if not o? then "(nil)" else o.toString()
          cx.write ["got #{outcomes.join ', '}"]
            .then ->
      cx
        .count()
    expect(p).to.be.fulfilled.then ->
      expect(stdout.promise).to.eventually.eql """
                                               got (nil), (nil), 6, 36
                                               """


  it "has some syntactic sugar for composing a script from sub-scripts", ->
    r = []
    p = shell (cx) ->
      partA = (cx)->
        cx.count(true).upperCase()
      partB = (cx)->
        cx.read(r)

      cx
        .write([
          "one"
          "two"
          "three"
        ])
        .call(partA)
        .call(partB)
    expect(p).to.be.fulfilled.then ->
      expect(r).to.eql [
        "ONE"
        "TWO"
        "THREE"
      ]

