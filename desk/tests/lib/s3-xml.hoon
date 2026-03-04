::  tests for s3-xml library
::
/-  s3
/+  *test, s3-xml
|%
::  test XML escape
::
++  test-xml-escape
  ;:  weld
    %+  expect-eq
      !>("&amp;&lt;&gt;")
    !>((xml-escape:s3-xml "&<>"))
  ::
    %+  expect-eq
      !>("hello")
    !>((xml-escape:s3-xml "hello"))
  ::
    %+  expect-eq
      !>("&quot;quoted&quot;")
    !>((xml-escape:s3-xml "\"quoted\""))
  ==
::
::  test error XML generation
::
++  test-error-xml
  =/  result=octs
    (error-xml:s3-xml 'NoSuchKey' 'Not found' '/bucket/key' 'req-1')
  ::  just check it produces non-empty output
  %+  expect-eq
    !>(%.y)
  !>((gth p.result 0))
::
::  test list bucket result
::
++  test-list-bucket-result-empty
  =/  result=octs
    %:  list-bucket-result:s3-xml
      'test-bucket'
      ~
      ~
      %.n
      0
      1.000
    ==
  ::  check it produces non-empty output
  %+  expect-eq
    !>(%.y)
  !>((gth p.result 0))
--
