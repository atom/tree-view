{CompositeDisposable} = require 'event-kit'
path = require 'path'

FileIcons = require './file-icons'

module.exports =
  config:
    squashDirectoryNames:
      type: 'boolean'
      default: false
      title: 'Collapse directories'
      description: 'Collapse directories that only contain a single directory.'
    hideVcsIgnoredFiles:
      type: 'boolean'
      default: false
      title: 'Hide VCS Ignored Files'
      description: 'Don\'t show files and directories ignored by the current project\'s VCS system. For example, projects using Git have these paths defined in their `.gitignore` file.'
    hideIgnoredNames:
      type: 'boolean'
      default: false
      description: 'Don\'t show items matched by the `Ignored Names` core config setting.'
    showOnRightSide:
      type: 'boolean'
      default: false
      description: 'Show the tree view on the right side of the editor instead of the left.'
    sortFoldersBeforeFiles:
      type: 'boolean'
      default: true
      description: 'When listing directory items, list subdirectories before listing files.'

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

  deactivate: ->
    @disposables.dispose()
    @fileIconsDisposable?.dispose()
    @treeView?.deactivate()
    @treeView = null

  consumeFileIcons: (service) ->
    FileIcons.setService(service)
    @fileIconsDisposable = service.onWillDeactivate -> FileIcons.resetService()

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
