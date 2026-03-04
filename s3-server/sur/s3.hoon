|%
+$  bucket-name   @t
+$  object-key    @t
::
+$  s3-object
  $:  data=octs
      content-type=@t
      etag=@t
      last-modified=@da
      metadata=(map @t @t)
  ==
::
+$  bucket        (map object-key s3-object)
+$  object-store  (map bucket-name bucket)
::
+$  credentials
  $:  access-key-id=@t
      secret-access-key=@t
  ==
::
+$  s3-config
  $:  region=@t
      =credentials
  ==
--
