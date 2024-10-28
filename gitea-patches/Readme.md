# Gitea Patches

`gitea-v1.22.3-activitypub.patch` Security/Privacy improvement for Gitea and Forgejo(the patch is focused on Gitea but should've work on forgejo too!). Return a fake 404 Page when user visiblity is either "private" or "limited"

`gitea-v1.22.3-no-contributorStats.patch` Gitea's Activity: "Recent Commit" "Code Frequency" "Contributors" is a resource-intensive tasks. This could turn small device into flames! This patch is remove 'ContributorStats'.

`gitea-v1.22.3-no-contributorStats-all.patch` same as above, But this patch also remove paths from web.go and templates