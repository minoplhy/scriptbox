import sys
import logging
import json
import re
from dotenv import load_dotenv
from requests import Session
import requests
import os

LOGGER = logging.getLogger(__name__)

CERTBOT_DOMAIN = '1w1.one'
CERTBOT_ZONE = '1w1.one'
CERTBOT_VALIDATION = '12345'

CERTBOT_DOMAIN = sys.argv[1]
CERTBOT_ZONE = sys.argv[2]
CERTBOT_VALIDATION = sys.argv[3]
load_dotenv()
auth_username = os.getenv('AUTH_USERNAME')
auth_password = os.getenv('AUTH_PASSWORD')

domain_id = None
session = None
session = Session()
session.get("https://umsjon.1984.is/accounts/login/?next=/")

# Hit the login page with authentication info to login the session
login_response = session.post(
    "https://umsjon.1984.is/accounts/checkuserauth/",
    data={
    "username": auth_username or "",
    "password": auth_password or "",
},
    )

cookie = session.cookies
for token in cookie:
    if token.name == "csrftoken":
        csrftoken = token.value
    elif token.name == "sessionid":
        sessionid = token.value

CERTBOT_HOST="_acme-challenge."+CERTBOT_DOMAIN
rtype="txt"

# Pull a list of records and check for ours
payload = {
    "Host": "umsjon.1984.is",
    "Referer": "https://umsjon.1984.is",
    "X-CSRFToken": csrftoken,
    "Cookie": "csrftoken="+csrftoken+"; sessionid="+sessionid
}
data = {
	"entry": "new",
	"zone": CERTBOT_ZONE,
	"type": "txt",
	"host": CERTBOT_HOST,
	"ttl": 900,
	"priority": "",
	"rdata": CERTBOT_VALIDATION,
    }
PostRecord = session.post("https://umsjon.1984.is/domains/entry/", data=data, headers=payload)
s = re.findall('"id": "..*\d"', PostRecord.text)
s = str(s)
s = re.sub('(\[|\"|\'|:|]| |id)', "", s)
ZoneFile = open('entry.txt', 'w')
ZoneFile.write(str(s))
exit()