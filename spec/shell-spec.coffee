describe "The Shell", ->
  cmdStub = stdin = stdout = stderr = shell = undefined
  Shell = require "../src/shell"
  
  beforeEach ->
    stdin=Source [
      "first chunk\n"
      "second chunk"
      "third chunk\n"
    ], objectMode:false
    stdout = Sink objectMode:false
    stderr = Sink objectMode:false
    cmdStub = sinon.stub()
    shell = Shell
      streams:
        in:stdin
        out:stdout
        err:stderr
      commands:
        cmd: -> cmdStub
        write: (chunks)->
          (input,output,error)->
            new Promise (resolve, reject)->
              process.nextTick ->
                console.log "write",chunks
                (output.write chunk) for chunk in chunks
                output.end()
                error.end()
                console.log("write end")
                resolve()
        read: (buf,copy)->
          (input,output,error)->
            console.log "read"
            new Promise (resolve,reject)->
              input.on "error", (e)-> 
                error.end(e.stack)
                output.end()
                reject e
              input.on "end", -> 
                output.end()
                error.end()
                console.log("read end")
                resolve()
              input.on "data", (chunk)->
                console.log "read data",chunk
                output.write chunk if copy
                buf.push(chunk.toString())
              input.resume()
        upperCase: ->
          (input,output,error)->
            console.log "upper case"
            new Promise (resolve,reject)->
              input.on "error", (e)-> 
                error.end(e.stack)
                output.end()
                reject e
              input.on "end", -> 
                error.end()
                output.end()
                console.log("uppercase end")
                resolve()
              input.on "data", (chunk)->
                console.log "uppercase data", chunk
                output.write(chunk.toString().toUpperCase())
              input.resume()


  describe "general interace", ->
    xit "provides access to registered commands", ->
      cmdStub.returns(42)
      p=shell (cx)->
        cx.cmd()
      expect(p).to.be.fulfilled.then (outcome)->
        expect(cmdStub).calledWith(stdin,stdout,stderr)
        expect(outcome).to.eql 42

    xit "handles filters that return promises", ->
      cmdStub.returns Promise.resolve 42
      p=shell (cx)->
        cx.cmd()
      expect(p).to.be.fulfilled.then (outcome)->
        expect(cmdStub).calledWith(stdin,stdout,stderr)
        expect(outcome).to.eql 42

    it "it allows connecting the output of one filter with the input of another", ->
      r=[]
      p=shell (cx)->
        cx
          .write(["foo","bar","baz"])
          .upperCase()
          .read(r,true)
      expect(p).to.be.fulfilled.then ->
        console.log "r",r
        expect(stdout.promise).to.eventually.eql("FOOBARBAZ")
        expect(r).to.eql ["FOO","BAR","BAZ"]
