{CompositeDisposable} = require 'event-kit'
IconServices = require './icon-services'

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

    @updateIcon()
    @subscriptions.add @file.onDidStatusChange => @updateStatus()
    @subscriptions.add IconServices.onDidChange => @updateIcon()
    @updateStatus()

  updateIcon: ->
    if service = IconServices.get 'element-icons'
      @subscriptions.add service @fileName, @file.path
    else
      service = IconServices.get 'file-icons'
      iconClass = service.iconClassForPath(@file.path, "tree-view")

    classes = ['name', 'icon']
    if iconClass
      unless Array.isArray iconClass
        iconClass = iconClass.toString().split(/\s+/g)
      classes.push(iconClass...)
    @fileName.classList.add(classes...)

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
