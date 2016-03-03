describe "The '.spawn()'-Command", ->
  Promise = require "promise"
  os = require "os"
  spawn = require "../src/spawn"
  node = process.execPath
  stdout = stdin = stderr = undefined

  beforeEach ->
    stdin = Source [
      "foo\n"
      "bar\n"
      "baz\n"
    ]
    stdout = Sink objectMode:false
    stderr = Sink objectMode:false

  runFilter = (f)->
    pf = f stdin, stdout, stderr
    Promise.all [pf,stdout.promise, stderr.promise]

  it "spawns a child process and wires it up", ->
    f = spawn node,
      '-e',
      """
      process.stdout.write("copying from stdin\\n");
      process.stdin.pipe(process.stdout);
      process.stderr.write("hello stderr\\n");
      """
    expect(runFilter f).to.be.fulfilled.then (oc)->
      [exitCode,out,err] = oc
      expect(exitCode).to.equal 0
      expect(out.toString()).to.eql """
                         copying from stdin
                         foo
                         bar
                         baz

                         """
      expect(err.toString()).to.eql "hello stderr\n"

  it "support alternative syntax for passing additional options", ->

    f = spawn
      commandLine:[
        node
        '-e'
        """
        process.stdout.write("copying from stdin\\n");
        process.stdin.pipe(process.stdout);
        process.stderr.write("hello stderr\\n");
        """
      ]
    expect(runFilter f).to.be.fulfilled.then (oc)->
      [exitCode,out,err] = oc
      expect(exitCode).to.equal 0
      expect(out.toString()).to.eql """
                         copying from stdin
                         foo
                         bar
                         baz

                         """
      expect(err.toString()).to.eql "hello stderr\n"
  it "rejects the returned promise if the child process exits with a nonzero exit code", ->
    f = spawn node, "-e", "process.exit(42);"
    expect(runFilter f).to.be.rejected.then (err)->
      expect(err).instanceOf Error
      expect(err.exitCode).to.equal 42

  it "can be configured to handle exit codes differently", ->
    f = spawn
      handleExitCode: (code)->
        foo: 2+code/2
        bar: 'baz'
      commandLine:[
        node
        "-e"
        "process.exit(42);"
      ]
    expect(runFilter f).to.be.fulfilled.then ([exitCode,out,err])->
      expect(exitCode).to.eql
        foo:23
        bar:'baz'
  it "can be configured to run the child process with a different environment", ->
    env=
      foo:"23"
      bar:'baz'
    f = spawn
      env:env
      commandLine:[
        node
        "-e"
        "process.stdout.write(JSON.stringify(process.env));"
      ]
    expect(runFilter f).to.be.fulfilled.then ([exitCode,out,err])->
      expect(JSON.parse(out.toString())).to.eql env
  it "can be configured to run the child process in another working directory", ->
    f = spawn
      cwd: os.tmpdir()
      commandLine:[
        node
        "-e"
        "process.stdout.write(process.cwd());"
      ]
    expect(runFilter f).to.be.fulfilled.then ([exitCode,out,err])->
      expect(out.toString()).to.eql os.tmpdir()
