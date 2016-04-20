{$} = require 'atom-space-pen-views'
path = require 'path'
fs = require 'fs-plus'
Dialog = require './dialog'
{repoForPath} = require './helpers'

module.exports =
class AddDialog extends Dialog
  constructor: (initialPath, isCreatingFile) ->
    @isCreatingFile = isCreatingFile

    if fs.isFileSync(initialPath)
      directoryPath = path.dirname(initialPath)
    else
      directoryPath = initialPath

    relativeDirectoryPath = directoryPath
    [@rootProjectPath, relativeDirectoryPath] = atom.project.relativizePath(directoryPath)
    relativeDirectoryPath += path.sep if relativeDirectoryPath.length > 0

    super
      prompt: "Enter the path for the new " + if isCreatingFile then "file." else "folder."
      initialPath: relativeDirectoryPath
      select: false
      iconClass: if isCreatingFile then 'icon-file-add' else 'icon-file-directory-create'

  onConfirm: (newPath) ->
    newPath = newPath.replace(/\s+$/, '') # Remove trailing whitespace
    endsWithDirectorySeparator = newPath[newPath.length - 1] is path.sep
    unless path.isAbsolute(newPath)
      unless @rootProjectPath?
        @showError("You must open a directory to create a file with a relative path")
        return

      newPath = path.join(@rootProjectPath, newPath)

    return unless newPath

    if atom.project.createFile?
      @createFileOrDirectory(newPath)
    else
      @createFileOrDirectoryLegacy(newPath)

  createFileOrDirectory: (newPath) ->
    if @isCreatingFile
      endsWithDirectorySeparator = newPath[newPath.length - 1] is path.sep
      if endsWithDirectorySeparator
        return @showError("File names must not end with a '#{path.sep}' character.")

      creation = atom.project.createFile(newPath)
      creation.then (path) =>
        @trigger('file-created', [newPath])
        @close()
    else
      creation = atom.project.createDirectory(newPath)
      creation.then (path) =>
        @trigger('directory-created', [newPath])
        @close()
        @focusTreeView()

    creation.catch (err) =>
      @showError(err.message)

  # TODO >=1.9.0: Delete this code path once Atom 1.9.0 stable is shipped
  createFileOrDirectoryLegacy: (newPath) ->
    endsWithDirectorySeparator = newPath[newPath.length - 1] is path.sep
    try
      if fs.existsSync(newPath)
        @showError("'#{newPath}' already exists.")
      else if @isCreatingFile
        if endsWithDirectorySeparator
          @showError("File names must not end with a '#{path.sep}' character.")
        else
          fs.writeFileSync(newPath, '')
          repoForPath(newPath)?.getPathStatus(newPath)
          @trigger 'file-created', [newPath]
          @close()
      else
        fs.makeTreeSync(newPath)
        @trigger 'directory-created', [newPath]
        @cancel()
    catch error
      @showError("#{error.message}.")
