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
        --static | -s) 
            BUILD_STATIC=true 
            ;;                          # Also Build Static Assets file
        --type=* )
            BUILD_TYPE="${1#*=}"
            BUILD_TYPE="${BUILD_TYPE,,}"
            case $BUILD_TYPE in
                "gitea")                    BUILD_TYPE="gitea"      ;;
                "forgejo")                  BUILD_TYPE="forgejo"  ;;
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
        *)
            ;;
    esac
    shift # Shift to next response for parsing
done
```

# Known Issues

- This script required root privileges because of dependencies installation, which is hard to avoid.