The Shell
=========


The `shell` executes `scripts`. Scripts are mode of `pipelines`.
A pipeline is made of one or more `filters` connected by `pipes`.

A `filter` is a function that accepts a tripple 

  (in:Readable, out:Writeable, err:Writeable)

as its arguments. It manipulates these streams in a way it sees fit
and returns a Promise that is resolved once the filter is done with whatever
it is doing to the streams.


A `command` is a factory function that takes arbitrary paramters and returns
a new filter.




Filters read from one input stream and write to an output and an error stream.
By default, these streams are connected to the corresponding streams of the pipeline,
which in turn are connected to the corresponding streams of the script.
This default can be overridden by connecting the output/error streams of one filter
with the input of another one. It is fairly obvious that we try to imitate the classical
pipes & filters idiom, as it can be found in the unix shell and even in the windows command
interpreter cmd.exe.


In theory, all filters within a pipeline "execute" in parallel.
A pipeline `terminates` when the last filter within this pipeline terminates.
Filters, aswell as pipelines use Promise objects to model this aspect.
Thus, by chaining pipelines using the `then`-semantics of the Promise/A+ standard,
we can compose arbitrarily complex sequences, including
conditional branching and whatnot. It should be noted, though, that it was not the
intention of this humble programmer to create a general purpose programming model, but
simply to have something akin to classical shell scripts: A most simple
way to compose and configure more or less generic components (a.k.a. "filters") to do a specific job. 
This needs to work on Linux aswell as on Windows systems, and it just so happens that nodejs is already
invited to the party. So... say hello to ScriptScript.

