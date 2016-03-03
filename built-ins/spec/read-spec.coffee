
describe "The '.read()'-Command", ->
  Promise = require "promise"
  os = require "os"
  fs = require "fs"
  read = require "../src/read"
  node = process.execPath
  tmpfile = undefined
  stdout = stdin = stderr = undefined
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
    writeFile tmpfile, "The content of the file\n"

  afterEach ->
    fs.access tmpfile, fs.W_OK, (err)->
      fs.unlink tmpfile if not err

  runFilter = (f)->
    pf = f stdin, stdout, stderr
    Promise.all [pf,stdout.promise, stderr.promise]

  it "is typically used to read the content of a file", ->
    f = read tmpfile
    expect(runFilter f).to.be.fulfilled.then ([outcome,out,err])->
      expect(out.toString()).to.equal "The content of the file\n"
  it "rejects the returned promise if the file does not exist", ->
    expect(runFilter read "/i/do/not/exist.txt").to.be.rejected.then (err)->
      expect(err).instanceOf Error
  it "can output a nice progress bar on stderr", ->
    p=runFilter read tmpfile,
      highWaterMark:6
      progressBar:
        lineWidth: 25
    expect(p).to.be.fulfilled.then ([outcome,out,err])->
      expect(out.toString()).to.equal "The content of the file\n"
      expect(err.toString().split('\r').join('\n')).to.equal(
        """

        [----------------]   0.0%
        [####------------]  25.0%
        [########--------]  50.0%
        [############----]  75.0%
        [################] 100.0%

        """
      )
