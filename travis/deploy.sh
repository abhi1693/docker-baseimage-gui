#!/bin/bash
#
# This is the deployment script for Travis CI.
#
# The deployment consists in:
#   * Checkout the branch associated to the current docker tag.
#   * Generate the Dockerfile for the current Docker tag.
#   * Commit the generated Dockerfile.
#   * Apply the same git tag that triggered the build.
#   * Push the changes.

set -e # Exit immediately if a command exits with a non-zero status.
set -u # Treat unset variables as an error.

# Sanity check: Deployment should be done only when a tag is applied to the
# commit.
if [ -z "$TRAVIS_TAG" ]; then
    echo "ERROR: No git tag."
    exit 1
fi

# Deployment should be done only on the master branch.  Exit now if it's not
# the case.
# NOTE: Cannot use TRAVIS_BRANCH, which is set to TRAVIS_TAG.
GIT_BRANCH="$(git branch --contains tags/$TRAVIS_TAG  | tr -d '* ')"
if [ "$GIT_BRANCH" != "master" ]; then
    echo "Skipping deployment because tag '$TRAVIS_TAG' is on the '$GIT_BRANCH' branch."
    exit 0
fi

echo "TRAVIS_TAG=$TRAVIS_TAG"
echo "GIT_TAG='$GIT_BRANCH'"

TARGET_BRANCH=deploy-$DOCKERTAG
REPO=$(git config remote.origin.url)

# Adjust git configuration.
git config remote.origin.fetch +refs/heads/*:refs/remotes/origin/*
git config user.name "Travis CI"
git config user.email "$COMMIT_AUTHOR_EMAIL"

# Update repository to get all remote branches.
echo "Updating repository..."
git fetch

# Switch to proper branch and sync it with master.
echo "Checking out branch $TARGET_BRANCH..."
if git branch -a | grep -w -q $TARGET_BRANCH; then
    git checkout --track origin/$TARGET_BRANCH
else
    git branch $TARGET_BRANCH
    git checkout $TARGET_BRANCH
fi

# Merge the master branch.
echo "Merging master in $TARGET_BRANCH..."
git merge --no-edit master

# Generate and validate the Dockerfile.
echo "Generating and validating the Dockerfile..."
travis/before_script.sh
sed -i "1s/^/# DO NOT EDIT - Dockerfile generated by Travis CI (Build $TRAVIS_BUILD_NUMBER)\n/" Dockerfile

# Add and commit the Dockerfile.
git add Dockerfile
git commit \
    --allow-empty \
    -m "Automatic Dockerfile deployment from Travis CI (build $TRAVIS_BUILD_NUMBER)." \
    --author="Travis CI <$COMMIT_AUTHOR_EMAIL>"

# Create the git tag.
git tag "${DOCKERTAG}-${TRAVIS_TAG}"

# Push changes.
echo "The following commit, with tag '${DOCKERTAG}-${TRAVIS_TAG}', will be pushed to branch $TARGET_BRANCH:"
git show
echo "Pushing changes to repository..."
git push ${REPO/https:\/\//https:\/\/$GIT_PERSONAL_ACCESS_TOKEN@} $TARGET_BRANCH