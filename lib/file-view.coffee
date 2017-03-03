{CompositeDisposable} = require 'event-kit'
FileIcons = require './file-icons'

module.exports =
class FileView
  constructor: (@file) ->
    @subscriptions = new CompositeDisposable()
    @subscriptions.add @file.onDidDestroy => @subscriptions.dispose()

    @element = document.createElement('li')
    @element.setAttribute('is', 'tree-view-file')
    @element.draggable = true
    @element.classList.add('file', 'entry', 'list-item')

    @fileName = document.createElement('span')
    @fileName.classList.add('name', 'icon')
    @element.appendChild(@fileName)
    @fileName.textContent = @file.name
    @fileName.title = @file.name
    @fileName.dataset.name = @file.name
    @fileName.dataset.path = @file.path

    iconClass = FileIcons.getService().iconClassForPath(@file.path, "tree-view")
    if iconClass
      unless Array.isArray iconClass
        iconClass = iconClass.toString().split(/\s+/g)
      @fileName.classList.add(iconClass...)

    @subscriptions.add @file.onDidStatusChange => @updateStatus()
    @updateStatus()

    @element.getPath = @getPath.bind(this)
    @element.isPathEqual = @isPathEqual.bind(this)
    @element.file = @file
    @element.fileName = @fileName
    @element.updateStatus = @updateStatus.bind(this)

  updateStatus: ->
    @element.classList.remove('status-ignored', 'status-modified',  'status-added')
    @element.classList.add("status-#{@file.status}") if @file.status?

  getPath: ->
    @fileName.dataset.path

  isPathEqual: (pathToCompare) ->
    @file.isPathEqual(pathToCompare)
