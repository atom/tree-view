{CompositeDisposable} = require 'event-kit'
Directory = require './directory'
FileView = require './file-view'
{repoForPath} = require './helpers'

module.exports =
class DirectoryView
  constructor: (@directory) ->
    @subscriptions = new CompositeDisposable()
    @subscriptions.add @directory.onDidDestroy => @subscriptions.dispose()
    @subscribeToDirectory()

    @element = document.createElement('li')
    @element.setAttribute('is', 'tree-view-directory')
    @element.classList.add('directory', 'entry',  'list-nested-item',  'collapsed')

    @header = document.createElement('div')
    @header.classList.add('header', 'list-item')

    @directoryName = document.createElement('span')
    @directoryName.classList.add('name', 'icon')

    @entries = document.createElement('ol')
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
    @directoryName.dataset.path = @directory.path

    if @directory.squashedNames?
      @directoryName.dataset.name = @directory.squashedNames.join('')
      @directoryName.title = @directory.squashedNames.join('')
      squashedDirectoryNameNode = document.createElement('span')
      squashedDirectoryNameNode.classList.add('squashed-dir')
      squashedDirectoryNameNode.textContent = @directory.squashedNames[0]
      @directoryName.appendChild(squashedDirectoryNameNode)
      @directoryName.appendChild(document.createTextNode(@directory.squashedNames[1]))
    else
      @directoryName.dataset.name = @directory.name
      @directoryName.title = @directory.name
      @directoryName.textContent = @directory.name

    @element.appendChild(@header)
    @header.appendChild(@directoryName)
    @element.appendChild(@entries)

    if @directory.isRoot
      @element.classList.add('project-root')
      @header.classList.add('project-root-header')
    else
      @element.draggable = true
      @subscriptions.add @directory.onDidStatusChange => @updateStatus()
      @updateStatus()

    @expand() if @directory.expansionState.isExpanded

    @element.collapse = @collapse.bind(this)
    @element.expand = @expand.bind(this)
    @element.toggleExpansion = @toggleExpansion.bind(this)
    @element.reload = @reload.bind(this)
    @element.isExpanded = @isExpanded
    @element.updateStatus = @updateStatus.bind(this)
    @element.isPathEqual = @isPathEqual.bind(this)
    @element.getPath = @getPath.bind(this)
    @element.directory = @directory
    @element.header = @header
    @element.entries = @entries
    @element.directoryName = @directoryName

  updateStatus: ->
    @element.classList.remove('status-ignored', 'status-modified', 'status-added')
    @element.classList.add("status-#{@directory.status}") if @directory.status?

  subscribeToDirectory: ->
    @subscriptions.add @directory.onDidAddEntries (addedEntries) =>
      return unless @isExpanded

      numberOfEntries = @entries.children.length

      for entry in addedEntries
        view = @createViewForEntry(entry)

        insertionIndex = entry.indexInParentDirectory
        if insertionIndex < numberOfEntries
          @entries.insertBefore(view.element, @entries.children[insertionIndex])
        else
          @entries.appendChild(view.element)

        numberOfEntries++

  getPath: ->
    @directory.path

  isPathEqual: (pathToCompare) ->
    @directory.isPathEqual(pathToCompare)

  createViewForEntry: (entry) ->
    if entry instanceof Directory
      view = new DirectoryView(entry)
    else
      view = new FileView(entry)

    subscription = @directory.onDidRemoveEntries (removedEntries) ->
      for removedName, removedEntry of removedEntries when entry is removedEntry
        view.element.remove()
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
      @element.isExpanded = @isExpanded
      @element.classList.add('expanded')
      @element.classList.remove('collapsed')
      @directory.expand()

    if isRecursive
      for entry in @entries.children when entry.classList.contains('directory')
        entry.expand(true)

    false

  collapse: (isRecursive=false) ->
    @isExpanded = false
    @element.isExpanded = false

    if isRecursive
      for entry in @entries.children when entry.isExpanded
        entry.collapse(true)

    @element.classList.remove('expanded')
    @element.classList.add('collapsed')
    @directory.collapse()
    @entries.innerHTML = ''
