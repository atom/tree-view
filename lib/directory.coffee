path = require 'path'
_ = require 'underscore-plus'
{CompositeDisposable, Emitter} = require 'event-kit'
fs = require 'fs-plus'
PathWatcher = require 'pathwatcher'
NaturalSort = require 'javascript-natural-sort'
File = require './file'
{repoForPath} = require './helpers'

realpathCache = {}

module.exports =
class Directory
  constructor: ({@name, fullPath, @symlink, @expansionState, @isRoot, @ignoredPatterns}) ->
    @destroyed = false
    @emitter = new Emitter()
    @subscriptions = new CompositeDisposable()

    @path = fullPath
    @realPath = @path
    if fs.isCaseInsensitive()
      @lowerCasePath = @path.toLowerCase()
      @lowerCaseRealPath = @lowerCasePath

    @isRoot ?= false
    @expansionState ?= {}
    @expansionState.isExpanded ?= false
    @expansionState.entries ?= {}
    @status = null
    @entries = {}

    @submodule = repoForPath(@path)?.isSubmodule(@path)

    @subscribeToRepo()
    @updateStatus()
    @loadRealPath()

  destroy: ->
    @destroyed = true
    @unwatch()
    @subscriptions.dispose()
    @emitter.emit('did-destroy')

  onDidDestroy: (callback) ->
    @emitter.on('did-destroy', callback)

  onDidStatusChange: (callback) ->
    @emitter.on('did-status-change', callback)

  onDidAddEntries: (callback) ->
    @emitter.on('did-add-entries', callback)

  onDidRemoveEntries: (callback) ->
    @emitter.on('did-remove-entries', callback)

  loadRealPath: ->
    fs.realpath @path, realpathCache, (error, realPath) =>
      return if @destroyed
      if realPath and realPath isnt @path
        @realPath = realPath
        @lowerCaseRealPath = @realPath.toLowerCase() if fs.isCaseInsensitive()
        @updateStatus()

  # Subscribe to project's repo for changes to the Git status of this directory.
  subscribeToRepo: ->
    repo = repoForPath(@path)
    return unless repo?

    @subscriptions.add repo.onDidChangeStatus (event) =>
      @updateStatus(repo) if @contains(event.path)
    @subscriptions.add repo.onDidChangeStatuses =>
      @updateStatus(repo)

  # Update the status property of this directory using the repo.
  updateStatus: ->
    repo = repoForPath(@path)
    return unless repo?

    newStatus = null
    if repo.isPathIgnored(@path)
      newStatus = 'ignored'
    else
      status = repo.getDirectoryStatus(@path)
      if repo.isStatusModified(status)
        newStatus = 'modified'
      else if repo.isStatusNew(status)
        newStatus = 'added'

    if newStatus isnt @status
      @status = newStatus
      @emitter.emit('did-status-change', newStatus)

  # Is the given path ignored?
  isPathIgnored: (filePath) ->
    if atom.config.get('tree-view.hideVcsIgnoredFiles')
      repo = repoForPath(@path)
      return true if repo? and repo.isProjectAtRoot() and repo.isPathIgnored(filePath)

    if atom.config.get('tree-view.hideIgnoredNames')
      for ignoredPattern in @ignoredPatterns
        return true if ignoredPattern.match(filePath)

    false

  # Does given full path start with the given prefix?
  isPathPrefixOf: (prefix, fullPath) ->
    fullPath.indexOf(prefix) is 0 and fullPath[prefix.length] is path.sep

  isPathEqual: (pathToCompare) ->
    @path is pathToCompare or @realPath is pathToCompare

  # Public: Does this directory contain the given path?
  #
  # See atom.Directory::contains for more details.
  contains: (pathToCheck) ->
    return false unless pathToCheck

    # Normalize forward slashes to back slashes on windows
    pathToCheck = pathToCheck.replace(/\//g, '\\') if process.platform is 'win32'

    if fs.isCaseInsensitive()
      directoryPath = @lowerCasePath
      pathToCheck = pathToCheck.toLowerCase()
    else
      directoryPath = @path

    return true if @isPathPrefixOf(directoryPath, pathToCheck)

    # Check real path
    if @realPath isnt @path
      if fs.isCaseInsensitive()
        directoryPath = @lowerCaseRealPath
      else
        directoryPath = @realPath

      return @isPathPrefixOf(directoryPath, pathToCheck)

    false

  # Public: Stop watching this directory for changes.
  unwatch: ->
    if @watchSubscription?
      @watchSubscription.close()
      @watchSubscription = null

    for key, entry of @entries
      entry.destroy()
      delete @entries[key]

  # Public: Watch this directory for changes.
  watch: ->
    try
      @watchSubscription ?= PathWatcher.watch @path, (eventType) =>
        switch eventType
          when 'change' then @reload()
          when 'delete' then @destroy()

  getEntries: ->
    try
      names = fs.readdirSync(@path)
    catch error
      names = []

    # NaturalSort.insensitive = true
    # names.sort(NaturalSort)

    files = []
    directories = []

    for name in names
      fullPath = path.join(@path, name)
      continue if @isPathIgnored(fullPath)

      stat = fs.lstatSyncNoException(fullPath)
      symlink = stat.isSymbolicLink?()
      stat = fs.statSyncNoException(fullPath) if symlink

      if stat.isDirectory?()
        dir = null

        if @entries.hasOwnProperty(name)
          # push a placeholder since this entry already exists but this helps
          # track the insertion index for the created views
          dir = name
        else
          expansionState = @expansionState.entries[name]
          dir = new Directory({name, fullPath, symlink, expansionState, @ignoredPatterns})

        directories.push({ 'element': dir, 'stat': stat });

      else if stat.isFile?()
        file = null

        if @entries.hasOwnProperty(name)
          # push a placeholder since this entry already exists but this helps
          # track the insertion index for the created views
          file = name
        else
          file = new File({name, fullPath, symlink, realpathCache})

        files.push({ 'element': file, 'stat': stat });

    return _.pluck(@sortEntries(directories, files), 'element')

  normalizeEntryName: (value) ->
    normalizedValue = value.name
    unless normalizedValue?
      normalizedValue = value
    if normalizedValue?
      normalizedValue = normalizedValue.toLowerCase()
    normalizedValue

  sortEntries: (directories, files) ->

    # find sort mode of closest ancestor with a sort mode
    sortMode = localStorage.getItem("tree-view:sort:" + @path)
    if sortMode == null
      pathParts = @path.split('/')
      i = pathParts.length
      while sortMode == null and i > 0
        joinedpath = pathParts.slice(0,i).join('/')
        if joinedpath == ''
          joinedpath = '/'
        sortMode = localStorage.getItem("tree-view:sort:" + joinedpath)
        i--
    # no ancestor has a user-specified sort mode, default to default sort
    if sortMode == null
      sortMode = "name_asc"

    console.log("sortmode", @path, sortMode)

    combinedEntries = []
    if atom.config.get('tree-view.sortFoldersBeforeFiles')
      @sortPathElements(directories, sortMode)
      @sortPathElements(files, sortMode)
      combinedEntries = directories.concat(files)
    else
      combinedEntries = directories.concat(files)
      @sortPathElements(combinedEntries, sortMode)

    combinedEntries

  sortPathElements: (elements, sortBy) ->
    if sortBy == "name_asc"
      elements.sort (first, second) =>
          firstName = @normalizeEntryName(first.element)
          secondName = @normalizeEntryName(second.element)
          return firstName.localeCompare(secondName)
    else if sortBy == "name_desc"
      elements.sort (first, second) =>
          firstName = @normalizeEntryName(first.element)
          secondName = @normalizeEntryName(second.element)
          return secondName.localeCompare(firstName)
    else if sortBy == "modified_asc"
      elements.sort (first, second) =>
          if first.stat.mtime == second.stat.mtime
            firstName = @normalizeEntryName(first.element)
            secondName = @normalizeEntryName(second.element)
            return firstName.localeCompare(secondName)
          else
            return if first.stat.mtime < second.stat.mtime then 1 else -1
    else if sortBy == "modified_desc"
      elements.sort (first, second) =>
          if first.stat.mtime == second.stat.mtime
            firstName = @normalizeEntryName(first.element)
            secondName = @normalizeEntryName(second.element)
            return firstName.localeCompare(secondName)
          else
            return if first.stat.mtime > second.stat.mtime then 1 else -1

  # Public: Perform a synchronous reload of the directory.
  reload: ->
    newEntries = []
    removedEntries = _.clone(@entries)
    index = 0

    for entry in @getEntries()
      if @entries.hasOwnProperty(entry)
        delete removedEntries[entry]
        index++
        continue

      entry.indexInParentDirectory = index
      index++
      newEntries.push(entry)

    entriesRemoved = false
    for name, entry of removedEntries
      entriesRemoved = true
      entry.destroy()
      delete @entries[name]
      delete @expansionState[name]
    @emitter.emit('did-remove-entries', removedEntries) if entriesRemoved

    if newEntries.length > 0
      @entries[entry.name] = entry for entry in newEntries
      @emitter.emit('did-add-entries', newEntries)

  # Public: Collapse this directory and stop watching it.
  collapse: ->
    @expansionState.isExpanded = false
    @expansionState = @serializeExpansionState()
    @unwatch()

  # Public: Expand this directory, load its children, and start watching it for
  # changes.
  expand: ->
    @expansionState.isExpanded = true
    @reload()
    @watch()

  serializeExpansionState: ->
    expansionState = {}
    expansionState.isExpanded = @expansionState.isExpanded
    expansionState.entries = {}
    for name, entry of @entries when entry.expansionState?
      expansionState.entries[name] = entry.serializeExpansionState()
    expansionState
