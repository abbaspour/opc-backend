branch_from='0bcc9a6da315f3a80df5315b83455a9437a40e71'
BRANCH_NAME='account-1234'

BODY=$(cat <<EOL
{
    "ref": "refs/heads/${BRANCH_NAME}",
    "sha": "${branch_from}"
}
EOL
)

curl -H "Authorization: token ${OAUTH_TOKEN}" -d "${BODY}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/abbaspour/opc-backend/git/refs
