::  tests for s3-auth library
::
/-  s3
/+  *test, s3-auth
|%
::  test HMAC-SHA256 against known vectors
::  RFC 4231 Test Case 2:
::    Key = "Jefe"
::    Data = "what do ya want for nothing?"
::    HMAC-SHA256 = 5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843
::
++  test-hmac-sha256-rfc4231
  =/  key=octs   [4 'Jefe']
  =/  msg=octs   [28 'what do ya want for nothing?']
  =/  result=@   (hmac-sha256:s3-auth key msg)
  =/  expected=@  0x4338.ec64.b958.ec9d.8339.279d.083f.005a.c775.9508.2624.046a.4e75.60bf.46c1.dc5b
  %+  expect-eq
    !>(expected)
  !>(result)
::
::  test hex rendering
::
++  test-hex-lower-cord
  =/  result=@t
    %-  hex-lower-cord:s3-auth
    0xd7a8.fbbe.2e0b.4975.7163.2efa.26fe.4a0b.7600.9c21.2f78.f02c.b6ce.3749.3026.1a38
  %+  expect-eq
    !>('381a26304937ceb62cf0782f219c00760b4afe26fa2e637175490b2ebefba8d7')
  ::  XX above is the raw hex; check format
  !>(result)
::
::  test query param parsing
::
++  test-parse-query-params
  =/  query=@t  'X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKID%2F20260303&X-Amz-Date=20260303T120000Z'
  =/  result=(map @t @t)  (parse-query-params:s3-auth query)
  ;:  weld
    %+  expect-eq
      !>(`'AWS4-HMAC-SHA256')
    !>((~(get by result) 'X-Amz-Algorithm'))
  ::
    %+  expect-eq
      !>(`'AKID/20260303')
    !>((~(get by result) 'X-Amz-Credential'))
  ::
    %+  expect-eq
      !>(`'20260303T120000Z')
    !>((~(get by result) 'X-Amz-Date'))
  ==
::
::  test AMZ date parsing
::
++  test-parse-amz-date
  =/  result=(unit @da)
    (parse-amz-date:s3-auth '20260303T120000Z')
  %+  expect-eq
    !>(`~2026.3.3..12.0.0)
  !>(result)
