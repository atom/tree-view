path = require 'path'

module.exports =
  configDefaults:
    hideVcsIgnoredFiles: false
    hideIgnoredNames: false
    showOnRightSide: false

  treeView: null

  activate: (@state) ->
    @state.attached ?= true if @shouldAttach()

    @createView() if @state.attached
    atom.workspaceView.command 'tree-view:show', => @createView().show()
    atom.workspaceView.command 'tree-view:toggle', => @createView().toggle()
    atom.workspaceView.command 'tree-view:toggle-focus', => @createView().toggleFocus()
    atom.workspaceView.command 'tree-view:reveal-active-file', => @createView().revealActiveFile()
    atom.workspaceView.command 'tree-view:toggle-side', => @createView().toggleSide()
    atom.workspaceView.command 'tree-view:add-file', => @createView().add(true)
    atom.workspaceView.command 'tree-view:add-folder', => @createView().add(false)
    atom.workspaceView.command 'tree-view:duplicate', => @createView().copySelectedEntry()
    atom.workspaceView.command 'tree-view:remove', => @createView().removeSelectedEntries()

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
    if atom.workspace.getActivePaneItem()
      false
    else if path.basename(atom.project.getPath()) is '.git'
      # Only attach when the project path matches the path to open signifying
      # the .git folder was opened explicitly and not by using Atom as the Git
      # editor.
      atom.project.getPath() is atom.getLoadSettings().pathToOpen
    else
      true
