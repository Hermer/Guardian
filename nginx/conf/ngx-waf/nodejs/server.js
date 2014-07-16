var http = require("http");
var jsp = require("uglify-js").parser;
var pro = require("uglify-js").uglify;
var CleanCSS = require("clean-css");
var cssMinify = new CleanCSS();

function onRequest(request, response) {
  var postData = "";
  request.setEncoding("utf-8");
  request.addListener("data", function(postDataChunk) {
      postData += postDataChunk;
  });

  request.addListener("end", function() {
      var orig_code = postData;
      var jsonData = JSON.parse(orig_code);
      var final_code = "";
      if(jsonData.option == "compressjs"){ 
      	var ast = jsp.parse(jsonData.body);
      	ast = pro.ast_mangle(ast);
      	ast = pro.ast_squeeze(ast);
      	final_code = pro.gen_code(ast);
      }else if(jsonData.option == "compresscss"){
	final_code = cssMinify.minify(jsonData.body); 
      }
      response.writeHead(200, {"Content-Type": "text/plain;charset=utf-8"});
      response.write(final_code);
      response.end();
  });
}

http.createServer(onRequest).listen(8888,"127.0.0.1");

console.log("Server has started.");
