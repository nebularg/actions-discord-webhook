#!/usr/bin/env bash

case "$INPUT_STATUS" in
	success)
		STATUS="passed"
		STATUS_COLOR=3066993
		;;
	failure)
		STATUS="failed"
		STATUS_COLOR=15158332
		;;
	cancelled)
		STATUS="cancelled"
		STATUS_COLOR=15909962
		;;
	*)
		echo "ERROR! Unknown status \"$INPUT_STATUS\""
		exit 0
		;;
esac

STATUS_MESSAGE="Workflow $GITHUB_WORKFLOW ($GITHUB_EVENT_NAME) $STATUS for $GITHUB_REPOSITORY"

AUTHOR_NAME=$( git -C "$GITHUB_WORKSPACE" log -1 "$GITHUB_SHA" --pretty="%aN" )
COMMITTER_NAME=$( git -C "$GITHUB_WORKSPACE" log -1 "$GITHUB_SHA" --pretty="%cN" )
if [ "$AUTHOR_NAME" = "$COMMITTER_NAME" ]; then
	COMMITTER="$COMMITTER_NAME committed"
else
	COMMITTER="$AUTHOR_NAME authored and $COMMITTER_NAME committed"
fi

COMMIT_SUBJECT=$( git -C "$GITHUB_WORKSPACE" log -1 "$GITHUB_SHA" --pretty="%s" )
COMMIT_BODY=$( git -C "$GITHUB_WORKSPACE" log -1 "$GITHUB_SHA" --pretty="%b" | sed -e $'s/\r//g' )

if [ "$GITHUB_EVENT_NAME" = "pull_request" ]; then
	TITLE=$( jq '.pull_request.title' "$GITHUB_EVENT_PATH" )
	DESCRIPTION=$( echo -n "$COMMIT_SUBJECT" | jq -sR '.' )
	CONTENT_URL=$( jq -r '.pull_request.html_url' "$GITHUB_EVENT_PATH" )
	STATUS_URL="$CONTENT_URL/checks"
	COMMIT_URL="[\`${GITHUB_SHA:0:7}\`]($CONTENT_URL/commits/$GITHUB_SHA)"
	BRANCH_URL=$( jq -r '"[`\(.pull_request.head.label)`](\(.pull_request.head.repo.html_url)/tree/\(.pull_request.head.ref))"' "$GITHUB_EVENT_PATH" )
else
	TITLE=$( echo -n "$COMMIT_SUBJECT" | jq -sR '.' )
	NUM_COMMITS=$( jq -r '.commits | length' "$GITHUB_EVENT_PATH" )
	if [ "$NUM_COMMITS" -gt 1 ]; then
		DESCRIPTION=$( echo -ne "$COMMIT_BODY\n[+$NUM_COMMITS commits]\n\n$COMMITTER" | jq -sR '.' )
	else
		DESCRIPTION=$( echo -ne "$COMMIT_BODY\n\n$COMMITTER" | jq -sR '.' )
	fi
	CONTENT_URL=$( jq -r '.compare' "$GITHUB_EVENT_PATH" )
	STATUS_URL="https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA/checks"
	COMMIT_URL="[\`${GITHUB_SHA:0:7}\`](https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA)"
	_BRANCH=${GITHUB_REF##*/}
	BRANCH_URL="[\`$_BRANCH\`](https://github.com/$GITHUB_REPOSITORY/tree/$_BRANCH)"
fi

PAYLOAD_DATA=$(
cat <<EOF
{
	"username": "GitHub Actions",
	"avatar_url": "https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png",
	"embeds": [
		{
			"title": $TITLE,
			"type": "rich",
			"description": $DESCRIPTION,
			"url": "$CONTENT_URL",
			"timestamp": "$( TZ='' printf "%(%FT%TZ)T" )",
			"color": $STATUS_COLOR,
			"author": {
				"name": "$STATUS_MESSAGE",
				"url": "$STATUS_URL"
			},
			"fields": [
				{
					"name": "Commit",
					"value": "$COMMIT_URL",
					"inline": true
				},
				{
					"name": "Branch",
					"value": "$BRANCH_URL",
					"inline": true
				}
			]
		}
	]
}
EOF
)

echo -n "Sending status to Discord..."
curl -sf -H "Content-Type: application/json" -d "$PAYLOAD_DATA" "$INPUT_WEBHOOK_URL" && echo "success!" || echo "failure!"
