fs = require 'fs-plus'
_ = require 'underscore-plus'
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
      @entries[path] = new Entry(attributes, path)

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
      @get(path).needsSync().then (shouldSync) ->
        pathsToSync.push(path) if shouldSync

    Promise.all(digestPromises).then ->
      pathsToSync

