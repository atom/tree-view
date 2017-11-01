DefaultFileIcons = require './default-file-icons'
{Emitter, CompositeDisposable} = require 'atom'
{repoForPath} = require './helpers'

class IconServices
  constructor: ->
    @emitter = new Emitter()
    @elementIcons = null
    @elementIconDisposables = new CompositeDisposable
    @fileIcons = DefaultFileIcons

  onDidChange: (callback) ->
    @emitter.on 'did-change', callback

  resetElementIcons: ->
    @setElementIcons null

  resetFileIcons: ->
    @setFileIcons DefaultFileIcons

  setElementIcons: (service) ->
    if service isnt @elementIcons
      @elementIconDisposables?.dispose()
      @elementIconDisposables = new CompositeDisposable if service
      @elementIcons = service
      @emitter.emit 'did-change'

  setFileIcons: (service) ->
    if service isnt @fileIcons
      @fileIcons = service
      @emitter.emit 'did-change'

  updateDirectoryIcon: (view) ->
    if @elementIcons?
      @elementIconDisposables.add @elementIcons(view.directoryName, view.directory.path)
    else
      if view.directory.symlink
        iconClass = 'icon-file-symlink-directory'
      else
        iconClass = 'icon-file-directory'
        if view.directory.isRoot
          iconClass = 'icon-repo' if repoForPath(view.directory.path)?.isProjectAtRoot()
        else
          iconClass = 'icon-file-submodule' if view.directory.submodule
      view.directoryName.classList.add iconClass

  updateFileIcon: (view) ->
    classes = ['name', 'icon']
    if @elementIcons?
      @elementIconDisposables.add @elementIcons(view.fileName, view.file.path)
    else
      iconClass = @fileIcons.iconClassForPath(view.file.path, 'tree-view')
    if iconClass
      unless Array.isArray iconClass
        iconClass = iconClass.toString().split(/\s+/g)
      classes.push(iconClass...)
    view.fileName.classList.add(classes...)

module.exports = new IconServices
