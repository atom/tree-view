module.exports =
  treeView: null

  activate: (@state) ->
    @state.attached ?= true unless rootView.getActivePaneItem()

    @createView() if @state.attached
    rootView.command 'tree-view:toggle', => @createView().toggle()
    rootView.command 'tree-view:reveal-active-file', => @createView().revealActiveFile()
    atom.contextMenu.add '.tree-view', { label: 'Add file', command: 'tree-view:add' }

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
