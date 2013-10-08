path = require 'path'

module.exports =
  treeView: null

  activate: (@state) ->
    @state.attached ?= true if @shouldAttach()

    @createView() if @state.attached
    rootView.command 'tree-view:toggle', => @createView().toggle()
    rootView.command 'tree-view:reveal-active-file', => @createView().revealActiveFile()

  deactivate: ->
    @treeView?.deactivate()
    @treeView = null

  serialize: ->
    if @treeView?
      @treeView.serialize()
    else
      @state

  createView: ->
    unless @treeView?
      TreeView = require './tree-view'
      @treeView = new TreeView(@state)
    @treeView

  shouldAttach: ->
    if rootView.getActivePaneItem()
      false
    else if path.basename(project.getPath()) is '.git'
      # Only attach when the project path matches the path to open signifying
      # the .git folder was opened explicitly and not by using Atom as the Git
      # editor.
      project.getPath() is atom.getLoadSettings().pathToOpen
    else
      true
