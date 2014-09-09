{Subscriber} = require 'emissary'

module.exports =
class FileView
  Subscriber.includeInto(this)

  constructor: (@file) ->
    @subscribe @file, 'destroyed', => @unsubscribe()

    @element = document.createElement('li')
    @element.classList.add('file', 'entry', 'list-item')

    @fileName = document.createElement('span')
    @element.appendChild(@fileName)
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

    @subscribe @file, 'status-changed', @updateStatus
    @updateStatus()

  updateStatus: =>
    @element.classList.remove('status-ignored', 'status-modified',  'status-added')
    @element.classList.add("status-#{@file.status}") if @file.status?

  getPath: ->
    @file.path
