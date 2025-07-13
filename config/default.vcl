vcl 4.0;

backend default {
    .host = "nginx";
    .port = "80";
}

sub vcl_recv {
    if (req.method == "PURGE") {
        if (client.ip != "127.0.0.1") {
            return (synth(405, "Not allowed."));
        }
        return (purge);
    }
    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }
}

sub vcl_backend_response {
    if (beresp.ttl <= 0s || beresp.http.Set-Cookie) {
        set beresp.uncacheable = true;
    } else {
        set beresp.ttl = 600s;
    }
}

sub vcl_deliver {
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    } else {
        set resp.http.X-Cache = "MISS";
    }
}
