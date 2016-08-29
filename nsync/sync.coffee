crypto = require 'crypto'
_fs = require 'fs-plus'
_ = require 'underscore-plus'

getDigest = (path) ->
  new Promise (resolve) ->
    hash = crypto.createHash('md5')
    stream = _fs.createReadStream(path)

    stream.on 'data', (data) ->
      hash.update(data, 'utf8')

    stream.on 'end', ->
      resolve hash.digest('hex')

module.exports =
class Sync
  constructor: (@virtualEntries, @targetDir) ->
    _fs.makeTreeSync(@targetDir)

  execute: ->
    localEntries = _fs.listTreeSync(@targetDir)

    # pathsToRemove = _.difference(localEntries, @virtualEntries)
    # pathsToRemove.forEach (path) -> _fs.remove(path)

    pathsToAdd = _.difference(@virtualEntries, localEntries)

    for own path, digest of @virtualEntries
      getDigest(path).then (localDigest) ->
        pathsToAdd.push(path) if localDigest isnt digest

    fs.fetch(pathsToAdd)

