path = require 'path'

{fs, Model} = require 'atom'

module.exports =
class File extends Model
  @properties
    status: null # Either null, 'added', 'ignored', or 'modified'

  @::accessor 'name',    get: -> @file.getBaseName()
  @::accessor 'path',    get: -> @file.getPath()
  @::accessor 'symlink', get: -> @file.symlink

  @::accessor 'type', get: ->
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

  # Private: Called by telepath.
  created: ->
    repo = atom.project.getRepo()
    if repo?
      @subscribeToRepo(repo)
      @updateStatus(repo)

  # Private: Called by telepath.
  destroyed: ->
    @unsubscribe()

  # Private: Subscribe to the given repo for changes to the Git status of this
  # directory.
  subscribeToRepo: ->
    repo = atom.project.getRepo()
    if repo?
      @subscribe repo, 'status-changed', (changedPath, status) =>
        @updateStatus(repo) if changedPath is @path
      @subscribe repo, 'statuses-changed', =>
        @updateStatus(repo)

  # Private: Update the status property of this directory using the repo.
  updateStatus: (repo) ->
    newStatus = null
    if repo.isPathIgnored(@path)
      newStatus = 'ignored'
    else
      status = repo.statuses[@path]
      if repo.isStatusModified(status)
        newStatus = 'modified'
      else if repo.isStatusNew(status)
        newStatus = 'added'

    @status = newStatus if newStatus isnt @status
