git clone --depth=1 https://github.com/go-gitea/gitea
cd gitea
LDFLAGS="-X \"code.gitea.io/gitea/modules/setting.AppWorkPath=/var/lib/gitea/\" -X \"code.gitea.io/gitea/modules/setting.CustomConf=/etc/gitea/app.ini\"" GOOS=linux GOARCH=amd64 make build
mv gitea $DESTINATION/gitea
rm -rf $MAKE_DIR