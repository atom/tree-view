path = require 'path'
fs = require 'fs-plus'
{CompositeDisposable, Emitter} = require 'event-kit'
{repoForPath} = require './helpers'

module.exports =
class File
  constructor: ({@name, fullPath, @symlink, realpathCache}) ->
    @destroyed = false
    @emitter = new Emitter()
    @subscriptions = new CompositeDisposable()

    @path = fullPath
    @realPath = @path

    @subscribeToRepo()
    @updateStatus()

    fs.realpath @path, realpathCache, (error, realPath) =>
      return if @destroyed
      if realPath and realPath isnt @path
        @realPath = realPath
        @updateStatus()

  destroy: ->
    @destroyed = true
    @subscriptions.dispose()
    @emitter.emit('did-destroy')

  onDidDestroy: (callback) ->
    @emitter.on('did-destroy', callback)

  onDidStatusChange: (callback) ->
    @emitter.on('did-status-change', callback)

  # Subscribe to the project' repo for changes to the Git status of this file.
  subscribeToRepo: ->
    if repo = repoForPath(@path)
      @subscriptions.add repo.onDidChangeStatus (event) =>
        @updateStatus(repo) if @isPathEqual(event.path)
      @subscriptions.add repo.onDidChangeStatuses =>
        @updateStatus(repo)

  # Update the status property of this directory using the repo.
  updateStatus: ->
    repo = repoForPath(@path)
    repo?.isPathIgnored(@path).then (isIgnored) =>
      newStatus = null
      if isIgnored
        newStatus = 'ignored'
      else
        return repo.getCachedPathStatus(@path)
    .then (status) =>
      if status is 'ignored'
        newStatus = 'ignored'
      else if repo.isStatusModified(status)
        newStatus = 'modified'
      else if repo.isStatusNew(status)
        newStatus = 'added'

      if newStatus isnt @status
        @status = newStatus
        @emitter.emit('did-status-change', newStatus)


  isPathEqual: (pathToCompare) ->
    @path is pathToCompare or @realPath is pathToCompare
