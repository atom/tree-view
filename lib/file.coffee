path = require 'path'

{Model} = require 'theorist'
{fs} = require 'atom'

module.exports =
class File extends Model
  @properties
    file: null
    status: null # Either null, 'added', 'ignored', or 'modified'

  @::accessor 'name', -> @file.getBaseName()
  @::accessor 'path', -> @file.getPath()
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
    if repo?
      @subscribeToRepo(repo)
      @updateStatus(repo)

  # Private: Called by theorist.
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
