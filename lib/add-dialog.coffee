path = require 'path'
fs = require 'fs-plus'
Dialog = require './dialog'

module.exports =
class AddDialog extends Dialog
  constructor: (initialPath, isCreatingFile) ->
    @isCreatingFile = isCreatingFile

    if fs.isFileSync(initialPath)
      directoryPath = path.dirname(initialPath)
    else
      directoryPath = initialPath
    relativeDirectoryPath = atom.project.relativize(directoryPath)

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
      newPath = atom.project.getDirectories()[0]?.resolve(newPath)

    return unless newPath

    try
      if fs.existsSync(newPath)
        @showError("'#{newPath}' already exists.")
      else if @isCreatingFile
        if endsWithDirectorySeparator
          @showError("File names must not end with a '#{path.sep}' character.")
        else
          fs.writeFileSync(newPath, '')
          atom.project.getRepositories()[0]?.getPathStatus(newPath)
          @trigger 'file-created', [newPath]
          @close()
      else
        fs.makeTreeSync(newPath)
        @trigger 'directory-created', [newPath]
        @cancel()
    catch error
      @showError("#{error.message}.")
