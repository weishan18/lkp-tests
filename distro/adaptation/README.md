# How to

The OS common adaptations are put in file named as $os \(like debian\). The
adaptations for exact OS are put in file named as $os-$version.

The mapping belongs to one of the below 3 reasons

1. not exist/valid packages, mark it empty to avoid installing error.
1. exist/valid packages, mark it empty if you don't want to install later.
1. exist/valid packages, but its name needs to be adapted for other distro,
   mapping to a new package name, then the new package will be install later.
