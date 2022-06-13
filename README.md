# FortiCare Registration Client
A lightweight script to bulk register Fortinet VM licenses. It's primarily used for trainings and workshops.

## How to use
The bash script requires jq and pdfgrep, so install them before you use it.

- Drop your PDF licenses in a folder (let's call it scanfolder) which have the registration codes
- run the script with:

```
Usage: ./forticare_client.sh [Options...]
                      [ -u | --username ]   FortiCloud API User ID (check https://docs.fortinet.com/document/forticloud/latest/identity-access-management-iam/282341/adding-an-api-user) 
                      [ -p | --password ]   API User password
                      [ -s | --scandir  ]   Path to the directory with the license Certificate PDF files containing the registration codes, exp: ./my_fg_licenses/
                      [ -c | --comment  ]   Comment to be added for the registered device (exp: FWB_Q22022_workshop)
                      [ -h | --help  ]      Display this help
          Example:
          ./forticare_client.sh -u ADCCCC8C-0001-AAB4-BDAF-2B0123456789 -p a0ed080311ebc55bf932001ac860ca9d@1Aa -s ./FC-2-10-CRLK-456-12-3_465454654 -c FortiPOC_FG
```
