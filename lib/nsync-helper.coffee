fs = require 'fs-plus'
nsync = require 'nsync-fs'
atomHelper = require './atom-helper'
{CompositeDisposable} = require 'event-kit'

disposables = new CompositeDisposable

disposables.add nsync.onDidConfigure ->
  atomHelper.addOpener (uri) ->
    fs.stat uri, (err, stats) ->
      if err? and nsync.hasPath(uri)
        nsync.open(uri)

disposables.add nsync.onDidSetPrimary ({localPath, expansionState}) ->
  atomHelper.updateProject(localPath, expansionState)

disposables.add nsync.onWillLoad ->
  secondsTillNotifying = 2

  setTimeout ->
    unless nsync.hasPrimaryNode()
      atomHelper.loading()
  , secondsTillNotifying * 1000


module.exports = disposables
