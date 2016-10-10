fs = require 'fs-plus'
nsync = require 'nsync-fs'
{CompositeDisposable} = require 'event-kit'

disposables = new CompositeDisposable

disposables.add nsync.onDidConfigure ->
  atom.workspace.addOpener (uri) ->
    fs.stat uri, (err, stats) ->
      if err? and nsync.hasPath(uri)
        nsync.open(uri)

module.exports = disposables