::
::  test signing key derivation produces a value
::
++  test-signing-key
  =/  result=@
    (signing-key:s3-auth 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY' '20130524' 'us-east-1' 's3')
  ::  just verify it produces a nonzero value
  %+  expect-eq
    !>(%.y)
  !>((gth result 0))
::
::  test url encoding
::
++  test-uri-encode
  ;:  weld
    %+  expect-eq
      !>('hello%20world')
    !>((uri-encode:s3-auth 'hello world'))
  ::
    %+  expect-eq
      !>('test/path')
    !>((uri-encode:s3-auth 'test/path'))
  ::
    %+  expect-eq
      !>('simple')
    !>((uri-encode:s3-auth 'simple'))
  ==
::
::  test split-on
::
++  test-split-on
  =/  result=(list tape)  (split-on:s3-auth '&' "a&b&c")
  %+  expect-eq
    !>(~["a" "b" "c"])
  !>(result)
::
::  test parse-auth-header extracts fields correctly
::
++  test-parse-auth-header
  =/  input=@t
    'AWS4-HMAC-SHA256 Credential=AKID/20260303/us-east-1/s3/aws4_request, SignedHeaders=host;x-amz-date, Signature=abc123def456'
  =/  result  (parse-auth-header:s3-auth input)
  %+  expect-eq
    !>(`['AKID/20260303/us-east-1/s3/aws4_request' 'host;x-amz-date' 'abc123def456'])
  !>(result)
::
::  +compute-presigned-sig: helper to compute a valid presigned URL signature
::
++  compute-presigned-sig
  |=  $:  method=@t
          url-path=@t
          signed-hdrs=@t
          headers=(list [@t @t])
          creds=credentials:s3
          region=@t
          amz-date=@t
          date-str=@t
          expires=@t
      ==
  ^-  [sig=@t query=@t]
  =/  credential=@t
    (crip "{(trip access-key-id.creds)}/{(trip date-str)}/{(trip region)}/s3/aws4_request")
  =/  params=(map @t @t)
    %-  ~(gas by *(map @t @t))
    :~  ['X-Amz-Algorithm' 'AWS4-HMAC-SHA256']
        ['X-Amz-Credential' credential]
        ['X-Amz-Date' amz-date]
        ['X-Amz-Expires' expires]
        ['X-Amz-SignedHeaders' signed-hdrs]
    ==
  =/  canon-qs=@t  (canonical-query-string:s3-auth params)
  =/  canon-hdrs=@t  (canonical-headers:s3-auth signed-hdrs headers)
  =/  canon-req=@t
    %:  crip
      %+  join-tapes:s3-auth  "\0a"
      :~  (trip method)
          (trip (uri-encode:s3-auth (url-decode:s3-auth url-path)))
          (trip canon-qs)
          (trip canon-hdrs)
          (trip signed-hdrs)
          "UNSIGNED-PAYLOAD"
      ==
    ==
  =/  canon-hash=@t
    (hex-lower-cord:s3-auth (shay (met 3 canon-req) canon-req))
  =/  scope=@t
    (crip "{(trip date-str)}/{(trip region)}/s3/aws4_request")
  =/  sts=@t
    %:  crip
      %+  join-tapes:s3-auth  "\0a"
      :~  "AWS4-HMAC-SHA256"
          (trip amz-date)
          (trip scope)
          (trip canon-hash)
      ==
    ==
  =/  sk=@  (signing-key:s3-auth secret-access-key.creds date-str region 's3')
  =/  sig=@t
    (hex-lower-cord:s3-auth (hmac-sha256:s3-auth [32 sk] [(met 3 sts) sts]))
  [sig canon-qs]
::
::  test presigned URL validation with valid signature
::
++  test-validate-presigned-url
  =/  method=@t  'GET'
  =/  url-path=@t  '/jars/mybucket/mykey'
  =/  creds=credentials:s3  ['minioadmin' 'minioadmin']
  =/  region=@t  'us-east-1'
  =/  amz-date=@t  '20260303T120000Z'
  =/  date-str=@t  '20260303'
  =/  expires=@t  '3600'
  =/  signed-hdrs=@t  'host'
  =/  headers=(list [@t @t])  ~[['host' 'localhost:8080']]
  =/  [sig=@t canon-qs=@t]
    %:  compute-presigned-sig
      method  url-path  signed-hdrs  headers
      creds  region  amz-date  date-str  expires
    ==
  =/  full-query=@t
    (crip "{(trip canon-qs)}&X-Amz-Signature={(trip sig)}")
  %+  expect-eq
    !>(%.y)
  !>  %:  validate-presigned-url:s3-auth
        method  url-path  full-query  headers
        creds  region  ~2026.3.3..12.0.0
      ==
::
::  test presigned URL validation rejects bad signature
::
++  test-validate-presigned-url-bad-sig
  =/  method=@t  'GET'
  =/  url-path=@t  '/jars/mybucket/mykey'
  =/  creds=credentials:s3  ['minioadmin' 'minioadmin']
  =/  region=@t  'us-east-1'
  =/  amz-date=@t  '20260303T120000Z'
  =/  date-str=@t  '20260303'
  =/  expires=@t  '3600'
  =/  signed-hdrs=@t  'host'
  =/  headers=(list [@t @t])  ~[['host' 'localhost:8080']]
  =/  [* canon-qs=@t]
    %:  compute-presigned-sig
      method  url-path  signed-hdrs  headers
      creds  region  amz-date  date-str  expires
    ==
  =/  bad-sig=@t  '0000000000000000000000000000000000000000000000000000000000000000'
  =/  full-query=@t
    (crip "{(trip canon-qs)}&X-Amz-Signature={(trip bad-sig)}")
  %+  expect-eq
    !>(%.n)
  !>  %:  validate-presigned-url:s3-auth
        method  url-path  full-query  headers
        creds  region  ~2026.3.3..12.0.0
      ==
::
::  test presigned URL validation rejects expired requests
::
++  test-validate-presigned-url-expired
  =/  method=@t  'GET'
  =/  url-path=@t  '/jars/mybucket/mykey'
  =/  creds=credentials:s3  ['minioadmin' 'minioadmin']
  =/  region=@t  'us-east-1'
  =/  amz-date=@t  '20260303T120000Z'
  =/  date-str=@t  '20260303'
  =/  expires=@t  '3600'
  =/  signed-hdrs=@t  'host'
  =/  headers=(list [@t @t])  ~[['host' 'localhost:8080']]
  =/  [sig=@t canon-qs=@t]
    %:  compute-presigned-sig
      method  url-path  signed-hdrs  headers
      creds  region  amz-date  date-str  expires
    ==
  =/  full-query=@t
    (crip "{(trip canon-qs)}&X-Amz-Signature={(trip sig)}")
  ::  now is 24h later, well past the 3600s expiry
  %+  expect-eq
    !>(%.n)
  !>  %:  validate-presigned-url:s3-auth
        method  url-path  full-query  headers
        creds  region  ~2026.3.4..12.0.0
      ==
::
::  test Authorization header validation with valid signature
::
++  test-validate-auth-header
  =/  method=@t  'GET'
  =/  url-path=@t  '/jars/mybucket/mykey'
  =/  creds=credentials:s3  ['minioadmin' 'minioadmin']
  =/  region=@t  'us-east-1'
  =/  amz-date=@t  '20260303T120000Z'
  =/  date-str=@t  '20260303'
  =/  signed-hdrs=@t  'host;x-amz-content-sha256;x-amz-date'
  =/  payload-hash=@t  'UNSIGNED-PAYLOAD'
  =/  headers=(list [@t @t])
    :~  ['host' 'localhost:8080']
        ['x-amz-date' amz-date]
        ['x-amz-content-sha256' payload-hash]
    ==
  ::  compute signature
  =/  credential=@t
    (crip "{(trip access-key-id.creds)}/{(trip date-str)}/{(trip region)}/s3/aws4_request")
  =/  canon-qs=@t  (canonical-query-string:s3-auth *(map @t @t))
  =/  canon-hdrs=@t  (canonical-headers:s3-auth signed-hdrs headers)
  =/  canon-req=@t
    %:  crip
      %+  join-tapes:s3-auth  "\0a"
      :~  (trip method)
          (trip (uri-encode:s3-auth (url-decode:s3-auth url-path)))
          (trip canon-qs)
          (trip canon-hdrs)
          (trip signed-hdrs)
          (trip payload-hash)
      ==
    ==
  =/  canon-hash=@t
    (hex-lower-cord:s3-auth (shay (met 3 canon-req) canon-req))
  =/  scope=@t
    (crip "{(trip date-str)}/{(trip region)}/s3/aws4_request")
  =/  sts=@t
    %:  crip
      %+  join-tapes:s3-auth  "\0a"
      :~  "AWS4-HMAC-SHA256"
          (trip amz-date)
          (trip scope)
          (trip canon-hash)
      ==
    ==
  =/  sk=@  (signing-key:s3-auth secret-access-key.creds date-str region 's3')
  =/  sig=@t
    (hex-lower-cord:s3-auth (hmac-sha256:s3-auth [32 sk] [(met 3 sts) sts]))
  ::  build Authorization header value
  =/  auth-header=@t
    %:  crip
      ;:  welp
        "AWS4-HMAC-SHA256 Credential="
        (trip credential)
        ", SignedHeaders="
        (trip signed-hdrs)
        ", Signature="
        (trip sig)
      ==
    ==
  =/  all-headers=(list [@t @t])
    [['authorization' auth-header] headers]
  %+  expect-eq
    !>(%.y)
  !>  %:  validate-auth-header:s3-auth
        method  url-path  ''  all-headers
        creds  region
      ==
--
