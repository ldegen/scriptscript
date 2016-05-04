describe "The command line interface",->
  cli = require "../src/cli"
  tmp = require "tmp"
  fs = require "fs"
  tmpObj = scriptFile = undefined
  beforeEach ->
    tmpObj = tmp.fileSync()
    scriptFile = tmpObj.name

  afterEach ->
    tmpObj.removeCallback()

  it "creates a shell and executes the script given as argument", ->
    fs.writeFileSync scriptFile, """
                                 module.exports = function(cx){
                                  return 42;
                                 };
                                 """
    p=cli 
      argv:[null,null,scriptFile]
    expect(p).to.eventually.eql 42
