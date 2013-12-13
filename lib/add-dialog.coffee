path = require 'path'

{fs} = require 'atom'

Dialog = require './dialog'

module.exports =
class AddDialog extends Dialog
  constructor: (initialPath) ->
    if fs.isFileSync(initialPath)
      directoryPath = path.dirname(initialPath)
    else
      directoryPath = initialPath
    relativeDirectoryPath = atom.project.relativize(directoryPath)
    relativeDirectoryPath += '/' if relativeDirectoryPath.length > 0

    super
      prompt: "Enter the path for the new file/directory. Directories end with a '/'."
      initialPath: relativeDirectoryPath
      select: false
      iconClass: 'icon-file-directory-create'

    @miniEditor.getBuffer().on 'changed', =>
      if /\/$/.test(@miniEditor.getText())
        @promptText.removeClass('icon-file-add').addClass('icon-file-directory-create')
      else
        @promptText.removeClass('icon-file-directory-create').addClass('icon-file-add')

  onConfirm: (relativePath) ->
    endsWithDirectorySeparator = /\/$/.test(relativePath)
    pathToCreate = atom.project.resolve(relativePath)
    try
      if fs.existsSync(pathToCreate)
        @showError("'#{pathToCreate}' already exists. Try a different path.")
      else if endsWithDirectorySeparator
        fs.makeTreeSync(pathToCreate)
        @trigger 'directory-created', [pathToCreate]
        @cancel()
      else
        fs.writeFileSync(pathToCreate, '')
        atom.project.getRepo()?.getPathStatus(pathToCreate)
        @trigger 'file-created', [pathToCreate]
        @close()
    catch error
      @showError("#{error.message} Try a different path.")
