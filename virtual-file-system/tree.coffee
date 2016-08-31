fs = require 'fs-plus'
_ = require 'underscore-plus'
VirtualFile = require './virtual-file'

module.exports =
class VirtualTree
  constructor: (pathsWithAttributes = {}, @virtualRoot,  @converter) ->
    @update(pathsWithAttributes)

  get: (path) ->
    @has(path) and @entries[path]

  has: (path) ->
    @entries.hasOwnProperty(path)

  update: (pathsWithAttributes) ->
    @entries = {}

    for own remotePath, attributes of pathsWithAttributes
      path = @converter.remoteToLocal(remotePath)
      @entries[path] = new VirtualFile(attributes)

  paths: ->
    Object.keys(@entries)

  addDigests: (pathsWithDigest) ->
    for own remotePath, digest of pathsWithDigest
      path = @converter.remoteToLocal(remotePath)
      @get(path).addDigest(digest)

  addContents: (pathsWithContent, virtualEntries) ->
    for own remotePath, content of pathsWithContent
      path = @converter.remoteToLocal(remotePath)
      @get(path).addContent(content)

  getPathsToRemove: ->
    _.difference(fs.listTreeSync(@virtualRoot), @paths())

  getPathsToSync: ->
    pathsToSync = []

    digestPromises = @paths().map (path) =>
      @needsSync(path).then (shouldSync) ->
        pathsToSync.push(path) if shouldSync

    Promise.all(digestPromises).then ->
      pathsToSync

  needsSync: (path) ->
    virtualDigest = @get(path).digest
    return new Error('virtual digest must be defined') unless virtualDigest?

    new Promise (resolve) ->
      resolve true unless fs.existsSync(path)

      if fs.isDirectorySync(path)
        str = fs.readdirSync(path).join('')
        digest = crypto.createHash('md5').update(str, 'utf8').digest('hex')

        resolve virtualDigest is digest
      else
        hash = crypto.createHash('md5')
        stream = fs.createReadStream(path)

        stream.on 'data', (data) ->
          hash.update(data, 'utf8')

        stream.on 'end', ->
          digest = hash.digest('hex')
          resolve virtualDigest is digest

