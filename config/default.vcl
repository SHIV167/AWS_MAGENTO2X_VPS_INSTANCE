vcl 4.0;

backend default {
    .host = "127.0.0.1";
    .port = "8080";
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
    # cache redirects for 60s
    if (beresp.status == 301 || beresp.status == 302) {
        unset beresp.http.Set-Cookie;
        set beresp.uncacheable = false;
        set beresp.ttl         = 60s;
        return (deliver);
    }
    # remove PHPSESSID so redirects/pages can be cached
    if (beresp.http.Set-Cookie ~ "PHPSESSID") {
        unset beresp.http.Set-Cookie;
    }
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
