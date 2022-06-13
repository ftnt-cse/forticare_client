#!/bin/bash
###################################################################################################################
# bulk register licenses on Forticare. Takes a directory with the registration code PDF files and outputs the license files on the local dir fcapi_storage
# based partly on https://fndn.fortinet.net/index.php?/tools/file/119-fcapi_bash_functionssh/
# Dependencies: pdfgrep, jq

SHORT_ARGS="u:,p:,s:,c:,h"
LONG_ARGS="username:,password:,scandir:,comment:,help"

alias fcapi_results_list_sn='grep -v "^#" | jq .assets | jq .[].serialNumber'
alias fcapi_results_list_detail="grep -v '^#' | jq -c '.assets[] | [.serialNumber,.productModel,.description]'"
export FCAPI_STORAGE="./fcapi_storage"

help(){
    echo "Usage: $0 [Options...]
                      [ -u | --username ]   FortiCloud API User ID (check https://docs.fortinet.com/document/forticloud/latest/identity-access-management-iam/282341/adding-an-api-user) 
                      [ -p | --password ]   API User password
                      [ -s | --scandir  ]   Path to the directory with the license Certificate PDF files containing the registration codes, exp: ./my_fg_licenses/
                      [ -c | --comment  ]   Comment to be added for the registered device (exp: FWB_Q22022_workshop)
                      [ -h | --help  ]      Display this help
          Example:
          $0 -u ADCCCC8C-0001-AAB4-BDAF-2B0123456789 -p a0ed080311ebc55bf932001ac860ca9d@1Aa -s ./FC-2-10-CRLK-456-12-3_465454654 -c FortiPOC_FG"
    exit 2
}

fcapi_login () {
  if [ $# -ne 2 ]
    then
      echo "${FUNCNAME[0]} <USER> <PASS>"
      return
   else
     FCUSER=$1
     FCPASS=$2
     FCAPI_BEARER=
     echo "#Attempting to obtain the token from customerapiauth.fortinet.com using \$FCUSER and \$FCPASS" 
     export FCAPI_BEARER=`curl -s -k -X POST \
       https://customerapiauth.fortinet.com/api/v1/oauth/token/ \
       -H 'Content-Type: application/json' \
       -d '{
         "username": "'$FCUSER'",
         "password": "'$FCPASS'",
         "client_id": "assetmanagement",
         "grant_type": "password"
       }' | jq -r .access_token`
    echo "#Setting \$FCAPI_BEARER --> $FCAPI_BEARER"
    echo "#Storing Results in \$FCAPI_STORAGE=$FCAPI_STORAGE"
    if [ ! -d $FCAPI_STORAGE ];
      then
        mkdir -p $FCAPI_STORAGE
    fi
  fi
}
fcapi_logout () {
  echo "#Revoking Token: $FCAPI_BEARER" 
  curl -s -X POST \
    https://customerapiauth.fortinet.com/api/v1/oauth/revoke_token/ \
    -H 'Content-Type: application/json' \
    -d '{
       "client_id": "assetmanagement",
       "token": "'$FCAPI_BEARER'"
    }'
}

fcapi_download_license () {
   if [ ! -z $1 ] 
     then
       myDATA="$FCAPI_STORAGE/$1-license.json"
       myLIC="$FCAPI_STORAGE/$1.lic"
       echo "#Download license for SN: \"$1\"" 
       curl -s -X POST \
         https://support.fortinet.com/ES/api/registration/v3/licenses/download \
         -H 'Content-Type: application/json' \
         -H 'Authorization: Bearer '$FCAPI_BEARER \
         -d '{
          "serialNumber": "'$1'"
         }' | jq -c > $myDATA
         cat $myDATA | jq .licenseFile -r > $myLIC
         echo "# $myDATA --> $myLIC"
      else
        echo "#Usage: fcapi_download_license <sn>" 
   fi
}

fcapi_register_license() {
   if [ $# -eq 2 ] 
    then
    rc=$1
    desc=$2
       myDATA="$FCAPI_STORAGE/$rc-license.json"
       echo "#Registering License: \"$rc\"" 
       curl -s -X POST \
         https://support.fortinet.com/ES/api/registration/v3/licenses/register \
         -H 'Content-Type: application/json' \
         -H 'Authorization: Bearer '$FCAPI_BEARER \
         -d '{
        "serialNumber": "",
        "licenseRegistrationCode": "'$rc'",
        "description": "'$desc'",
        "partner": "Unknown",
        "isGovernment": false
        }' | jq -c > $myDATA
        if grep -F "errorCode" $myDATA
        then
            echo "# Error Registering '$rc', check '$myDATA' for details"
        else
            license_file="/home/csadmin/fcapi_storage/$(cat $myDATA | jq .assetDetails.serialNumber -r).lic"
            cat $myDATA | jq .assetDetails.license.licenseFile -r > $license_file
            echo "# License $license_file Downloaded"
        fi
   else
    echo "#Usage: fcapi_register_license <registration_code> <description>" 
   fi  
}

fcapi_bulk_register_licenses() {
   if [ $# -eq 2 ] 
    then
    pdf_licenses_dir=$1
    desc=$2
    registration_codes=$(pdfgrep -ore"[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{6}" $pdf_licenses_dir | cut -d":" -f2 | sort |uniq )
    while IFS= read -r line ; do fcapi_register_license $line $desc && sleep 10; done <<< "$registration_codes"
   else
    echo "#Usage: fcapi_bulk_register_licenses <pdf_licenses_dir> <description>" 
   fi  

}

# Main
[ $# -eq 0 ] && help
VALID_ARGS=$(getopt -o $SHORT_ARGS --long $LONG_ARGS -- "$@")
if [[ $? -ne 0 ]]; then
    echo "Could not parse arguments $1"
    help
    exit 1;
fi

eval set -- "$VALID_ARGS"
while [ : ]; do
  case "$1" in
    -u | --username)
        username="$2"
        shift 2
        ;;
    -p | --password)
        password="$2"
        shift 2
        ;;
    -s | --scandir)
        scandir="$2"
        shift 2
        ;;
    -c | --comment)
        comment="$2"
        shift 2
        ;;
    -h | --help)
        help
        exit 3
        ;;
    --) shift; 
        break 
        ;;
    *)
      echo "Unexpected option: $1"
      help
      ;;        
  esac
done


if [ -z "$username" ] || [ -z "$password" ] || [ -z "$scandir" ] || [ -z "$comment" ]
then 
echo "Missing arguments !"
help
exit 3
fi

fcapi_login $username $password
fcapi_bulk_register_licenses $scandir $comment
fcapi_logout