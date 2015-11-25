#!/bin/bash

upstream="$1"
my="$2"

[ "$upstream" ] && [ "$my" ] || {
    echo "Usage: $0 UPSTREAM-REMOTE MY-REMOTE" >&2
    exit 1
}

echo "Run 'git remote update'..."
git remote update

git branch -a | fgrep remotes/$upstream/ |
    fgrep -v remotes/$upstream/HEAD |
    while read branch; do
        b=${branch#remotes/$upstream/}
        [ "$b" ] && {
            echo "Sync $branch to remotes/$my/$b..."
            git push $my $branch:refs/heads/$b
        }
    done

echo "Push tags..."
git push --tags $my

