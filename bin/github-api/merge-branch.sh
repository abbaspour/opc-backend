base='account-1234'
head='main'

BODY=$(cat <<EOL
{
    "base": "${base}",
    "head": "${head}",
    "commit_message": "merge from cli"
}
EOL
)

curl -H "Authorization: token ${OAUTH_TOKEN}" -d "${BODY}" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/abbaspour/opc-backend/merges
