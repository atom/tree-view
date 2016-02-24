# Tree View package [![Build Status](https://travis-ci.org/atom/tree-view.svg?branch=master)](https://travis-ci.org/atom/tree-view)

Explore and open files in the current project.

This fork successfully blocks dragging and dropping of files using a configuration parameter. See issue #566.
This solution was not merged due to a decision to limit the number of configuration parameters, as well as a desire to solve in a global manner.

I'm leaving the solution here for others.

Changes to files:

package.json            - Added **allowDragAndDrop** parameter.

tree-view.coffee        - Added one-liner to refresh tree-view on a change to **allowDragAndDrop**.

directory-view.coffee   - Added one-liner to set HTMLElement **draggable** attribute with **allowDragAndDrop** value.

file-view.coffee        - Added one-liner to set HTMLElement **draggable** attribute with **allowDragAndDrop** value.

tree-view-spec.coffee   - Added tests.
