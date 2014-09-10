{Subscriber} = require 'emissary'

module.exports =
class FileView extends HTMLElement
  Subscriber.includeInto(this)

  initialize: (@file) ->
    @subscribe @file, 'destroyed', => @unsubscribe()

    @classList.add('file', 'entry', 'list-item')

    @fileName = document.createElement('span')
    @fileName.classList.add('name')
    @appendChild(@fileName)
    @fileName.textContent = @file.name
    @fileName.setAttribute('data-name', @file.name)
    @fileName.setAttribute('data-path', @file.path)

    if @file.symlink
      @fileName.classList.add('icon-file-symlink-file')
    else
      switch @file.type
        when 'binary'     then @fileName.classList.add('icon-file-binary')
        when 'compressed' then @fileName.classList.add('icon-file-zip')
        when 'image'      then @fileName.classList.add('icon-file-media')
        when 'pdf'        then @fileName.classList.add('icon-file-pdf')
        when 'readme'     then @fileName.classList.add('icon-book')
        when 'text'       then @fileName.classList.add('icon-file-text')

    @subscribe @file, 'status-changed', => @updateStatus()
    @updateStatus()

  updateStatus: ->
    @classList.remove('status-ignored', 'status-modified',  'status-added')
    @classList.add("status-#{@file.status}") if @file.status?

  getPath: ->
    @file.path

module.exports = document.registerElement('tree-view-file', prototype: FileView.prototype, extends: 'li')
