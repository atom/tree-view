{CompositeDisposable} = require 'event-kit'
IconServices = require './icon-services'

module.exports =
class FileView extends HTMLElement
  initialize: (@file) ->
    @subscriptions = new CompositeDisposable()
    @subscriptions.add @file.onDidDestroy => @subscriptions.dispose()

    @draggable = true

    @classList.add('file', 'entry', 'list-item')

    @fileName = document.createElement('span')
    @fileName.classList.add('name', 'icon')
    @appendChild(@fileName)
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

  updateStatus: ->
    @classList.remove('status-ignored', 'status-modified',  'status-added')
    @classList.add("status-#{@file.status}") if @file.status?

  getPath: ->
    @fileName.dataset.path

  isPathEqual: (pathToCompare) ->
    @file.isPathEqual(pathToCompare)

module.exports = document.registerElement('tree-view-file', prototype: FileView.prototype, extends: 'li')
