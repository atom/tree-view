{CompositeDisposable} = require 'event-kit'
path = require 'path'

FileIcons = require './file-icons'

nsync = require 'nsync-fs'

module.exports =
  treeView: null

  activate: (@state) ->
    @helperDisposables = require('./nsync/nsync-helper')(@state)

    treeViewisDisabled = localStorage.disableTreeView is 'true'

    if not treeViewisDisabled
      @warnIfAtomsTreeViewIsActive()

      window.addEventListener 'offline', -> nsync.resetConnection()
      window.addEventListener 'online', -> nsync.safeResetConnection()

      document.body.classList.add('learn-ide')

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
    nsync.cache() unless @preventCache
    window.removeEventListener 'offline', -> nsync.resetConnection()
    window.removeEventListener 'online', -> nsync.safeResetConnection()
    @disposables.dispose()
    @helperDisposables.dispose()
    @fileIconsDisposable?.dispose()
    @treeView?.deactivate()
    @treeView = null

  consumeFileIcons: (service) ->
    FileIcons.setService(service)
    @fileIconsDisposable = service.onWillDeactivate ->
      FileIcons.resetService()
      @treeView?.updateRoots()
    @treeView?.updateRoots()

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

  warnIfAtomsTreeViewIsActive: ->
    if atom.packages.getActivePackage('tree-view')?
      atom.notifications.addWarning 'Learn IDE: two tree packages enabled',
        detail: """Atom's core tree-view package is enabled. You may want
                to disable it while using the Learn IDE, which uses its
                own tree package (learn-ide-tree)."""
        dismissable: true

