::  s3-http: URL parsing, query params, response helpers for S3 server
::
/-  s3
/+  server
|%
::  +base-path: the Eyre binding path prefix
::
++  base-path  '/jars/'
::
::  +cors-headers: CORS headers for all responses
::
++  cors-headers
  ^-  (list [@t @t])
  :~  ['access-control-allow-origin' '*']
      ['access-control-allow-methods' 'GET, PUT, HEAD, DELETE, OPTIONS, POST']
      ['access-control-allow-headers' '*']
      ['access-control-expose-headers' 'ETag, Content-Length, x-amz-request-id, Content-Type']
      ['access-control-max-age' '86400']
  ==
::
::  +parse-s3-path: extract bucket and key from URL path
::
::    Strips /jars/ prefix.
::    Returns [bucket-name (unit object-key)]
::    /jars/my-bucket → ['my-bucket' ~]
::    /jars/my-bucket/path/to/file.txt → ['my-bucket' `'path/to/file.txt']
::
++  parse-s3-path
  |=  url-path=@t
  ^-  (unit [bucket=@t key=(unit @t)])
  =/  full=tape  (trip url-path)
  =/  prefix=tape  (trip base-path)
  =/  plen=@ud  (lent prefix)
  ::  check prefix matches
  ?.  =(prefix (scag plen full))
    ~
  =/  raw=tape  (slag plen full)
  ::  trim trailing slash if any
  =/  rest=tape
    ?:  &(?=(^ raw) =('/' (rear raw)))
      (flop (tail (flop raw)))
    raw
  ?:  =(~ rest)  ~
  ::  find first slash to split bucket/key
  =/  slash-idx  (find "/" rest)
  ?~  slash-idx
    `[(crip rest) ~]
  =/  bucket=@t  (crip (scag u.slash-idx rest))
  =/  key=@t     (url-decode-full (crip (slag +(u.slash-idx) rest)))
  ?:  =(key '')
    `[bucket ~]
  `[bucket `key]
::
::  +extract-query: extract query string from raw URL
::
++  extract-query
  |=  url=@t
  ^-  [path=@t query=@t]
  =/  t=tape  (trip url)
  =/  idx  (find "?" t)
  ?~  idx
    [url '']
  [(crip (scag u.idx t)) (crip (slag +(u.idx) t))]
::
::  +etag-from-octs: compute ETag as quoted SHA-256 hex
::
++  etag-from-octs
  |=  =octs
  ^-  @t
  =/  hash=@  (shay p.octs q.octs)
  =/  hex=tape
    =/  res=tape  ~
    =/  i=@ud  0
    |-
    ?:  =(i 32)
      (flop res)
    =/  byte=@  (cut 3 [i 1] hash)
    =/  hi=@ud  (div byte 16)
    =/  lo=@ud  (mod byte 16)
    =/  hex-char
      |=  n=@ud
      ^-  @tD
      ?:  (lth n 10)  (add '0' n)
      (add 'a' (sub n 10))
    %=  $
      i    +(i)
      res  [(hex-char lo) (hex-char hi) res]
    ==
  (crip (weld "\"" (weld hex "\"")))
::
::  +da-to-http-date: format @da as HTTP date string
::
::    e.g. "Tue, 03 Mar 2026 12:00:00 GMT"
::
++  da-to-http-date
  |=  d=@da
  ^-  @t
  =/  dt  (yore d)
  =/  =tape
    ;:  welp
      (weekday d)
      ", "
      (zero-pad 2 d.t.dt)
      " "
      (month-name m.dt)
      " "
      (a-co:co y.dt)
      " "
      (zero-pad 2 h.t.dt)
      ":"
      (zero-pad 2 m.t.dt)
      ":"
      (zero-pad 2 s.t.dt)
      " GMT"
    ==
  (crip tape)
::
++  zero-pad
  |=  [wid=@ud n=@ud]
  ^-  tape
  =/  raw=tape  (a-co:co n)
  =/  pad=@ud  ?:((gte (lent raw) wid) 0 (sub wid (lent raw)))
  (weld (reap pad '0') raw)
::
++  weekday
  |=  d=@da
  ^-  tape
  =/  dow  (mod (div (sub d ~1970.1.1) ~d1) 7)
  =/  days=(list tape)
    ~["Thu" "Fri" "Sat" "Sun" "Mon" "Tue" "Wed"]
  (snag dow days)
::
++  month-name
  |=  m=@ud
  ^-  tape
  =/  months=(list tape)
    ~["Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"]
  (snag (dec m) months)
::
::  +da-to-iso8601: format @da as ISO 8601 for S3 XML
::
::    e.g. "2026-03-03T12:00:00.000Z"
::
++  da-to-iso8601
  |=  d=@da
  ^-  @t
  =/  dt  (yore d)
  =/  =tape
    ;:  welp
      (a-co:co y.dt)
      "-"
      (zero-pad 2 m.dt)
      "-"
      (zero-pad 2 d.t.dt)
      "T"
      (zero-pad 2 h.t.dt)
      ":"
      (zero-pad 2 m.t.dt)
      ":"
      (zero-pad 2 s.t.dt)
      ".000Z"
    ==
  (crip tape)
::
::  +s3-response: build a simple-payload with status, headers, and optional body
::
++  s3-response
  |=  [status=@ud headers=(list [@t @t]) body=(unit octs)]
  ^-  simple-payload:http
  [[status (weld cors-headers headers)] body]
::
::  +s3-give: give an S3 response through Eyre
::
++  s3-give
  |=  [eyre-id=@ta status=@ud headers=(list [@t @t]) body=(unit octs)]
  ^-  (list card:agent:gall)
  %+  give-simple-payload:app:server
    eyre-id
  (s3-response status headers body)
::
::  +s3-error-xml: format an S3 error as XML body
::
++  s3-error-xml
  |=  [code=@t message=@t]
  ^-  octs
  %-  as-octt:mimes:html
  ;:  welp
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    "<Error>"
    "<Code>{(trip code)}</Code>"
    "<Message>{(trip message)}</Message>"
    "</Error>"
  ==
::
::  +url-decode-full: repeatedly URL-decode until stable
::
::    Handles double/triple encoding (e.g., %2520 → %20 → space)
::
++  url-decode-full
  |=  txt=@t
  ^-  @t
  =/  decoded=@t  (url-decode txt)
  ?:  =(decoded txt)  txt
  $(txt decoded)
::
::  +url-decode: percent-decode a cord
::
++  url-decode
  |=  txt=@t
  ^-  @t
  =/  in=tape  (trip txt)
  =/  out=tape  ~
  |-
  ?~  in  (crip (flop out))
  ?:  &(=(i.in '%') ?=(^ t.in) ?=(^ t.t.in))
    =/  hi  (from-hex-char i.t.in)
    =/  lo  (from-hex-char i.t.t.in)
    ?:  |(?=(~ hi) ?=(~ lo))
      $(in t.in, out [i.in out])
    $(in t.t.t.in, out [(add (mul 16 (need hi)) (need lo)) out])
  $(in t.in, out [i.in out])
::
++  from-hex-char
  |=  c=@tD
  ^-  (unit @ud)
  ?:  &((gte c '0') (lte c '9'))  `(sub c '0')
  ?:  &((gte c 'a') (lte c 'f'))  `(add 10 (sub c 'a'))
  ?:  &((gte c 'A') (lte c 'F'))  `(add 10 (sub c 'A'))
  ~
::
::  +find-header: find a header value by name (case-insensitive)
::
++  find-header
  |=  [name=@t headers=(list [k=@t v=@t])]
  ^-  (unit @t)
  =/  lower-name=tape  (cass (trip name))
  |-
  ?~  headers  ~
  ?:  =((cass (trip k.i.headers)) lower-name)
    `v.i.headers
  $(headers t.headers)
::
::  +lowercase-headers: convert all header names to lowercase
::
++  lowercase-headers
  |=  headers=(list [@t @t])
  ^-  (list [@t @t])
  %+  turn  headers
  |=  [k=@t v=@t]
  [(crip (cass (trip k))) v]
--
