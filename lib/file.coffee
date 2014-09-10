path = require 'path'
fs = require 'fs-plus'
{Emitter, Subscriber} = require 'emissary'

module.exports =
class File
  Emitter.includeInto(this)
  Subscriber.includeInto(this)

  constructor: ({@name, fullPath, @symlink}) ->
    @path = fullPath

    extension = path.extname(@path)
    if fs.isReadmePath(@path)
      @type = 'readme'
    else if fs.isCompressedExtension(extension)
      @type = 'compressed'
    else if fs.isImageExtension(extension)
      @type = 'image'
    else if fs.isPdfExtension(extension)
      @type = 'pdf'
    else if fs.isBinaryExtension(extension)
      @type = 'binary'
    else
      @type = 'text'

    repo = atom.project.getRepo()
    if repo?
      @subscribeToRepo(repo)
      @updateStatus(repo)

    fs.realpath @path, (error, realPath) =>
      if realPath and realPath isnt @path
        @path = realPath
        @updateStatus(repo) if repo?

  destroy: ->
    @unsubscribe()
    @emit 'destroyed'

  # Subscribe to the given repo for changes to the Git status of this directory.
  subscribeToRepo: (repo)->
    @subscribe repo, 'status-changed', (changedPath, status) =>
      @updateStatus(repo) if changedPath is @path
    @subscribe repo, 'statuses-changed', =>
      @updateStatus(repo)

  # Update the status property of this directory using the repo.
  updateStatus: (repo) ->
    newStatus = null
    if repo.isPathIgnored(@path)
      newStatus = 'ignored'
    else
      status = repo.getCachedPathStatus(@path)
      if repo.isStatusModified(status)
        newStatus = 'modified'
      else if repo.isStatusNew(status)
        newStatus = 'added'

    if newStatus isnt @status
      @status = newStatus
      @emit 'status-changed', newStatus
