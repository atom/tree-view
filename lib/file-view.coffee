{View} = require 'space-pen'
$ = require 'jquery'
fsUtils = require 'fs-utils'
path = require 'path'

module.exports =
class FileView extends View

  @content: ({file} = {}) ->
    @li class: 'file entry list-group-item', =>
      @span class: 'highlight'
      @span file.getBaseName(), class: 'name', outlet: 'fileName'

  file: null

  initialize: ({@file, @project} = {}) ->
    if @file.symlink
      @fileName.addClass('icon-file-symlink-file')
    else
      extension = path.extname(@getPath())
      if fsUtils.isReadmePath(@getPath())
        @fileName.addClass('icon-book')
      else if fsUtils.isCompressedExtension(extension)
        @fileName.addClass('icon-file-zip')
      else if fsUtils.isImageExtension(extension)
        @fileName.addClass('icon-file-media')
      else if fsUtils.isPdfExtension(extension)
        @fileName.addClass('icon-file-pdf')
      else if fsUtils.isBinaryExtension(extension)
        @fileName.addClass('icon-file-binary')
      else
        @fileName.addClass('icon-file-text')

    repo = project.getRepo()
    if repo?
      @subscribe repo, 'status-changed', (changedPath, status) =>
        @updateStatus() if changedPath is @getPath()
      @subscribe repo, 'statuses-changed', =>
        @updateStatus()

    @updateStatus()

  updateStatus: ->
    @removeClass('subtle warning info ignored modified new')
    repo = project.getRepo()
    return unless repo?

    filePath = @getPath()
    if repo.isPathIgnored(filePath)
      @addClass('subtle ignored')
    else
      status = repo.statuses[filePath]
      if repo.isStatusModified(status)
        @addClass('warning modified')
      else if repo.isStatusNew(status)
        @addClass('info new')

  getPath: ->
    @file.path
