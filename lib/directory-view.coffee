{CompositeDisposable} = require 'event-kit'
Directory = require './directory'
FileView = require './file-view'
{repoForPath} = require './helpers'

class DirectoryView extends HTMLElement
  initialize: (@directory) ->
    @subscriptions = new CompositeDisposable()
    @subscriptions.add @directory.onDidDestroy => @subscriptions.dispose()
    @subscribeToDirectory()

    @draggable = true

    @classList.add('directory', 'entry',  'list-nested-item',  'collapsed')

    @header = document.createElement('div')
    @appendChild(@header)
    @header.classList.add('header', 'list-item')

    @directoryName = document.createElement('span')
    @header.appendChild(@directoryName)
    @directoryName.classList.add('name', 'icon')

    @entries = document.createElement('ol')
    @appendChild(@entries)
    @entries.classList.add('entries', 'list-tree')

    if @directory.symlink
      iconClass = 'icon-file-symlink-directory'
    else
      iconClass = 'icon-file-directory'
      if @directory.isRoot
        iconClass = 'icon-repo' if repoForPath(@directory.path)?.isProjectAtRoot()
      else
        iconClass = 'icon-file-submodule' if @directory.submodule
    @directoryName.classList.add(iconClass)
    @directoryName.textContent = @directory.name
    @directoryName.dataset.name = @directory.name
    @directoryName.dataset.path = @directory.path

    if @directory.isRoot
      @classList.add('project-root')
    else
      @subscriptions.add @directory.onDidStatusChange => @updateStatus()
      @updateStatus()

    @expand() if @directory.expansionState.isExpanded

  updateStatus: ->
    @classList.remove('status-ignored', 'status-modified', 'status-added')
    @classList.add("status-#{@directory.status}") if @directory.status?

  subscribeToDirectory: ->
    @subscriptions.add @directory.onDidAddEntries (addedEntries) =>
      return unless @isExpanded

      numberOfEntries = @entries.children.length

      for entry in addedEntries
        view = @createViewForEntry(entry)

        insertionIndex = entry.indexInParentDirectory
        if insertionIndex < numberOfEntries
          @entries.insertBefore(view, @entries.children[insertionIndex])
        else
          @entries.appendChild(view)

        numberOfEntries++

  getPath: ->
    @directory.path

  isPathEqual: (pathToCompare) ->
    @directory.isPathEqual(pathToCompare)

  createViewForEntry: (entry) ->
    if entry instanceof Directory
      view = new DirectoryElement()
    else
      view = new FileView()
    view.initialize(entry)

    subscription = @directory.onDidRemoveEntries (removedEntries) ->
      for removedName, removedEntry of removedEntries when entry is removedEntry
        view.remove()
        subscription.dispose()
        break
    @subscriptions.add(subscription)

    view

  reload: ->
    @directory.reload() if @isExpanded

  toggleExpansion: (isRecursive=false) ->
    if @isExpanded then @collapse(isRecursive) else @expand(isRecursive)

  expand: (isRecursive=false) ->
    unless @isExpanded
      @isExpanded = true
      @classList.add('expanded')
      @classList.remove('collapsed')
      @directory.expand()

    if isRecursive
      for entry in @entries.children when entry instanceof DirectoryView
        entry.expand(true)

    false

  collapse: (isRecursive=false) ->
    @isExpanded = false

    if isRecursive
      for entry in @entries.children when entry.isExpanded
        entry.collapse(true)

    @classList.remove('expanded')
    @classList.add('collapsed')
    @directory.collapse()
    @entries.innerHTML = ''

DirectoryElement = document.registerElement('tree-view-directory', prototype: DirectoryView.prototype, extends: 'li')
module.exports = DirectoryElement
