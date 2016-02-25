shell = require("scriptscript");

shell(function(cx) {

  var host,cluster,index; //TODO

  var esUrl = "http://"+host+"/"+index

  var lookupCsv = cx.file(geprisHome,"snapshots","lookup.csv.gz");
  var primaryCsv = cx.file(geprisHome,"snapshots","projekte.csv.gz");

  var lookupJson = cx.tempFile('lookup.json');

  var aggregator = cx.file(__dirname,'..','aggregator','target','aggregatpr0.0.1-SNAPSHOT.jar');

  var referentFilter = cx.file(__dirname,'filters','keine_referenten.js');
  var intranetFilter = cx.file(__dirname,'filters','from-intranet.js');

  var cache = cx.file(geprisHome,"cache","explore-raw-docs.txt");

  var buildLookup = function(cx) {
    return cx
      .bar(lookupCsv)
      .gunzip()
      .pipe("csv2json", "-k", "type", "-v", "entries", "-s")
      .write(lookupJson);
  };
  var aggregate = function(cx) {
    return cx
      .pipe("java", "-Xmx4069", "-XX:-UseGCOverheadLimit", "-jar", aggregator,
        "-e", host, "-c", cluster, "-i", index)
      .tee(cx.tempFile('log.log'))
      .grep('Skipping', {
        invert: true
      });
  };

  var csv2json = function(cx) {
    return cx
      .bar(primary)
      .gunzip()
      .pipe('csv2json', '-L', lookupJson, '-F', referentFilter, '-F', intranetFilter)
      .tee(cache);
  };

  var resetIndex = function(cx){
    var url = "http://"+host+":9200/"+index;
    return cx
      .curl('DELETE',url)
      .then(function(cx){
        return cx.curl("PUT",url);
      })
      .then(function(cx){
        cx.read(__dirname,'clique-mapping.json').curl('PUT',url+"/clique/_mapping");
        cx.read(__dirname,'vertex-mapping.json').curl('PUT',url+"/vertex/_mapping");
        return cx.join();
      });
  };

  cx.pipe(buildLookup).then(function(cx) {
    if (cache.olderThan(primary)) {
      console.error("fyi: storing raw docs in " + cache + " for later use");
      return cx
        .pipe(csv2json)
        .pipe(aggregate);
    } else {
      console.error("using cached raw docs from " + cache);
      return cx
        .bar(cache)
        .pipe(aggregate);
    }
  });
});
