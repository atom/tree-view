fs = require 'fs-plus'
temp = require('temp').track()
path = require 'path'

DefaultFileIcons = require '../lib/default-file-icons'
FileIcons = require '../lib/file-icons'

describe 'FileIcons', ->
  afterEach ->
    FileIcons.setService(new DefaultFileIcons)

  it 'provides a default', ->
    expect(FileIcons.getService()).toBeDefined()
    expect(FileIcons.getService()).not.toBeNull()

  it 'allows the default to be overridden', ->
    service = new Object
    FileIcons.setService(service)

    expect(FileIcons.getService()).toBe(service)

  it 'allows the service to be reset to the default easily', ->
    service = new Object
    FileIcons.setService(service)
    FileIcons.resetService()

    expect(FileIcons.getService()).not.toBe(service)

  
  describe 'Class handling', ->
    [workspaceElement, treeView, files] = []
    
    beforeEach ->
      rootDirPath = fs.absolute(temp.mkdirSync('tree-view-root1'))
      
      for i in [1..3]
        filepath = path.join(rootDirPath, "file-#{i}.txt")
        fs.writeFileSync(filepath, "Nah")
      
      atom.project.setPaths([rootDirPath])
      workspaceElement = atom.views.getView(atom.workspace)
      jasmine.attachToDOM(workspaceElement)

      FileIcons.setService
        iconClassForPath: (path, file) ->
          [name, id] = path.match(/file-(\d+)\.txt$/)
          switch id
            when "1" then 'first second'
            when "2" then ['first', 'second']
            when "3" then file.constructor.name

      waitsForPromise ->
        atom.packages.activatePackage('tree-view')
      
      runs ->
        treeView = atom.packages.getActivePackage("tree-view").mainModule.createView()
        files = workspaceElement.querySelectorAll('li[is="tree-view-file"]')
      
    afterEach ->
      temp.cleanup()
  
    it 'allows multiple classes to be passed', ->
      expect(files[0].fileName.className).toBe('name icon first second')

    it 'allows an array of classes to be passed', ->
      expect(files[1].fileName.className).toBe('name icon first second')

    it 'passes a FileView reference as iconClassForPath\'s second argument', ->
      expect(files[2].fileName.className).toBe('name icon tree-view-file')
