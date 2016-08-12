RemoteFileSystem = require('./remote-file-system')

module.exports = nsync =
  activate: ->
    remoteFS = new RemoteFileSystem()
    global.learnIDE = {remoteFS}

  deactivate: ->
    global.learnIDE = undefined

