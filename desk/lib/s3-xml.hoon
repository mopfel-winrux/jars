::  s3-xml: XML response generation for S3 API
::
/-  s3
|%
::  +da-to-iso8601: format @da as ISO 8601
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
++  zero-pad
  |=  [wid=@ud n=@ud]
  ^-  tape
  =/  raw=tape  (a-co:co n)
  =/  pad=@ud  ?:((gte (lent raw) wid) 0 (sub wid (lent raw)))
  (weld (reap pad '0') raw)
::
::  +list-bucket-result: ListObjectsV2 XML response
::
++  list-bucket-result
  |=  $:  bucket-name=@t
          prefix=(unit @t)
          objects=(list [key=@t obj=s3-object:s3])
          is-truncated=?
          key-count=@ud
          max-keys=@ud
      ==
  ^-  octs
  =/  prefix-xml=tape
    ?~  prefix
      "<Prefix></Prefix>"
    "<Prefix>{(trip u.prefix)}</Prefix>"
  =/  trunc-xml=tape
    ?:  is-truncated  "<IsTruncated>true</IsTruncated>"
    "<IsTruncated>false</IsTruncated>"
  =/  contents-xml=tape
    (zing (turn objects contents-entry))
  %-  as-octt:mimes:html
  ;:  welp
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    "<ListBucketResult xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\">"
    "<Name>{(trip bucket-name)}</Name>"
    prefix-xml
    "<KeyCount>{(a-co:co key-count)}</KeyCount>"
    "<MaxKeys>{(a-co:co max-keys)}</MaxKeys>"
    trunc-xml
    contents-xml
    "</ListBucketResult>"
  ==
::
::  +contents-entry: single <Contents> XML element
::
++  contents-entry
  |=  [key=@t obj=s3-object:s3]
  ^-  tape
  ;:  welp
    "<Contents>"
    "<Key>{(xml-escape (trip key))}</Key>"
    "<LastModified>{(trip (da-to-iso8601 last-modified.obj))}</LastModified>"
    "<ETag>{(xml-escape (trip etag.obj))}</ETag>"
    "<Size>{(a-co:co p.data.obj)}</Size>"
    "<StorageClass>STANDARD</StorageClass>"
    "</Contents>"
  ==
::
::  +error-xml: S3 error XML response
::
++  error-xml
  |=  [code=@t message=@t resource=@t request-id=@t]
  ^-  octs
  %-  as-octt:mimes:html
  ;:  welp
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    "<Error>"
    "<Code>{(xml-escape (trip code))}</Code>"
    "<Message>{(xml-escape (trip message))}</Message>"
    "<Resource>{(xml-escape (trip resource))}</Resource>"
    "<RequestId>{(xml-escape (trip request-id))}</RequestId>"
    "</Error>"
  ==
::
::  +xml-escape: escape special XML characters
::
++  xml-escape
  |=  =tape
  ^-  ^tape
  %-  zing
  %+  turn  tape
  |=  c=@tD
  ^-  ^tape
  ?:  =(c '&')   "&amp;"
  ?:  =(c '<')   "&lt;"
  ?:  =(c '>')   "&gt;"
  ?:  =(c '"')   "&quot;"
  ?:  =(c '\'')  "&apos;"
  [c ~]
--
