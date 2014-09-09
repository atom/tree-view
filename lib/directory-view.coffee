{$, View} = require 'atom'
{Subscriber} = require 'emissary'
Directory = require './directory'
FileView = require './file-view'
File = require './file'

class DirectoryView extends HTMLElement
  Subscriber.includeInto(this)

  initialize: (@directory) ->
    @subscribe @directory, 'destroyed', => @unsubscribe()

    @classList.add('directory', 'entry',  'list-nested-item',  'collapsed')

    header = document.createElement('div')
    @appendChild(header)
    header.classList.add('header', 'list-item')

    @directoryName = document.createElement('span')
    header.appendChild(@directoryName)
    @directoryName.classList.add('name', 'icon')

    @entries = document.createElement('ol')
    @appendChild(@entries)
    @entries.classList.add('entries', 'list-tree')

    if @directory.symlink
      iconClass = 'icon-file-symlink-directory'
    else
      iconClass = 'icon-file-directory'
      if @directory.isRoot
        iconClass = 'icon-repo' if atom.project.getRepo()?.isProjectAtRoot()
      else
        iconClass = 'icon-file-submodule' if @directory.submodule
    @directoryName.classList.add(iconClass)
    @directoryName.textContent = @directory.name
    @directoryName.setAttribute('data-name', @directory.name)
    @directoryName.setAttribute('data-path', @directory.path)

    unless @directory.isRoot
      @subscribe @directory, 'status-changed', @updateStatus
      @updateStatus()

    @expand() if @directory.isExpanded

  updateStatus: =>
    @classList.remove('status-ignored', 'status-modified', 'status-added')
    @classList.add("status-#{@directory.status}") if @directory.status?

  subscribeToDirectory: ->
    @subscribe @directory, 'entry-added', (entry) =>
      view = @createViewForEntry(entry)
      if view instanceof HTMLElement
        @entries.appendChild(view)
      else
        @entries.appendChild(view.element)

    @subscribe @directory, 'entry-added entry-removed', =>
      @trigger 'tree-view:directory-modified' if @isExpanded

  getPath: ->
    @directory.path

  createViewForEntry: (entry) ->
    if entry instanceof Directory
      view = new DirectoryElement()
    else
      view = new FileView()
    view.initialize(entry)

    subscription = @subscribe @directory, 'entry-removed', (removedEntry) ->
      if entry is removedEntry
        view.remove()
        subscription.off()

    view

  reload: ->
    @directory.reload() if @isExpanded

  toggleExpansion: (isRecursive=false) ->
    if @isExpanded then @collapse(isRecursive) else @expand(isRecursive)

  expand: (isRecursive=false) ->
    if not @isExpanded
      @classList.add('expanded')
      @classList.remove('collapsed')
      @subscribeToDirectory()
      @directory.expand()
      @isExpanded = true

    if isRecursive
      for child in @entries.children()
        childView = $(child).view()
        childView.expand(true) if childView instanceof DirectoryView

    false

  collapse: (isRecursive=false) ->
    if isRecursive
      for child in @entries.children()
        childView = $(child).view()
        childView.collapse(true) if childView instanceof DirectoryView and childView.isExpanded

    @classList.remove('expanded')
    @classList.add('collapsed')
    @directory.collapse()
    @unsubscribe(@directory)
    @entries.innerHTML = ''
    @isExpanded = false

DirectoryElement = document.registerElement('tree-view-directory', prototype: DirectoryView.prototype, extends: 'li')
module.exports = DirectoryElement
