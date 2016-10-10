# Learn IDE's Tree View

This fork of Atom's [Tree View package](https://github.com/atom/tree-view) is used by the [Learn IDE](https://learn.co/ide) to provide all of tree-view's functionality while synchronizing with a remote filesystem. It's intended to be used alongside the primary [Learn IDE package](https://github.com/flatiron-labs/learn-ide).

## Methodology
For an understanding of how tree-view works, see [it's repo](https://github.com/atom/tree-view). This fork has been altered [as minimally as possible](https://github.com/atom/tree-view/compare/master...learn-co:master), and should be regularly merging releases from the upstream package.

This minimal amount of change is primarily accomplished by using the [nsync-fs]() module, which provides an fs interface to meet the usage of fs throughout the tree-view package. In other words, this pacakge simply intercepts tree-view's calls to the physical filesystem, and routes them to the virtual filesystem maintained by the `nsync-fs` module. Most other functionality of the package is left unchanged.

