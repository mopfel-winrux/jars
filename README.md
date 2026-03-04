# Jars — S3-Compatible Object Store for Urbit

Jars is a Gall agent (`%s3-server`) that implements a subset of the AWS S3 HTTP API, backed entirely by agent state. It provides object storage accessible via standard S3 clients, other Gall agents (via poke/scry), and the Landscape `%storage` agent.

## Setup / Installation

```dojo
:: Install the desk
|install our %jars

:: Mount to Unix for file editing
|mount %jars

:: Configure the Landscape %storage agent to use Jars
:s3-server [%configure-storage 'https://your-ship.example.com']
```

On init, the agent generates credentials (access key = your `@p`, secret key = random hex), binds at `/jars` on Eyre, and prints credentials to the dojo. To view them later:

```dojo
:s3-server %print-config
```

## HTTP API (S3-Compatible)

The agent binds at `/jars` and accepts standard S3 requests. URL format: `/jars/<bucket>/<key>`.

### Authentication

Three methods supported (checked in order):

1. **Public reads** — `GET`/`HEAD` on objects (with key) require no auth
2. **Presigned URLs** — AWS Signature V4 presigned query parameters (`X-Amz-Signature`, etc.)
3. **Authorization header** — AWS Signature V4 `Authorization: AWS4-HMAC-SHA256 ...`
4. **Eyre session** — Standard Urbit `+code` authentication cookie

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `PUT` | `/jars/<bucket>` | Create bucket |
| `PUT` | `/jars/<bucket>/<key>` | Upload object |
| `GET` | `/jars/<bucket>` | List objects (XML). Query params: `prefix`, `max-keys` |
| `GET` | `/jars/<bucket>/<key>` | Download object |
| `HEAD` | `/jars/<bucket>` | Check bucket exists |
| `HEAD` | `/jars/<bucket>/<key>` | Get object metadata headers |
| `DELETE` | `/jars/<bucket>/<key>` | Delete object |
| `OPTIONS` | `*` | CORS preflight (always 200) |

## Scry Endpoints

All scrys use the `%gx` care. The agent name is `%s3-server`.

| Path | Mark | Return Type | Description |
|------|------|-------------|-------------|
| `/config` | `json` | `{region, accessKeyId}` | Server configuration |
| `/buckets` | `noun` | `(set bucket-name)` | Set of all bucket names |
| `/bucket/<name>` | `noun` | `?(%.y %.n)` | Does bucket exist? |
| `/bucket/<name>/keys` | `noun` | `(list @t)` | Sorted list of object keys |
| `/bucket/<name>/object/<key...>` | `noun` | `s3-object` | Full object (data + metadata) |
| `/bucket/<name>/data/<key...>` | `noun` | `octs` | Raw file data (p=size, q=bytes) |
| `/bucket/<name>/has/<key...>` | `noun` | `?(%.y %.n)` | Does object exist? |
| `/bucket/<name>/meta/<key...>` | `json` | `{contentType, etag, ...}` | Object metadata as JSON |

For objects with `/` in the key (e.g. `path/to/file.txt`), the key segments are part of the scry path.

### Dojo Examples

```dojo
:: List all buckets
.^((set @t) %gx /=s3-server=/buckets/noun)

:: Check if 'default' bucket exists
.^(? %gx /=s3-server=/bucket/default/noun)

:: List keys in 'default' bucket
.^((list @t) %gx /=s3-server=/bucket/default/keys/noun)

:: Check if object exists
.^(? %gx /=s3-server=/bucket/default/has/my-file.txt/noun)

:: Get object metadata as JSON
.^(json %gx /=s3-server=/bucket/default/meta/my-file.txt/json)

:: Get raw data
.^(octs %gx /=s3-server=/bucket/default/data/my-file.txt/noun)
```

## Poke Interface

The agent accepts `%s3-action` pokes (local ship only). The mark is defined in `mar/s3-action.hoon` and the type in `sur/s3.hoon`.

### `s3-action` type

```hoon
+$  s3-action
  $%  [%put-object =bucket-name =object-key =s3-object]
      [%delete-object =bucket-name =object-key]
      [%create-bucket =bucket-name]
      [%delete-bucket =bucket-name]
  ==
```

### Actions

**`%create-bucket`** — Create an empty bucket (no-op if it already exists).

```dojo
:s3-server &s3-action [%create-bucket 'my-bucket']
```

**`%delete-bucket`** — Remove a bucket and all its objects.

```dojo
:s3-server &s3-action [%delete-bucket 'my-bucket']
```

**`%put-object`** — Insert or overwrite an object.

```dojo
:s3-server &s3-action [%put-object 'default' 'hello.txt' [[9 'hello wor'] 'text/plain' '"abc"' now *~]]
```

**`%delete-object`** — Remove a single object from a bucket.

```dojo
:s3-server &s3-action [%delete-object 'default' 'hello.txt']
```

### From another agent

```hoon
[%pass /s3 %agent [our.bowl %s3-server] %poke %s3-action !>([%create-bucket 'uploads'])]
```

## Configuration

**Set config directly** (mark `%s3-set-config`):

```dojo
:s3-server &s3-set-config ['us-east-1' ['~zod' 'my-secret-key']]
```

**Configure Landscape `%storage`** (mark `%noun`):

```dojo
:s3-server [%configure-storage 'https://your-domain.com']
```

This pokes the `%storage` agent with the endpoint, credentials, region, and a `default` bucket so that Landscape apps (Groups, etc.) use Jars for media uploads.
