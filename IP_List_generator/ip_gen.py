"""
IP List Generator
------------------

Currently, Input file must be in List format for example :

~ ~ ~ ~ ~ ~ ~ ~ ~ ~
1.1.1.1
1.0.0.1
8.8.8.8
2a07:e340::2
2a10:50c0::ad2:ff
~ ~ ~ ~ ~ ~ ~ ~ ~ ~

"""
import pytz
import datetime

filters_set = tuple(["#","###","!"])

def caddy(listname, input, output):
    with open(input ,'r') as f:
        readinput = f.read().splitlines()
    with open(output, 'w') as f:
        f.write("# Caddy IP List Generated\n# Date Generated : " + BuildDate()+"\n#\n")
        f.write("@"+listname+" {\n")
        for line in readinput:
            if line.strip() and not line.startswith((filters_set)):
                f.write("    remote_ip " + line + "\n")
            else:
                pass
        f.write("}")

def nginx(input, output):
    with open(input ,'r') as f:
        readinput = f.read().splitlines()
    with open(output, 'w') as f:
        f.write("# Nginx IP List Generated\n# Date Generated : " + BuildDate()+"\n#\n")
        for line in readinput:
            if line.strip() and not line.startswith((filters_set)):
                f.write("deny " + line + ";\n")
            else:
                pass

def htaccess(input, output):
    with open(input ,'r') as f:
        readinput = f.read().splitlines()
    with open(output, 'w') as f:
        f.write("# htaccess IP List Generated\n# Date Generated : " + BuildDate()+"\n#\n")
        f.write("Order Deny,Allow\n")
        for line in readinput:
            if line.strip() and not line.startswith((filters_set)):
                f.write("Deny from " + line + "\n")
            else:
                pass

def BuildDate():
    UTC = pytz.utc
    date = datetime.datetime.now(UTC)
    return str(date)