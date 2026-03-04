::  s3-server: S3-compatible object store
::
::  Implements a subset of the S3 HTTP API for object storage.
::  Objects are stored in agent state as binary blobs.
::  Auth via AWS Signature V4 presigned URLs.
::
/-  s3, storage
/+  dbug, verb, server, default-agent,
    s3-auth, s3-http, s3-xml
|%
+$  card  card:agent:gall
+$  versioned-state
  $:  state-0
  ==
+$  state-0
  $:  %0
      config=s3-config:s3
      store=object-store:s3
  ==
--
%-  agent:dbug
=|  state-0
=*  state  -
%+  verb  &
^-  agent:gall
|_  =bowl:gall
+*  this   .
    def    ~(. (default-agent this %|) bowl)
::
++  on-agent  on-agent:def
++  on-leave  on-leave:def
++  on-fail   on-fail:def
::
++  on-save
  ^-  vase
  !>(state)
::
++  on-load
  |=  =vase
  ^-  (quip card _this)
  =/  old  !<(versioned-state vase)
  :-  ~
  ?-    -.old
      %0
    this(state old)
  ==
::
++  on-init
  ^-  (quip card _this)
  =/  access-key=@t  (scot %p our.bowl)
  =/  secret-key=@t  (hex-lower-cord:s3-auth (end [3 32] eny.bowl))
  =/  default-config=s3-config:s3
    ['us-east-1' [access-key secret-key]]
  %-  (slog leaf+"s3-server: access-key={(trip access-key)}" ~)
  %-  (slog leaf+"s3-server: secret-key={(trip secret-key)}" ~)
  :_  this(config default-config)
  :~  :*  %pass  /eyre/connect
          %arvo  %e  %connect
          [`/apps/jars dap.bowl]
      ==
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  |^  ?+  mark
        (on-poke:def mark vase)
      ::
          %handle-http-request
        (handle-http !<([@ta inbound-request:eyre] vase))
      ::
          %noun
        =/  act  !<(@tas vase)
        ?+  act  (on-poke:def mark vase)
            %print-config
          %-  (slog leaf+"s3-server config:" ~)
          %-  (slog leaf+"  region: {(trip region.config)}" ~)
          %-  (slog leaf+"  access-key: {(trip access-key-id.credentials.config)}" ~)
          %-  (slog leaf+"  secret-key: {(trip secret-access-key.credentials.config)}" ~)
          `this
        ::
            %configure-storage
          =/  bucket=@t  'default'
          =/  endpoint=@t  'http://localhost:8080/apps/jars'
          =/  new-store=object-store:s3
            ?~  (~(get by store) bucket)
              (~(put by store) bucket *(map object-key:s3 s3-object:s3))
            store
          %-  (slog leaf+"s3-server: configuring %storage agent" ~)
          %-  (slog leaf+"  endpoint: {(trip endpoint)}" ~)
          %-  (slog leaf+"  access-key: {(trip access-key-id.credentials.config)}" ~)
          %-  (slog leaf+"  region: {(trip region.config)}" ~)
          %-  (slog leaf+"  bucket: {(trip bucket)}" ~)
          :_  this(store new-store)
          :~  [%pass /storage/endpoint %agent [our.bowl %storage] %poke %storage-action !>(^-(action:storage [%set-endpoint endpoint]))]
              [%pass /storage/access-key %agent [our.bowl %storage] %poke %storage-action !>(^-(action:storage [%set-access-key-id access-key-id.credentials.config]))]
              [%pass /storage/secret-key %agent [our.bowl %storage] %poke %storage-action !>(^-(action:storage [%set-secret-access-key secret-access-key.credentials.config]))]
              [%pass /storage/region %agent [our.bowl %storage] %poke %storage-action !>(^-(action:storage [%set-region region.config]))]
              [%pass /storage/bucket %agent [our.bowl %storage] %poke %storage-action !>(^-(action:storage [%add-bucket bucket]))]
              [%pass /storage/current-bucket %agent [our.bowl %storage] %poke %storage-action !>(^-(action:storage [%set-current-bucket bucket]))]
              [%pass /storage/service %agent [our.bowl %storage] %poke %storage-action !>(^-(action:storage [%toggle-service %credentials]))]
          ==
        ==
      ::
          %s3-set-config
        ?>  =(src our):bowl
        =/  new-config  !<(s3-config:s3 vase)
        `this(config new-config)
      ==
  ::
  ++  handle-http
    |=  [eyre-id=@ta req=inbound-request:eyre]
    ^-  (quip card _this)
    ::  log every incoming request
    %-  (slog leaf+"s3-server: {(trip method.request.req)} {(trip url.request.req)}" ~)
    ::  handle OPTIONS preflight for any path
    ?:  =(method.request.req %'OPTIONS')
      :_  this
      (s3-give:s3-http eyre-id 200 ~ ~)
    ::  parse URL path and query
    =/  [url-path=@t query=@t]
      (extract-query:s3-http url.request.req)
    ::  parse S3 path components
    =/  parsed=(unit [bucket=@t key=(unit @t)])
      (parse-s3-path:s3-http url-path)
    ?~  parsed
      :_  this
      %:  s3-give:s3-http
        eyre-id  404
        ~[['content-type' 'application/xml']]
        `(s3-error-xml:s3-http 'NoSuchBucket' 'Invalid path')
      ==
    ::  allow public read access for GET/HEAD on objects
    =/  is-public-read=?
      ?&  ?|(=(method.request.req %'GET') =(method.request.req %'HEAD'))
          ?=(^ key.u.parsed)
      ==
    ::  validate auth: presigned URL, Authorization header, or Eyre session
    =/  is-presigned=?
      ?=(^ (find "X-Amz-Signature" (trip query)))
    =/  has-aws-auth=?
      ?=(^ (find-header:s3-http 'authorization' header-list.request.req))
    %-  (slog leaf+"s3-server: presigned={?:(is-presigned "yes" "no")} aws-auth={?:(has-aws-auth "yes" "no")} eyre-auth={?:(authenticated.req "yes" "no")}" ~)
    =/  authed=?
      ?:  is-public-read  %.y
      ?:  is-presigned
        %:  validate-presigned-url:s3-auth
          method.request.req
          url-path
          query
          header-list.request.req
          credentials.config
          region.config
          now.bowl
        ==
      ?:  has-aws-auth
        ::  reconstruct content-length if missing (Eyre strips it)
        =/  auth-headers=(list [@t @t])
          ?.  ?&  ?=(^ body.request.req)
                  ?=(~ (find-header:s3-http 'content-length' header-list.request.req))
              ==
            header-list.request.req
          [['content-length' (crip (a-co:co p.u.body.request.req))] header-list.request.req]
        =/  result=?
          %:  validate-auth-header:s3-auth
            method.request.req
            url-path
            query
            auth-headers
            credentials.config
            region.config
          ==
        ?.  result
          =/  auth-hdr=(unit @t)
            (find-header:s3-http 'authorization' header-list.request.req)
          %-  (slog leaf+"s3-server: auth-header validation failed" ~)
          %-  (slog leaf+"  method: {(trip method.request.req)}" ~)
          %-  (slog leaf+"  path: {(trip url-path)}" ~)
          %-  (slog leaf+"  query: {(trip query)}" ~)
          %-  (slog leaf+"  auth: {?~(auth-hdr "~" (trip u.auth-hdr))}" ~)
          %.n
        %.y
      authenticated.req
    ?.  authed
      :_  this
      %:  s3-give:s3-http
        eyre-id  403
        ~[['content-type' 'application/xml']]
        `(s3-error-xml:s3-http 'AccessDenied' 'Authentication failed')
      ==
    ::  dispatch by method
    =/  =bucket-name:s3  bucket.u.parsed
    =/  mkey=(unit object-key:s3)  key.u.parsed
    ?+  method.request.req
      :_  this
      (s3-give:s3-http eyre-id 405 ~ ~)
    ::
        %'PUT'
      ?~  mkey
        (handle-create-bucket eyre-id bucket-name)
      (handle-put-object eyre-id bucket-name u.mkey req)
    ::
        %'GET'
      ?~  mkey
        (handle-list-objects eyre-id bucket-name query)
      (handle-get-object eyre-id bucket-name u.mkey)
    ::
        %'HEAD'
      ?~  mkey
        (handle-head-bucket eyre-id bucket-name)
      (handle-head-object eyre-id bucket-name u.mkey)
    ::
        %'DELETE'
      ?~  mkey
        :_  this
        %:  s3-give:s3-http
          eyre-id  405
          ~[['content-type' 'application/xml']]
          `(s3-error-xml:s3-http 'MethodNotAllowed' 'DELETE not supported on buckets')
        ==
      (handle-delete-object eyre-id bucket-name u.mkey)
    ==
  ::
  ++  handle-put-object
    |=  [eyre-id=@ta =bucket-name:s3 =object-key:s3 req=inbound-request:eyre]
    ^-  (quip card _this)
    =/  bkt=bucket:s3
      (~(gut by store) bucket-name *(map object-key:s3 s3-object:s3))
    =/  body=octs
      ?~  body.request.req
        [0 0]
      u.body.request.req
    =/  content-type=@t
      %+  fall
        (find-header:s3-http 'content-type' header-list.request.req)
      'application/octet-stream'
    =/  etag=@t  (etag-from-octs:s3-http body)
    =/  obj=s3-object:s3
      :*  body
          content-type
          etag
          now.bowl
          *(map @t @t)
      ==
    =/  new-bkt=bucket:s3  (~(put by bkt) object-key obj)
    =/  new-store=object-store:s3  (~(put by store) bucket-name new-bkt)
    :_  this(store new-store)
    %:  s3-give:s3-http
      eyre-id  200
      ~[['etag' etag]]
      ~
    ==
  ::
  ++  handle-get-object
    |=  [eyre-id=@ta =bucket-name:s3 =object-key:s3]
    ^-  (quip card _this)
    =/  bkt=(unit bucket:s3)  (~(get by store) bucket-name)
    ?~  bkt
      :_  this
      %:  s3-give:s3-http
        eyre-id  404
        ~[['content-type' 'application/xml']]
        `(s3-error-xml:s3-http 'NoSuchBucket' 'The specified bucket does not exist')
      ==
    =/  obj=(unit s3-object:s3)  (~(get by u.bkt) object-key)
    ?~  obj
      :_  this
      %:  s3-give:s3-http
        eyre-id  404
        ~[['content-type' 'application/xml']]
        `(s3-error-xml:s3-http 'NoSuchKey' 'The specified key does not exist')
      ==
    :_  this
    %:  s3-give:s3-http
      eyre-id  200
      :~  ['content-type' content-type.u.obj]
          ['etag' etag.u.obj]
          ['last-modified' (da-to-http-date:s3-http last-modified.u.obj)]
      ==
      `data.u.obj
    ==
  ::
  ++  handle-head-object
    |=  [eyre-id=@ta =bucket-name:s3 =object-key:s3]
    ^-  (quip card _this)
    =/  bkt=(unit bucket:s3)  (~(get by store) bucket-name)
    ?~  bkt
      :_  this
      (s3-give:s3-http eyre-id 404 ~ ~)
    =/  obj=(unit s3-object:s3)  (~(get by u.bkt) object-key)
    ?~  obj
      :_  this
      (s3-give:s3-http eyre-id 404 ~ ~)
    :_  this
    %:  s3-give:s3-http
      eyre-id  200
      :~  ['content-type' content-type.u.obj]
          ['content-length' (crip (a-co:co p.data.u.obj))]
          ['etag' etag.u.obj]
          ['last-modified' (da-to-http-date:s3-http last-modified.u.obj)]
      ==
      ~
    ==
  ::
  ++  handle-head-bucket
    |=  [eyre-id=@ta =bucket-name:s3]
    ^-  (quip card _this)
    ?~  (~(get by store) bucket-name)
      :_  this
      (s3-give:s3-http eyre-id 404 ~ ~)
    :_  this
    (s3-give:s3-http eyre-id 200 ~ ~)
  ::
  ++  handle-delete-object
    |=  [eyre-id=@ta =bucket-name:s3 =object-key:s3]
    ^-  (quip card _this)
    =/  bkt=(unit bucket:s3)  (~(get by store) bucket-name)
    ?~  bkt
      :_  this
      (s3-give:s3-http eyre-id 204 ~ ~)
    =/  new-bkt=bucket:s3  (~(del by u.bkt) object-key)
    =/  new-store=object-store:s3  (~(put by store) bucket-name new-bkt)
    :_  this(store new-store)
    (s3-give:s3-http eyre-id 204 ~ ~)
  ::
  ++  handle-create-bucket
    |=  [eyre-id=@ta =bucket-name:s3]
    ^-  (quip card _this)
    =/  new-store=object-store:s3
      ?~  (~(get by store) bucket-name)
        (~(put by store) bucket-name *(map object-key:s3 s3-object:s3))
      store
    :_  this(store new-store)
    (s3-give:s3-http eyre-id 200 ~ ~)
  ::
  ++  handle-list-objects
    |=  [eyre-id=@ta =bucket-name:s3 query=@t]
    ^-  (quip card _this)
    =/  bkt=(unit bucket:s3)  (~(get by store) bucket-name)
    ?~  bkt
      :_  this
      %:  s3-give:s3-http
        eyre-id  404
        ~[['content-type' 'application/xml']]
        `(s3-error-xml:s3-http 'NoSuchBucket' 'The specified bucket does not exist')
      ==
    =/  params=(map @t @t)  (parse-query-params:s3-auth query)
    =/  prefix=(unit @t)  (~(get by params) 'prefix')
    =/  max-keys=@ud
      %+  fall
        (bind (~(get by params) 'max-keys') |=(v=@t (fall (rush v dem) 1.000)))
      1.000
    =/  all-objects=(list [key=@t obj=s3-object:s3])
      ~(tap by u.bkt)
    =/  filtered=(list [key=@t obj=s3-object:s3])
      ?~  prefix  all-objects
      %+  skim  all-objects
      |=  [key=@t *]
      =/  prefix-tape=tape  (trip u.prefix)
      =/  key-tape=tape  (trip key)
      =(prefix-tape (scag (lent prefix-tape) key-tape))
    =/  sorted=(list [key=@t obj=s3-object:s3])
      %+  sort  filtered
      |=  [[a=@t *] [b=@t *]]
      (aor a b)
    =/  truncated=(list [key=@t obj=s3-object:s3])
      (scag max-keys sorted)
    =/  key-count=@ud  (lent truncated)
    =/  is-truncated=?  (gth (lent sorted) max-keys)
    =/  xml-body=octs
      %:  list-bucket-result:s3-xml
        bucket-name
        prefix
        truncated
        is-truncated
        key-count
        max-keys
      ==
    :_  this
    %:  s3-give:s3-http
      eyre-id  200
      ~[['content-type' 'application/xml']]
      `xml-body
    ==
  --
::
++  on-peek
  |=  =(pole knot)
  ^-  (unit (unit cage))
  ?+  pole  (on-peek:def `path`pole)
    ::
    ::  .^(json %gx /=jars=/config/json)
    [%x %config ~]
      =/  =json
        %-  pairs:enjs:format
        :~  ['region' s+region.config]
            ['accessKeyId' s+access-key-id.credentials.config]
        ==
      ``json+!>(json)
    ::
    ::  .^(noun %gx /=jars=/buckets/noun)
    [%x %buckets ~]
      ``noun+!>(~(key by store))
  ==
::
++  on-arvo
  |=  [=(pole knot) =sign-arvo]
  ^-  (quip card _this)
  ?+  pole
    `this
  ::
      [%eyre %connect ~]
    ?>  ?=([%eyre %bound *] sign-arvo)
    ?:  accepted.sign-arvo
      %-  (slog leaf+"s3-server: bound at /apps/jars" ~)
      `this
    %-  (slog leaf+"s3-server: FAILED to bind at /apps/jars" ~)
    `this
  ==
::
++  on-watch
  |=  =(pole knot)
  ^-  (quip card _this)
  ?+    pole  (on-watch:def `path`pole)
      [%http-response eyre-id=@ta ~]
    `this
  ==
--
