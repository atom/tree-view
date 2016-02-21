path = require 'path'
fs = require 'fs-plus'
{CompositeDisposable, Emitter} = require 'event-kit'
{repoForPath} = require './helpers'

module.exports =
class File
  constructor: ({@name, fullPath, @symlink, realpathCache}) ->
    @destroyed = false
    @emitter = new Emitter()

    @path = fullPath
    @realPath = @path

    @loadStatus()
    @loadRealPath(realpathCache)

  destroy: ->
    @destroyed = true
    @unsubscribeFromRepo()
    @emitter.emit('did-destroy')

  onDidDestroy: (callback) ->
    @emitter.on('did-destroy', callback)

  onDidStatusChange: (callback) ->
    @emitter.on('did-status-change', callback)

  loadRealPath: (realpathCache) ->
    canUpdateStatus = atom.config.get('tree-view.displayVcsStatus')
    fs.realpath @path, realpathCache, (error, realPath) =>
      return if @destroyed
      if realPath and realPath isnt @path
        @realPath = realPath
        @updateStatus() if displayVcsStatus

  loadStatus: ->
    if atom.config.get('tree-view.displayVcsStatus')
      @subscribeToRepo()
      @updateStatus()

    atom.config.onDidChange 'tree-view.displayVcsStatus', (value) =>
      if value.newValue
        @subscribeToRepo()
        @updateStatus()
      else
        @unsubscribeFromRepo()
        @resetStatus()

  # Subscribe to the project' repo for changes to the Git status of this file.
  subscribeToRepo: ->
    repo = repoForPath(@path)
    return unless repo?

    @repoSubscriptions = new CompositeDisposable()
    @repoSubscriptions.add repo.onDidChangeStatus (event) =>
      @updateStatus(repo) if @isPathEqual(event.path)
    @repoSubscriptions.add repo.onDidChangeStatuses =>
      @updateStatus(repo)

  unsubscribeFromRepo: ->
    @repoSubscriptions?.dispose()

  # Update the status property of this directory using the repo.
  updateStatus: ->
    repo = repoForPath(@path)
    return unless repo?

    newStatus = null
    if repo.isPathIgnored(@path)
      newStatus = 'ignored'
    else
      status = repo.getCachedPathStatus(@path)
      if repo.isStatusModified(status)
        newStatus = 'modified'
      else if repo.isStatusNew(status)
        newStatus = 'added'

    if newStatus isnt @status
      @status = newStatus
      @emitter.emit('did-status-change', newStatus)

  resetStatus: ->
    @status = null
    @emitter.emit('did-status-change', @status)

  isPathEqual: (pathToCompare) ->
    @path is pathToCompare or @realPath is pathToCompare
