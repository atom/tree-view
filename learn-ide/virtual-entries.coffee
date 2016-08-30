VirtualFile = require './virtual-file'

module.exports =
class VirtualEntries
  constructor: (pathsWithAttributes = {}, @converter) ->
    @update(pathsWithAttributes)

  get: (path) ->
    @entries[path]

  include: (path) ->
    @entries.hasOwnProperty(path)

  update: (pathsWithAttributes) ->
    @entries = {}

    for own remotePath, attributes of pathsWithAttributes
      path = @converter.remoteToLocal(remotePath)
      @entries[path] = new VirtualFile(attributes)

  addDigestToEntries: (pathsWithDigest) ->
    for own remotePath, digest of pathsWithDigest
      path = @converter.remoteToLocal(remotePath)
      @get(path).addDigest(digest)

  addContentToEntries: (pathsWithContent, virtualEntries) ->
    for own remotePath, content of pathsWithContent
      path = @converter.remoteToLocal(remotePath)
      @get(path).addContent(content)

