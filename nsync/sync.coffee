crypto = require 'crypto'
_fs = require 'fs-plus'
_ = require 'underscore-plus'

fetch = (path) ->
  fs.send {command: 'fetch', path}

fetchIfDigestDiffers = (path, digest) ->
  hash = crypto.createHash('md5')
  stream = _fs.createReadStream(path)

  stream.on 'data', (data) ->
    hash.update(data, 'utf8')

  stream.on 'end', ->
    calculatedDigest = hash.digest('hex')
    console.log "DIGEST COMPARE: #{digest} == #{calculatedDigest}"
    fetch(path) if calculatedDigest isnt digest

module.exports =
class Sync
  constructor: (@virtualEntries, @targetDir) ->
    _fs.makeTreeSync(@targetDir)

  execute: ->
    localEntries = _fs.listTreeSync(@targetDir)
    pathsToRemove = _.difference(localEntries, @virtualEntries)
    pathsToRemove.forEach (path) -> _fs.remove(path)

    start = 0
    delay = 1000
    for own path, digest of @virtualEntries
      if not _fs.existsSync(path)
        setTimeout fetch.bind(this, path), start += delay
      else
        setTimeout fetchIfDigestDiffers.bind(this, path, digest), start += delay

