describe "The Shell", ->
  cmdStub = stdin = stdout = stderr = shell = undefined
  Shell = require "../src/shell"
  BaseFilter = require "./helpers/base-filter"
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
                output.end()
                error.end()
                resolve()
        read: (buf,copy)->
          (input,output,error)->
            f=new BaseFilter input,output,error
            f.data = (chunk)->
              output.write chunk if copy
              buf.push(chunk.toString())
            f.register()
        upperCase: ->
          (input,output,error)->
            f=new BaseFilter input,output,error
            f.data = (chunk)->
              output.write(chunk.toString().toUpperCase())
            f.register()
        count:->
            (input,output,error)->
              counter = 0
              f=new BaseFilter input,output,error
              f.data = (chunk)->
                counter += chunk.length
                BaseFilter.prototype.data.call this,chunk
              f.end = (chunk)->
                counter += chunk.length if chunk?
                error.write "Got #{counter} bytes"
                BaseFilter.prototype.end.call this,chunk
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
      cx.count().stderr().read(r)
    expect(p).to.be.fulfilled.then ->
      expect(r).to.eql  [
        "Got 36 bytes"
      ]

      expect(stdout.promise).to.eventually.eql """
                                               first chunk
                                               second chunkthird chunk
                                               """
