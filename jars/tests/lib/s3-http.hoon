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
--
