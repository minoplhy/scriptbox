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
        v) GITEA_GIT_TAG=${OPTARG};;        # Gitea Git Tag
        g) GO_VERSION=${OPTARG};;           # GOLANG Version
        n) NODEJS_VERSION=${OPTARG};;       # NodeJS Version
```

# Known Issues

- This script required root privileges because of dependencies installation, which is hard to avoid.