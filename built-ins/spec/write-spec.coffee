
describe "The '.write()'-Command", ->
  Promise = require "promise"
  os = require "os"
  fs = require "fs"
  write = require "../src/write"
  node = process.execPath
  tmpfile = undefined
  stdout = stdin = stderr = undefined
  readFile = Promise.denodeify fs.readFile 
  writeFile = Promise.denodeify fs.writeFile 
  beforeEach ->
    stdin = Source [
      "foo\n"
      "bar\n"
      "baz\n"
    ]
    stdout = Sink objectMode:false
    stderr = Sink objectMode:false
    tmpfile = tmpFileName(@test)

  #afterEach ->
    #fs.access tmpfile, fs.W_OK, (err)->
      #fs.unlink tmpfile if not err

  runFilter = (f)->
    pf = f stdin, stdout, stderr
    Promise.all [pf,stdout.promise, stderr.promise]

  it "is typically used to write content to a file", ->
    expect(runFilter write tmpfile).to.be.fulfilled.then ([outcome,out,err])->
      expect(out).to.be.empty
      expect(err).to.be.empty
      expect((readFile tmpfile).then (buf)->buf.toString()).to.eventually.eql "foo\nbar\nbaz\n"
  it "copies data to stdout if asked to", ->
    expect(runFilter write tmpfile, copy:true).to.be.fulfilled.then ([outcome,out,err])->
      expect(out.toString()).to.eql "foo\nbar\nbaz\n"
      expect(err).to.be.empty
      expect((readFile tmpfile).then (buf)->buf.toString()).to.eventually.eql "foo\nbar\nbaz\n"
  it "can be configured to append data instead of overwriting the content", ->
    p = writeFile(tmpfile, "first line\n")
      .then -> runFilter write tmpfile, append:true
    expect(p).to.be.fulfilled.then ([outcome,out,err])->
      expect(out).to.be.empty
      expect(err).to.be.empty
      expect((readFile tmpfile).then (buf)->buf.toString()).to.eventually.eql "first line\nfoo\nbar\nbaz\n"
