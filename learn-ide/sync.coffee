crypto = require 'crypto'
_fs = require 'fs-plus'
_ = require 'underscore-plus'

getPathsNeedingSync = (virtualEntries) ->
  pathsNeedingSync = []

  digestPromises = _.map virtualEntries, (remoteDigest, path) ->

    getDigest(path).then (localDigest) ->
      console.log("local digest for path #{path}: #{localDigest}")

      if localDigest != remoteDigest
        pathsNeedingSync.push(path)


  Promise.all(digestPromises).then(-> pathsNeedingSync)

getDigest = (path) ->
  new Promise (resolve) ->
    _fs.stat(path, (err, stats) ->
      if err
        resolve(false)
        return

      if stats.isDirectory()
        resolve(false)
        return


      hash = crypto.createHash('md5')
      stream = _fs.createReadStream(path)

      stream.on 'data', (data) ->
        hash.update(data, 'utf8')

      stream.on 'end', ->
        resolve hash.digest('hex')
    )


module.exports =
class Sync
  constructor: (@virtualEntries, @targetDir) ->
    _fs.makeTreeSync(@targetDir)

  execute: ->
    localEntries = _fs.listTreeSync(@targetDir)

    # pathsToRemove = _.difference(localEntries, @virtualEntries)
    # pathsToRemove.forEach (path) -> _fs.remove(path)

    getPathsNeedingSync(@virtualEntries).then((paths) ->
      console.log('paths needing sync')
      console.log(paths)
      fs.fetch(paths)
    )
