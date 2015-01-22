{CompositeDisposable} = require 'event-kit'
path = require 'path'

module.exports =
  config:
    hideVcsIgnoredFiles:
      type: 'boolean'
      default: false
      title: 'Hide VCS Ignored Files'
    hideIgnoredNames:
      type: 'boolean'
      default: false
    showOnRightSide:
      type: 'boolean'
      default: false
    automaticallyRevealFile:
      type: 'string'
      default: 'Never'
      enum: [
        'Never',
        'Upon Opening',
        'Upon Focusing'
      ]

  treeView: null

  activate: (@state) ->
    @disposables = new CompositeDisposable
    @state.attached ?= true if @shouldAttach()

    @createView() if @state.attached

    @disposables.add atom.commands.add('atom-workspace', {
      'tree-view:show': => @createView().show()
      'tree-view:toggle': => @createView().toggle()
      'tree-view:toggle-focus': => @createView().toggleFocus()
      'tree-view:reveal-active-file': => @createView().revealActiveFile()
      'tree-view:toggle-side': => @createView().toggleSide()
      'tree-view:add-file': => @createView().add(true)
      'tree-view:add-folder': => @createView().add(false)
      'tree-view:duplicate': => @createView().copySelectedEntry()
      'tree-view:remove': => @createView().removeSelectedEntries()
      'tree-view:rename': => @createView().moveSelectedEntry()
    })

    workspaceElement = atom.views.getView(atom.workspace)

    atom.workspace.onDidOpen ->
      if atom.config.get('tree-view.automaticallyRevealFile') is 'Upon Opening'
        atom.commands.dispatch workspaceElement, 'tree-view:reveal-active-file'

    atom.workspace.onDidChangeActivePaneItem ->
      if atom.config.get('tree-view.automaticallyRevealFile') is 'Upon Focusing'
        atom.commands.dispatch workspaceElement, 'tree-view:reveal-active-file'

  deactivate: ->
    @disposables.dispose()
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
    projectPath = atom.project.getPaths()[0]
    if atom.workspace.getActivePaneItem()
      false
    else if path.basename(projectPath) is '.git'
      # Only attach when the project path matches the path to open signifying
      # the .git folder was opened explicitly and not by using Atom as the Git
      # editor.
      projectPath is atom.getLoadSettings().pathToOpen
    else
      true
