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

  onConfirm: (relativePath) ->
    relativePath = relativePath.replace(/\s+$/, '') # Remove trailing whitespace
    endsWithDirectorySeparator = relativePath[relativePath.length - 1] is path.sep
    pathToCreate = atom.project.resolve(relativePath)
    return unless pathToCreate

    try
      if fs.existsSync(pathToCreate)
        @showError("'#{pathToCreate}' already exists.")
      else if @isCreatingFile
        if endsWithDirectorySeparator
          @showError("File names must not end with a '#{path.sep}' character.")
        else
          fs.writeFileSync(pathToCreate, '')
          atom.project.getRepo()?.getPathStatus(pathToCreate)
          @trigger 'file-created', [pathToCreate]
          @close()
      else
        fs.makeTreeSync(pathToCreate)
        @trigger 'directory-created', [pathToCreate]
        @cancel()
    catch error
      @showError("#{error.message}.")
