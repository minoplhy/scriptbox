# rclone-easy

Back up local folders with rclone, configured from one simple text file.

1. List your folders and where they go in `config.txt`.
2. Run `./generate.sh`. It writes `run.sh`.
3. Run `./run.sh` (by hand or from cron) to sync everything.

Each folder is copied to `<Remote>/<folder name>`. For example, `/home/user/Pictures` with `Remote: backup:bucket` ends up in `backup:bucket/Pictures`.

---

## Quick start

```bash
# 1. Set up a remote (or edit rclone.conf by hand, see "Remote examples")
rclone config

# 2. Write config.txt next to generate.sh
cat > config.txt <<'EOF'
Remote: deeparchive:my-bucket/backup
Folders: /home/user/Pictures, /home/user/Documents
SizeOnly: true
EOF

# 3. Generate run.sh
./generate.sh

# 4. Check what would happen, then sync for real
./run.sh --dry-run
./run.sh
```

> **Warning:** `run.sh` uses `rclone sync`. Anything you delete locally is also **deleted on the remote**. Always try `--dry-run` first.

---

## config.txt

A config is made of **blocks**. Each block is one destination (`Remote`) and the folders that go there.

```
# Block 1
Nickname: Photos
Remote: deeparchive:my-bucket/backup
Folders: ["/home/user/Pictures", "/home/user/Videos"]
FastList: true
SizeOnly: true
RcloneFlags: --s3-no-check-bucket --transfers 8

# Block 2: folder list in a separate file
Remote: deeparchive:my-bucket/docs
Folders: folders.txt
```

`folders.txt` has one folder per line:
```
# documents
/home/user/Documents
/srv/share
```

This produces:
```
/home/user/Pictures  -> deeparchive:my-bucket/backup/Pictures
/home/user/Videos    -> deeparchive:my-bucket/backup/Videos
/home/user/Documents -> deeparchive:my-bucket/docs/Documents
/srv/share           -> deeparchive:my-bucket/docs/share
```

### Keys

| Key | Required | Example | What it does |
|---|---|---|---|
| `Nickname` | no | `Photos` | Name shown in the output. Put it **before** `Remote` |
| `Remote` | **yes** | `deeparchive:my-bucket/backup` | Where to sync to. Starts a new block |
| `Folders` | **yes** | `/a, /b` or `["/a", "/b"]` or `folders.txt` | What to sync |
| `FastList` | no | `true` | Adds `--fast-list` (fewer API calls on S3) |
| `SizeOnly` | no | `true` | Adds `--size-only` (recommended for Glacier / Deep Archive) |
| `RcloneFlags` | no | `--exclude "*.tmp" --transfers 8` | Any extra rclone flags |

Good to know:
- Keys are not case-sensitive. Blank lines and lines starting with `#` are ignored.
- Relative paths (in `Folders` or in a folder file) are relative to the config file's folder.
- `generate.sh` warns about typos, incomplete blocks, folders that don't exist, and two folders with the same name going to the same place.

---

## Commands

### generate.sh

| Option | What it does |
|---|---|
| `-c, --config FILE` | Use another config file (default: `config.txt` next to `generate.sh`) |
| `-o, --output FILE` | Write the run script somewhere else (default: `run.sh` next to `generate.sh`) |
| `-d, --dry-run` | Make `run.sh` always run as a dry run |
| `-h, --help` | Show help |

If an `rclone` binary sits next to `generate.sh`, it is used instead of the system one.

### run.sh

| Option | What it does |
|---|---|
| `-d, --dry-run` | Show what would change without changing anything |

`run.sh` exits with `0` if every folder synced, `1` if any failed. That makes it easy to use from cron.

`run.sh` does not read `config.txt`. **Run `./generate.sh` again after every config change.**

---

## Remote examples

Remotes live in `~/.config/rclone/rclone.conf`. You can create them with `rclone config` or write them by hand.

### AWS S3 Glacier Deep Archive

```ini
[deeparchive]
type = s3
provider = AWS
access_key_id = XXXXXXXXXXXXXXXX
secret_access_key = XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
region = ap-southeast-1
storage_class = DEEP_ARCHIVE
```

To use another storage class, change `storage_class`: `STANDARD`, `STANDARD_IA`, `GLACIER_IR`, `GLACIER` or `DEEP_ARCHIVE`.

Deep Archive tips:
- Use `SizeOnly: true` and `FastList: true`. They avoid extra API requests, which cost money.
- Every file is billed for at least **180 days**, even if you delete it sooner.
- To guard against accidental deletes, add `--backup-dir` or `--max-delete` to `RcloneFlags`.

### Encrypted (crypt)

A `crypt` remote encrypts your files before they are uploaded. It sits on top of another remote.

```ini
[deeparchive]
# ... same as above ...

[secret]
type = crypt
remote = deeparchive:my-bucket/encrypted
filename_encryption = standard
directory_name_encryption = true
password = <output of: rclone obscure 'your password'>
password2 = <output of: rclone obscure 'your salt'>
```

Then use the **crypt** remote in `config.txt`:
```
Nickname: Encrypted photos
Remote: secret:backup
Folders: /home/user/Pictures, /home/user/Documents
FastList: true
SizeOnly: true
RcloneFlags: --s3-no-check-bucket
```

`/home/user/Pictures` goes to `secret:backup/Pictures`, which is stored encrypted inside `deeparchive:my-bucket/encrypted/`.

How file names look in the bucket:

| `filename_encryption` | Example in the bucket | Use when |
|---|---|---|
| `standard` | `us8bs8lf00v4ad1bptbq2831j0/7nf42jt54tm159n9jdoisrnnik/...` | You want names hidden (recommended) |
| `obfuscate` | `118.onpxHC/79.nGARSPCQ/208.d.msj` | You only want names unreadable at a glance |
| `off` | `backup/Pictures/a.jpg.bin` | You want readable names, encrypted content |

Crypt tips:
- **Keep a copy of `password` and `password2`** somewhere safe. If you lose them, your backup cannot be decrypted.
- The obscured passwords in `rclone.conf` are not real protection. Run `chmod 600` on the file, or encrypt the whole config in `rclone config` (`s) Set configuration password`) and pass it with `RCLONE_CONFIG_PASS` for cron.
- Keep storage settings (like `storage_class`) on the S3 remote, not on the crypt remote.
- Check an upload with `rclone cryptcheck /home/user/Pictures secret:backup/Pictures`. This does not work for files in Deep Archive until they are restored.

---

## Restoring from Glacier / Deep Archive

Files in Deep Archive can't be downloaded directly. They have to be restored first, which takes hours.

**Normal remote:**
```bash
rclone backend restore deeparchive:my-bucket/backup/Pictures -o priority=Bulk -o lifetime=7
# wait until the restore finishes, then:
rclone copy deeparchive:my-bucket/backup/Pictures /restore/Pictures
```

**Crypt remote** (restore runs on the S3 remote, using the encrypted path):
```bash
# 1. Find the encrypted path
rclone cryptdecode --reverse secret: backup/Pictures

# 2. Restore that path on the S3 remote
rclone backend restore deeparchive:my-bucket/encrypted/<encrypted path> -o priority=Bulk -o lifetime=7

# 3. When restored, copy back through the crypt remote (decrypts on the fly)
rclone copy secret:backup/Pictures /restore/Pictures
```

---

## Testing

`./test_sync.sh` runs the test suite in a temporary folder. It never touches your `config.txt` or `run.sh`.

```bash
./test_sync.sh                 # run all tests
./test_sync.sh test_dry_run    # run one test
./test_sync.sh -v -k           # show output and keep the test folder
```
