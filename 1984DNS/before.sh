CERTBOT_ZONE=1w1.one
python3 before.py "$CERTBOT_DOMAIN" "$CERTBOT_ZONE" "$CERTBOT_VALIDATION"
echo "Please wait for 15 minutes, before certbot continues . This is for updating reasons"
sleep 900