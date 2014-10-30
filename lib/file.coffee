path = require 'path'
fs = require 'fs-plus'
{CompositeDisposable, Emitter} = require 'event-kit'

module.exports =
class File
  constructor: ({@name, fullPath, @symlink, realpathCache}) ->
    @emitter = new Emitter()
    @subscriptions = new CompositeDisposable()

    @path = fullPath
    @realPath = @path

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

    @subscribeToRepo()
    @updateStatus()

    fs.realpath @path, realpathCache, (error, realPath) =>
      if realPath and realPath isnt @path
        @realPath = realPath
        @updateStatus()

  destroy: ->
    @subscriptions.dispose()
    @emitter.emit('did-destroy')

  onDidDestroy: (callback) ->
    @emitter.on('did-destroy', callback)

  onDidStatusChange: (callback) ->
    @emitter.on('did-status-change', callback)

  # Subscribe to the project' repo for changes to the Git status of this file.
  subscribeToRepo: ->
    repo = atom.project.getRepo()
    return unless repo?

    @subscriptions.add repo.onDidChangeStatus (event) =>
      @updateStatus(repo) if @isPathEqual(event.path)
    @subscriptions.add repo.onDidChangeStatuses =>
      @updateStatus(repo)

  # Update the status property of this directory using the repo.
  updateStatus:  ->
    repo = atom.project.getRepo()
    return unless repo?

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
      @emitter.emit('did-status-change', newStatus)

  isPathEqual: (pathToCompare) ->
    @path is pathToCompare or @realPath is pathToCompare
