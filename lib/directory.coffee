path = require 'path'
_ = require 'underscore-plus'
{CompositeDisposable, Emitter} = require 'event-kit'
fs = require 'fs-plus'
PathWatcher = require 'pathwatcher'
File = require './file'
{repoForPath} = require './helpers'
realpathCache = {}

module.exports =
class Directory
  constructor: ({@name, fullPath, @symlink, @expansionState, @isRoot, @ignoredPatterns, @useSyncFS, @stats}) ->
    @destroyed = false
    @emitter = new Emitter()
    @subscriptions = new CompositeDisposable()

    if atom.config.get('tree-view.squashDirectoryNames') and not @isRoot
      fullPath = @squashDirectoryNames(fullPath)

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

  onDidCollapse: (callback) ->
    @emitter.on('did-collapse', callback)

  onDidExpand: (callback) ->
    @emitter.on('did-expand', callback)

  loadRealPath: ->
    if @useSyncFS
      @realPath = fs.realpathSync(@path)
      @lowerCaseRealPath = @realPath.toLowerCase() if fs.isCaseInsensitive()
    else
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
    names.sort(new Intl.Collator(undefined, {numeric: true, sensitivity: "base"}).compare)

    files = []
    directories = []

    for name in names
      fullPath = path.join(@path, name)
      continue if @isPathIgnored(fullPath)

      stat = fs.lstatSyncNoException(fullPath)
      symlink = stat.isSymbolicLink?()
      stat = fs.statSyncNoException(fullPath) if symlink
      statFlat = _.pick stat, _.keys(stat)...
      for key in ["atime", "birthtime", "ctime", "mtime"]
        statFlat[key] = statFlat[key]?.getTime()

      if stat.isDirectory?()
        if @entries.hasOwnProperty(name)
          # push a placeholder since this entry already exists but this helps
          # track the insertion index for the created views
          directories.push(name)
        else
          expansionState = @expansionState.entries[name]
          directories.push(new Directory({name, fullPath, symlink, expansionState, @ignoredPatterns, @useSyncFS, stats: statFlat}))
      else if stat.isFile?()
        if @entries.hasOwnProperty(name)
          # push a placeholder since this entry already exists but this helps
          # track the insertion index for the created views
          files.push(name)
        else
          files.push(new File({name, fullPath, symlink, realpathCache, @useSyncFS, stats: statFlat}))

    @sortEntries(directories.concat(files))

  normalizeEntryName: (value) ->
    normalizedValue = value.name
    unless normalizedValue?
      normalizedValue = value
    if normalizedValue?
      normalizedValue = normalizedValue.toLowerCase()
    normalizedValue

  sortEntries: (combinedEntries) ->
    if atom.config.get('tree-view.sortFoldersBeforeFiles')
      combinedEntries
    else
      combinedEntries.sort (first, second) =>
        firstName = @normalizeEntryName(first)
        secondName = @normalizeEntryName(second)
        firstName.localeCompare(secondName)

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

      if @entries.hasOwnProperty(name)
        delete @entries[name]

      if @expansionState.entries.hasOwnProperty(name)
        delete @expansionState.entries[name]

    @emitter.emit('did-remove-entries', removedEntries) if entriesRemoved

    if newEntries.length > 0
      @entries[entry.name] = entry for entry in newEntries
      @emitter.emit('did-add-entries', newEntries)

  # Public: Collapse this directory and stop watching it.
  collapse: ->
    @expansionState.isExpanded = false
    @expansionState = @serializeExpansionState()
    @unwatch()
    @emitter.emit('did-collapse')

  # Public: Expand this directory, load its children, and start watching it for
  # changes.
  expand: ->
    @expansionState.isExpanded = true
    @reload()
    @watch()
    @emitter.emit('did-expand')

  serializeExpansionState: ->
    expansionState = {}
    expansionState.isExpanded = @expansionState.isExpanded
    expansionState.entries = {}
    for name, entry of @entries when entry.expansionState?
      expansionState.entries[name] = entry.serializeExpansionState()
    expansionState

  squashDirectoryNames: (fullPath) ->
    squashedDirs = [@name]
    loop
      try
        contents = fs.listSync fullPath
      catch error
        break
      break if contents.length isnt 1
      break if not fs.isDirectorySync(contents[0])
      relativeDir = path.relative(fullPath, contents[0])
      squashedDirs.push relativeDir
      fullPath = path.join(fullPath, relativeDir)

    if squashedDirs.length > 1
      @squashedNames = [squashedDirs[0..squashedDirs.length - 2].join(path.sep) + path.sep, _.last(squashedDirs)]

    return fullPath
