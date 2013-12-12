path = require 'path'

{_, Model} = require 'atom'

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

  # Private: Called by telepath.
  created: ->
    repo = atom.project.getRepo()
    if repo?
      @subscribeToRepo(repo)
      @updateStatus(repo)

  # Private: Called by telepath.
  destroyed: ->
    @unwatch()
    @unsubscribe()

  # Private: Subscribe to the given repo for changes to the Git status of this
  # directory.
  subscribeToRepo: (repo) ->
    @subscribe repo, 'status-changed', (changedPath, status) =>
      @updateStatus(repo) if changedPath.indexOf("#{@path}#{path.sep}") is 0
    @subscribe repo, 'statuses-changed', =>
      @updateStatus(repo)

  # Private: Update the status property of this directory using the repo.
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

  # Private: Is the given path ignored?
  isPathIgnored: (filePath) ->
    if atom.config.get('tree-view.hideVcsIgnoredFiles')
      repo = atom.project.getRepo()
      return true if repo? and repo.isProjectAtRoot() and repo.isPathIgnored(filePath)

    if atom.config.get('tree-view.hideIgnoredNames')
      ignoredNames = atom.config.get('core.ignoredNames') ? []
      return true if _.contains(ignoredNames, path.basename(filePath))

    false

  # Private: Create a new model for the given atom.File or atom.Directory entry.
  createEntry: (entry) ->
    if entry.getEntries?
      Directory.createAsRoot(directory: entry)
    else
      File.createAsRoot(file: entry)

  # Public: Does this directory contain the given path?
  #
  # See atom.Directory::contains for more details.
  contains: (pathToCheck) ->
    @directory.contains(pathToCheck)

  # Public: Stop watching this directory for changes.
  unwatch: ->
    if @watchSubscription?
      @watchSubscription.off()
      @watchSubscription = null
      @entries = null

  # Public: Watch this directory for changes.
  #
  # The changes will be emitted as 'entry-added' and 'entry-removed' events.
  watch: ->
    unless @watchSubscription?
      @watchSubscription = @directory.on 'contents-changed', => @reload()
      @subscribe(@watchSubscription)

  # Public: Perform a synchronous reload of the directory.
  reload: ->
    @entries ?= {}
    newEntries = []
    removedEntries = _.clone(@entries)
    index = 0
    for entry in @directory.getEntries() when not @isPathIgnored(entry.path)
      name = entry.getBaseName()
      newEntries.push([entry, index]) unless @entries.hasOwnProperty(name)
      delete removedEntries[name]
      index++

    for name, entry of removedEntries
      @entries[name]?.destroy()
      delete @entries[name]
      @emit 'entry-removed', entry

    for [entry, index] in newEntries
      newEntry = @createEntry(entry)
      @entries[newEntry.name] = newEntry
      @emit 'entry-added', newEntry, index

  # Public: Get all the file and directory entries in this directory.
  #
  # Returns a non-null array of File and Directory objects.
  getEntries: ->
    unless @entries?
      @entries = {}
      for entry in @directory.getEntries() when not @isPathIgnored(entry.path)
        entry = @createEntry(entry)
        @entries[entry.name] = entry

    _.values(@entries)
