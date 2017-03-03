{Disposable, CompositeDisposable} = require 'event-kit'
path = require 'path'

FileIcons = require './file-icons'
TreeView = require './tree-view'

module.exports =
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
      'tree-view:show-current-file-in-file-manager': => @createView().showCurrentFileInFileManager()
    })

  deactivate: ->
    @disposables.dispose()
    @fileIconsDisposable?.dispose()
    @treeView?.deactivate()
    @treeView = null

  consumeFileIcons: (service) ->
    FileIcons.setService(service)
    @treeView?.updateRoots()
    new Disposable =>
      FileIcons.resetService()
      @treeView?.updateRoots()

  serialize: ->
    if @treeView?
      @treeView.serialize()
    else
      @state

  createView: ->
    unless @treeView?
      @treeView = new TreeView(@state)
    @treeView

  shouldAttach: ->
    projectPath = atom.project.getPaths()[0] ? ''
    if atom.workspace.getActivePaneItem()
      false
    else if path.basename(projectPath) is '.git'
      # Only attach when the project path matches the path to open signifying
      # the .git folder was opened explicitly and not by using Atom as the Git
      # editor.
      projectPath is atom.getLoadSettings().pathToOpen
    else
      true
