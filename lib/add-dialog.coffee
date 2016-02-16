path = require 'path'
fs = require 'fs-plus'
Dialog = require './dialog'
{repoForPath} = require './helpers'

module.exports =
class AddDialog extends Dialog
  constructor: (initialPath, mode) ->
    @mode = mode

    if fs.isFileSync(initialPath)
      directoryPath = path.dirname(initialPath)
    else
      directoryPath = initialPath

    relativeDirectoryPath = directoryPath
    [@rootProjectPath, relativeDirectoryPath] = atom.project.relativizePath(directoryPath)
    relativeDirectoryPath += path.sep if relativeDirectoryPath.length > 0

    @relativeDirectoryPath = relativeDirectoryPath
    console.log('full', @relativeDirectoryPath)
    console.log('project', @rootProjectPath)

    icon = switch @mode
      when 'file' then 'icon-file-add'
      when 'folder' then 'icon-file-directory-create'
      when 'advanced' then 'icon-file-advanced-create'

    prompt =
      "Enter the path for the new " +
      (switch @mode
        when 'file' then 'file'
        when 'folder' then 'folder'
        when 'advanced' then "file/folder at #{@relativeDirectoryPath}"
      ) + '.'

    super
      prompt: prompt
      initialPath: if @mode is "advanced" then "" else @relativeDirectoryPath
      select: false
      iconClass: icon

  parsePaths: (newPathsString, subProjectPath) ->
    paths = newPathsString.split(/,\s?/g)
    console.log(paths)

    return paths.map((unparsed) => @pathToDesc(unparsed, subProjectPath))

  pathToDesc: (unparsed, subProjectPath, forceType = null) ->
    unparsed = unparsed.trim()

    console.log('forceType', unparsed, forceType, subProjectPath)

    type:
      if forceType is null
        if unparsed.endsWith('/') then "folder" else "file"
      else
        forceType
    path:
      if unparsed.startsWith('.')
        path.join(@rootProjectPath, unparsed)
      else if unparsed.startsWith(path.sep)
        unparsed
      else
        path.join(@rootProjectPath, subProjectPath, unparsed)

  createFile: (path) ->
    try
      if fs.existsSync(path)
        @showError("'#{path}' already exists.")
        return false
      fs.writeFileSync(path, '')
      repoForPath(path)?.getPathStatus(path)
    catch error
      @showError("#{error.message}.")
      return false

    @trigger 'file-created', [path]
    return true

  createFolder: (path) ->
    try
      if fs.existsSync(path)
        @showError("'#{path}' already exists.")
        return false

      fs.makeTreeSync(path)
    catch error
      @showError("#{error.message}.")
      return false

    @trigger 'directory-created', [path]
    return true

  createDesc: (fileDesc) ->
    if fileDesc.type is "folder"
      return @createFolder(fileDesc.path)
    else
      return @createFile(fileDesc.path)

  onConfirm: (newPath) ->

    return unless newPath

    unless @rootProjectPath?
      @showError("You must open a directory to create a file with a relative path")
      return

    if @mode is "advanced"
      pathDescs = @parsePaths(newPath, @relativeDirectoryPath)

      for desc in pathDescs
        break unless @createDesc(desc)

      @close()
    else if @mode is "folder"
      desc = @pathToDesc(newPath, '.', 'folder')

      @close() if @createDesc(desc)
    else
      desc = @pathToDesc(newPath, '.', 'file')

      if desc.path.endsWith(path.sep)
        @showError("File names must not end with a '#{path.sep}' character.")
        return

      @close() if @createDesc(desc)
