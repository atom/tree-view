# Tree View package
[![OS X Build Status](https://travis-ci.org/atom/tree-view.svg?branch=master)](https://travis-ci.org/atom/tree-view)
[![Windows Build Status](https://ci.appveyor.com/api/projects/status/com793ehi0hajrkd/branch/master?svg=true)](https://ci.appveyor.com/project/Atom/tree-view/branch/master) [![Dependency Status](https://david-dm.org/atom/tree-view.svg)](https://david-dm.org/atom/tree-view)


Explore and open files in the current project.

Press <kbd>ctrl-\\</kbd> or <kbd>cmd-\\</kbd> to open/close the Tree view and <kbd>alt-\\</kbd> or <kbd>ctrl-0</kbd> to focus it.

When the Tree view has focus you can press <kbd>a</kbd>, <kbd>shift-a</kbd>, <kbd>m</kbd>, or <kbd>delete</kbd> to add, move
or delete files and folders.

![](https://f.cloud.github.com/assets/671378/2241932/6d9cface-9ceb-11e3-9026-31d5011d889d.png)

## API

The Tree View displays icons next to files. These icons are customizable by installing a package that provides an `atom.file-icons` service.

The `atom.file-icons` service must provide the following methods:

* `iconClassForPath(path)` - Returns a CSS class name to add to the file view
