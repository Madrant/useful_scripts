#!/bin/bash

read -r -d '' commit_filter << EOM
'
if [ "\${GIT_AUTHOR_NAME}" = "user" ]; then
    GIT_AUTHOR_NAME="Madrant";
    GIT_AUTHOR_EMAIL="a.polygaev@gmail.com";

    GIT_COMMITTER_NAME="Madrant";
    GIT_COMMITTER_EMAIL="a.polygaev@gmail.com";
fi
'
EOM

git_commit_filter_cmd="git filter-branch -f --env-filter ${commit_filter} HEAD"

echo -e "Commit filter:\n${commit_filter}"

echo "Executing: ${git_commit_filter_cmd}"
eval ${git_commit_filter_cmd}
