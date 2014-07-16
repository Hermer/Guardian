backend default {
  .host = "127.0.0.1";
  .port = "8080";
  .connect_timeout = 5s;
  .first_byte_timeout = 5s;
  .between_bytes_timeout = 20s;
}

sub vcl_recv {

  set req.backend = default;

  if (req.backend.healthy) {
    set req.grace = 5s;
  } else {
    set req.grace = 5m;
  }


  if (req.restarts == 0) {
		if (req.http.x-forwarded-for) {
			set req.http.X-Forwarded-For =
			req.http.X-Forwarded-For + ", " + client.ip;
		} else {
			set req.http.X-Forwarded-For = client.ip;
		}
  }
	
  remove req.http.X-real-ip; 
  set req.http.X-real-ip = client.ip;

  if (req.request != "GET" &&
    req.request != "HEAD" &&
    req.request != "PUT" &&
    req.request != "POST" &&
    req.request != "TRACE" &&
    req.request != "OPTIONS" &&
    req.request != "DELETE") {
    /* Non-RFC2616 or CONNECT which is weird. */
    return (pipe);
  }

  if (req.request != "GET" && req.request != "HEAD") {
    /* We only deal with GET and HEAD by default */
    return (pass);
  }


#     if (req.http.Authorization || req.http.Cookie) {
#         /* Not cacheable by default */
#         return (pass);
#     }

  if(req.request == "GET" && req.url ~ "\.(js|css|png|jpg|gif|swf|jsp|htm|html|jpeg|ico)$"){
    return (lookup);
  }

  return (pass);
 
}
 
sub vcl_pipe {
  return (pipe);
}
 
sub vcl_pass {
  return (pass);
}
 
sub vcl_hash {
  hash_data(req.url);

  if (req.http.host) {
    hash_data(req.http.host);
  } else {
    hash_data(server.ip);
  }

  return (hash);

}
 
sub vcl_hit {
  
  if (req.http.Pragma ~ "no-cache" ) {
    set obj.ttl = 0s ;
    return (pass); 
  }

  return (deliver);
 
}
 
sub vcl_miss {
  return (fetch);
}
 
sub vcl_fetch {
  if (req.request == "GET" &&
        req.url ~ "\.(js|css|png|jpg|gif|swf|htm|html|jpeg|ico)$") {
	  unset beresp.http.set-cookie;
 	  set beresp.ttl = 1d;
  }else{
	  return (hit_for_pass);
  }

  return (deliver);

 }
 
sub vcl_deliver {

	set resp.http.Cache-Control = "max-age=60";
	
	if (obj.hits > 0) {
    set resp.http.X-Cache = "HIT";
    #统计命中了多少次
    set resp.http.X-Cache-Hits = obj.hits;
  } else {
    set resp.http.X-Cache = "MISS";
 	}

  return (deliver);

}
 
sub vcl_init {
  return (ok);
}
 
sub vcl_fini {
  return (ok);
}

 sub vcl_error {
     set obj.http.Content-Type = "text/html; charset=utf-8";
     set obj.http.Retry-After = "5";
     synthetic {"
 <?xml version="1.0" encoding="utf-8"?>
 <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
 <html>
   <head>
     <title>"} + obj.status + " " + obj.response + {"</title>
   </head>
   <body>
     <h1>Error "} + obj.status + " " + obj.response + {"</h1>
     <p>"} + obj.response + {"</p>
     <h3>Guru Meditation:</h3>
     <p>XID: "} + req.xid + {"</p>
     <hr>
     <p>Varnish cache server</p>
   </body>
 </html>
 "};
     return (deliver);
 }