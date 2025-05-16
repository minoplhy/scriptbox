# Build Gitea
It's simple, Build Gitea and done. nothing special.

```shell
curl -L https://github.com/minoplhy/scriptbox/raw/main/build_gitea/Linux/build.sh | bash
```
or with a git tag

```shell
curl -L https://github.com/minoplhy/scriptbox/raw/main/build_gitea/Linux/build.sh | bash -s -- -v "v1.18.0"
```

# Arguments

```bash
while [ ${#} -gt 0 ]; do
    case "$1" in
        --git-tag | -v)
            shift
            GITEA_GIT_TAG=$1
            ;;                          # Gitea Git Tag
        --golang-version | -g)
            shift
            GO_VERSION=$1
            ;;                          # GOLANG Version
        --nodejs-version | -n)
            shift
            NODEJS_VERSION=$1
            ;;                          # NodeJS Version
        --dest | -d )
            shift
            DESTINATION=$1
            ;;                          # Destination Dir
        --static | -s)
            BUILD_STATIC=true
            ;;                          # Also Build Static Assets file
        --system | -s)
            USE_SYSTEM=true
            ;;                          # Use system's NPM and Go
        --type=* )
            BUILD_TYPE="${1#*=}"
            BUILD_TYPE="${BUILD_TYPE,,}"
            case $BUILD_TYPE in
                "gitea")                    BUILD_TYPE="gitea"      ;;
                "forgejo")                  BUILD_TYPE="forgejo"    ;;
                "")
                    echo "ERROR : --type= is empty!"
                    exit 1
                    ;;
                *)
                    echo "ERROR :  Vaild values for --type are -> gitea, forgejo"
                    exit 1
                    ;;
            esac
            ;;
        --source-folder=* )
            SOURCE_FOLDER="${1#*=}"
            case $SOURCE_FOLDER in
                "")
                    echo "ERROR: --source-folder= is empty!"
                    exit 1
                    ;;
                *)
                    ;;
            esac
            ;;                          # Source folder for your gitea/forgejo build / in case --type does not satisfy you
        --patch=* )
            PATCH_FILES="${1#*=}"
            case $PATCH_FILES in
                "")
                    echo "ERROR: --patch= is empty!"
                    exit 1
                    ;;
                *)
                    ;;
            esac                                                    # Add Patches to your Gitea build. Format -> patch1.patch or patch1.patch,https://patch (Absolute path)
            ;;
        --build-arch=* )
            BUILD_ARCH="${1#*=}"
            case $BUILD_ARCH in
                "x86_64")   BUILD_ARCH="x86_64"          ;;
                "aarch64")  BUILD_ARCH="aarch64"         ;;
                "")
                    echo "ERROR : --build-arch= is empty!"
                    exit 1
                    ;;
                *)
                    echo "ERROR :  Vaild values for --build-arch are -> x86_64, aarch64"
                    exit 1
                    ;;
            esac                                                    # Architect for your binary to be build. This is for Cross-compiling etc.
            ;;
        *)
            ;;
    esac
    shift # Shift to next response for parsing
done
```

# Known Issues

- For Alpine Linux: to get `npm` installation working, please ensure community package is enable in `/etc/apk/repositories`
- This script required root privileges because of dependencies installation, which is hard to avoid.