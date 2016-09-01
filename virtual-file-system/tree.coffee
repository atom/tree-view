fs = require 'fs-plus'
_ = require 'underscore-plus'
crypto = require 'crypto'
Entry = require './entry'

module.exports =
class Tree
  constructor: (pathsWithAttributes = {},  @converter) ->
    @update(pathsWithAttributes)

  get: (path) ->
    @has(path) and @entries[path]

  has: (path) ->
    @entries.hasOwnProperty(path)

  update: (pathsWithAttributes, projectRoot) ->
    if projectRoot?
      @projectRoot = projectRoot

    @entries = {}

    for own remotePath, attributes of pathsWithAttributes
      path = @converter.remoteToLocal(remotePath)
      @entries[path] = new Entry(attributes)

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
    return [] unless @projectRoot?
    _.difference(fs.listTreeSync(@projectRoot), @paths())

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
      fs.stat path, (err, stats) ->
        if err?
          return resolve true

        if stats.isDirectory()
          str = fs.readdirSync(path).join('')
          digest = crypto.createHash('md5').update(str, 'utf8').digest('hex')

          console.log "PATH: #{path} // REMOTE: #{virtualDigest} // LOCAL: #{digest}"

          return resolve virtualDigest is digest
        else
          hash = crypto.createHash('md5')
          stream = fs.createReadStream(path)

          stream.on 'data', (data) ->
            hash.update(data, 'utf8')

          stream.on 'end', ->
            digest = hash.digest('hex')
            console.log "PATH: #{path} // REMOTE: #{virtualDigest} // LOCAL: #{digest}"

            return resolve virtualDigest is digest

