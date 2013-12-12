path = require 'path'

{fs, Model} = require 'atom'

module.exports =
class File extends Model
  @properties
    status: null

  created: ->
    repo = atom.project.getRepo()
    if repo?
      @subscribeToRepo(repo)
      @updateStatus(repo)

  subscribeToRepo: ->
    repo = atom.project.getRepo()
    if repo?
      @subscribe repo, 'status-changed', (changedPath, status) =>
        @updateStatus(repo) if changedPath is @getPath()
      @subscribe repo, 'statuses-changed', =>
        @updateStatus(repo)

  updateStatus: (repo) ->
    newStatus = null
    filePath = @getPath()
    if repo.isPathIgnored(filePath)
      newStatus = 'ignored'
    else
      status = repo.statuses[filePath]
      if repo.isStatusModified(status)
        newStatus = 'modified'
      else if repo.isStatusNew(status)
        newStatus = 'added'

    @status = newStatus if newStatus isnt @status

  destroyed: ->
    @unsubscribe()

  # Public: Is this file a symlink?
  isSymlink: ->
    @file.symlink

  # Public: Get the path of this file.
  getPath: ->
    @file.getPath()

  # Public: Get the base name of this file.
  getName: ->
    @file.getBaseName()

  # Public: Get the Git status of this file.
  #
  # Returns either null, 'added', 'ignored', or 'modified'.
  getStatus: ->
    @status

  # Public: Get the content type of this file.
  getType: ->
    extension = path.extname(@getPath())
    if fs.isReadmePath(@getPath())
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
