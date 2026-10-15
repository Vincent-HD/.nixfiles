# T3 Code patch maintenance

Before changing or rebasing a patch, read [the repair guide](patches/README.md)
and its linked feature contract. Update that contract when intended behavior changes.
Keep documentation in English. Preserve the user's existing work and both independent
feature switches. Do not weaken `--fuzz=0` or silently skip a selected patch to fix a build.
