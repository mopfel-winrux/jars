::  storage types (subset for cross-desk poke to %storage agent)
::
|%
+$  service  ?(%presigned-url %credentials)
+$  action
  $%  [%set-endpoint endpoint=@t]
      [%set-access-key-id access-key-id=@t]
      [%set-secret-access-key secret-access-key=@t]
      [%add-bucket bucket=@t]
      [%remove-bucket bucket=@t]
      [%set-current-bucket bucket=@t]
      [%set-region region=@t]
      [%set-public-url-base public-url-base=@t]
      [%set-presigned-url url=@t]
      [%toggle-service =service]
  ==
--
