{CompositeDisposable} = require 'event-kit'
Directory = require './directory'
FileView = require './file-view'
{repoForPath} = require './helpers'

class DirectoryView extends HTMLElement
  initialize: (@directory) ->
    @subscriptions = new CompositeDisposable()
    @subscriptions.add @directory.onDidDestroy => @subscriptions.dispose()
    @subscribeToDirectory()

    @classList.add('directory', 'entry',  'list-nested-item',  'collapsed')

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
        repoForPath(@directory.path)?.isProjectAtRoot().then (projectAtRoot) =>
          @directoryName.classList.add('icon-repo') if projectAtRoot
      else
        repoForPath(@directory.path)?.isSubmodule(@directory.path).then (isSubmodule) =>
          @directoryName.classList.add('icon-file-submodule') if isSubmodule

    @directoryName.classList.add(iconClass)
    @directoryName.dataset.name = @directory.name
    @directoryName.title = @directory.name
    @directoryName.dataset.path = @directory.path

    if @directory.squashedName?
      @squashedDirectoryName = document.createElement('span')
      @squashedDirectoryName.classList.add('squashed-dir')
      @squashedDirectoryName.textContent = @directory.squashedName

    directoryNameTextNode = document.createTextNode(@directory.name)

    @appendChild(@header)
    if @squashedDirectoryName?
      @directoryName.appendChild(@squashedDirectoryName)
    @directoryName.appendChild(directoryNameTextNode)
    @header.appendChild(@directoryName)
    @appendChild(@entries)

    if @directory.isRoot
      @classList.add('project-root')
    else

      @draggable = true
      @subscriptions.add @directory.onDidStatusChange => @updateStatus(arguments[0])
      @updateStatus()

    @expand() if @directory.expansionState.isExpanded

  updateStatus: (status) ->
    @classList.remove('status-ignored', 'status-modified', 'status-added')
    if status?
      @classList.add("status-#{status}")
    else
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
    initial = Promise.resolve(true)
    unless @isExpanded
      @isExpanded = true
      @classList.add('expanded')
      @classList.remove('collapsed')
      initial = initial.then => @directory.expand()

    if isRecursive
      children = (entry for entry in @entries.children when entry instanceof DirectoryView)
      firstEntry = children.shift()
      if firstEntry
        initial.then => first.expandAsync()
        reducer = (curr, next) =>
          curr.then =>
            next.expand(true)
        children.reduce reducer, initial
      else
        initial.then =>
          @expandAsync()
        .then (children) =>
          for child in children when child instanceof DirectoryView
            child.expand(true)
    false

  # Non-recursive ::expand that returns the promise from the model, for use in
  # recursively revealing the active file
  expandAsync: ->
    if @isExpanded
      return Promise.resolve(@entries.children)
    else
      @isExpanded = true
      @classList.add('expanded')
      @classList.remove('collapsed')
      return @directory.expand().then => @entries.children

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
