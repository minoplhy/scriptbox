# Build Gitea
It's simple, Build Gitea and done. nothing special.

```shell
curl -L https://github.com/minoplhy/scriptbox/raw/main/build_gitea/Linux/build.sh | bash
```
or with a git tag

```shell
curl -L https://github.com/minoplhy/scriptbox/raw/main/build_gitea/Linux/build.sh | bash -s -- "v1.18.0"
```

# Known Issues

- Run the script with sudo or root privileges. can cause a build to fail because of how I get NodeJS, which doesn't want to be fixed right now. Even the script required sudo privileges, though.