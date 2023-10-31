# Sysstat_Webhook

currently, WIP. But yeah, Discord sucks! They don't rendering SVG.
```
sudo apt install -y librsvg2-bin
```
```
        w) webhook_url=${OPTARG};;    # Discord Webhook URL
        c) CPU="True";;               # CPU
        r) RAM="True";;               # RAM
        d) DISK_IO="True";;           # DISK I/O
        n) NETWORK="True";;           # Network
        f) datafile=${OPTARG};;       # where your data belongs!
```

```
curl -sL https://github.com/minoplhy/scriptbox/raw/main/sysstat_webhook/stat_discord.sh | bash -s -- -w WEBHOOK_URL ARGUMENTS GOES HERE!
```