#!/usr/bin/env bash

# assignment function demo script

# Requires: bash curl jq

set -e
set -o pipefail

test -n "$AB_CLIENT_ID" || (echo "AB_CLIENT_ID is not set"; exit 1)
test -n "$AB_CLIENT_SECRET" || (echo "AB_CLIENT_SECRET is not set"; exit 1)
test -n "$AB_NAMESPACE" || (echo "AB_NAMESPACE is not set"; exit 1)

if [ -z "$GRPC_SERVER_URL" ] && [ -z "$EXTEND_APP_NAME" ]; then
  echo "GRPC_SERVER_URL or EXTEND_APP_NAME is not set"
  exit 1
fi

DEMO_PREFIX='challenge_grpc_demo'
STAT_CODE_1='custom-requirements'
STAT_CODE_2='exp'
CHALLENGE_CODE='custom-challenge'

api_curl()
{
  curl -s -D api_curl_http_header.out -o api_curl_http_response.out -w '%{http_code}' "$@" > api_curl_http_code.out
  echo >> api_curl_http_response.out
  cat api_curl_http_response.out
}

get_code_verifier() 
{
  echo $RANDOM | sha256sum | cut -d ' ' -f 1   # For demo only: In reality, it needs to be secure random
}

get_code_challenge()
{
  echo -n "$1" | sha256sum | xxd -r -p | base64 | tr -d '\n' | sed -e 's/+/-/g' -e 's/\//\_/g' -e 's/=//g'
}

clean_up()
{
  echo Getting player ...

  USER_ID=$(api_curl -X GET "${AB_BASE_URL}/iam/v3/admin/namespaces/$AB_NAMESPACE/users?emailAddress=${DEMO_PREFIX}_player@test.com" -H "Authorization: Bearer $ACCESS_TOKEN" -H 'Content-Type: application/json' | jq --raw-output .userId)

  if [ "$USER_ID" != "null" ] && [ -n "$USER_ID" ]; then
    echo Deleting player ...

    api_curl -X DELETE "${AB_BASE_URL}/iam/v3/admin/namespaces/$AB_NAMESPACE/users/$USER_ID/information" -H "Authorization: Bearer $ACCESS_TOKEN"
  fi

  echo Deleting tied challenge ...

  api_curl -X DELETE -s "${AB_BASE_URL}/challenge/v1/admin/namespaces/$AB_NAMESPACE/challenges/$CHALLENGE_CODE/tied" -H "Authorization: Bearer $ACCESS_TOKEN" -H 'Content-Type: application/json' >/dev/null

  echo Deleting stat config ...

  api_curl -X DELETE -s "${AB_BASE_URL}/social/v1/admin/namespaces/$AB_NAMESPACE/stats/$STAT_CODE_1" -H "Authorization: Bearer $ACCESS_TOKEN" -H 'Content-Type: application/json' >/dev/null

  api_curl -X DELETE -s "${AB_BASE_URL}/social/v1/admin/namespaces/$AB_NAMESPACE/stats/$STAT_CODE_2" -H "Authorization: Bearer $ACCESS_TOKEN" -H 'Content-Type: application/json' >/dev/null

  echo Resetting challenge assignment  ...

  api_curl -X DELETE -s "${AB_BASE_URL}/challenge/v1/admin/namespaces/$AB_NAMESPACE/plugins/assignment" -H "Authorization: Bearer $ACCESS_TOKEN" -H 'Content-Type: application/json' >/dev/null
}

trap clean_up EXIT

echo Logging in client ...

ACCESS_TOKEN="$(api_curl -s ${AB_BASE_URL}/iam/v3/oauth/token -H 'Content-Type: application/x-www-form-urlencoded' -u "$AB_CLIENT_ID:$AB_CLIENT_SECRET" -d "grant_type=client_credentials" | jq --raw-output .access_token)"

if [ "$(cat api_curl_http_code.out)" -ge "400" ]; then
  cat api_curl_http_response.out
  exit 1
fi

clean_up

