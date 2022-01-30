import sys
import logging
import re
from bs4 import BeautifulSoup
from dotenv import load_dotenv
from requests import Session
import os

LOGGER = logging.getLogger(__name__)

domain_id = None
session = None
session = Session()
session.get("https://umsjon.1984.is/accounts/login/?next=/")
load_dotenv()
auth_username = os.getenv('AUTH_USERNAME')
auth_password = os.getenv('AUTH_PASSWORD')
rtype="TXT"

    
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
        
payload = {
    "Host": "umsjon.1984.is",
    "Referer": "https://umsjon.1984.is",
    "X-CSRFToken": csrftoken,
    "Cookie": "csrftoken="+csrftoken+"; sessionid="+sessionid
}

file1 = open('entry.txt', 'r')
file = file1.read().split('\n')
for zone_id in file:
     delete_response = session.post(
        "https://umsjon.1984.is/domains/delentry/",
        data={
        "entry": zone_id,
         }, headers=payload,
     )
print(delete_response.text)