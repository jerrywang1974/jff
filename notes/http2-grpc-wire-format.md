# HTTP/2 and GRPC wire format

## HTTP/2

1. HTTP/2 connection preface from client:

```
PRI * HTTP/2.0 \r\n\r\n
SM\r\n\r\n
```

2. frame: 9-octet frame header + frame payload
```
length      24 bits     // length of payload, not include frame header
type        8 bits
flags       8 bites
reserved    1 bit
stream-id   31 bit
```

3. header block

 * HEADERS or PUSH\_PROMISE frame with END\_HEADERS flag
 * HEADERS or PUSH\_PROMISE frame + CONTINUATION frames

## GRPC

* Request

header(flags=END\_HEADERS):
```
:method                 POST
:scheme                 http
:path                   /helloworld.Greeter/SayHello
:authority              localhost:50051
grpc-timeout            10S         # H, M, S, m(millisecond), u(microsecond), n(nanosecond), immediately after reserved headers
te                      trailers        # used to detect incompatible proxies
content-type            application/grpc    # application/grpc+proto, application/grpc+json, application/grpc+xxx
grpc-encoding           identity    # identity,gzip,deflate,snappy,...
grpc-accept-encoding    identity,gzip,deflate,snappy
user-agent              ...
grpc-message-type       ...
authorization           ...
xxx                     yyy     # custom meta data should be at the end
xxx-bin                 base64-yyy
```

data(flags=END\_STREAM):
```
compressed-flag         1 byte  # 0 or 1
message-length          4 bytes
message                 binary octets
```

A request is ended by a data frame with END\_STREAM flag set, and GRPC call id is identified by stream id.

* Response

header (flags=END\_HEADERS):
```
:status                 200
grpc-encoding           identity
grpc-accept-encoding    identity,gzip,deflate,snappy
content-type            application/grpc    # application/grpc+proto, application/grpc+json, application/grpc+xxx
xxx                     yyy     # custom meta data should be at the end
xxx-bin                 base64-yyy
```

data:
```
same with request
```

trailer(flags=END\_STREAM,END\_HEADERS):
```
grpc-status         0
grpc-message        percent-encoded-message
```

## Tools

* nghttp, nghttpx, h2load: https://nghttp2.org/
* grpc\_cli: https://github.com/grpc/grpc/blob/master/doc/command_line_tool.md
* polyglot: https://github.com/grpc-ecosystem/polyglot

```
# "00 00000000" means "not compressed"(1 byte) and zero payment length(4 bytes)
nghttp -v http://localhost:50051/helloworld.Greeter/SayHello -H ':method: POST' -H 'content-type: application/grpc' -H 'te: trailers' -d <(printf '\x00\x00\x00\x00\x00')

# SayHello,  helloworld.Greeter/SayHello, helloworld.Greeter.SayHello all work.
grpc_cli call localhost:50051 /helloworld.Greeter/SayHello 'name: "xxx"'

echo '{"name": "xxx"}' | java -jar polyglot.jar --command call --endpoint localhost:50051 --full_method helloworld.Greeter/SayHello
```

## References

* HTTP/2 https://httpwg.org/specs/rfc7540.html
* HPACK https://httpwg.org/specs/rfc7541.html
* GRPC https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md
