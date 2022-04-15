# Public IP address of your ingress controller
export IP="20.127.181.45"

# Name to associate with public IP address
export DNSNAME="tstahltest"

# Get the resource-id of the public ip
export PUBLICIPID=$(az network public-ip list --query "[?ipAddress!=null]|[?contains(ipAddress, '$IP')].[id]" --output tsv)

# Update public ip address with DNS name
az network public-ip update --ids $PUBLICIPID --dns-name $DNSNAME

# Display the FQDN
az network public-ip show --ids $PUBLICIPID --query "[dnsSettings.fqdn]" --output tsv