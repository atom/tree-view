{Emitter, Subscriber} = require 'emissary'

module.exports =
class TreeFile
  Emitter.includeInto(this)
  Subscriber.includeInto(this)

  constructor: (@file) ->
    @status = null

    @subscribeToRepo()

  subscribeToRepo: ->
    repo = atom.project.getRepo()
    if repo?
      @subscribe repo, 'status-changed', (changedPath, status) =>
        @updateStatus(repo) if changedPath is @getPath()
      @subscribe repo, 'statuses-changed', =>
        @updateStatus(repo)

  updateStatus: (repo) ->
    filePath = @getPath()
    newStatus = null
    if repo.isPathIgnored(filePath)
      newStatus = 'ignored'
    else
      status = repo.statuses[filePath]
      if repo.isStatusModified(status)
        newStatus = 'modified'
      else if repo.isStatusNew(status)
        newStatus = 'added'

    if newStatus isnt @status
      @status = newStatus
      @emit 'status-changed', newStatus

  # Public: Destroy this file.
  destroy: ->
    @unsubscribe()

  # Public: Get the path of this file.
  getPath: ->
    @file.getPath()

  # Public: Get the Git status of this file.
  #
  # Returns either null, 'added', 'ignored', or 'modified'.
  getStatus: ->
    @status
