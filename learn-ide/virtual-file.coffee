module.exports =
class VirtualFile
  constructor: ({@name, @path, @size, @digest, @symlink, @directory, @entries, atime, ctime, mtime, birthtime}) ->
    @atime = new Date(atime)
    @ctime = new Date(ctime)
    @mtime = new Date(mtime)
    @birthtime = new Date(birthtime)

  setContents: (@contents) ->
    # noop

  read: ->
    @contents

  list: (extension) ->
    if extension?
      entries = @entries.filter (entry) -> entry.endsWith(".#{extension}")

    (entries or @entries).map (entry) => "#{@path}/#{entry}"

  isDirectory: ->
    @directory

  isFile: ->
    not @directory

  isSymbolicLink: ->
    @symlink