if [ -n "$GRPC_SERVER_URL" ]; then
  echo Registering challenge assignment function $GRPC_SERVER_URL ...

  api_curl -X DELETE -s "${AB_BASE_URL}/challenge/v1/admin/namespaces/$AB_NAMESPACE/plugins/assignment" -H "Authorization: Bearer $ACCESS_TOKEN" -H 'Content-Type: application/json' >/dev/null

  api_curl -X POST -s "${AB_BASE_URL}/challenge/v1/admin/namespaces/$AB_NAMESPACE/plugins/assignment" -H "Authorization: Bearer $ACCESS_TOKEN" -H 'Content-Type: application/json' -d "{\"extendType\": \"CUSTOM\",\"grpcServerAddress\": \"${GRPC_SERVER_URL}\"}" >/dev/null

  if [ "$(cat api_curl_http_code.out)" -ge "400" ]; then
    cat api_curl_http_response.out
    exit 1
  fi
elif [ -n "$EXTEND_APP_NAME" ]; then
  echo Registering challenge assignment function $EXTEND_APP_NAME ...

  api_curl -X DELETE -s "${AB_BASE_URL}/challenge/v1/admin/namespaces/$AB_NAMESPACE/plugins/assignment" -H "Authorization: Bearer $ACCESS_TOKEN" -H 'Content-Type: application/json' >/dev/null

  api_curl -X POST -s "${AB_BASE_URL}/challenge/v1/admin/namespaces/$AB_NAMESPACE/plugins/assignment" -H "Authorization: Bearer $ACCESS_TOKEN" -H 'Content-Type: application/json' -d "{\"appName\": \"${EXTEND_APP_NAME}\",\"extendType\": \"APP\"}" >/dev/null

  if [ "$(cat api_curl_http_code.out)" -ge "400" ]; then
    cat api_curl_http_response.out
    exit 1
  fi
else
  echo "GRPC_SERVER_URL or EXTEND_APP_NAME is not set"
  exit 1
fi

echo Creating stat config ...

api_curl -X POST -s "${AB_BASE_URL}/social/v1/admin/namespaces/$AB_NAMESPACE/stats" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"statCode\":\"$STAT_CODE_1\",\"name\":\"Requirement stat\",\"description\":\"\",\"minimum\":0,\"maximum\":100000,\"defaultValue\":0,\"incrementOnly\":true,\"setAsGlobal\":false,\"setBy\":\"SERVER\",\"tags\":[\"requirement\"]}" >/dev/null

if [ "$(cat api_curl_http_code.out)" -ge "400" ]; then
  cat api_curl_http_response.out
  exit 1
fi

api_curl -X POST -s "${AB_BASE_URL}/social/v1/admin/namespaces/$AB_NAMESPACE/stats" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"statCode\":\"$STAT_CODE_2\",\"name\":\"Experience points\",\"description\":\"\",\"minimum\":0,\"maximum\":1000000,\"defaultValue\":0,\"incrementOnly\":true,\"setAsGlobal\":false,\"setBy\":\"SERVER\",\"tags\":[\"exp\"]}" >/dev/null

if [ "$(cat api_curl_http_code.out)" -ge "400" ]; then
  cat api_curl_http_response.out
  exit 1
fi

echo Creating challenge with custom assignment rule ...

api_curl -X POST -s "${AB_BASE_URL}/challenge/v1/admin/namespaces/$AB_NAMESPACE/challenges" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"assignmentRule\":\"CUSTOM\",\"name\":\"Custom Challenge\",\"code\":\"$CHALLENGE_CODE\",\"description\":\"Challenge description\",\"goalsVisibility\":\"PERIODONLY\",\"rotation\":\"NONE\",\"startDate\":\"2024-08-01T00:00:00Z\",\"activeGoalsPerRotation\":1}" >/dev/null

if [ "$(cat api_curl_http_code.out)" -ge "400" ]; then
  cat api_curl_http_response.out
  exit 1
fi

echo Adding goals to the created challenge ...

api_curl -X POST -s "${AB_BASE_URL}/challenge/v1/admin/namespaces/$AB_NAMESPACE/challenges/$CHALLENGE_CODE/goals" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"name\":\"test 1\",\"code\":\"test-1\",\"isActive\":true,\"description\":\"Goal description\",\"tags\":[\"test\"],\"requirementGroups\":[{\"operator\":\"AND\",\"predicates\":[{\"matcher\":\"GREATER_THAN_EQUAL\",\"parameterName\":\"$STAT_CODE_1\",\"parameterType\":\"STATISTIC\",\"targetValue\":2000}]}],\"rewards\":[{\"type\":\"STATISTIC\",\"itemId\":\"$STAT_CODE_2\",\"itemName\":\"Experience points\",\"qty\":200}]}" >/dev/null

