{View} = require 'atom'

module.exports =
class FileView extends View
  @content: ->
    @li class: 'file entry list-item', =>
      @span class: 'name icon', outlet: 'fileName'

  initialize: (@file) ->
    @fileName.text(@file.name)
    @fileName.attr('data-name', @file.name)
    @fileName.attr('data-path', @file.path)

    if @file.symlink
      @fileName.addClass('icon-file-symlink-file')
    else
      switch @file.type
        when 'binary'     then @fileName.addClass('icon-file-binary')
        when 'compressed' then @fileName.addClass('icon-file-zip')
        when 'image'      then @fileName.addClass('icon-file-media')
        when 'pdf'        then @fileName.addClass('icon-file-pdf')
        when 'readme'     then @fileName.addClass('icon-book')
        when 'text'       then @fileName.addClass('icon-file-text')

    @subscribe @file, 'status-changed', @updateStatus
    @updateStatus()

  updateStatus: =>
    @removeClass('status-ignored status-modified status-added')
    @addClass("status-#{@file.status}") if @file.status?

  getPath: ->
    @file.path

  beforeRemove: ->
    @file.destroy()
