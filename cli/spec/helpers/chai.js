var chai = require('chai');
var asPromised = require('chai-as-promised');
var Writable = require("stream").Writable;
var Readable = require("stream").Readable;
var Promise = require("promise");


chai.config.includeStack = true;
chai.use(asPromised);

global.sinon = require("sinon");
chai.use(require('sinon-chai'));


global.expect = chai.expect;
global.AssertionError = chai.AssertionError;
global.Assertion = chai.Assertion;
global.assert = chai.assert;

global.Source = function(chunks, opts0) {
  var opts = opts0 || {
    objectMode: true
  };
  var input = new Readable(opts);
  chunks.forEach(function(chunk) {
    input.push(chunk);
  });
  input.push(null);
  return input;
};
global.tmpFileName = function(test) {
  var sha1 = require("crypto").createHash("sha1");
  sha1.update(new Buffer([process.pid]));
  sha1.update(test.fullTitle());
  return require("path").join(
    require("os").tmpdir(), 
    sha1.digest().toString("hex")
  );
};

global.Sink = function(opts0) {
  var opts = opts0 || {
    objectMode: true
  };
  var buf = opts.objectMode ? [] : new Buffer([]);
  var output = new Writable(opts);
  output._write = function(chunk, enc, next) {
    if (chunk) {
      if (opts.objectMode) {
        buf.push(chunk);
      } else {
        buf = Buffer.concat([buf, chunk]);
      }
    }
    next();
  };
  output.promise = new Promise(function(resolve, reject) {
    output.on("error", function(e) {
      console.log("sink error", e.stack);
      reject(e);
    });
    /*
     *output.on("end", function() {
     *  console.log("sink end");
     *});
     */
    output.on("finish", function() {
      resolve(buf);
    });
  });
  return output;
};
