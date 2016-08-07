path = require 'path'
fs = require 'fs-plus'
{CompositeDisposable, Emitter} = require 'event-kit'
{repoForPath} = require './helpers'

module.exports =
class File
  constructor: ({@name, fullPath, @symlink, realpathCache, useSyncFS}) ->
    @destroyed = false
    @emitter = new Emitter()
    @subscriptions = new CompositeDisposable()

    @path = fullPath
    @realPath = @path

    @statuses = []

    @subscribeToRepo()
    @updateStatus()

    if useSyncFS
      @realPath = fs.realpathSync(@path)
    else
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

  # Subscribe to the project's repo for changes to the Git status of this file.
  subscribeToRepo: ->
    repo = repoForPath(@path)
    return unless repo?

    @subscriptions.add repo.onDidChangeStatus (event) =>
      @updateStatus(repo) if @isPathEqual(event.path)
    @subscriptions.add repo.onDidChangeStatuses =>
      @updateStatus(repo)

  # Update the status property of this directory using the repo.
  updateStatus: ->

    GIT_STATUS_INDEX_NEW        = 1 << 0
    GIT_STATUS_INDEX_MODIFIED   = 1 << 1
    GIT_STATUS_INDEX_DELETED    = 1 << 2
    GIT_STATUS_INDEX_RENAMED    = 1 << 3
    GIT_STATUS_INDEX_TYPECHANGE = 1 << 4
    GIT_STATUS_WT_NEW           = 1 << 7
    GIT_STATUS_WT_MODIFIED      = 1 << 8
    GIT_STATUS_WT_DELETED       = 1 << 9
    GIT_STATUS_WT_TYPECHANGE    = 1 << 10
    GIT_STATUS_WT_RENAMED       = 1 << 11
    GIT_STATUS_WT_UNREADABLE    = 1 << 12
    GIT_STATUS_IGNORED          = 1 << 14
    GIT_STATUS_CONFLICTED       = 1 << 15

    repo = repoForPath(@path)
    return unless repo?

    if repo.isPathIgnored(@path)
      newStatuses = ['ignored']
    else
      statusCode = repo.getCachedPathStatus(@path)
      index =
        if statusCode & GIT_STATUS_INDEX_NEW
          # git treats added the same as updated internally, but provides a
          # different configuration slot name
          "added"
        else if statusCode & GIT_STATUS_INDEX_MODIFIED \
             || statusCode & GIT_STATUS_INDEX_DELETED \
             || statusCode & GIT_STATUS_INDEX_RENAMED \
             || statusCode & GIT_STATUS_INDEX_TYPECHANGE
          "updated"

      working =
        if statusCode & GIT_STATUS_WT_MODIFIED \
        || statusCode & GIT_STATUS_WT_DELETED \
        || statusCode & GIT_STATUS_WT_TYPECHANGE \
        || statusCode & GIT_STATUS_WT_RENAMED \
        || statusCode & GIT_STATUS_WT_UNREADABLE
          "changed"


      overall =
        if statusCode & GIT_STATUS_WT_NEW
          "untracked"
        else if statusCode & GIT_STATUS_IGNORED
          "ignored"
        else if statusCode & GIT_STATUS_CONFLICTED
          "conflicted"

      newStatuses = [index, working, overall].filter (x) -> x?
      newStatuses = ["unmodified"] if newStatuses == []

    if newStatuses isnt @statuses
      @statuses = newStatuses
      @emitter.emit('did-status-change', newStatuses)

  isPathEqual: (pathToCompare) ->
    @path is pathToCompare or @realPath is pathToCompare
