path = require 'path'
_ = require 'underscore-plus'
{CompositeDisposable, Emitter} = require 'event-kit'
fs = require 'fs-plus'
PathWatcher = require 'pathwatcher'
File = require './file'
{repoForPath} = require './helpers'
{GitRepositoryAsync} = require 'atom'

realpathCache = {}

module.exports =
class Directory
  constructor: ({@name, fullPath, @symlink, @expansionState, @isRoot, @ignoredPatterns}) ->
    @destroyed = false
    @emitter = new Emitter()
    @subscriptions = new CompositeDisposable()

    if atom.config.get('tree-view.squashDirectoryNames')
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
    if repo = repoForPath(@path)
      @subscriptions.add repo.onDidChangeStatus (event) =>
        @updateStatus() if @contains(event.path)
      @subscriptions.add repo.onDidChangeStatuses =>
        @updateStatus()

  # Update the status property of this directory using the repo.
  updateStatus: ->
    repo = repoForPath(@path)
    repo?.isPathIgnored(@path).then (isIgnored) =>
      if isIgnored
        return GitRepositoryAsync.Git.Status.STATUS.IGNORED
      else
        return repo.getDirectoryStatus(@path)
    .then (status) =>
      newStatus = null
      if status is GitRepositoryAsync.Git.Status.STATUS.IGNORED
        newStatus = 'ignored'
      else if repo.isStatusModified(status)
        newStatus = 'modified'
      else if repo.isStatusNew(status)
        newStatus = 'added'

      if newStatus isnt @status
        @status = newStatus
        @emitter.emit('did-status-change', newStatus)
      newStatus

  # Is the given path ignored?
  isPathIgnored: (filePath) ->
    if atom.config.get('tree-view.hideVcsIgnoredFiles')
      repo = repoForPath(@path)
      if repo? and repo.isProjectAtRoot()
        # repo.isPathIgnored also returns a promise that resolves to a Boolean
        return repo.isPathIgnored(filePath)
    else if atom.config.get('tree-view.hideIgnoredNames')
      for ignoredPattern in @ignoredPatterns
        return Promise.resolve(true) if ignoredPattern.match(filePath)

    return Promise.resolve(false)

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

    # async/await will make this more pleasant when this is
    # inevitably ported to ES6
    namePromises = names.map (name) =>
      localName = name
      fullPath = path.join(@path, localName)

      return @isPathIgnored(fullPath).then (isIgnored) =>
        return if isIgnored

        stat = fs.lstatSyncNoException(fullPath)
        symlink = stat.isSymbolicLink?()
        stat = fs.statSyncNoException(fullPath) if symlink
        if stat.isDirectory?()
          if @entries.hasOwnProperty(localName)
            # push a placeholder since this entry already exists but this helps
            # track the insertion index for the created views
            return [localName, 'directory']
          else
            expansionState = @expansionState.entries[localName]
            return [localName, new Directory({
                name: localName,
                fullPath: fullPath,
                symlink: symlink,
                expansionState: expansionState,
                ignoredPatterns: @ignoredPatterns
                })]
        else if stat.isFile?()
          if @entries.hasOwnProperty(localName)
            return [localName, @entries[localName]]
          else
            return [localName, new File({
              name: localName,
              fullPath: fullPath,
              symlink: symlink,
              realpathCache: realpathCache
              })]

    Promise.all(namePromises).then (values) =>
      directories = []
      files = []
      values = values.filter (v) -> v isnt undefined
      for value in values
        if value[1] instanceof File
          files.push value[1]
        else if value[1] instanceof Directory
          directories.push value[1]
        else if value[1] is 'file'
          files.push value[0]
        else if value[1] is 'directory'
          directories.push value[0]
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

  # Public: Perform an asynchronous reload of the directory.
  reload: ->
    newEntries = []
    removedEntries = _.clone(@entries)
    index = 0
    @getEntries().then (entries) =>
      for entry in entries
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

  # Public: Expand this directory, load its children, and start watching it for
  # changes.
  expand: ->
    @expansionState.isExpanded = true
    @reload().then =>
      @watch()

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
      contents = fs.listSync fullPath
      break if contents.length isnt 1
      break if not fs.isDirectorySync(contents[0])
      relativeDir = path.relative(fullPath, contents[0])
      squashedDirs.push relativeDir
      fullPath = path.join(fullPath, relativeDir)

    if squashedDirs.length > 1
      @squashedName = squashedDirs[0..squashedDirs.length - 2].join(path.sep) + path.sep
    @name = squashedDirs[squashedDirs.length - 1]

    return fullPath
