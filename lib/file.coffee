path = require 'path'
fs = require 'fs-plus'
{Model} = require 'theorist'

module.exports =
class File extends Model
  @properties
    file: null
    status: null # Either null, 'added', 'ignored', or 'modified'

  @::accessor 'name', -> @file.getBaseName()
  @::accessor 'symlink', -> @file.symlink
  @::accessor 'type', ->
    extension = path.extname(@path)
    if fs.isReadmePath(@path)
      'readme'
    else if fs.isCompressedExtension(extension)
      'compressed'
    else if fs.isImageExtension(extension)
      'image'
    else if fs.isPdfExtension(extension)
      'pdf'
    else if fs.isBinaryExtension(extension)
      'binary'
    else
      'text'

  constructor: ->
    super
    repo = atom.project.getRepo()

    try
      @path = fs.realpathSync(@file.getPath())
    catch error
      @path = @file.getPath()

    if repo?
      @subscribeToRepo(repo)
      @updateStatus(repo)

  # Called by theorist.
  destroyed: ->
    @unsubscribe()

  # Subscribe to the given repo for changes to the Git status of this directory.
  subscribeToRepo: ->
    repo = atom.project.getRepo()
    if repo?
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

    @status = newStatus if newStatus isnt @status
