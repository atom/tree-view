path = require 'path'

{Model} = require 'theorist'
{_} = require 'atom'

File = require './file'

module.exports =
class Directory extends Model
  @properties
    directory: null
    isRoot: false
    isExpanded: false
    expandedEntries: -> {}
    status: null # Either null, 'added', 'ignored', or 'modified'
    entries: -> {}

  @::accessor 'name', -> @directory.getBaseName()
  @::accessor 'path', -> @directory.getPath()
  @::accessor 'submodule', -> atom.project.getRepo()?.isSubmodule(@path)
  @::accessor 'symlink', -> @directory.symlink

  constructor: ->
    super
    repo = atom.project.getRepo()
    if repo?
      @subscribeToRepo(repo)
      @updateStatus(repo)

  # Private: Called by theorist.
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
  createEntry: (entry, index) ->
    if entry.getEntries?
      expandedEntries = @expandedEntries[entry.getBaseName()]
      isExpanded = expandedEntries?
      entry = new Directory({directory: entry, isExpanded, expandedEntries})
    else
      entry = new File(file: entry)
    entry.indexInParentDirectory = index
    entry

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
      if @isAlive()
        for key, entry of @entries
          entry.destroy()
          delete @entries[key]

  # Public: Watch this directory for changes.
  #
  # The changes will be emitted as 'entry-added' and 'entry-removed' events.
  watch: ->
    unless @watchSubscription?
      @watchSubscription = @directory.on 'contents-changed', => @reload()
      @subscribe(@watchSubscription)

  # Public: Perform a synchronous reload of the directory.
  reload: ->
    newEntries = []
    removedEntries = _.clone(@entries)
    index = 0

    for entry in @directory.getEntries()
      name = entry.getBaseName()
      if @entries.hasOwnProperty(name)
        delete removedEntries[name]
        index++
      else if not @isPathIgnored(entry.path)
        newEntries.push([entry, index])
        index++

    for name, entry of removedEntries
      entry.destroy()
      delete @entries[name]
      @emit 'entry-removed', entry

    for [entry, index] in newEntries
      entry = @createEntry(entry, index)
      @entries[entry.name] = entry
      @emit 'entry-added', entry

  collapse: ->
    @isExpanded = false
    @expandedEntries = @serializeExpansionStates()
    @unwatch()

  expand: ->
    @isExpanded = true
    @reload()
    @watch()

  serializeExpansionStates: ->
    expandedEntries = {}
    for name, entry of  @entries when entry.isExpanded
      expandedEntries[name] = entry.serializeExpansionStates()
    expandedEntries
