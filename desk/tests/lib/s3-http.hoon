::  tests for s3-http library
::
/-  s3
/+  *test, s3-http
|%
::  test parse-s3-path: bucket only
::
++  test-parse-path-bucket-only
  %+  expect-eq
    !>(`['mybucket' ~])
  !>((parse-s3-path:s3-http '/jars/mybucket'))
::
::  test parse-s3-path: bucket with trailing slash
::
++  test-parse-path-bucket-trailing-slash
  %+  expect-eq
    !>(`['mybucket' ~])
  !>((parse-s3-path:s3-http '/jars/mybucket/'))
::
::  test parse-s3-path: bucket and key
::
++  test-parse-path-object
  %+  expect-eq
    !>(`['mybucket' `'file.txt'])
  !>((parse-s3-path:s3-http '/jars/mybucket/file.txt'))
::
::  test parse-s3-path: nested key
::
++  test-parse-path-nested-key
  %+  expect-eq
    !>(`['mybucket' `'path/to/file.txt'])
  !>((parse-s3-path:s3-http '/jars/mybucket/path/to/file.txt'))
::
::  test parse-s3-path: folder key (trailing slash preserved)
::
++  test-parse-path-folder
  %+  expect-eq
    !>(`['mybucket' `'myfolder/'])
  !>((parse-s3-path:s3-http '/jars/mybucket/myfolder/'))
::
::  test parse-s3-path: nested folder key
::
++  test-parse-path-nested-folder
  %+  expect-eq
    !>(`['mybucket' `'path/to/folder/'])
  !>((parse-s3-path:s3-http '/jars/mybucket/path/to/folder/'))
::
::  test parse-s3-path: invalid prefix
::
++  test-parse-path-bad-prefix
  %+  expect-eq
    !>(~)
  !>((parse-s3-path:s3-http '/other/mybucket'))
::
::  test parse-s3-path: empty after prefix
::
++  test-parse-path-empty
  %+  expect-eq
    !>(~)
  !>((parse-s3-path:s3-http '/jars/'))
::
::  test parse-copy-source: absolute source path
::
++  test-parse-copy-source
  %+  expect-eq
    !>(`['default' 'path/to/file.txt'])
  !>((parse-copy-source:s3-http '/default/path/to/file.txt'))
::
::  test parse-copy-source: strips query params
::
++  test-parse-copy-source-query
  %+  expect-eq
    !>(`['default' 'file.txt'])
  !>((parse-copy-source:s3-http '/default/file.txt?versionId=123'))
::
::  test parse-copy-source: URL-decoded key
::
++  test-parse-copy-source-encoded
  %+  expect-eq
    !>(`['default' 'path/to/file.txt'])
  !>((parse-copy-source:s3-http '/default/path%2Fto%2Ffile.txt'))
::
::  test metadata extraction from HTTP headers
::
++  test-metadata-from-headers
  =/  headers=(list [@t @t])
    :~  ['content-type' 'image/png']
        ['x-amz-meta-pdna' 'ok']
        ['X-AmZ-MeTa-source' 'scan-job']
    ==
  =/  metadata=(map @t @t)
    (metadata-from-headers:s3-http headers)
  ;:  weld
    %+  expect-eq
      !>(`'ok')
    !>((~(get by metadata) 'pdna'))
  ::
    %+  expect-eq
      !>(`'scan-job')
    !>((~(get by metadata) 'source'))
  ==
::
::  test metadata header rendering as x-amz-meta-*
::
++  test-metadata-headers
  =/  metadata=(map @t @t)
    %-  ~(gas by *(map @t @t))
    :~  ['pdna' 'ok']
        ['source' 'scan-job']
    ==
  =/  headers=(list [@t @t])
    (metadata-headers:s3-http metadata)
  =/  header-map=(map @t @t)
    (~(gas by *(map @t @t)) headers)
  ;:  weld
    %+  expect-eq
      !>(`'ok')
    !>((~(get by header-map) 'x-amz-meta-pdna'))
  ::
    %+  expect-eq
      !>(`'scan-job')
    !>((~(get by header-map) 'x-amz-meta-source'))
  ==
--
