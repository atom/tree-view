crypto = require 'crypto'
fs = require 'fs-plus'
_ = require 'underscore-plus'

fetch = (path) ->
  console.log "FETCH: #{path}"
  # learnIDE.remoteFS.fetch(path)

fetchIfDigestDiffers = (path, digest) ->
  hash = crypto.createHash('md5')
  stream = fs.createReadStream(path)

  stream.on 'data', (data) ->
    hash.update(data, 'utf8')

  stream.on 'end', ->
    calculatedDigest = hash.digest('hex')
    console.log "DIGEST COMPARE: #{digest} == #{calculatedDigest}"
    fetch(path) if calculatedDigest isnt digest

module.exports =
class Sync
  # TODO: make recursive, so that a directory exists before we attempt to create a file it houses?
  constructor: (@virtualEntries, @targetDir) ->
    fs.makeTreeSync(@targetDir)

  execute: ->
    localEntries = fs.listTreeSync(@targetDir)
    pathsToRemove = _.difference(localEntries, @remoteEntries)
    pathsToRemove.forEach (path) -> fs.remove(path)

    for own path, digest of @virtualEntries
      path = path.replace('/home', @targetDir)
      if not fs.existsSync(path)
        fetch(path)
      else
        fetchIfDigestDiffers(path, digest)