if [ "$(cat api_curl_http_code.out)" -ge "400" ]; then
  cat api_curl_http_response.out
  exit 1
fi

api_curl -X POST -s "${AB_BASE_URL}/challenge/v1/admin/namespaces/$AB_NAMESPACE/challenges/$CHALLENGE_CODE/goals" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"name\":\"test 2\",\"code\":\"test-2\",\"isActive\":true,\"description\":\"Goal description\",\"tags\":[\"test\"],\"requirementGroups\":[{\"operator\":\"AND\",\"predicates\":[{\"matcher\":\"GREATER_THAN_EQUAL\",\"parameterName\":\"$STAT_CODE_1\",\"parameterType\":\"STATISTIC\",\"targetValue\":4000}]}],\"rewards\":[{\"type\":\"STATISTIC\",\"itemId\":\"$STAT_CODE_2\",\"itemName\":\"Experience points\",\"qty\":300}]}" >/dev/null

if [ "$(cat api_curl_http_code.out)" -ge "400" ]; then
  cat api_curl_http_response.out
  exit 1
fi

echo Creating player ...

USER_ID="$(api_curl "${AB_BASE_URL}/iam/v4/public/namespaces/$AB_NAMESPACE/users" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"authType\":\"EMAILPASSWD\",\"country\":\"ID\",\"dateOfBirth\":\"1995-01-10\",\"displayName\":\"Challenge gRPC Player\",\"uniqueDisplayName\":\"Challenge gRPC Player\",\"emailAddress\":\"${DEMO_PREFIX}_player@test.com\",\"password\":\"GFPPlmdb2-\",\"username\":\"${DEMO_PREFIX}_player\"}" | jq --raw-output .userId)"

if [ "$(cat api_curl_http_code.out)" -ge "400" ]; then
  cat api_curl_http_response.out
  exit 1
fi

echo Logging in player ...

CODE_VERIFIER="$(get_code_verifier)"

api_curl "${AB_BASE_URL}/iam/v3/oauth/authorize?scope=commerce+account+social+publishing+analytics&response_type=code&code_challenge_method=S256&code_challenge=$(get_code_challenge "$CODE_VERIFIER")&client_id=$AB_CLIENT_ID"

if [ "$(cat api_curl_http_code.out)" -ge "400" ]; then
  exit 1
fi

REQUEST_ID="$(cat api_curl_http_header.out | grep -o 'request_id=[a-f0-9]\+' | cut -d= -f2)"

api_curl ${AB_BASE_URL}/iam/v3/authenticate \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -d "password=GFPPlmdb2-&user_name=${DEMO_PREFIX}_player@test.com&request_id=$REQUEST_ID&client_id=$AB_CLIENT_ID"

if [ "$(cat api_curl_http_code.out)" -ge "400" ]; then
  exit 1
fi

CODE="$(cat api_curl_http_header.out | grep -o 'code=[a-f0-9]\+' | cut -d= -f2)"

PLAYER_ACCESS_TOKEN="$(api_curl ${AB_BASE_URL}/iam/v3/oauth/token \
    -H 'Content-Type: application/x-www-form-urlencoded' -u "$AB_CLIENT_ID:$AB_CLIENT_SECRET" \
    -d "code=$CODE&grant_type=authorization_code&client_id=$AB_CLIENT_ID&code_verifier=$CODE_VERIFIER" | jq --raw-output .access_token)"

if [ "$(cat api_curl_http_code.out)" -ge "400" ]; then
  cat api_curl_http_response.out
  exit 1
fi

echo Getting user progression ...

api_curl -X GET -s "${AB_BASE_URL}/challenge/v1/public/namespaces/$AB_NAMESPACE/users/me/progress/$CHALLENGE_CODE" \
    -H "Authorization: Bearer $PLAYER_ACCESS_TOKEN" \
    -H 'Content-Type: application/json'

if [ "$(cat api_curl_http_code.out)" -ge "400" ]; then
  exit 1
fi
