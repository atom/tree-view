path = require 'path'

{Model} = require 'atom'

File = require './file'

module.exports =
class Directory extends Model
  @properties
    status: null # Either null, 'added', 'ignored', or 'modified'

  @::accessor 'name', get: -> @directory.getBaseName()
  @::accessor 'path', get: -> @directory.getPath()
  @::accessor 'symlink', get: -> @directory.symlink
  @::accessor 'submodule',
    get: -> atom.project.getRepo()?.isSubmodule(@path)

  created: ->
    repo = atom.project.getRepo()
    if repo?
      @subscribeToRepo(repo)
      @updateStatus(repo)

  destroyed: ->
    @unsubscribe()

  subscribeToRepo: (repo) ->
    @subscribe repo, 'status-changed', (changedPath, status) =>
      @updateStatus(repo) if changedPath.indexOf("#{@path}#{path.sep}") is 0
    @subscribe repo, 'statuses-changed', =>
      @updateStatus(repo)

  updateStatus: (repo) ->
    newStatus = null
    if repo.isPathIgnored(@path)
      newStatus = 'ignored'
    else
      status = repo.getDirectoryStatus(@path)
      if repo.isStatusModified(status)
        newStatus = 'modified'
      else if repo.isStatusNew(status)
        newStatus = 'added'

    @status = newStatus if newStatus isnt @status

  isPathIgnored: (filePath) ->
    if atom.config.get('tree-view.hideVcsIgnoredFiles')
      repo = atom.project.getRepo()
      return true if repo? and repo.isProjectAtRoot() and repo.isPathIgnored(filePath)

    if atom.config.get('tree-view.hideIgnoredNames')
      ignoredNames = atom.config.get('core.ignoredNames') ? []
      return true if _.contains(ignoredNames, path.basename(filePath))

    false

  getEntries: ->
    entries = []
    for entry in @directory.getEntries() when not @isPathIgnored(entry.path)
      if entry.getEntries?
        entries.push(Directory.createAsRoot(directory: entry))
      else
        entries.push(File.createAsRoot(file: entry))

    entries
