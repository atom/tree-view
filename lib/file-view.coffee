{$, fs, View} = require 'atom'
path = require 'path'

module.exports =
class FileView extends View

  @content: ({file} = {}) ->
    @li class: 'file entry list-item', =>
      @span file.getBaseName(), class: 'name icon', outlet: 'fileName'

  file: null

  initialize: ({@file, @project} = {}) ->
    if @file.symlink
      @fileName.addClass('icon-file-symlink-file')
    else
      extension = path.extname(@getPath())
      if fs.isReadmePath(@getPath())
        @fileName.addClass('icon-book')
      else if fs.isCompressedExtension(extension)
        @fileName.addClass('icon-file-zip')
      else if fs.isImageExtension(extension)
        @fileName.addClass('icon-file-media')
      else if fs.isPdfExtension(extension)
        @fileName.addClass('icon-file-pdf')
      else if fs.isBinaryExtension(extension)
        @fileName.addClass('icon-file-binary')
      else
        @fileName.addClass('icon-file-text')

    repo = @project.getRepo()
    if repo?
      @subscribe repo, 'status-changed', (changedPath, status) =>
        @updateStatus() if changedPath is @getPath()
      @subscribe repo, 'statuses-changed', =>
        @updateStatus()

    @updateStatus()

  updateStatus: ->
    @removeClass('status-ignored status-modified status-added')
    repo = @project.getRepo()
    return unless repo?

    filePath = @getPath()
    if repo.isPathIgnored(filePath)
      @addClass('status-ignored')
    else
      status = repo.statuses[filePath]
      if repo.isStatusModified(status)
        @addClass('status-modified')
      else if repo.isStatusNew(status)
        @addClass('status-added')

  getPath: ->
    @file.path
