_ = require 'underscore-plus'
fs = require 'fs-plus'
path = require 'path'
temp = require('temp').track()
os = require 'os'
{remote} = require 'electron'
eventHelpers = require "./event-helpers"

DefaultFileIcons = require '../lib/default-file-icons'
FileIcons = require '../lib/file-icons'

waitsForFileToOpen = (causeFileToOpen) ->
  waitsFor (done) ->
    disposable = atom.workspace.onDidOpen ->
      disposable.dispose()
      done()
    causeFileToOpen()

setupPaneFiles = ->
  rootDirPath = fs.absolute(temp.mkdirSync('tree-view'))

  dirPath = path.join(rootDirPath, "test-dir")

  fs.makeTreeSync(dirPath)
  [1..9].forEach (index) ->
    filePath = path.join(dirPath, "test-file-#{index}.txt")
    fs.writeFileSync(filePath, "#{index}. Some text.")

  return dirPath

getPaneFileName = (index) -> "test-file-#{index}.txt"

# TODO: Remove this after atom/atom#13977 lands in favor of unguarded `getCenter()` calls
getCenter = -> atom.workspace.getCenter?() ? atom.workspace

describe "TreeView", ->
  [treeView, path1, path2, root1, root2, sampleJs, sampleTxt, workspaceElement] = []

  selectEntry = (pathToSelect) ->
    treeView.selectEntryForPath atom.project.getDirectories()[0].resolve pathToSelect

  beforeEach ->
    expect(atom.config.get('core.allowPendingPaneItems')).toBeTruthy()

    fixturesPath = atom.project.getPaths()[0]
    path1 = path.join(fixturesPath, "root-dir1")
    path2 = path.join(fixturesPath, "root-dir2")
    atom.project.setPaths([path1, path2])

    workspaceElement = atom.views.getView(atom.workspace)

    waitsForPromise ->
      atom.packages.activatePackage("tree-view")

    runs ->
      atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
      treeView = atom.workspace.getLeftPanels()[0].getItem()
      files = treeView.element.querySelectorAll('.file')
      root1 = treeView.roots[0]
      root2 = treeView.roots[1]
      sampleJs = files[0]
      sampleTxt = files[1]

      expect(root1.directory.watchSubscription).toBeTruthy()

  afterEach ->
    temp.cleanup()

  describe ".initialize(project)", ->
    it "renders the root directories of the project and their contents alphabetically with subdirectories first, in a collapsed state", ->
      expect(root1.querySelector('.header .disclosure-arrow')).not.toHaveClass('expanded')
      expect(root1.querySelector('.header .name')).toHaveText('root-dir1')

      rootEntries = root1.querySelectorAll('.entries li')
      subdir0 = rootEntries[0]
      expect(subdir0).not.toHaveClass('expanded')
      expect(subdir0.querySelector('.name')).toHaveText('dir1')

      subdir2 = rootEntries[1]
      expect(subdir2).not.toHaveClass('expanded')
      expect(subdir2.querySelector('.name')).toHaveText('dir2')

      expect(subdir0.querySelector('[data-name="dir1"]')).toExist()
      expect(subdir2.querySelector('[data-name="dir2"]')).toExist()

      file1 = root1.querySelector('.file [data-name="tree-view.js"]')
      expect(file1).toExist()
      expect(file1).toHaveText('tree-view.js')

      file2 = root1.querySelector('.file [data-name="tree-view.txt"]')
      expect(file2).toExist()
      expect(file2).toHaveText('tree-view.txt')

    it "selects the root folder", ->
      expect(treeView.selectedEntry()).toEqual(treeView.roots[0])

    it "makes the root folder non-draggable", ->
      expect(treeView.roots[0].hasAttribute('draggable')).toBe(false)

    describe "when the project has no path", ->
      beforeEach ->
        atom.project.setPaths([])
        atom.packages.deactivatePackage("tree-view")

        waitsForPromise ->
          atom.packages.activatePackage("tree-view")

        runs ->
          treeView = atom.packages.getActivePackage("tree-view").mainModule.createView()

      it "does not attach to the workspace or create a root node when initialized", ->
        expect(treeView.element.parentElement).toBeFalsy()
        expect(treeView.roots).toHaveLength(0)

      it "does not attach to the workspace or create a root node when attach() is called", ->
        treeView.attach()
        expect(treeView.element.parentElement).toBeFalsy()
        expect(treeView.roots).toHaveLength(0)

      it "serializes without throwing an exception", ->
        expect(-> treeView.serialize()).not.toThrow()

      it "does not throw an exception when files are opened", ->
        filePath = path.join(os.tmpdir(), 'non-project-file.txt')
        fs.writeFileSync(filePath, 'test')

        waitsForPromise ->
          atom.workspace.open(filePath)

      it "does not reveal the active file", ->
        filePath = path.join(os.tmpdir(), 'non-project-file.txt')
        fs.writeFileSync(filePath, 'test')

        waitsForPromise ->
          atom.workspace.open(filePath)

        runs ->
          atom.commands.dispatch(workspaceElement, 'tree-view:reveal-active-file')
          expect(treeView.element.parentElement).toBeFalsy()
          expect(treeView.roots).toHaveLength(0)

      describe "when the project is assigned a path because a new buffer is saved", ->
        it "creates a root directory view and attaches to the workspace", ->
          waitsForPromise ->
            atom.workspace.open()

          runs ->
            projectPath = temp.mkdirSync('atom-project')
            atom.workspace.getActivePaneItem().saveAs(path.join(projectPath, 'test.txt'))
            expect(treeView.element.parentElement).toBeTruthy()
            expect(treeView.roots).toHaveLength(1)
            expect(fs.absolute(treeView.roots[0].getPath())).toBe fs.absolute(projectPath)

    describe "when the root view is opened to a file path", ->
      it "does not attach to the workspace but does create a root node when initialized", ->
        atom.packages.deactivatePackage("tree-view")
        atom.packages.packageStates = {}

        waitsForPromise ->
          atom.workspace.open('tree-view.js')

        waitsForPromise ->
          atom.packages.activatePackage('tree-view')

        runs ->
          treeView = atom.packages.getActivePackage("tree-view").mainModule.createView()
          expect(treeView.element.parentElement).toBeFalsy()
          expect(treeView.roots).toHaveLength(2)

    describe "when the root view is opened to a directory", ->
      it "attaches to the workspace", ->
        waitsForPromise ->
          atom.packages.activatePackage('tree-view')

        runs ->
          treeView = atom.packages.getActivePackage("tree-view").mainModule.createView()
          expect(treeView.element.parentElement).toBeTruthy()
          expect(treeView.roots).toHaveLength(2)

    describe "when the project is a .git folder", ->
      it "does not create the tree view", ->
        dotGit = path.join(temp.mkdirSync('repo'), '.git')
        fs.makeTreeSync(dotGit)
        atom.project.setPaths([dotGit])
        atom.packages.deactivatePackage("tree-view")
        atom.packages.packageStates = {}

        waitsForPromise ->
          atom.packages.activatePackage('tree-view')

        runs ->
          {treeView} = atom.packages.getActivePackage("tree-view").mainModule
          expect(treeView).toBeFalsy()

  describe "serialization", ->
    it "restores the attached/detached state of the tree-view", ->
      jasmine.attachToDOM(workspaceElement)
      atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
      expect(atom.workspace.getLeftPanels().length).toBe(0)

      atom.packages.deactivatePackage("tree-view")

      waitsForPromise ->
        atom.packages.activatePackage("tree-view")

      runs ->
        expect(atom.workspace.getLeftPanels().length).toBe(0)

    it "restores expanded directories and selected file when deserialized", ->
      root1.querySelectorAll('.directory')[0].dispatchEvent(new MouseEvent('click', {detail: 1, bubbles: true}))

      waitsForFileToOpen ->
        sampleJs.dispatchEvent(new MouseEvent('click', {detail: 1, bubbles: true}))

      runs ->
        atom.packages.deactivatePackage("tree-view")

      waitsForPromise ->
        atom.packages.activatePackage("tree-view")

      runs ->
        treeView = atom.workspace.getLeftPanels()[0].getItem()
        expect(treeView.element).toExist()
        expect(treeView.selectedEntry().textContent).toBe('tree-view.js')
        root1 = treeView.roots[0]
        expect(root1.querySelector(".directory")).toHaveClass("expanded")

    it "restores the focus state of the tree view", ->
      jasmine.attachToDOM(workspaceElement)
      treeView.focus()
      expect(treeView.list).toHaveFocus()
      atom.packages.deactivatePackage("tree-view")

      waitsForPromise ->
        atom.packages.activatePackage("tree-view")

      runs ->
        treeView = atom.workspace.getLeftPanels()[0].getItem()
        expect(treeView.list).toHaveFocus()

    it "restores the scroll top when toggled", ->
      workspaceElement.style.height = '5px'
      jasmine.attachToDOM(workspaceElement)
      expect(treeView.element).toBeVisible()
      treeView.focus()

      treeView.scrollTop(10)
      expect(treeView.scrollTop()).toBe(10)

      runs -> atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
      waitsFor -> treeView.element.offsetHeight is 0

      runs -> atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
      waitsFor -> treeView.element.offsetHeight > 0

      runs -> expect(treeView.scrollTop()).toBe(10)

    it "restores the scroll left when toggled", ->
      treeView.element.style.width = '5px'
      jasmine.attachToDOM(workspaceElement)
      expect(treeView.element).toBeVisible()
      treeView.focus()

      treeView.scroller.scrollLeft = 5
      expect(treeView.scroller.scrollLeft).toBe(5)

      runs -> atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
      waitsFor -> treeView.element.offsetHeight is 0

      runs -> atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
      waitsFor -> treeView.element.offsetHeight > 0

      runs -> expect(treeView.scroller.scrollLeft).toBe(5)

  describe "when tree-view:toggle is triggered on the root view", ->
    beforeEach ->
      jasmine.attachToDOM(workspaceElement)

    describe "when the tree view is visible", ->
      beforeEach ->
        expect(treeView.element).toBeVisible()

      describe "when the tree view is focused", ->
        it "hides the tree view", ->
          treeView.focus()
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
          expect(treeView.element).toBeHidden()

      describe "when the tree view is not focused", ->
        it "hides the tree view", ->
          workspaceElement.focus()
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
          expect(treeView.element).toBeHidden()

    describe "when the tree view is hidden", ->
      it "shows and focuses the tree view", ->
        treeView.detach()
        atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
        expect(treeView.element.parentElement).toBeTruthy()
        expect(treeView.list).toHaveFocus()

    describe "when tree-view:toggle-side is triggered on the root view", ->
      describe "when the tree view is on the left", ->
        it "moves the tree view to the right", ->
          expect(treeView.element).toBeVisible()
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle-side')
          expect(treeView.element.dataset.showOnRightSide).toBe('true')

      describe "when the tree view is on the right", ->
        beforeEach ->
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle-side')

        it "moves the tree view to the left", ->
          expect(treeView.element).toBeVisible()
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle-side')
          expect(treeView.element.dataset.showOnRightSide).toBe('false')

      describe "when the tree view is hidden", ->
        it "shows the tree view on the other side next time it is opened", ->
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle-side')
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
          expect(atom.workspace.getLeftPanels().length).toBe 0
          treeView = atom.workspace.getRightPanels()[0].getItem()
          expect(treeView.element.dataset.showOnRightSide).toBe('true')

  describe "when tree-view:toggle-focus is triggered on the root view", ->
    beforeEach ->
      jasmine.attachToDOM(workspaceElement)

    describe "when the tree view is hidden", ->
      it "shows and focuses the tree view", ->
        treeView.detach()
        atom.commands.dispatch(workspaceElement, 'tree-view:toggle-focus')
        expect(treeView.element.parentElement).toBeTruthy()
        expect(treeView.list).toHaveFocus()

    describe "when the tree view is shown", ->
      it "focuses the tree view", ->
        waitsForPromise ->
          atom.workspace.open() # When we call focus below, we want an editor to become focused

        runs ->
          workspaceElement.focus()
          expect(treeView.element).toBeVisible()
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle-focus')
          expect(treeView.element).toBeVisible()
          expect(treeView.list).toHaveFocus()

      describe "when the tree view is focused", ->
        it "unfocuses the tree view", ->
          waitsForPromise ->
            atom.workspace.open() # When we call focus below, we want an editor to become focused

          runs ->
            treeView.focus()
            expect(treeView.element).toBeVisible()
            atom.commands.dispatch(workspaceElement, 'tree-view:toggle-focus')
            expect(treeView.element).toBeVisible()
            expect(treeView.list).not.toHaveFocus()

  describe "when tree-view:reveal-active-file is triggered on the root view", ->
    beforeEach ->
      treeView.detach()
      spyOn(treeView, 'focus')

    describe "if the current file has a path", ->
      describe "if the tree-view.focusOnReveal config option is true", ->
        it "shows and focuses the tree view and selects the file", ->
          atom.config.set "tree-view.focusOnReveal", true

          waitsForPromise ->
            atom.workspace.open(path.join(atom.project.getPaths()[0], 'dir1', 'file1'))

          runs ->
            atom.commands.dispatch(workspaceElement, 'tree-view:reveal-active-file')
            expect(treeView.element.parentElement).toBeTruthy()
            expect(treeView.focus).toHaveBeenCalled()

          waitsForPromise ->
            treeView.focus.reset()
            atom.workspace.open(path.join(atom.project.getPaths()[1], 'dir3', 'file3'))

          runs ->
            atom.commands.dispatch(workspaceElement, 'tree-view:reveal-active-file')
            expect(treeView.element.parentElement).toBeTruthy()
            expect(treeView.focus).toHaveBeenCalled()

      describe "if the tree-view.focusOnReveal config option is false", ->
        it "shows the tree view and selects the file, but does not change the focus", ->
          atom.config.set "tree-view.focusOnReveal", false

          waitsForPromise ->
            atom.workspace.open(path.join(atom.project.getPaths()[0], 'dir1', 'file1'))

          runs ->
            atom.commands.dispatch(workspaceElement, 'tree-view:reveal-active-file')
            expect(treeView.element.parentElement).toBeTruthy()
            expect(treeView.focus).not.toHaveBeenCalled()

          waitsForPromise ->
            treeView.focus.reset()
            atom.workspace.open(path.join(atom.project.getPaths()[1], 'dir3', 'file3'))

          runs ->
            atom.commands.dispatch(workspaceElement, 'tree-view:reveal-active-file')
            expect(treeView.element.parentElement).toBeTruthy()
            expect(treeView.focus).not.toHaveBeenCalled()

    describe "if the current file has no path", ->
      it "shows and focuses the tree view, but does not attempt to select a specific file", ->
        waitsForPromise ->
          atom.workspace.open()

        runs ->
          expect(atom.workspace.getActivePaneItem().getPath()).toBeUndefined()
          atom.commands.dispatch(workspaceElement, 'tree-view:reveal-active-file')
          expect(treeView.element.parentElement).toBeTruthy()
          expect(treeView.focus).toHaveBeenCalled()

    describe "if there is no editor open", ->
      it "shows and focuses the tree view, but does not attempt to select a specific file", ->
        expect(atom.workspace.getActivePaneItem()).toBeUndefined()
        atom.commands.dispatch(workspaceElement, 'tree-view:reveal-active-file')
        expect(treeView.element.parentElement).toBeTruthy()
        expect(treeView.focus).toHaveBeenCalled()

    describe 'if there are more items than can be visible in the viewport', ->
      [rootDirPath] = []

      beforeEach ->
        rootDirPath = fs.absolute(temp.mkdirSync('tree-view-root1'))

        for i in [1..20]
          filepath = path.join(rootDirPath, "file-#{i}.txt")
          fs.writeFileSync(filepath, "doesn't matter")

        atom.project.setPaths([rootDirPath])
        treeView.element.style.height = '100px'
        jasmine.attachToDOM(workspaceElement)

      it 'scrolls the selected file into the visible view', ->
        # Open file at bottom
        waitsForPromise -> atom.workspace.open(path.join(rootDirPath, 'file-20.txt'))
        runs ->
          atom.commands.dispatch(workspaceElement, 'tree-view:reveal-active-file')
          expect(treeView.scrollTop()).toBeGreaterThan 400

        # Open file in the middle, should be centered in scroll
        waitsForPromise -> atom.workspace.open(path.join(rootDirPath, 'file-10.txt'))
        runs ->
          atom.commands.dispatch(workspaceElement, 'tree-view:reveal-active-file')
          expect(treeView.scrollTop()).toBeLessThan 400
          expect(treeView.scrollTop()).toBeGreaterThan 0

        # Open file at top
        waitsForPromise -> atom.workspace.open(path.join(rootDirPath, 'file-1.txt'))
        runs ->
          atom.commands.dispatch(workspaceElement, 'tree-view:reveal-active-file')
          expect(treeView.scrollTop()).toEqual 0

  describe "when tool-panel:unfocus is triggered on the tree view", ->
    it "surrenders focus to the workspace but remains open", ->
      waitsForPromise ->
        atom.workspace.open() # When we trigger 'tool-panel:unfocus' below, we want an editor to become focused

      runs ->
        jasmine.attachToDOM(workspaceElement)
        treeView.focus()
        expect(treeView.list).toHaveFocus()
        atom.commands.dispatch(treeView.element, 'tool-panel:unfocus')
        expect(treeView.element).toBeVisible()
        expect(treeView.list).not.toHaveFocus()
        expect(atom.workspace.getActivePane().isActive()).toBe(true)

  describe "copy path commands", ->
    [pathToSelect, relativizedPath] = []

    beforeEach ->
      pathToSelect = path.join(treeView.roots[0].directory.path, 'dir1', 'file1')
      relativizedPath = atom.project.relativize(pathToSelect)
      spyOn(atom.clipboard, 'write')

    describe "when tree-view:copy-full-path is triggered on the tree view", ->
      it "copies the selected path to the clipboard", ->
        treeView.selectedPath = pathToSelect
        atom.commands.dispatch(treeView.element, 'tree-view:copy-full-path')
        expect(atom.clipboard.write).toHaveBeenCalledWith(pathToSelect)

      describe "when there is no selected path", ->
        beforeEach ->
          treeView.selectedPath = null

        it "does nothing", ->
          atom.commands.dispatch(treeView.element, 'tree-view:copy-full-path')
          expect(atom.clipboard.write).not.toHaveBeenCalled()

    describe "when tree-view:copy-project-path is triggered on the tree view", ->
      it "copies the relativized selected path to the clipboard", ->
        treeView.selectedPath = pathToSelect
        atom.commands.dispatch(treeView.element, 'tree-view:copy-project-path')
        expect(atom.clipboard.write).toHaveBeenCalledWith(relativizedPath)

      describe "when there is no selected path", ->
        beforeEach ->
          treeView.selectedPath = null

        it "does nothing", ->
          atom.commands.dispatch(treeView.element, 'tree-view:copy-project-path')
          expect(atom.clipboard.write).not.toHaveBeenCalled()

  describe "when a directory's disclosure arrow is clicked", ->
    it "expands / collapses the associated directory", ->
      subdir = root1.querySelector('.entries > li')

      expect(subdir).not.toHaveClass('expanded')

      subdir.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

      expect(subdir).toHaveClass('expanded')

      subdir.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
      expect(subdir).not.toHaveClass('expanded')

    it "restores the expansion state of descendant directories", ->
      child = root1.querySelector('.entries > li')
      child.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

      grandchild = child.querySelector('.entries > li')
      grandchild.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

      root1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
      expect(treeView.roots[0]).not.toHaveClass('expanded')
      root1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

      # previously expanded descendants remain expanded
      expect(root1.querySelectorAll('.entries > li > .entries > li > .entries').length).toBe 1

      # collapsed descendants remain collapsed
      expect(root1.querySelectorAll('.entries > li')[1].querySelector('.entries')).not.toHaveClass('expanded')

    it "when collapsing a directory, removes change subscriptions from the collapsed directory and its descendants", ->
      child = root1.querySelector('li')
      child.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

      grandchild = child.querySelector('li')
      grandchild.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

      expect(root1.directory.watchSubscription).toBeTruthy()
      expect(child.directory.watchSubscription).toBeTruthy()
      expect(grandchild.directory.watchSubscription).toBeTruthy()

      root1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

      expect(root1.directory.watchSubscription).toBeFalsy()
      expect(child.directory.watchSubscription).toBeFalsy()
      expect(grandchild.directory.watchSubscription).toBeFalsy()

  describe "when mouse down fires on a file or directory", ->
    it "selects the entry", ->
      dir = root1.querySelector('li')
      expect(dir).not.toHaveClass 'selected'
      dir.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, detail: 1}))
      expect(dir).toHaveClass 'selected'

      expect(sampleJs).not.toHaveClass 'selected'
      sampleJs.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, detail: 1}))
      expect(sampleJs).toHaveClass 'selected'

  describe "when the package first activates and there is a file open (regression)", ->
    # Note: it is important that this test is not nested inside any other tests
    # that generate click events in their `beforeEach` hooks, as this test
    # tests incorrect behavior that only manifested itself on the first
    # UI interaction after the package was activated.
    describe "when the file is permanent", ->
      beforeEach ->
        waitsForFileToOpen ->
          atom.workspace.open('tree-view.js')

      it "does not throw when the file is double clicked", ->
        expect ->
          sampleJs.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          sampleJs.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 2}))
        .not.toThrow()

        waitsFor ->
          # Ensure we don't move on to the next test until the promise spawned click event resolves.
          # (If it resolves in the middle of the next test we'll pollute that test).
          not treeView.currentlyOpening.has(atom.workspace.getActivePaneItem().getPath())

    describe "when the file is pending", ->
      editor = null

      beforeEach ->
        waitsForPromise ->
          atom.workspace.open('tree-view.js', pending: true).then (o) ->
            editor = o

      it "marks the pending file as permanent", ->
        runs ->
          expect(atom.workspace.getActivePane().getActiveItem()).toBe editor
          expect(atom.workspace.getActivePane().getPendingItem()).toBe editor
          sampleJs.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          sampleJs.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 2}))

        waitsFor ->
          atom.workspace.getActivePane().getPendingItem() is null

  describe "when files are clicked", ->
    beforeEach ->
      jasmine.attachToDOM(workspaceElement)

    describe "when a file is single-clicked", ->

      describe "when core.allowPendingPaneItems is set to true (default)", ->
        activePaneItem = null
        beforeEach ->
          treeView.focus()

          waitsForFileToOpen ->
            sampleJs.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

          runs ->
            activePaneItem = atom.workspace.getActivePaneItem()

        it "selects the file and retains focus on tree-view", ->
          expect(sampleJs).toHaveClass 'selected'
          expect(treeView.element).toHaveFocus()

        it "opens the file in a pending state", ->
          expect(activePaneItem.getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.js')
          expect(atom.workspace.getActivePane().getPendingItem()).toEqual activePaneItem

      describe "when core.allowPendingPaneItems is set to false", ->
        beforeEach ->
          atom.config.set('core.allowPendingPaneItems', false)
          spyOn(atom.workspace, 'open')

          treeView.focus()
          sampleJs.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

        it "selects the file and retains focus on tree-view", ->
          expect(sampleJs).toHaveClass 'selected'
          expect(treeView.element).toHaveFocus()

        it "does not open the file", ->
          expect(atom.workspace.open).not.toHaveBeenCalled()

      describe "when it is immediately opened with `::openSelectedEntry` afterward", ->
        it "does not open a duplicate file", ->
          # Fixes https://github.com/atom/atom/issues/11391
          openedCount = 0
          originalOpen = atom.workspace.open.bind(atom.workspace)
          spyOn(atom.workspace, 'open').andCallFake (uri, options) ->
            originalOpen(uri, options).then -> openedCount++

          sampleJs.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          treeView.openSelectedEntry()

          waitsFor 'open to be called twice', ->
            openedCount is 2

          runs ->
            expect(atom.workspace.getActivePane().getItems().length).toBe 1

    describe "when a file is double-clicked", ->
      activePaneItem = null

      beforeEach ->
        treeView.focus()

      it "opens the file and focuses it", ->
        waitsForFileToOpen ->
          sampleJs.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          sampleJs.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 2}))

        waitsFor "next tick to avoid race condition", (done) ->
          setImmediate(done)

        runs ->
          activePaneItem = atom.workspace.getActivePaneItem()
          expect(activePaneItem.getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.js')
          expect(atom.views.getView(activePaneItem)).toHaveFocus()

      it "does not open a duplicate file", ->
        # Fixes https://github.com/atom/atom/issues/11391
        openedCount = 0
        originalOpen = atom.workspace.open.bind(atom.workspace)
        spyOn(atom.workspace, 'open').andCallFake (uri, options) ->
          originalOpen(uri, options).then -> openedCount++

        sampleJs.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
        sampleJs.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 2}))

        waitsFor 'open to be called twice', ->
          openedCount is 2

        runs ->
          expect(atom.workspace.getActivePane().getItems().length).toBe 1

  describe "when a directory is single-clicked", ->
    it "is selected", ->
      subdir = root1.querySelector('.directory')
      subdir.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
      expect(subdir).toHaveClass 'selected'

  describe "when a directory is double-clicked", ->
    it "toggles the directory expansion state and does not change the focus to the editor", ->
      jasmine.attachToDOM(workspaceElement)

      subdir = null
      waitsForFileToOpen ->
        sampleJs.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

      runs ->
        treeView.focus()
        subdir = root1.querySelector('.directory')
        subdir.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
        expect(subdir).toHaveClass 'selected'
        expect(subdir).toHaveClass 'expanded'
        subdir.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 2}))
        expect(subdir).toHaveClass 'selected'
        expect(subdir).not.toHaveClass 'expanded'
        expect(treeView.element).toHaveFocus()

  describe "when an directory is alt-clicked", ->
    describe "when the directory is collapsed", ->
      it "recursively expands the directory", ->
        root1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
        treeView.roots[0].collapse()

        expect(treeView.roots[0]).not.toHaveClass 'expanded'
        root1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1, altKey: true}))
        expect(treeView.roots[0]).toHaveClass 'expanded'

        children = root1.querySelectorAll('.directory')
        expect(children.length).toBeGreaterThan 0
        for child in children
          expect(child).toHaveClass 'expanded'

    describe "when the directory is expanded", ->
      parent    = null
      children  = null

      beforeEach ->
        parent = root1.querySelectorAll('.entries > .directory')[2]
        parent.expand()
        children = parent.querySelectorAll('.expanded.directory')
        for child in children
          child.expand()

      it "recursively collapses the directory", ->
        parent.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
        parent.expand()
        expect(parent).toHaveClass 'expanded'
        for child in children
          child.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          child.expand()
          expect(child).toHaveClass 'expanded'

        parent.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1, altKey: true}))

        expect(parent).not.toHaveClass 'expanded'
        for child in children
          expect(child).not.toHaveClass 'expanded'
        expect(treeView.roots[0]).toHaveClass 'expanded'

  describe "when the active item changes on the active pane", ->
    describe "when the item has a path", ->
      it "selects the entry with that path in the tree view if it is visible", ->
        waitsForFileToOpen ->
          sampleJs.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

        waitsForPromise ->
          atom.workspace.open(atom.project.getDirectories()[0].resolve('tree-view.txt'))

        runs ->
          expect(sampleTxt).toHaveClass 'selected'
          expect(treeView.element.querySelectorAll('.selected').length).toBe 1

      it "selects the path's parent dir if its entry is not visible", ->
        waitsForPromise ->
          atom.workspace.open(path.join('dir1', 'sub-dir1', 'sub-file1'))

        runs ->
          dirView = root1.querySelector('.directory')
          expect(dirView).toHaveClass 'selected'

      describe "when the tree-view.autoReveal config setting is true", ->
        beforeEach ->
          atom.config.set "tree-view.autoReveal", true

        it "selects the active item's entry in the tree view, expanding parent directories if needed", ->
          waitsForPromise ->
            atom.workspace.open(path.join('dir1', 'sub-dir1', 'sub-file1'))

          runs ->
            dirView = root1.querySelector('.directory')
            fileView = root1.querySelector('.file')
            expect(dirView).not.toHaveClass 'selected'
            expect(fileView).toHaveClass 'selected'
            expect(treeView.element.querySelectorAll('.selected').length).toBe 1

    describe "when the item has no path", ->
      it "deselects the previously selected entry", ->
        waitsForFileToOpen ->
          sampleJs.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

        runs ->
          atom.workspace.getActivePane().activateItem(document.createElement("div"))
          expect(treeView.element.querySelector('.selected')).not.toExist()

  describe "when a different editor becomes active", ->
    beforeEach ->
      jasmine.attachToDOM(workspaceElement)

    it "selects the file in that is open in that editor", ->
      leftEditorPane = null

      waitsForFileToOpen ->
        sampleJs.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

      runs ->
        leftEditorPane = atom.workspace.getActivePane()
        leftEditorPane.splitRight()

      waitsForFileToOpen ->
        sampleTxt.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

      runs ->
        expect(sampleTxt).toHaveClass('selected')
        leftEditorPane.activate()
        expect(sampleJs).toHaveClass('selected')

  describe "keyboard navigation", ->
    afterEach ->
      expect(treeView.element.querySelectorAll('.selected').length).toBeLessThan 2

    describe "core:move-down", ->
      describe "when a collapsed directory is selected", ->
        it "skips to the next directory", ->
          root1.querySelector('.directory').dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

          atom.commands.dispatch(treeView.element, 'core:move-down')
          expect(root1.querySelectorAll('.directory')[1]).toHaveClass 'selected'

      describe "when an expanded directory is selected", ->
        it "selects the first entry of the directory", ->
          subdir = root1.querySelectorAll('.directory')[1]
          subdir.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

          atom.commands.dispatch(treeView.element, 'core:move-down')

          expect(subdir.querySelector('.entry')).toHaveClass 'selected'

      describe "when the last entry of an expanded directory is selected", ->
        it "selects the entry after its parent directory", ->
          subdir1 = root1.querySelectorAll('.directory')[1]
          subdir1.expand()
          waitsForFileToOpen ->
            entries = subdir1.querySelectorAll('.entry')
            entries[entries.length - 1].dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

          runs ->
            atom.commands.dispatch(treeView.element, 'core:move-down')
            expect(root1.querySelectorAll('.directory')[2]).toHaveClass 'selected'

      describe "when the last directory of another last directory is selected", ->
        [nested, nested2] = []

        beforeEach ->
          nested = root1.querySelectorAll('.directory')[2]
          expect(nested.querySelector('.header').textContent).toContain 'nested'
          nested.expand()
          entries = nested.querySelectorAll('.entry')
          nested2 = entries[entries.length - 1]
          nested2.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          nested2.collapse()

        describe "when the directory is collapsed", ->
          it "selects the entry after its grandparent directory", ->
            atom.commands.dispatch(treeView.element, 'core:move-down')
            expect(nested.nextSibling).toHaveClass 'selected'

        describe "when the directory is expanded", ->
          it "selects the entry after its grandparent directory", ->
            nested2.expand()
            nested2.querySelector('.file').remove() # kill the .gitkeep file, which has to be there but screws the test
            atom.commands.dispatch(treeView.element, 'core:move-down')
            expect(nested.nextSibling).toHaveClass 'selected'

      describe "when the last entry of the last directory is selected", ->
        it "does not change the selection", ->
          entries = root2.querySelectorAll('.entries .entry')
          lastEntry = entries[entries.length - 1]
          waitsForFileToOpen ->
            lastEntry.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

          runs ->
            atom.commands.dispatch(treeView.element, 'core:move-down')
            expect(lastEntry).toHaveClass 'selected'

    describe "core:move-up", ->
      describe "when there is an expanded directory before the currently selected entry", ->
        it "selects the last entry in the expanded directory", ->
          directories = root1.querySelectorAll('.directory')
          lastDir = directories[directories.length - 1]
          fileAfterDir = lastDir.nextSibling
          lastDir.expand()
          waitsForFileToOpen ->
            fileAfterDir.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

          runs ->
            atom.commands.dispatch(treeView.element, 'core:move-up')
            entries = lastDir.querySelectorAll('.entry')
            expect(entries[entries.length - 1]).toHaveClass 'selected'

      describe "when there is an entry before the currently selected entry", ->
        it "selects the previous entry", ->
          entries = root1.querySelectorAll('.entry')
          lastEntry = entries[entries.length - 1]
          waitsForFileToOpen ->
            lastEntry.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

          runs ->
            atom.commands.dispatch(treeView.element, 'core:move-up')
            expect(lastEntry.previousSibling).toHaveClass 'selected'

      describe "when there is no entry before the currently selected entry, but there is a parent directory", ->
        it "selects the parent directory", ->
          subdir = root1.querySelector('.directory')
          subdir.expand()
          subdir.querySelector('.entries .entry').dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

          atom.commands.dispatch(treeView.element, 'core:move-up')

          expect(subdir).toHaveClass 'selected'

      describe "when there is no parent directory or previous entry", ->
        it "does not change the selection", ->
          root1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          atom.commands.dispatch(treeView.element, 'core:move-up')
          expect(treeView.roots[0]).toHaveClass 'selected'

      describe "when the tree view is empty", ->
        it "does nothing", ->
          atom.commands.dispatch(treeView.roots[0].querySelector(".header"), "tree-view:remove-project-folder")
          atom.commands.dispatch(treeView.roots[0].querySelector(".header"), "tree-view:remove-project-folder")
          expect(atom.project.getPaths()).toHaveLength(0)
          expect(treeView.element.querySelectorAll('.selected').length).toBe 0

          atom.commands.dispatch(treeView.element, 'core:move-up')
          expect(treeView.element.querySelectorAll('.selected').length).toBe 0

    describe "core:move-to-top", ->
      it "scrolls to the top", ->
        treeView.element.style.height = '100px'
        jasmine.attachToDOM(treeView.element)
        element.expand() for element in treeView.element.querySelectorAll('.directory')
        expect(treeView.list.offsetHeight).toBeGreaterThan treeView.scroller.offsetHeight
        expect(treeView.scroller.scrollTop).toBe(0)

        entryCount = treeView.element.querySelectorAll(".entry").length
        _.times entryCount, -> atom.commands.dispatch(treeView.element, 'core:move-down')
        expect(treeView.scroller.scrollTop).toBeGreaterThan 0

        atom.commands.dispatch(treeView.element, 'core:move-to-top')
        expect(treeView.scroller.scrollTop).toBe(0)

      it "selects the root entry", ->
        entryCount = treeView.element.querySelectorAll(".entry").length
        _.times entryCount, -> atom.commands.dispatch(treeView.element, 'core:move-down')

        expect(treeView.roots[0]).not.toHaveClass 'selected'
        atom.commands.dispatch(treeView.element, 'core:move-to-top')
        expect(treeView.roots[0]).toHaveClass 'selected'

    describe "core:move-to-bottom", ->
      it "scrolls to the bottom", ->
        treeView.element.style.height = '100px'
        jasmine.attachToDOM(treeView.element)
        element.expand() for element in treeView.element.querySelectorAll('.directory')
        expect(treeView.list.offsetHeight).toBeGreaterThan treeView.scroller.offsetHeight
        expect(treeView.scroller.scrollTop).toBe(0)

        atom.commands.dispatch(treeView.element, 'core:move-to-bottom')
        expect(treeView.scroller.scrollTop).toBeGreaterThan(0)

        treeView.roots[0].collapse()
        treeView.roots[1].collapse()
        atom.commands.dispatch(treeView.element, 'core:move-to-bottom')
        expect(treeView.scroller.scrollTop).toBe(0)

      it "selects the last entry", ->
        expect(treeView.roots[0]).toHaveClass 'selected'
        atom.commands.dispatch(treeView.element, 'core:move-to-bottom')
        entries = root2.querySelectorAll('.entry')
        expect(entries[entries.length - 1]).toHaveClass 'selected'

    describe "core:page-up", ->
      it "scrolls up a page", ->
        treeView.element.style.height = '5px'
        jasmine.attachToDOM(treeView.element)
        element.expand() for element in treeView.element.querySelectorAll('.directory')
        expect(treeView.list.offsetHeight).toBeGreaterThan treeView.scroller.offsetHeight

        expect(treeView.scroller.scrollTop).toBe(0)
        treeView.scrollToBottom()
        scrollTop = treeView.scroller.scrollTop
        expect(scrollTop).toBeGreaterThan 0

        atom.commands.dispatch(treeView.element, 'core:page-up')
        expect(treeView.scroller.scrollTop).toBe scrollTop - treeView.element.offsetHeight

    describe "core:page-down", ->
      it "scrolls down a page", ->
        treeView.element.style.height = '5px'
        jasmine.attachToDOM(treeView.element)
        element.expand() for element in treeView.element.querySelectorAll('.directory')
        expect(treeView.list.offsetHeight).toBeGreaterThan treeView.scroller.offsetHeight

        expect(treeView.scroller.scrollTop).toBe(0)
        atom.commands.dispatch(treeView.element, 'core:page-down')
        expect(treeView.scroller.scrollTop).toBe treeView.element.offsetHeight

    describe "movement outside of viewable region", ->
      it "scrolls the tree view to the selected item", ->
        treeView.element.style.height = '100px'
        jasmine.attachToDOM(treeView.element)
        element.expand() for element in treeView.element.querySelectorAll('.directory')
        expect(treeView.list.offsetHeight).toBeGreaterThan treeView.scroller.offsetHeight

        atom.commands.dispatch(treeView.element, 'core:move-down')
        expect(treeView.scroller.scrollTop).toBe(0)

        entryCount = treeView.element.querySelectorAll(".entry").length
        entryHeight = treeView.element.querySelector('.file').offsetHeight

        _.times entryCount, -> atom.commands.dispatch(treeView.element, 'core:move-down')
        expect(treeView.scroller.scrollTop + treeView.element.offsetHeight).toBeGreaterThan((entryCount * entryHeight) - 1)

        _.times entryCount, -> atom.commands.dispatch(treeView.element, 'core:move-up')
        expect(treeView.scroller.scrollTop).toBe 0

    describe "tree-view:expand-directory", ->
      describe "when a directory entry is selected", ->
        it "expands the current directory", ->
          subdir = root1.querySelector('.directory')
          subdir.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          subdir.collapse()

          expect(subdir).not.toHaveClass 'expanded'
          atom.commands.dispatch(treeView.element, 'tree-view:expand-item')
          expect(subdir).toHaveClass 'expanded'

        describe "when the directory is already expanded", ->
          describe "when the directory is empty", ->
            it "does nothing", ->
              rootDirPath = fs.absolute(temp.mkdirSync('tree-view-root1'))
              fs.mkdirSync(path.join(rootDirPath, "empty-dir"))
              atom.project.setPaths([rootDirPath])
              rootView = treeView.roots[0]

              subdir = rootView.querySelector('.directory')
              subdir.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
              subdir.expand()
              expect(subdir).toHaveClass('expanded')
              expect(subdir).toHaveClass('selected')

              atom.commands.dispatch(treeView.element, 'tree-view:expand-directory')
              expect(subdir).toHaveClass('expanded')
              expect(subdir).toHaveClass('selected')

          describe "when the directory has entries", ->
            it "moves the cursor down to the first sub-entry", ->
              subdir = root1.querySelector('.directory')
              subdir.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
              subdir.expand()

              atom.commands.dispatch(treeView.element, 'tree-view:expand-item')
              expect(subdir.querySelector('.entry')).toHaveClass('selected')

      describe "when a file entry is selected", ->
        it "does nothing", ->
          waitsForFileToOpen ->
            root1.querySelector('.file').dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

          runs ->
            atom.commands.dispatch(treeView.element, 'tree-view:expand-directory')

    describe "tree-view:recursive-expand-directory", ->
      describe "when an collapsed root is recursively expanded", ->
        it "expands the root and all subdirectories", ->
          root1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          treeView.roots[0].collapse()

          expect(treeView.roots[0]).not.toHaveClass 'expanded'
          atom.commands.dispatch(treeView.element, 'tree-view:recursive-expand-directory')
          expect(treeView.roots[0]).toHaveClass 'expanded'

          children = root1.querySelectorAll('.directory')
          expect(children.length).toBeGreaterThan 0
          for child in children
            expect(child).toHaveClass 'expanded'

    describe "tree-view:collapse-directory", ->
      subdir = null

      beforeEach ->
        subdir = root1.querySelector('.entries > .directory')
        subdir.expand()

      describe "when an expanded directory is selected", ->
        it "collapses the selected directory", ->
          subdir.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          subdir.expand()
          expect(subdir).toHaveClass 'expanded'

          atom.commands.dispatch(treeView.element, 'tree-view:collapse-directory')

          expect(subdir).not.toHaveClass 'expanded'
          expect(treeView.roots[0]).toHaveClass 'expanded'

      describe "when a collapsed directory is selected", ->
        it "collapses and selects the selected directory's parent directory", ->
          directories = subdir.querySelector('.directory')
          directories.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          directories.collapse()
          atom.commands.dispatch(treeView.element, 'tree-view:collapse-directory')

          expect(subdir).not.toHaveClass 'expanded'
          expect(subdir).toHaveClass 'selected'
          expect(treeView.roots[0]).toHaveClass 'expanded'

      describe "when collapsed root directory is selected", ->
        it "does not raise an error", ->
          treeView.roots[0].collapse()
          treeView.selectEntry(treeView.roots[0])

          atom.commands.dispatch(treeView.element, 'tree-view:collapse-directory')

      describe "when a file is selected", ->
        it "collapses and selects the selected file's parent directory", ->
          waitsForFileToOpen ->
            subdir.querySelector('.file').dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

          runs ->
            atom.commands.dispatch(treeView.element, 'tree-view:collapse-directory')
            expect(subdir).not.toHaveClass 'expanded'
            expect(subdir).toHaveClass 'selected'
            expect(treeView.roots[0]).toHaveClass 'expanded'

    describe "tree-view:recursive-collapse-directory", ->
      parent    = null
      children  = null

      beforeEach ->
        parent = root1.querySelectorAll('.entries > .directory')[2]
        parent.expand()
        children = parent.querySelectorAll('.expanded.directory')
        for child in children
          child.expand()

      describe "when an expanded directory is recursively collapsed", ->
        it "collapses the directory and all its child directories", ->
          parent.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          parent.expand()
          expect(parent).toHaveClass 'expanded'
          for child in children
            child.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
            child.expand()
            expect(child).toHaveClass 'expanded'

          atom.commands.dispatch(treeView.element, 'tree-view:recursive-collapse-directory')

          expect(parent).not.toHaveClass 'expanded'
          for child in children
            expect(child).not.toHaveClass 'expanded'
          expect(treeView.roots[0]).toHaveClass 'expanded'

    describe "tree-view:open-selected-entry", ->
      describe "when a file is selected", ->
        it "opens the file in the editor and focuses it", ->
          jasmine.attachToDOM(workspaceElement)

          treeView.selectEntry(sampleJs)

          waitsForFileToOpen ->
            atom.commands.dispatch(treeView.element, 'tree-view:open-selected-entry')

          runs ->
            item = atom.workspace.getActivePaneItem()
            expect(item.getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.js')
            expect(atom.views.getView(item)).toHaveFocus()
            expect(atom.workspace.getActivePane().getPendingItem()).not.toEqual item

        it "opens pending items in a permanent state", ->
          jasmine.attachToDOM(workspaceElement)

          treeView.selectEntry(sampleJs)

          waitsForFileToOpen ->
            atom.commands.dispatch(treeView.element, 'tree-view:expand-item')

          runs ->
            item = atom.workspace.getActivePaneItem()
            expect(item.getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.js')
            expect(atom.workspace.getActivePane().getPendingItem()).toEqual item
            expect(atom.views.getView(item)).toHaveFocus()

            treeView.selectEntry(sampleJs)

          waitsForFileToOpen ->
            atom.commands.dispatch(treeView.element, 'tree-view:open-selected-entry')

          runs ->
            item = atom.workspace.getActivePaneItem()
            expect(item.getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.js')
            expect(atom.views.getView(item)).toHaveFocus()
            expect(atom.workspace.getActivePane().getPendingItem()).not.toEqual item

      describe "when a directory is selected", ->
        it "expands or collapses the directory", ->
          subdir = root1.querySelector('.directory')
          subdir.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          subdir.collapse()

          expect(subdir).not.toHaveClass 'expanded'
          atom.commands.dispatch(treeView.element, 'tree-view:open-selected-entry')
          expect(subdir).toHaveClass 'expanded'
          atom.commands.dispatch(treeView.element, 'tree-view:open-selected-entry')
          expect(subdir).not.toHaveClass 'expanded'

      describe "when nothing is selected", ->
        it "does nothing", ->
          atom.commands.dispatch(treeView.element, 'tree-view:open-selected-entry')
          expect(atom.workspace.getActivePaneItem()).toBeUndefined()

    describe "opening in new split panes", ->
      splitOptions =
        right: ['horizontal', 'after']
        left: ['horizontal', 'before']
        up: ['vertical', 'before']
        down: ['vertical', 'after']

      _.each splitOptions, (options, direction) ->
        command = "tree-view:open-selected-entry-#{direction}"

        describe command, ->
          describe "when a file is selected", ->
            previousPane = null

            beforeEach ->
              jasmine.attachToDOM(workspaceElement)

              waitsForFileToOpen ->
                sampleJs.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

              runs ->
                previousPane = atom.workspace.getActivePane()
                spyOn(previousPane, 'split').andCallThrough()

              waitsForFileToOpen ->
                selectEntry 'tree-view.txt'
                atom.commands.dispatch(treeView.element, command)

            it "creates a new split pane #{direction}", ->
              expect(previousPane.split).toHaveBeenCalledWith options...

            it "opens the file in the new split pane and focuses it", ->
              splitPane = atom.workspace.getActivePane()
              splitPaneItem = atom.workspace.getActivePaneItem()
              expect(previousPane).not.toBe splitPane
              expect(splitPaneItem.getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.txt')
              expect(atom.views.getView(splitPaneItem)).toHaveFocus()

          describe "when a directory is selected", ->
            it "does nothing", ->
              atom.commands.dispatch(treeView.element, command)
              expect(atom.workspace.getActivePaneItem()).toBeUndefined()

          describe "when nothing is selected", ->
            it "does nothing", ->
              atom.commands.dispatch(treeView.element, command)
              expect(atom.workspace.getActivePaneItem()).toBeUndefined()

    describe "tree-view:expand-item", ->
      describe "when a file is selected", ->
        it "opens the file in the editor in pending state and focuses it", ->
          jasmine.attachToDOM(workspaceElement)

          treeView.selectEntry(sampleJs)

          waitsForFileToOpen ->
            atom.commands.dispatch(treeView.element, 'tree-view:expand-item')

          runs ->
            item = atom.workspace.getActivePaneItem()
            expect(item.getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.js')
            expect(atom.workspace.getActivePane().getPendingItem()).toEqual item
            expect(atom.views.getView(item)).toHaveFocus()

      describe "when a directory is selected", ->
        it "expands the directory", ->
          subdir = root1.querySelector('.directory')
          subdir.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          subdir.collapse()

          expect(subdir).not.toHaveClass 'expanded'
          atom.commands.dispatch(treeView.element, 'tree-view:expand-item')
          expect(subdir).toHaveClass 'expanded'

      describe "when nothing is selected", ->
        it "does nothing", ->
          atom.commands.dispatch(treeView.element, 'tree-view:expand-item')
          expect(atom.workspace.getActivePaneItem()).toBeUndefined()

  describe "opening in existing split panes", ->
    beforeEach ->
      jasmine.attachToDOM(workspaceElement)
      [1..9].forEach ->
        waitsForFileToOpen ->
          selectEntry "tree-view.js"
          atom.commands.dispatch(treeView.element, 'tree-view:open-selected-entry-right')

    it "should have opened all windows", ->
      expect(getCenter().getPanes().length).toBe 9

    [0..8].forEach (index) ->
      paneNumber = index + 1
      command = "tree-view:open-selected-entry-in-pane-#{paneNumber}"

      describe command, ->
        describe "when a file is selected", ->
          beforeEach ->
            selectEntry 'tree-view.txt'
            waitsForFileToOpen ->
              atom.commands.dispatch treeView.element, command

          it "opens the file in pane #{paneNumber} and focuses it", ->
            pane = getCenter().getPanes()[index]
            item = atom.workspace.getActivePaneItem()
            expect(atom.views.getView(pane)).toHaveFocus()
            expect(item.getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.txt')

  describe "opening existing opened files in existing split panes", ->
    beforeEach ->
      projectPath = setupPaneFiles()
      atom.project.setPaths([projectPath])

      jasmine.attachToDOM(workspaceElement)
      [1..9].forEach (index) ->
        waitsForFileToOpen ->
          selectEntry getPaneFileName(index)
          atom.commands.dispatch(treeView.element, 'tree-view:open-selected-entry-right')

    it "should have opened all windows", ->
      expect(getCenter().getPanes().length).toBe 9

    [0..8].forEach (index) ->
      paneNumber = index + 1
      command = "tree-view:open-selected-entry-in-pane-#{paneNumber}"

      describe command, ->
        [1..9].forEach (fileIndex) ->
          fileName = getPaneFileName(fileIndex)
          describe "when a file is selected that is already open in pane #{fileIndex}", ->
            beforeEach ->
              selectEntry fileName
              waitsForFileToOpen ->
                atom.commands.dispatch treeView.element, command

            it "opens the file in pane #{paneNumber} and focuses it", ->
              pane = getCenter().getPanes()[index]
              item = atom.workspace.getActivePaneItem()
              expect(atom.views.getView(pane)).toHaveFocus()
              expect(item.getPath()).toBe atom.project.getDirectories()[0].resolve(fileName)

  describe "removing a project folder", ->
    it "removes the folder from the project", ->
      rootHeader = treeView.roots[1].querySelector(".header")
      atom.commands.dispatch(rootHeader, "tree-view:remove-project-folder")
      expect(atom.project.getPaths()).toHaveLength(1)

  describe "file modification", ->
    [dirView, dirView2, dirView3, fileView, fileView2, fileView3, fileView4] = []
    [rootDirPath, rootDirPath2, dirPath, dirPath2, dirPath3, filePath, filePath2, filePath3, filePath4] = []

    beforeEach ->
      rootDirPath = fs.absolute(temp.mkdirSync('tree-view-root1'))
      rootDirPath2 = fs.absolute(temp.mkdirSync('tree-view-root2'))

      dirPath = path.join(rootDirPath, "test-dir")
      filePath = path.join(dirPath, "test-file.txt")

      dirPath2 = path.join(rootDirPath, "test-dir2")
      filePath2 = path.join(dirPath2, "test-file2.txt")
      filePath3 = path.join(dirPath2, "test-file3.txt")

      dirPath3 = path.join(rootDirPath2, "test-dir3")
      filePath4 = path.join(dirPath3, "test-file4.txt")

      fs.makeTreeSync(dirPath)
      fs.writeFileSync(filePath, "doesn't matter 1")

      fs.makeTreeSync(dirPath2)
      fs.writeFileSync(filePath2, "doesn't matter 2")
      fs.writeFileSync(filePath3, "doesn't matter 3")

      fs.makeTreeSync(dirPath3)
      fs.writeFileSync(filePath4, "doesn't matter 4")

      atom.project.setPaths([rootDirPath, rootDirPath2])

      root1 = treeView.roots[0]
      root2 = treeView.roots[1]
      [dirView, dirView2] = root1.querySelectorAll('.directory')
      dirView.expand()
      dirView2.expand()
      dirView3 = root2.querySelector('.directory')
      dirView3.expand()
      [fileView, fileView2, fileView3] = root1.querySelectorAll('.file')
      fileView4 = root2.querySelector('.file')

    describe "tree-view:copy", ->
      LocalStorage = window.localStorage
      beforeEach ->
        LocalStorage.clear()

        waitsForFileToOpen ->
          fileView2.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

        runs ->
          atom.commands.dispatch(treeView.element, "tree-view:copy")

      describe "when a file is selected", ->
        it "saves the selected file/directory path to localStorage['tree-view:copyPath']", ->
          expect(LocalStorage['tree-view:copyPath']).toBeTruthy()

        it "Clears the localStorage['tree-view:cutPath']", ->
          LocalStorage.clear()
          LocalStorage['tree-view:cutPath'] = "I live!"
          atom.commands.dispatch(treeView.element, "tree-view:copy")
          expect(LocalStorage['tree-view:cutPath']).toBeFalsy

      describe 'when multiple files are selected', ->
        it 'saves the selected item paths in localStorage', ->
          fileView3.classList.add('selected')
          atom.commands.dispatch(treeView.element, "tree-view:copy")
          storedPaths = JSON.parse(LocalStorage['tree-view:copyPath'])

          expect(storedPaths.length).toBe 2
          expect(storedPaths[0]).toBe fileView2.getPath()
          expect(storedPaths[1]).toBe fileView3.getPath()

    describe "tree-view:cut", ->
      LocalStorage = window.localStorage

      beforeEach ->
        LocalStorage.clear()

        waitsForFileToOpen ->
          fileView2.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

        runs ->
          atom.commands.dispatch(treeView.element, "tree-view:cut")

      describe "when a file is selected", ->
        it "saves the selected file/directory path to localStorage['tree-view:cutPath']", ->
          expect(LocalStorage['tree-view:cutPath']).toBeTruthy()

        it "Clears the localStorage['tree-view:copyPath']", ->
          LocalStorage.clear()
          LocalStorage['tree-view:copyPath'] = "I live to CUT!"
          atom.commands.dispatch(treeView.element, "tree-view:cut")
          expect(LocalStorage['tree-view:copyPath']).toBeFalsy()

      describe 'when multiple files are selected', ->
        it 'saves the selected item paths in localStorage', ->
          LocalStorage.clear()
          fileView3.classList.add('selected')
          atom.commands.dispatch(treeView.element, "tree-view:cut")
          storedPaths = JSON.parse(LocalStorage['tree-view:cutPath'])

          expect(storedPaths.length).toBe 2
          expect(storedPaths[0]).toBe fileView2.getPath()
          expect(storedPaths[1]).toBe fileView3.getPath()

    describe "tree-view:paste", ->
      LocalStorage = window.localStorage

      beforeEach ->
        LocalStorage.clear()

      describe "when attempting to paste a directory into itself", ->
        describe "when copied", ->
          beforeEach ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([dirPath])

          it "makes a copy inside itself", ->
            newPath = path.join(dirPath, path.basename(dirPath))
            dirView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
            expect(-> atom.commands.dispatch(treeView.element, "tree-view:paste")).not.toThrow()
            expect(fs.existsSync(newPath)).toBeTruthy()

          it "dispatches an event to the tree-view", ->
            newPath = path.join(dirPath, path.basename(dirPath))
            callback = jasmine.createSpy("onEntryCopied")
            treeView.onEntryCopied(callback)

            dirView.click()
            atom.commands.dispatch(treeView.element, "tree-view:paste")
            expect(callback).toHaveBeenCalledWith(initialPath: dirPath, newPath: newPath)

          it 'does not keep copying recursively', ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([dirPath])
            dirView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

            newPath = path.join(dirPath, path.basename(dirPath))
            expect(-> atom.commands.dispatch(treeView.element, "tree-view:paste")).not.toThrow()
            expect(fs.existsSync(newPath)).toBeTruthy()
            expect(fs.existsSync(path.join(newPath, path.basename(dirPath)))).toBeFalsy()

        describe "when cut", ->
          it "does nothing", ->
            LocalStorage['tree-view:cutPath'] = JSON.stringify([dirPath])
            dirView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

            expect(fs.existsSync(dirPath)).toBeTruthy()
            expect(fs.existsSync(path.join(dirPath, path.basename(dirPath)))).toBeFalsy()

      describe "when pasting entries which don't exist anymore", ->
        it "skips the entry which doesn't exist", ->
          filePathDoesntExist1 = path.join(dirPath2, "test-file-doesnt-exist1.txt")
          filePathDoesntExist2 = path.join(dirPath2, "test-file-doesnt-exist2.txt")

          LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath2, filePathDoesntExist1, filePath3, filePathDoesntExist2])

          fileView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          atom.commands.dispatch(treeView.element, "tree-view:paste")

          expect(fs.existsSync(path.join(dirPath, path.basename(filePath2)))).toBeTruthy()
          expect(fs.existsSync(path.join(dirPath, path.basename(filePath3)))).toBeTruthy()
          expect(fs.existsSync(path.join(dirPath, path.basename(filePathDoesntExist1)))).toBeFalsy()
          expect(fs.existsSync(path.join(dirPath, path.basename(filePathDoesntExist2)))).toBeFalsy()
          expect(fs.existsSync(filePath2)).toBeTruthy()
          expect(fs.existsSync(filePath3)).toBeTruthy()

      describe "when a file has been copied", ->
        describe "when a file is selected", ->
          beforeEach ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath])

          it "creates a copy of the original file in the selected file's parent directory", ->
            fileView2.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            newPath = path.join(dirPath2, path.basename(filePath))
            expect(fs.existsSync(newPath)).toBeTruthy()
            expect(fs.existsSync(filePath)).toBeTruthy()

          it "emits an event", ->
            callback = jasmine.createSpy("onEntryCopied")
            treeView.onEntryCopied(callback)
            fileView2.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            newPath = path.join(dirPath2, path.basename(filePath))
            expect(callback).toHaveBeenCalledWith({initialPath: filePath, newPath: newPath})

          describe "when the target already exists", ->
            it "appends a number to the destination name", ->
              LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath])

              fileView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
              atom.commands.dispatch(treeView.element, "tree-view:paste")
              atom.commands.dispatch(treeView.element, "tree-view:paste")

              expect(fs.existsSync(path.join(path.dirname(filePath), "test-file0.txt"))).toBeTruthy()
              expect(fs.existsSync(path.join(path.dirname(filePath), "test-file1.txt"))).toBeTruthy()
              expect(fs.existsSync(filePath)).toBeTruthy()

        describe "when a file containing two or more periods has been copied", ->
          describe "when a file is selected", ->
            it "creates a copy of the original file in the selected file's parent directory", ->
              dotFilePath = path.join(dirPath, "test.file.txt")
              fs.writeFileSync(dotFilePath, "doesn't matter .")
              LocalStorage['tree-view:copyPath'] = JSON.stringify([dotFilePath])

              atom.commands.dispatch(treeView.element, "tree-view:paste")

              fileView2.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
              atom.commands.dispatch(treeView.element, "tree-view:paste")
              expect(fs.existsSync(path.join(dirPath, path.basename(dotFilePath)))).toBeTruthy()
              expect(fs.existsSync(dotFilePath)).toBeTruthy()

            describe "when the target already exists", ->
              it "appends a number to the destination name", ->
                dotFilePath = path.join(dirPath, "test.file.txt")
                fs.writeFileSync(dotFilePath, "doesn't matter .")
                LocalStorage['tree-view:copyPath'] = JSON.stringify([dotFilePath])

                fileView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
                atom.commands.dispatch(treeView.element, "tree-view:paste")
                atom.commands.dispatch(treeView.element, "tree-view:paste")

                expect(fs.existsSync(path.join(dirPath, 'test0.file.txt'))).toBeTruthy()
                expect(fs.existsSync(path.join(dirPath, 'test1.file.txt'))).toBeTruthy()
                expect(fs.existsSync(dotFilePath)).toBeTruthy()

        describe "when a directory is selected", ->
          it "creates a copy of the original file in the selected directory", ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath])

            dirView2.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            expect(fs.existsSync(path.join(dirPath2, path.basename(filePath)))).toBeTruthy()
            expect(fs.existsSync(filePath)).toBeTruthy()

          describe "when the target already exists", ->
            it "appends a number to the destination file name", ->
              LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath])

              dirView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
              atom.commands.dispatch(treeView.element, "tree-view:paste")
              atom.commands.dispatch(treeView.element, "tree-view:paste")

              expect(fs.existsSync(path.join(path.dirname(filePath), "test-file0.txt"))).toBeTruthy()
              expect(fs.existsSync(path.join(path.dirname(filePath), "test-file1.txt"))).toBeTruthy()
              expect(fs.existsSync(filePath)).toBeTruthy()

        describe "when a directory with a period is selected", ->
          [dotDirPath] = []

          beforeEach ->
            dotDirPath = path.join(rootDirPath, "test.dir")
            fs.makeTreeSync(dotDirPath)

            atom.project.setPaths([rootDirPath]) # Force test.dir to show up

          it "creates a copy of the original file in the selected directory", ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath])

            directories = treeView.roots[0].entries.querySelectorAll('.directory')
            dotDirView = directories[directories.length - 1]
            dotDirView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            expect(fs.existsSync(path.join(dotDirPath, path.basename(filePath)))).toBeTruthy()
            expect(fs.existsSync(filePath)).toBeTruthy()

          describe "when the target already exists", ->
            it "appends a number to the destination file name", ->
              dotFilePath = path.join(dotDirPath, "test.file.txt")
              fs.writeFileSync(dotFilePath, "doesn't matter .")
              LocalStorage['tree-view:copyPath'] = JSON.stringify([dotFilePath])

              directories = treeView.roots[0].entries.querySelectorAll('.directory')
              dotDirView = directories[directories.length - 1]
              dotDirView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
              atom.commands.dispatch(treeView.element, "tree-view:paste")
              atom.commands.dispatch(treeView.element, "tree-view:paste")

              expect(fs.existsSync(path.join(dotDirPath, "test0.file.txt"))).toBeTruthy()
              expect(fs.existsSync(path.join(dotDirPath, "test1.file.txt"))).toBeTruthy()
              expect(fs.existsSync(dotFilePath)).toBeTruthy()

        describe "when pasting into a different root directory", ->
          it "creates the file", ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath4])
            dirView2.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
            atom.commands.dispatch(treeView.element, "tree-view:paste")
            expect(fs.existsSync(path.join(dirPath2, path.basename(filePath4)))).toBeTruthy()

        describe "when pasting a file with an asterisk char '*' in to different directory", ->
          it "should successfully move the file", ->
            # Files cannot contain asterisks on Windows
            return if process.platform is "win32"

            asteriskFilePath = path.join(dirPath, "test-file-**.txt")
            fs.writeFileSync(asteriskFilePath, "doesn't matter *")
            LocalStorage['tree-view:copyPath'] = JSON.stringify([asteriskFilePath])
            dirView2.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
            atom.commands.dispatch(treeView.element, "tree-view:paste")
            expect(fs.existsSync(path.join(dirPath2, path.basename(asteriskFilePath)))).toBeTruthy()

      describe "when nothing has been copied", ->
        it "does not paste anything", ->
          expect(-> atom.commands.dispatch(treeView.element, "tree-view:paste")).not.toThrow()

      describe "when multiple files have been copied", ->
        describe "when a file is selected", ->
          it "copies the selected files to the parent directory of the selected file", ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath2, filePath3])

            fileView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            expect(fs.existsSync(path.join(dirPath, path.basename(filePath2)))).toBeTruthy()
            expect(fs.existsSync(path.join(dirPath, path.basename(filePath3)))).toBeTruthy()
            expect(fs.existsSync(filePath2)).toBeTruthy()
            expect(fs.existsSync(filePath3)).toBeTruthy()

          describe 'when the target destination file exists', ->
            it 'appends a number to the duplicate destination target names', ->
              LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath2, filePath3])

              filePath4 = path.join(dirPath, "test-file2.txt")
              filePath5 = path.join(dirPath, "test-file3.txt")
              fs.writeFileSync(filePath4, "doesn't matter")
              fs.writeFileSync(filePath5, "doesn't matter")

              fileView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
              atom.commands.dispatch(treeView.element, "tree-view:paste")

              expect(fs.existsSync(path.join(dirPath, "test-file20.txt"))).toBeTruthy()
              expect(fs.existsSync(path.join(dirPath, "test-file30.txt"))).toBeTruthy()

      describe "when a file has been cut", ->
        beforeEach ->
          LocalStorage['tree-view:cutPath'] = JSON.stringify([filePath])

        describe "when a file is selected", ->
          it "creates a copy of the original file in the selected file's parent directory and removes the original", ->
            fileView2.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            newPath = path.join(dirPath2, path.basename(filePath))
            expect(fs.existsSync(newPath)).toBeTruthy()
            expect(fs.existsSync(filePath)).toBeFalsy()

          it "emits an event", ->
            callback = jasmine.createSpy("onEntryMoved")
            treeView.onEntryMoved(callback)

            fileView2.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            newPath = path.join(dirPath2, path.basename(filePath))
            expect(callback).toHaveBeenCalledWith({initialPath: filePath, newPath})

          describe 'when the target destination file exists', ->
            it 'does not move the cut file', ->
              callback = jasmine.createSpy("onEntryMoved")
              treeView.onEntryMoved(callback)

              filePath3 = path.join(dirPath2, "test-file.txt")
              fs.writeFileSync(filePath3, "doesn't matter")

              fileView2.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
              atom.commands.dispatch(treeView.element, "tree-view:paste")

              expect(fs.existsSync(filePath)).toBeTruthy()
              expect(callback).not.toHaveBeenCalled()

        describe "when a directory is selected", ->
          it "creates a copy of the original file in the selected directory and removes the original", ->
            LocalStorage['tree-view:cutPath'] = JSON.stringify([filePath])

            callback = jasmine.createSpy("onEntryMoved")
            treeView.onEntryMoved(callback)
            dirView2.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            newPath = path.join(dirPath2, path.basename(filePath))
            expect(fs.existsSync(newPath)).toBeTruthy()
            expect(fs.existsSync(filePath)).toBeFalsy()
            expect(callback).toHaveBeenCalledWith({initialPath: filePath, newPath})

      describe "when multiple files have been cut", ->
        describe "when a file is selected", ->
          beforeEach ->
            LocalStorage['tree-view:cutPath'] = JSON.stringify([filePath2, filePath3])

          it "moves the selected files to the parent directory of the selected file", ->
            fileView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            newPath2 = path.join(dirPath, path.basename(filePath2))
            newPath3 = path.join(dirPath, path.basename(filePath3))
            expect(fs.existsSync(newPath2)).toBeTruthy()
            expect(fs.existsSync(newPath3)).toBeTruthy()
            expect(fs.existsSync(filePath2)).toBeFalsy()
            expect(fs.existsSync(filePath3)).toBeFalsy()

          it "emits events", ->
            callback = jasmine.createSpy("onEntryMoved")
            treeView.onEntryMoved(callback)
            fileView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            newPath2 = path.join(dirPath, path.basename(filePath2))
            newPath3 = path.join(dirPath, path.basename(filePath3))
            expect(callback.callCount).toEqual(2)
            expect(callback).toHaveBeenCalledWith({initialPath: filePath2, newPath: newPath2})
            expect(callback).toHaveBeenCalledWith({initialPath: filePath3, newPath: newPath3})

          describe 'when the target destination file exists', ->
            it 'does not move the cut file', ->
              LocalStorage['tree-view:cutPath'] = JSON.stringify([filePath2, filePath3])

              filePath4 = path.join(dirPath, "test-file2.txt")
              filePath5 = path.join(dirPath, "test-file3.txt")
              fs.writeFileSync(filePath4, "doesn't matter")
              fs.writeFileSync(filePath5, "doesn't matter")

              fileView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
              atom.commands.dispatch(treeView.element, "tree-view:paste")

              expect(fs.existsSync(filePath2)).toBeTruthy()
              expect(fs.existsSync(filePath3)).toBeTruthy()

        describe "when a directory is selected", ->
          it "creates a copy of the original file in the selected directory and removes the original", ->
            LocalStorage['tree-view:cutPath'] = JSON.stringify([filePath])

            dirView2.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            expect(fs.existsSync(path.join(dirPath2, path.basename(filePath)))).toBeTruthy()
            expect(fs.existsSync(filePath)).toBeFalsy()

      describe "when pasting the file fails due to a filesystem error", ->
        it "shows a notification", ->
          spyOn(fs, 'writeFileSync').andCallFake ->
            writeError = new Error("ENOENT: no such file or directory, open '#{filePath}'")
            writeError.code = 'ENOENT'
            writeError.path = filePath
            throw writeError

          LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath])

          fileView2.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          atom.notifications.clear()
          atom.commands.dispatch(treeView.element, "tree-view:paste")

          expect(atom.notifications.getNotifications()[0].getMessage()).toContain 'Unable to paste paths'
          expect(atom.notifications.getNotifications()[0].getDetail()).toContain 'ENOENT: no such file or directory'

    describe "tree-view:add-file", ->
      [addPanel, addDialog, callback] = []

      beforeEach ->
        jasmine.attachToDOM(workspaceElement)
        callback = jasmine.createSpy("onFileCreated")
        treeView.onFileCreated(callback)

        waitsForFileToOpen ->
          fileView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

        runs ->
          atom.commands.dispatch(treeView.element, "tree-view:add-file")
          [addPanel] = atom.workspace.getModalPanels()
          addDialog = addPanel.getItem()

      describe "when a file is selected", ->
        it "opens an add dialog with the file's current directory path populated", ->
          expect(addDialog.element).toExist()
          expect(addDialog.promptText.textContent).toBeTruthy()
          expect(atom.project.relativize(dirPath)).toMatch(/[^\\\/]$/)
          expect(addDialog.miniEditor.getText()).toBe(atom.project.relativize(dirPath) + path.sep)
          expect(addDialog.miniEditor.getCursorBufferPosition().column).toBe addDialog.miniEditor.getText().length
          expect(addDialog.miniEditor.element).toHaveFocus()

        describe "when the parent directory of the selected file changes", ->
          it "still shows the active file as selected", ->
            dirView.directory.emitter.emit 'did-remove-entries', {'deleted.txt': {}}
            expect(treeView.element.querySelector('.selected').textContent).toBe path.basename(filePath)

        describe "when the path without a trailing '#{path.sep}' is changed and confirmed", ->
          describe "when no file exists at that location", ->
            it "adds a file, closes the dialog, selects the file in the tree-view, and emits an event", ->
              newPath = path.join(dirPath, "new-test-file.txt")

              waitsForFileToOpen ->
                addDialog.miniEditor.insertText(path.basename(newPath))
                atom.commands.dispatch addDialog.element, 'core:confirm'

              runs ->
                expect(fs.isFileSync(newPath)).toBeTruthy()
                expect(atom.workspace.getModalPanels().length).toBe 0
                expect(atom.workspace.getActivePaneItem().getPath()).toBe newPath

              waitsFor "tree view to be updated", ->
                dirView.entries.querySelectorAll(".file").length > 1

              runs ->
                expect(treeView.element.querySelector('.selected').textContent).toBe path.basename(newPath)
                expect(callback).toHaveBeenCalledWith({path: newPath})

            it "adds file in any project path", ->
              newPath = path.join(dirPath3, "new-test-file.txt")

              waitsForFileToOpen ->
                fileView4.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

              waitsForFileToOpen ->
                atom.commands.dispatch(treeView.element, "tree-view:add-file")
                [addPanel] = atom.workspace.getModalPanels()
                addDialog = addPanel.getItem()
                addDialog.miniEditor.insertText(path.basename(newPath))
                atom.commands.dispatch addDialog.element, 'core:confirm'

              runs ->
                expect(fs.isFileSync(newPath)).toBeTruthy()
                expect(atom.workspace.getModalPanels().length).toBe 0
                expect(atom.workspace.getActivePaneItem().getPath()).toBe newPath

              waitsFor "tree view to be updated", ->
                dirView3.entries.querySelectorAll(".file").length > 1

              runs ->
                expect(treeView.element.querySelector('.file.selected').textContent).toBe path.basename(newPath)
                expect(callback).toHaveBeenCalledWith({path: newPath})

          describe "when a file already exists at that location", ->
            it "shows an error message and does not close the dialog", ->
              newPath = path.join(dirPath, "new-test-file.txt")
              fs.writeFileSync(newPath, '')
              addDialog.miniEditor.insertText(path.basename(newPath))
              atom.commands.dispatch addDialog.element, 'core:confirm'

              expect(addDialog.errorMessage.textContent).toContain 'already exists'
              expect(addDialog.element).toHaveClass('error')
              expect(atom.workspace.getModalPanels()[0]).toBe addPanel
              expect(callback).not.toHaveBeenCalled()

          describe "when the project has no path", ->
            it "adds a file and closes the dialog", ->
              atom.project.setPaths([])
              addDialog.close()
              atom.commands.dispatch(treeView.element, "tree-view:add-file")
              [addPanel] = atom.workspace.getModalPanels()
              addDialog = addPanel.getItem()

              newPath = path.join(fs.realpathSync(temp.mkdirSync()), 'a-file')
              addDialog.miniEditor.insertText(newPath)

              waitsForFileToOpen ->
                atom.commands.dispatch addDialog.element, 'core:confirm'

              runs ->
                expect(fs.isFileSync(newPath)).toBeTruthy()
                expect(atom.workspace.getModalPanels().length).toBe 0
                expect(atom.workspace.getActivePaneItem().getPath()).toBe(newPath)
                expect(callback).toHaveBeenCalledWith({path: newPath})

        describe "when the path with a trailing '#{path.sep}' is changed and confirmed", ->
          it "shows an error message and does not close the dialog", ->
            addDialog.miniEditor.insertText("new-test-file" + path.sep)
            atom.commands.dispatch addDialog.element, 'core:confirm'

            expect(addDialog.errorMessage.textContent).toContain 'names must not end with'
            expect(addDialog.element).toHaveClass('error')
            expect(atom.workspace.getModalPanels()[0]).toBe addPanel
            expect(callback).not.toHaveBeenCalled()

        describe "when 'core:cancel' is triggered on the add dialog", ->
          it "removes the dialog and focuses the tree view", ->
            atom.commands.dispatch addDialog.element, 'core:cancel'
            expect(atom.workspace.getModalPanels().length).toBe 0
            expect(document.activeElement).toBe(treeView.element.querySelector(".tree-view"))
            expect(callback).not.toHaveBeenCalled()

        describe "when the add dialog's editor loses focus", ->
          it "removes the dialog and focuses root view", ->
            workspaceElement.focus()
            expect(atom.workspace.getModalPanels().length).toBe 0
            expect(atom.views.getView(atom.workspace.getActivePane())).toHaveFocus()

        describe "when the path ends with whitespace", ->
          it "removes the trailing whitespace before creating the file", ->
            newPath = path.join(dirPath, "new-test-file.txt")
            addDialog.miniEditor.insertText(path.basename(newPath) + "  ")

            waitsForFileToOpen ->
              atom.commands.dispatch addDialog.element, 'core:confirm'

            runs ->
              expect(fs.isFileSync(newPath)).toBeTruthy()
              expect(atom.workspace.getActivePaneItem().getPath()).toBe newPath
              expect(callback).toHaveBeenCalledWith({path: newPath})

      describe "when a directory is selected", ->
        it "opens an add dialog with the directory's path populated", ->
          addDialog.cancel()
          dirView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          atom.commands.dispatch(treeView.element, "tree-view:add-file")
          addDialog = atom.workspace.getModalPanels()[0].getItem()

          expect(addDialog.element).toExist()
          expect(addDialog.promptText.textContent).toBeTruthy()
          expect(atom.project.relativize(dirPath)).toMatch(/[^\\\/]$/)
          expect(addDialog.miniEditor.getText()).toBe(atom.project.relativize(dirPath) + path.sep)
          expect(addDialog.miniEditor.getCursorBufferPosition().column).toBe addDialog.miniEditor.getText().length
          expect(addDialog.miniEditor.element).toHaveFocus()

      describe "when the root directory is selected", ->
        it "opens an add dialog with no path populated", ->
          addDialog.cancel()
          root1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          atom.commands.dispatch(treeView.element, "tree-view:add-file")
          addDialog = atom.workspace.getModalPanels()[0].getItem()

          expect(addDialog.miniEditor.getText()).toBe ""

      describe "when there is no entry selected", ->
        it "opens an add dialog with no path populated", ->
          addDialog.cancel()
          root1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          root1.classList.remove('selected')
          expect(treeView.selectedEntry()).toBeNull()
          atom.commands.dispatch(treeView.element, "tree-view:add-file")
          addDialog = atom.workspace.getModalPanels()[0].getItem()

          expect(addDialog.miniEditor.getText()).toBe ""

      describe "when the project doesn't have a root directory", ->
        it "shows an error", ->
          addDialog.cancel()
          atom.project.setPaths([])
          atom.commands.dispatch(workspaceElement, "tree-view:add-folder")
          [addPanel] = atom.workspace.getModalPanels()
          addDialog = addPanel.getItem()
          addDialog.miniEditor.insertText("a-file")
          atom.commands.dispatch(addDialog.element, 'core:confirm')
          expect(addDialog.element.textContent).toContain("You must open a directory to create a file with a relative path")

    describe "tree-view:add-folder", ->
      [addPanel, addDialog, callback] = []

      beforeEach ->
        jasmine.attachToDOM(workspaceElement)
        callback = jasmine.createSpy("onDirectoryCreated")
        treeView.onDirectoryCreated(callback)

        waitsForFileToOpen ->
          fileView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

        runs ->
          atom.commands.dispatch(treeView.element, "tree-view:add-folder")
          [addPanel] = atom.workspace.getModalPanels()
          addDialog = addPanel.getItem()

      describe "when a file is selected", ->
        it "opens an add dialog with the file's current directory path populated", ->
          expect(addDialog.element).toExist()
          expect(addDialog.promptText.textContent).toBeTruthy()
          expect(atom.project.relativize(dirPath)).toMatch(/[^\\\/]$/)
          expect(addDialog.miniEditor.getText()).toBe(atom.project.relativize(dirPath) + path.sep)
          expect(addDialog.miniEditor.getCursorBufferPosition().column).toBe addDialog.miniEditor.getText().length
          expect(addDialog.miniEditor.element).toHaveFocus()

        describe "when the path without a trailing '#{path.sep}' is changed and confirmed", ->
          describe "when no directory exists at the given path", ->
            it "adds a directory and closes the dialog", ->
              newPath = path.join(dirPath, 'new', 'dir')
              addDialog.miniEditor.insertText("new#{path.sep}dir")
              atom.commands.dispatch addDialog.element, 'core:confirm'
              expect(fs.isDirectorySync(newPath)).toBeTruthy()
              expect(atom.workspace.getModalPanels().length).toBe 0
              expect(atom.workspace.getActivePaneItem().getPath()).not.toBe newPath

              expect(document.activeElement).toBe(treeView.element.querySelector(".tree-view"))
              expect(dirView.querySelector('.directory.selected').textContent).toBe('new')
              expect(callback).toHaveBeenCalledWith({path: newPath})

        describe "when the path with a trailing '#{path.sep}' is changed and confirmed", ->
          describe "when no directory exists at the given path", ->
            it "adds a directory, closes the dialog, and emits an event", ->
              newPath = path.join(dirPath, 'new', 'dir')
              addDialog.miniEditor.insertText("new#{path.sep}dir#{path.sep}")
              atom.commands.dispatch addDialog.element, 'core:confirm'
              expect(fs.isDirectorySync(newPath)).toBeTruthy()
              expect(atom.workspace.getModalPanels().length).toBe 0
              expect(atom.workspace.getActivePaneItem().getPath()).not.toBe newPath

              expect(document.activeElement).toBe(treeView.element.querySelector(".tree-view"))
              expect(dirView.querySelector('.directory.selected').textContent).toBe('new')
              expect(callback).toHaveBeenCalledWith({path: newPath + path.sep})

            it "selects the created directory and does not change the expansion state of existing directories", ->
              expandedPath = path.join(dirPath, 'expanded-dir')
              fs.makeTreeSync(expandedPath)
              treeView.entryForPath(dirPath).expand()
              treeView.entryForPath(dirPath).reload()
              expandedView = treeView.entryForPath(expandedPath)
              expandedView.expand()

              newPath = path.join(dirPath, "new2") + path.sep
              addDialog.miniEditor.insertText("new2#{path.sep}")
              atom.commands.dispatch addDialog.element, 'core:confirm'
              expect(fs.isDirectorySync(newPath)).toBeTruthy()
              expect(atom.workspace.getModalPanels().length).toBe 0
              expect(atom.workspace.getActivePaneItem().getPath()).not.toBe newPath

              expect(document.activeElement).toBe(treeView.element.querySelector(".tree-view"))
              expect(dirView.querySelector('.directory.selected').textContent).toBe('new2')
              expect(treeView.entryForPath(expandedPath).isExpanded).toBeTruthy()
              expect(callback).toHaveBeenCalledWith({path: newPath})

            describe "when the project has no path", ->
              it "adds a directory and closes the dialog", ->
                addDialog.close()
                atom.project.setPaths([])
                atom.commands.dispatch(treeView.element, "tree-view:add-folder")
                [addPanel] = atom.workspace.getModalPanels()
                addDialog = addPanel.getItem()

                expect(addDialog.miniEditor.getText()).toBe ''
                newPath = temp.path()
                addDialog.miniEditor.insertText(newPath)
                atom.commands.dispatch addDialog.element, 'core:confirm'
                expect(fs.isDirectorySync(newPath)).toBeTruthy()
                expect(atom.workspace.getModalPanels().length).toBe 0
                expect(callback).toHaveBeenCalledWith({path: newPath})

          describe "when a directory already exists at the given path", ->
            it "shows an error message and does not close the dialog", ->
              newPath = path.join(dirPath, "new-dir")
              fs.makeTreeSync(newPath)
              addDialog.miniEditor.insertText("new-dir#{path.sep}")
              atom.commands.dispatch addDialog.element, 'core:confirm'

              expect(addDialog.errorMessage.textContent).toContain 'already exists'
              expect(addDialog.element).toHaveClass('error')
              expect(atom.workspace.getModalPanels()[0]).toBe addPanel
              expect(callback).not.toHaveBeenCalled()

    describe "tree-view:move", ->
      describe "when a file is selected", ->
        [moveDialog, callback] = []

        beforeEach ->
          jasmine.attachToDOM(workspaceElement)
          callback = jasmine.createSpy("onEntryMoved")
          treeView.onEntryMoved(callback)

          waitsForFileToOpen ->
            fileView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

          runs ->
            atom.commands.dispatch(treeView.element, "tree-view:move")
            moveDialog = atom.workspace.getModalPanels()[0].getItem()

        afterEach ->
          waits 50 # The move specs cause too many false positives because of their async nature, so wait a little bit before we cleanup

        it "opens a move dialog with the file's current path (excluding extension) populated", ->
          extension = path.extname(filePath)
          fileNameWithoutExtension = path.basename(filePath, extension)
          expect(moveDialog.element).toExist()
          expect(moveDialog.promptText.textContent).toBe "Enter the new path for the file."
          expect(moveDialog.miniEditor.getText()).toBe(atom.project.relativize(filePath))
          expect(moveDialog.miniEditor.getSelectedText()).toBe path.basename(fileNameWithoutExtension)
          expect(moveDialog.miniEditor.element).toHaveFocus()

        describe "when the path is changed and confirmed", ->
          describe "when all the directories along the new path exist", ->
            it "moves the file, updates the tree view, closes the dialog, and emits an event", ->
              newPath = path.join(rootDirPath, 'renamed-test-file.txt')
              moveDialog.miniEditor.setText(path.basename(newPath))

              atom.commands.dispatch moveDialog.element, 'core:confirm'

              expect(fs.existsSync(newPath)).toBeTruthy()
              expect(fs.existsSync(filePath)).toBeFalsy()
              expect(atom.workspace.getModalPanels().length).toBe 0

              waitsFor "tree view to update", ->
                files = Array.from(root1.querySelectorAll('.entries .file'))
                files.filter((f) -> f.textContent is 'renamed-test-file.txt').length > 0

              runs ->
                dirView = treeView.roots[0].querySelector('.directory')
                dirView.expand()
                expect(dirView.entries.children.length).toBe 0
                expect(callback).toHaveBeenCalledWith({initialPath: filePath, newPath})

          describe "when the directories along the new path don't exist", ->
            it "creates the target directory before moving the file", ->
              newPath = path.join(rootDirPath, 'new', 'directory', 'renamed-test-file.txt')
              moveDialog.miniEditor.setText(newPath)

              atom.commands.dispatch moveDialog.element, 'core:confirm'

              waitsFor "tree view to update", ->
                directories = Array.from(root1.querySelectorAll('.entries .directory'))
                directories.filter((f) -> f.textContent is 'new').length > 0

              runs ->
                expect(fs.existsSync(newPath)).toBeTruthy()
                expect(fs.existsSync(filePath)).toBeFalsy()
                expect(callback).toHaveBeenCalledWith({initialPath: filePath, newPath})

          describe "when a file or directory already exists at the target path", ->
            it "shows an error message and does not close the dialog", ->
              runs ->
                fs.writeFileSync(path.join(rootDirPath, 'target.txt'), '')
                newPath = path.join(rootDirPath, 'target.txt')
                moveDialog.miniEditor.setText(newPath)

                atom.commands.dispatch moveDialog.element, 'core:confirm'

                expect(moveDialog.errorMessage.textContent).toContain 'already exists'
                expect(moveDialog.element).toHaveClass('error')
                expect(moveDialog.element.parentElement).toBeTruthy()
                expect(callback).not.toHaveBeenCalled()

        describe "when 'core:cancel' is triggered on the move dialog", ->
          it "removes the dialog and focuses the tree view", ->
            atom.commands.dispatch moveDialog.element, 'core:cancel'
            expect(atom.workspace.getModalPanels().length).toBe 0
            expect(treeView.list).toHaveFocus()

        describe "when the move dialog's editor loses focus", ->
          it "removes the dialog and focuses root view", ->
            workspaceElement.focus()
            expect(atom.workspace.getModalPanels().length).toBe 0
            expect(atom.views.getView(atom.workspace.getActivePane())).toHaveFocus()

      describe "when a file is selected that's name starts with a '.'", ->
        [dotFilePath, dotFileView, moveDialog] = []

        beforeEach ->
          dotFilePath = path.join(dirPath, ".dotfile")
          fs.writeFileSync(dotFilePath, "dot")
          dirView.collapse()
          dirView.expand()
          dotFileView = treeView.entryForPath(dotFilePath)

          waitsForFileToOpen ->
            dotFileView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

          runs ->
            atom.commands.dispatch(treeView.element, "tree-view:move")
            moveDialog = atom.workspace.getModalPanels()[0].getItem()

        it "selects the entire file name", ->
          expect(moveDialog.element).toExist()
          expect(moveDialog.miniEditor.getText()).toBe(atom.project.relativize(dotFilePath))
          expect(moveDialog.miniEditor.getSelectedText()).toBe '.dotfile'

      describe "when a subdirectory is selected", ->
        moveDialog = null

        beforeEach ->
          jasmine.attachToDOM(workspaceElement)

          waitsForFileToOpen ->
            atom.workspace.open(filePath)

          runs ->
            dirView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
            treeView.toggleFocus()
            atom.commands.dispatch(treeView.element, "tree-view:move")
            moveDialog = atom.workspace.getModalPanels()[0].getItem()

        afterEach ->
          waits 50 # The move specs cause too many false positives because of their async nature, so wait a little bit before we cleanup

        it "opens a move dialog with the folder's current path populated", ->
          extension = path.extname(dirPath)
          expect(moveDialog.element).toExist()
          expect(moveDialog.promptText.textContent).toBe "Enter the new path for the directory."
          expect(moveDialog.miniEditor.getText()).toBe(atom.project.relativize(dirPath))
          expect(moveDialog.miniEditor.element).toHaveFocus()

        describe "when the path is changed and confirmed", ->
          it "updates text editor paths accordingly", ->
            editor = atom.workspace.getActiveTextEditor()
            expect(editor.getPath()).toBe(filePath)

            newPath = path.join(rootDirPath, 'renamed-dir')
            moveDialog.miniEditor.setText(newPath)

            atom.commands.dispatch moveDialog.element, 'core:confirm'
            expect(editor.getPath()).toBe(filePath.replace('test-dir', 'renamed-dir'))

      describe "when the project is selected", ->
        it "doesn't display the move dialog", ->
          treeView.roots[0].dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          atom.commands.dispatch(treeView.element, "tree-view:move")
          expect(atom.workspace.getModalPanels().length).toBe(0)

    describe "tree-view:duplicate", ->
      describe "when a file is selected", ->
        copyDialog = null

        beforeEach ->
          jasmine.attachToDOM(workspaceElement)

          waitsForFileToOpen ->
            fileView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

          runs ->
            atom.commands.dispatch(treeView.element, "tree-view:duplicate")
            copyDialog = atom.workspace.getModalPanels()[0].getItem()

        afterEach ->
          waits 50 # The copy specs cause too many false positives because of their async nature, so wait a little bit before we cleanup

        it "opens a copy dialog to duplicate with the file's current path populated", ->
          extension = path.extname(filePath)
          fileNameWithoutExtension = path.basename(filePath, extension)
          expect(copyDialog.element).toExist()
          expect(copyDialog.promptText.textContent).toBe "Enter the new path for the duplicate."
          expect(copyDialog.miniEditor.getText()).toBe(atom.project.relativize(filePath))
          expect(copyDialog.miniEditor.getSelectedText()).toBe path.basename(fileNameWithoutExtension)
          expect(copyDialog.miniEditor.element).toHaveFocus()

        describe "when the path is changed and confirmed", ->
          describe "when all the directories along the new path exist", ->
            it "duplicates the file, updates the tree view, opens the new file and closes the dialog", ->
              newPath = path.join(rootDirPath, 'duplicated-test-file.txt')
              copyDialog.miniEditor.setText(path.basename(newPath))

              waitsForFileToOpen ->
                atom.commands.dispatch copyDialog.element, 'core:confirm'

              waitsFor "tree view to update", ->
                treeView.entryForPath(newPath)

              runs ->
                expect(fs.existsSync(newPath)).toBeTruthy()
                expect(fs.existsSync(filePath)).toBeTruthy()
                expect(atom.workspace.getModalPanels().length).toBe 0
                dirView = treeView.roots[0].entries.querySelector('.directory')
                dirView.expand()
                expect(dirView.entries.children.length).toBe 1
                expect(atom.workspace.getActiveTextEditor().getPath()).toBe(newPath)

          describe "when the directories along the new path don't exist", ->
            it "duplicates the tree and opens the new file", ->
              newPath = path.join(rootDirPath, 'new', 'directory', 'duplicated-test-file.txt')
              copyDialog.miniEditor.setText(newPath)

              waitsForFileToOpen ->
                atom.commands.dispatch copyDialog.element, 'core:confirm'

              waitsFor "tree view to update", ->
                treeView.entryForPath(newPath)

              waitsFor "new path to exist", -> fs.existsSync(newPath)

              runs ->
                expect(fs.existsSync(filePath)).toBeTruthy()
                expect(atom.workspace.getActiveTextEditor().getPath()).toBe(newPath)

          describe "when a file or directory already exists at the target path", ->
            it "shows an error message and does not close the dialog", ->
              runs ->
                fs.writeFileSync(path.join(rootDirPath, 'target.txt'), '')
                newPath = path.join(rootDirPath, 'target.txt')
                copyDialog.miniEditor.setText(newPath)

                atom.commands.dispatch copyDialog.element, 'core:confirm'

                expect(copyDialog.errorMessage.textContent).toContain 'already exists'
                expect(copyDialog.element).toHaveClass('error')
                expect(copyDialog.element.parentElement).toBeTruthy()

        describe "when 'core:cancel' is triggered on the copy dialog", ->
          it "removes the dialog and focuses the tree view", ->
            jasmine.attachToDOM(treeView.element)
            atom.commands.dispatch copyDialog.element, 'core:cancel'
            expect(atom.workspace.getModalPanels().length).toBe 0
            expect(treeView.list).toHaveFocus()

        describe "when the duplicate dialog's editor loses focus", ->
          it "removes the dialog and focuses root view", ->
            workspaceElement.focus()
            expect(atom.workspace.getModalPanels().length).toBe 0
            expect(atom.views.getView(atom.workspace.getActivePane())).toHaveFocus()

      describe "when a file is selected that's name starts with a '.'", ->
        [dotFilePath, dotFileView, copyDialog] = []

        beforeEach ->
          dotFilePath = path.join(dirPath, ".dotfile")
          fs.writeFileSync(dotFilePath, "dot")
          dirView.collapse()
          dirView.expand()
          dotFileView = treeView.entryForPath(dotFilePath)

          waitsForFileToOpen ->
            dotFileView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

          runs ->
            atom.commands.dispatch(treeView.element, "tree-view:duplicate")
            copyDialog = atom.workspace.getModalPanels()[0].getItem()

        it "selects the entire file name", ->
          expect(copyDialog.element).toExist()
          expect(copyDialog.miniEditor.getText()).toBe(atom.project.relativize(dotFilePath))
          expect(copyDialog.miniEditor.getSelectedText()).toBe '.dotfile'

      describe "when the project is selected", ->
        it "doesn't display the copy dialog", ->
          treeView.roots[0].dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          atom.commands.dispatch(treeView.element, "tree-view:duplicate")
          expect(atom.workspace.getModalPanels().length).toBe(0)

      describe "when the editor has focus", ->
        copyDialog = null

        beforeEach ->
          waitsForPromise ->
            atom.workspace.open('tree-view.js')

          runs ->
            editorElement = atom.views.getView(atom.workspace.getActivePaneItem())
            atom.commands.dispatch(editorElement, "tree-view:duplicate")
            copyDialog = atom.workspace.getModalPanels()[0].getItem()

        it "duplicates the current file", ->
          expect(copyDialog.miniEditor.getText()).toBe('tree-view.js')

      describe "when nothing is selected", ->
        it "doesn't display the copy dialog", ->
          jasmine.attachToDOM(workspaceElement)
          treeView.focus()
          treeView.deselect()
          atom.commands.dispatch(treeView.element, "tree-view:duplicate")
          expect(atom.workspace.getModalPanels().length).toBe(0)

    describe "tree-view:remove", ->
      it "won't remove the root directory", ->
        spyOn(atom, 'confirm')
        jasmine.attachToDOM(workspaceElement)
        treeView.focus()
        root1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
        atom.commands.dispatch(treeView.element, 'tree-view:remove')

        args = atom.confirm.mostRecentCall.args[0]
        expect(args.buttons).toEqual ['OK']

      it "shows the native alert dialog", ->
        spyOn(atom, 'confirm')

        waitsForFileToOpen ->
          fileView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

        runs ->
          atom.commands.dispatch(treeView.element, 'tree-view:remove')
          args = atom.confirm.mostRecentCall.args[0]
          expect(Object.keys(args.buttons)).toEqual ['Move to Trash', 'Cancel']

      it "shows a notification on failure", ->
        atom.notifications.clear()

        spyOn(atom, 'confirm')

        waitsForFileToOpen ->
          fileView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

        runs ->
          repeat = 2
          while (repeat > 0)
            atom.commands.dispatch(treeView.element, 'tree-view:remove')
            args = atom.confirm.mostRecentCall.args[0]
            args.buttons["Move to Trash"]()
            --repeat

          notificationsNumber = atom.notifications.getNotifications().length
          expect(notificationsNumber).toBe 1
          if notificationsNumber is 1
            notification = atom.notifications.getNotifications()[0]
            expect(notification.getMessage()).toContain 'The following file couldn\'t be moved to the trash'
            expect(notification.getDetail()).toContain 'test-file.txt'

      it "does nothing when no file is selected", ->
        atom.notifications.clear()

        jasmine.attachToDOM(workspaceElement)
        treeView.focus()
        treeView.deselect()
        atom.commands.dispatch(treeView.element, 'tree-view:remove')

        expect(atom.confirm.mostRecentCall).not.toExist
        expect(atom.notifications.getNotifications().length).toBe 0

      describe "when a directory is removed", ->
        it "closes editors with files belonging to the removed folder", ->
          jasmine.attachToDOM(workspaceElement)

          waitsForFileToOpen ->
            atom.workspace.open(filePath2)

          waitsForFileToOpen ->
            atom.workspace.open(filePath3)

          runs ->
            openFilePaths = atom.workspace.getTextEditors().map((e) -> e.getPath())
            expect(openFilePaths).toEqual([filePath2, filePath3])
            dirView2.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
            treeView.toggleFocus()

            spyOn(atom, 'confirm').andCallFake (dialog) ->
              dialog.buttons["Move to Trash"]()

            atom.commands.dispatch(treeView.element, 'tree-view:remove')
            openFilePaths = (editor.getPath() for editor in atom.workspace.getTextEditors())
            expect(openFilePaths).toEqual([])

  describe "file system events", ->
    temporaryFilePath = null

    beforeEach ->
      atom.project.setPaths([fs.absolute(temp.mkdirSync('tree-view'))])
      temporaryFilePath = path.join(atom.project.getPaths()[0], 'temporary')

    describe "when a file is added or removed in an expanded directory", ->
      it "updates the directory view to display the directory's new contents", ->
        entriesCountBefore = null

        runs ->
          expect(fs.existsSync(temporaryFilePath)).toBeFalsy()
          entriesCountBefore = treeView.roots[0].querySelectorAll('.entry').length
          fs.writeFileSync temporaryFilePath, 'hi'

        waitsFor "directory view contents to refresh", ->
          treeView.roots[0].querySelectorAll('.entry').length is entriesCountBefore + 1

        runs ->
          expect(treeView.entryForPath(temporaryFilePath)).toExist()
          fs.removeSync(temporaryFilePath)

        waitsFor "directory view contents to refresh", ->
          treeView.roots[0].querySelectorAll('.entry').length is entriesCountBefore

  describe "project changes", ->
    beforeEach ->
      atom.project.setPaths([path1])
      treeView = atom.workspace.getLeftPanels()[0].getItem()
      root1 = treeView.roots[0]

    describe "when a root folder is added", ->
      it "maintains expanded folders", ->
        root1.querySelector('.directory').dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
        atom.project.setPaths([path1, path2])

        treeView = atom.workspace.getLeftPanels()[0].getItem()
        expect(treeView.element).toExist()
        expect(treeView.roots[0].querySelector(".directory")).toHaveClass("expanded")

      it "maintains collapsed (root) folders", ->
        root1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
        atom.project.setPaths([path1, path2])

        treeView = atom.workspace.getLeftPanels()[0].getItem()
        expect(treeView.element).toExist()
        expect(treeView.roots[0]).toHaveClass("collapsed")

  describe "the hideVcsIgnoredFiles config option", ->
    describe "when the project's path is the repository's working directory", ->
      beforeEach ->
        dotGitFixture = path.join(__dirname, 'fixtures', 'git', 'working-dir', 'git.git')
        projectPath = temp.mkdirSync('tree-view-project')
        dotGit = path.join(projectPath, '.git')
        fs.copySync(dotGitFixture, dotGit)
        ignoreFile = path.join(projectPath, '.gitignore')
        fs.writeFileSync(ignoreFile, 'ignored.txt')
        ignoredFile = path.join(projectPath, 'ignored.txt')
        fs.writeFileSync(ignoredFile, 'ignored text')

        atom.project.setPaths([projectPath])
        atom.config.set "tree-view.hideVcsIgnoredFiles", false

      it "hides git-ignored files if the option is set, but otherwise shows them", ->
        expect(Array.from(treeView.element.querySelectorAll('.file')).map((f) -> f.textContent)).toEqual(['.gitignore', 'ignored.txt'])

        atom.config.set("tree-view.hideVcsIgnoredFiles", true)
        expect(Array.from(treeView.element.querySelectorAll('.file')).map((f) -> f.textContent)).toEqual(['.gitignore'])

        atom.config.set("tree-view.hideVcsIgnoredFiles", false)
        expect(Array.from(treeView.element.querySelectorAll('.file')).map((f) -> f.textContent)).toEqual(['.gitignore', 'ignored.txt'])

    describe "when the project's path is a subfolder of the repository's working directory", ->
      beforeEach ->
        fixturePath = path.join(__dirname, 'fixtures', 'root-dir1')
        projectPath = temp.mkdirSync('tree-view-project')
        fs.copySync(fixturePath, projectPath)
        ignoreFile = path.join(projectPath, '.gitignore')
        fs.writeFileSync(ignoreFile, 'tree-view.js')

        atom.project.setPaths([projectPath])
        atom.config.set("tree-view.hideVcsIgnoredFiles", true)

      it "does not hide git ignored files", ->
        expect(Array.from(treeView.element.querySelectorAll('.file')).map((f) -> f.textContent)).toEqual(['.gitignore', 'tree-view.js', 'tree-view.txt'])

  describe "the hideIgnoredNames config option", ->
    beforeEach ->
      atom.config.set('core.ignoredNames', ['.git', '*.js'])
      dotGitFixture = path.join(__dirname, 'fixtures', 'git', 'working-dir', 'git.git')
      projectPath = temp.mkdirSync('tree-view-project')
      dotGit = path.join(projectPath, '.git')
      fs.copySync(dotGitFixture, dotGit)
      fs.writeFileSync(path.join(projectPath, 'test.js'), '')
      fs.writeFileSync(path.join(projectPath, 'test.txt'), '')
      atom.project.setPaths([projectPath])
      atom.config.set "tree-view.hideIgnoredNames", false

    it "hides ignored files if the option is set, but otherwise shows them", ->
      expect(Array.from(treeView.roots[0].querySelectorAll('.entry')).map((e) -> e.textContent)).toEqual(['.git', 'test.js', 'test.txt'])

      atom.config.set("tree-view.hideIgnoredNames", true)
      expect(Array.from(treeView.roots[0].querySelectorAll('.entry')).map((e) -> e.textContent)).toEqual(['test.txt'])

      atom.config.set("core.ignoredNames", [])
      expect(Array.from(treeView.roots[0].querySelectorAll('.entry')).map((e) -> e.textContent)).toEqual(['.git', 'test.js', 'test.txt'])

  describe "the squashedDirectoryName config option", ->
    beforeEach ->
      rootDirPath = fs.absolute(temp.mkdirSync('tree-view'))

      zetaDirPath = path.join(rootDirPath, "zeta")
      zetaFilePath = path.join(zetaDirPath, "zeta.txt")

      alphaDirPath = path.join(rootDirPath, "alpha")
      betaDirPath = path.join(alphaDirPath, "beta")
      betaFilePath = path.join(betaDirPath, "beta.txt")

      gammaDirPath = path.join(rootDirPath, "gamma")
      deltaDirPath = path.join(gammaDirPath, "delta")
      epsilonDirPath = path.join(deltaDirPath, "epsilon")
      thetaFilePath = path.join(epsilonDirPath, "theta.txt")

      lambdaDirPath = path.join(rootDirPath, "lambda")
      iotaDirPath = path.join(lambdaDirPath, "iota")
      kappaDirPath = path.join(lambdaDirPath, "kappa")

      muDirPath = path.join(rootDirPath, "mu")
      nuDirPath = path.join(muDirPath, "nu")
      xiDirPath1 = path.join(muDirPath, "xi")
      xiDirPath2 = path.join(nuDirPath, "xi")

      omicronDirPath = path.join(rootDirPath, "omicron")
      piDirPath = path.join(omicronDirPath, "pi")

      fs.makeTreeSync(zetaDirPath)
      fs.writeFileSync(zetaFilePath, "doesn't matter")

      fs.makeTreeSync(alphaDirPath)
      fs.makeTreeSync(betaDirPath)
      fs.writeFileSync(betaFilePath, "doesn't matter")

      fs.makeTreeSync(gammaDirPath)
      fs.makeTreeSync(deltaDirPath)
      fs.makeTreeSync(epsilonDirPath)
      fs.writeFileSync(thetaFilePath, "doesn't matter")

      fs.makeTreeSync(lambdaDirPath)
      fs.makeTreeSync(iotaDirPath)
      fs.makeTreeSync(kappaDirPath)

      fs.makeTreeSync(muDirPath)
      fs.makeTreeSync(nuDirPath)
      fs.makeTreeSync(xiDirPath1)
      fs.makeTreeSync(xiDirPath2)

      fs.makeTreeSync(omicronDirPath)
      fs.makeTreeSync(piDirPath)

      atom.project.setPaths([rootDirPath])

    it "defaults to disabled", ->
      expect(atom.config.get("tree-view.squashDirectoryNames")).toBeFalsy()

    describe "when enabled", ->
      beforeEach ->
        atom.config.set('tree-view.squashDirectoryNames', true)

      it "does not squash root directories", ->
        rootDir = fs.absolute(temp.mkdirSync('tree-view'))
        zetaDir = path.join(rootDir, "zeta")
        fs.makeTreeSync(zetaDir)
        atom.project.setPaths([rootDir])
        jasmine.attachToDOM(workspaceElement)

        rootDirPath = treeView.roots[0].getPath()
        expect(rootDirPath).toBe(rootDir)
        zetaDirPath = findDirectoryContainingText(treeView.roots[0], 'zeta').getPath()
        expect(zetaDirPath).toBe(zetaDir)

      it "does not squash a file in to a DirectoryViews", ->
        zetaDir = findDirectoryContainingText(treeView.roots[0], 'zeta')
        zetaDir.expand()
        zetaEntries = [].slice.call(zetaDir.children[1].children).map (element) ->
          element.innerText

        expect(zetaEntries).toEqual(["zeta.txt"])

      it "squashes two dir names when the first only contains a single dir", ->
        betaDir = findDirectoryContainingText(treeView.roots[0], "alpha#{path.sep}beta")
        betaDir.expand()
        betaEntries = [].slice.call(betaDir.children[1].children).map (element) ->
          element.innerText

        expect(betaEntries).toEqual(["beta.txt"])

      it "squashes three dir names when the first and second only contain single dirs", ->
        epsilonDir = findDirectoryContainingText(treeView.roots[0], "gamma#{path.sep}delta#{path.sep}epsilon")
        epsilonDir.expand()
        epsilonEntries = [].slice.call(epsilonDir.children[1].children).map (element) ->
          element.innerText

        expect(epsilonEntries).toEqual(["theta.txt"])

      it "does not squash a dir name when there are two child dirs ", ->
        lambdaDir = findDirectoryContainingText(treeView.roots[0], "lambda")
        lambdaDir.expand()
        lambdaEntries = [].slice.call(lambdaDir.children[1].children).map (element) ->
          element.innerText

        expect(lambdaEntries).toEqual(["iota", "kappa"])

      describe "when a squashed directory is deleted", ->
        it "un-squashes the directories", ->
          jasmine.attachToDOM(workspaceElement)
          piDir = findDirectoryContainingText(treeView.roots[0], "omicron#{path.sep}pi")
          treeView.focus()
          treeView.selectEntry(piDir)
          spyOn(atom, 'confirm').andCallFake (dialog) ->
            dialog.buttons["Move to Trash"]()
          atom.commands.dispatch(treeView.element, 'tree-view:remove')

          omicronDir = findDirectoryContainingText(treeView.roots[0], "omicron")
          expect(omicronDir.header.textContent).toEqual("omicron")

      describe "when a file is created within a directory with another squashed directory", ->
        it "un-squashes the directories", ->
          jasmine.attachToDOM(workspaceElement)
          piDir = findDirectoryContainingText(treeView.roots[0], "omicron#{path.sep}pi")
          expect(piDir).not.toBeNull()
          # omicron is a squashed dir, so searching for omicron would give us omicron/pi instead
          omicronPath = piDir.getPath().replace "#{path.sep}pi", ""
          sigmaFilePath = path.join(omicronPath, "sigma.txt")
          fs.writeFileSync(sigmaFilePath, "doesn't matter")
          treeView.updateRoots()

          omicronDir = findDirectoryContainingText(treeView.roots[0], "omicron")
          expect(omicronDir.header.textContent).toEqual("omicron")
          omicronDir.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          piDir = findDirectoryContainingText(omicronDir, "pi")
          expect(piDir.header.textContent).toEqual("pi")
          sigmaFile = findFileContainingText(omicronDir, "sigma.txt")
          expect(sigmaFile.fileName.textContent).toEqual("sigma.txt")

      describe "when a directory is created within a directory with another squashed directory", ->
        it "un-squashes the directories", ->
          jasmine.attachToDOM(workspaceElement)
          piDir = findDirectoryContainingText(treeView.roots[0], "omicron#{path.sep}pi")
          expect(piDir).not.toBeNull()
          # omicron is a squashed dir, so searching for omicron would give us omicron/pi instead
          omicronPath = piDir.getPath().replace "#{path.sep}pi", ""
          rhoDirPath = path.join(omicronPath, "rho")
          fs.makeTreeSync(rhoDirPath)
          treeView.updateRoots()

          omicronDir = findDirectoryContainingText(treeView.roots[0], "omicron")
          expect(omicronDir.header.textContent).toEqual("omicron")
          omicronDir.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          piDir = findDirectoryContainingText(omicronDir, "pi")
          expect(piDir.header.textContent).toEqual("pi")
          rhoDir = findDirectoryContainingText(omicronDir, "rho")
          expect(rhoDir.header.textContent).toEqual("rho")

      describe "when a directory is reloaded", ->
        it "squashes the directory names the last of which is same as an unsquashed directory", ->
          muDir = findDirectoryContainingText(treeView.roots[0], "mu")
          muDir.expand()
          muEntries = Array.from(muDir.children[1].children).map (element) -> element.innerText
          expect(muEntries).toEqual(["nu#{path.sep}xi", "xi"])

          muDir.expand()
          muDir.reload()
          muEntries = Array.from(muDir.children[1].children).map (element) -> element.innerText
          expect(muEntries).toEqual(["nu#{path.sep}xi", "xi"])

  describe "Git status decorations", ->
    [projectPath, modifiedFile, originalFileContent] = []

    beforeEach ->
      projectPath = fs.realpathSync(temp.mkdirSync('tree-view-project'))
      workingDirFixture = path.join(__dirname, 'fixtures', 'git', 'working-dir')
      fs.copySync(workingDirFixture, projectPath)
      fs.moveSync(path.join(projectPath, 'git.git'), path.join(projectPath, '.git'))
      atom.project.setPaths([projectPath])

      newDir = path.join(projectPath, 'dir2')
      fs.mkdirSync(newDir)

      newFile = path.join(newDir, 'new2')
      fs.writeFileSync(newFile, '')
      atom.project.getRepositories()[0].getPathStatus(newFile)

      ignoreFile = path.join(projectPath, '.gitignore')
      fs.writeFileSync(ignoreFile, 'ignored.txt')
      ignoredFile = path.join(projectPath, 'ignored.txt')
      fs.writeFileSync(ignoredFile, '')

      modifiedFile = path.join(projectPath, 'dir', 'b.txt')
      originalFileContent = fs.readFileSync(modifiedFile, 'utf8')
      fs.writeFileSync modifiedFile, 'ch ch changes'
      atom.project.getRepositories()[0].getPathStatus(modifiedFile)

      treeView.useSyncFS = true
      treeView.updateRoots()
      treeView.roots[0].entries.querySelectorAll('.directory')[1].expand()

    describe "when the project is the repository root", ->
      it "adds a custom style", ->
        expect(treeView.element.querySelectorAll('.icon-repo').length).toBe 1

    describe "when a file is modified", ->
      it "adds a custom style", ->
        expect(treeView.element.querySelector('.file.status-modified')).toHaveText('b.txt')

    describe "when a directory if modified", ->
      it "adds a custom style", ->
        expect(treeView.element.querySelector('.directory.status-modified').header).toHaveText('dir')

    describe "when a file is new", ->
      it "adds a custom style", ->
        treeView.roots[0].entries.querySelectorAll('.directory')[2].expand()
        expect(treeView.element.querySelector('.file.status-added')).toHaveText('new2')

    describe "when a directory is new", ->
      it "adds a custom style", ->
        expect(treeView.element.querySelector('.directory.status-added').header).toHaveText('dir2')

    describe "when a file is ignored", ->
      it "adds a custom style", ->
        expect(treeView.element.querySelector('.file.status-ignored')).toHaveText('ignored.txt')

    describe "when a file is selected in a directory", ->
      beforeEach ->
        jasmine.attachToDOM(workspaceElement)
        treeView.focus()
        element.expand() for element in treeView.element.querySelectorAll('.directory')
        fileView = treeView.element.querySelector('.file.status-added')
        expect(fileView).not.toBeNull()
        fileView.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

      describe "when the file is deleted", ->
        it "updates the style of the directory", ->
          callback = jasmine.createSpy("onEntryDeleted")
          treeView.onEntryDeleted(callback)

          deletedPath = treeView.selectedEntry().getPath()
          expect(treeView.selectedEntry().getPath()).toContain(path.join('dir2', 'new2'))
          dirView = findDirectoryContainingText(treeView.roots[0], 'dir2')
          expect(dirView).not.toBeNull()
          spyOn(dirView.directory, 'updateStatus')
          spyOn(atom, 'confirm').andCallFake (dialog) ->
            dialog.buttons["Move to Trash"]()
          atom.commands.dispatch(treeView.element, 'tree-view:remove')
          expect(dirView.directory.updateStatus).toHaveBeenCalled()
          expect(callback).toHaveBeenCalledWith({path: deletedPath})

    describe "on #darwin, when the project is a symbolic link to the repository root", ->
      beforeEach ->
        symlinkPath = temp.path('tree-view-project')
        fs.symlinkSync(projectPath, symlinkPath, 'junction')
        atom.project.setPaths([symlinkPath])
        treeView.roots[0].entries.querySelectorAll('.directory')[1].expand()

        waitsFor (done) ->
          disposable = atom.project.getRepositories()[0].onDidChangeStatuses ->
            disposable.dispose()
            done()

      describe "when a file is modified", ->
        it "updates its and its parent directories' styles", ->
          expect(treeView.element.querySelector('.file.status-modified')).toHaveText('b.txt')
          expect(treeView.element.querySelector('.directory.status-modified').header).toHaveText('dir')

      describe "when a file loses its modified status", ->
        it "updates its and its parent directories' styles", ->
          fs.writeFileSync(modifiedFile, originalFileContent)
          atom.project.getRepositories()[0].getPathStatus(modifiedFile)

          expect(treeView.element.querySelector('.file.status-modified')).not.toExist()
          expect(treeView.element.querySelector('.directory.status-modified')).not.toExist()

  describe "when the resize handle is double clicked", ->
    beforeEach ->
      treeView.element.style.width = '10px'
      treeView.element.querySelector('.list-tree').style.width = '100px'
      jasmine.attachToDOM(workspaceElement)

    it "sets the width of the tree to be the width of the list", ->
      expect(parseInt(treeView.element.style.width)).toBe 10
      treeView.element.querySelector('.tree-view-resize-handle').dispatchEvent(new MouseEvent('dblclick', {bubbles: true}))
      expect(parseInt(treeView.element.style.width)).toBeGreaterThan 10

      treeView.element.style.width = '1000px'
      treeView.element.querySelector('.tree-view-resize-handle').dispatchEvent(new MouseEvent('dblclick', {bubbles: true}))
      expect(parseInt(treeView.element.style.width)).toBeLessThan 1000

  describe "when other panels are added", ->
    beforeEach ->
      jasmine.attachToDOM(workspaceElement)

    it "should resize normally", ->
      expect(treeView.element).toBeVisible()
      expect(atom.workspace.getLeftPanels().length).toBe(1)

      treeView.element.style.width = '100px'

      expect(parseInt(treeView.element.style.width)).toBe(100)

      panel = document.createElement('div')
      panel.style.width = '100px'
      atom.workspace.addLeftPanel({item: panel, priority: 10})

      expect(atom.workspace.getLeftPanels().length).toBe(2)
      expect(parseInt(treeView.element.style.width)).toBe(100)

      treeView.resizeTreeView({pageX: 250, which: 1})

      expect(parseInt(treeView.element.style.width)).toBe(150)

    it "should resize normally on the right side", ->
      atom.commands.dispatch(workspaceElement, 'tree-view:toggle-side')
      expect(treeView.element.dataset.showOnRightSide).toBe('true')

      expect(treeView.element).toBeVisible()
      expect(atom.workspace.getRightPanels().length).toBe(1)

      treeView.element.style.width = '100px'

      expect(parseInt(treeView.element.style.width)).toBe(100)

      panel = document.createElement('div')
      panel.style.width = '100px'
      atom.workspace.addRightPanel({item: panel, priority: 10})

      expect(atom.workspace.getRightPanels().length).toBe(2)
      expect(parseInt(treeView.element.style.width)).toBe(100)

      treeView.resizeTreeView({pageX: document.body.offsetWidth - 250, which: 1})

      expect(parseInt(treeView.element.style.width)).toBe(150)

  describe "selecting items", ->
    [dirView, fileView1, fileView2, fileView3, treeView, rootDirPath, dirPath, filePath1, filePath2, filePath3] = []

    beforeEach ->
      rootDirPath = fs.absolute(temp.mkdirSync('tree-view'))

      dirPath = path.join(rootDirPath, "test-dir")
      filePath1 = path.join(dirPath, "test-file1.txt")
      filePath2 = path.join(dirPath, "test-file2.txt")
      filePath3 = path.join(dirPath, "test-file3.txt")

      fs.makeTreeSync(dirPath)
      fs.writeFileSync(filePath1, "doesn't matter")
      fs.writeFileSync(filePath2, "doesn't matter")
      fs.writeFileSync(filePath3, "doesn't matter")

      atom.project.setPaths([rootDirPath])

      dirView = treeView.entryForPath(dirPath)
      dirView.expand()
      [fileView1, fileView2, fileView3] = dirView.querySelectorAll('.file')

    describe 'selecting multiple items', ->
      it 'switches the contextual menu to muli-select mode', ->
        fileView1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
        fileView2.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, shiftKey: true}))
        expect(treeView.list).toHaveClass('multi-select')
        fileView3.dispatchEvent(new MouseEvent('mousedown', {bubbles: true}))
        expect(treeView.list).toHaveClass('full-menu')

    describe 'selecting multiple items', ->
      it 'switches the contextual menu to muli-select mode', ->
        fileView1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
        fileView2.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, shiftKey: true}))
        expect(treeView.list).toHaveClass('multi-select')

      describe 'using the shift key', ->
        it 'selects the items between the already selected item and the shift clicked item', ->
          fileView1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          fileView3.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, shiftKey: true}))
          expect(fileView1).toHaveClass('selected')
          expect(fileView2).toHaveClass('selected')
          expect(fileView3).toHaveClass('selected')

      describe 'using the metakey(cmd) key', ->
        it 'selects the cmd-clicked item in addition to the original selected item', ->
          fileView1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
          fileView3.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, metaKey: true}))
          expect(fileView1).toHaveClass('selected')
          expect(fileView3).toHaveClass('selected')
          expect(fileView2).not.toHaveClass('selected')

      describe 'non-darwin platform', ->
        originalPlatform = process.platform

        beforeEach ->
          # Stub platform.process so we can test non-darwin behavior
          Object.defineProperty(process, "platform", {__proto__: null, value: 'win32'})

        afterEach ->
          # Ensure that process.platform is set back to its original value
          Object.defineProperty(process, "platform", {__proto__: null, value: originalPlatform})

        describe 'using the ctrl key', ->
          it 'selects the ctrl-clicked item in addition to the original selected item', ->
            fileView1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
            fileView3.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, ctrlKey: true}))
            expect(fileView1).toHaveClass('selected')
            expect(fileView3).toHaveClass('selected')
            expect(fileView2).not.toHaveClass('selected')

      describe 'darwin platform', ->
        originalPlatform = process.platform

        beforeEach ->
          # Stub platform.process so we can test non-darwin behavior
          Object.defineProperty(process, "platform", {__proto__: null, value: 'darwin'})

        afterEach ->
          # Ensure that process.platform is set back to its original value
          Object.defineProperty(process, "platform", {__proto__: null, value: originalPlatform})

        describe 'using the ctrl key', ->
          describe "previous item is selected but the ctrl-clicked item is not", ->
            it 'selects the clicked item, but deselects the previous item', ->
              fileView1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
              fileView3.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, ctrlKey: true}))
              expect(fileView1).not.toHaveClass('selected')
              expect(fileView3).toHaveClass('selected')
              expect(fileView2).not.toHaveClass('selected')

            it 'displays the full contextual menu', ->
              fileView1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
              fileView3.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, ctrlKey: true}))
              expect(treeView.list).toHaveClass('full-menu')
              expect(treeView.list).not.toHaveClass('multi-select')

          describe 'previous item is selected including the ctrl-clicked', ->
            it 'displays the multi-select menu', ->
              fileView1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
              fileView3.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, metaKey: true}))
              fileView3.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, ctrlKey: true}))
              expect(treeView.list).not.toHaveClass('full-menu')
              expect(treeView.list).toHaveClass('multi-select')

            it 'does not deselect any of the items', ->
              fileView1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
              fileView3.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, metaKey: true}))
              fileView3.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, ctrlKey: true}))
              expect(fileView1).toHaveClass('selected')
              expect(fileView3).toHaveClass('selected')

          describe 'when clicked item is the only item selected', ->
            it 'displays the full contextual menu', ->
              fileView1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
              fileView3.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, ctrlKey: true}))
              expect(treeView.list).toHaveClass('full-menu')
              expect(treeView.list).not.toHaveClass('multi-select')

          describe 'when no item is selected', ->
            it 'selects the ctrl-clicked item', ->
              fileView3.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, ctrlKey: true}))
              expect(fileView3).toHaveClass('selected')

            it 'displays the full context menu', ->
              fileView3.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, ctrlKey: true}))
              expect(treeView.list).toHaveClass('full-menu')
              expect(treeView.list).not.toHaveClass('multi-select')

        describe "right-clicking", ->
          describe 'when multiple items are selected', ->
            it 'displays the multi-select context menu', ->
              fileView1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
              fileView3.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, metaKey: true}))
              fileView3.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, button: 2}))
              expect(fileView1).toHaveClass('selected')
              expect(fileView3).toHaveClass('selected')
              expect(treeView.list).not.toHaveClass('full-menu')
              expect(treeView.list).toHaveClass('multi-select')

          describe 'when a single item is selected', ->
            it 'displays the full context menu', ->
              fileView1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
              fileView3.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, button: 2}))
              expect(treeView.list).toHaveClass('full-menu')
              expect(treeView.list).not.toHaveClass('multi-select')

            it 'selects right-clicked item', ->
              fileView1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
              fileView3.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, button: 2}))
              expect(fileView3).toHaveClass('selected')

            it 'deselects the previously selected item', ->
              fileView1.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
              fileView3.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, button: 2}))
              expect(fileView1).not.toHaveClass('selected')

          describe 'when no item is selected', ->
            it 'selects the right-clicked item', ->
              fileView3.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, button: 2}))
              expect(fileView3).toHaveClass('selected')

            it 'shows the full context menu', ->
              fileView3.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, button: 2}))
              expect(fileView3).toHaveClass('selected')
              expect(treeView.list).toHaveClass('full-menu')
              expect(treeView.list).not.toHaveClass('multi-select')

  describe "the sortFoldersBeforeFiles config option", ->
    [dirView, fileView, dirView2, fileView2, fileView3, rootDirPath, dirPath, filePath, dirPath2, filePath2, filePath3] = []

    beforeEach ->
      rootDirPath = fs.absolute(temp.mkdirSync('tree-view'))

      alphaFilePath = path.join(rootDirPath, "alpha.txt")
      zetaFilePath = path.join(rootDirPath, "zeta.txt")

      alphaDirPath = path.join(rootDirPath, "alpha")
      betaFilePath = path.join(alphaDirPath, "beta.txt")
      etaDirPath = path.join(alphaDirPath, "eta")

      gammaDirPath = path.join(rootDirPath, "gamma")
      deltaFilePath = path.join(gammaDirPath, "delta.txt")
      epsilonFilePath = path.join(gammaDirPath, "epsilon.txt")
      thetaDirPath = path.join(gammaDirPath, "theta")

      fs.writeFileSync(alphaFilePath, "doesn't matter")
      fs.writeFileSync(zetaFilePath, "doesn't matter")

      fs.makeTreeSync(alphaDirPath)
      fs.writeFileSync(betaFilePath, "doesn't matter")
      fs.makeTreeSync(etaDirPath)

      fs.makeTreeSync(gammaDirPath)
      fs.writeFileSync(deltaFilePath, "doesn't matter")
      fs.writeFileSync(epsilonFilePath, "doesn't matter")
      fs.makeTreeSync(thetaDirPath)

      atom.project.setPaths([rootDirPath])


    it "defaults to set", ->
      expect(atom.config.get("tree-view.sortFoldersBeforeFiles")).toBeTruthy()

    it "lists folders first if the option is set", ->
      atom.config.set "tree-view.sortFoldersBeforeFiles", true

      topLevelEntries = [].slice.call(treeView.roots[0].entries.children).map (element) ->
        element.innerText

      expect(topLevelEntries).toEqual(["alpha", "gamma", "alpha.txt", "zeta.txt"])

      alphaDir = findDirectoryContainingText(treeView.roots[0], 'alpha')
      alphaDir.expand()
      alphaEntries = [].slice.call(alphaDir.children[1].children).map (element) ->
        element.innerText

      expect(alphaEntries).toEqual(["eta", "beta.txt"])

      gammaDir = findDirectoryContainingText(treeView.roots[0], 'gamma')
      gammaDir.expand()
      gammaEntries = [].slice.call(gammaDir.children[1].children).map (element) ->
        element.innerText

      expect(gammaEntries).toEqual(["theta", "delta.txt", "epsilon.txt"])

    it "sorts folders as files if the option is not set", ->
      atom.config.set "tree-view.sortFoldersBeforeFiles", false

      topLevelEntries = [].slice.call(treeView.roots[0].entries.children).map (element) ->
        element.innerText

      expect(topLevelEntries).toEqual(["alpha", "alpha.txt", "gamma", "zeta.txt"])

      alphaDir = findDirectoryContainingText(treeView.roots[0], 'alpha')
      alphaDir.expand()
      alphaEntries = [].slice.call(alphaDir.children[1].children).map (element) ->
        element.innerText

      expect(alphaEntries).toEqual(["beta.txt", "eta"])

      gammaDir = findDirectoryContainingText(treeView.roots[0], 'gamma')
      gammaDir.expand()
      gammaEntries = [].slice.call(gammaDir.children[1].children).map (element) ->
        element.innerText

      expect(gammaEntries).toEqual(["delta.txt", "epsilon.txt", "theta"])

  describe "showSelectedEntryInFileManager()", ->
    beforeEach ->
      atom.notifications.clear()

    it "displays the standard error output when the process fails", ->
      {BufferedProcess} = require 'atom'
      spyOn(BufferedProcess.prototype, 'spawn').andCallFake ->
        EventEmitter = require 'events'
        fakeProcess = new EventEmitter()
        fakeProcess.send = ->
        fakeProcess.kill = ->
        fakeProcess.stdout = new EventEmitter()
        fakeProcess.stdout.setEncoding = ->
        fakeProcess.stderr = new EventEmitter()
        fakeProcess.stderr.setEncoding = ->
        @process = fakeProcess
        process.nextTick ->
          fakeProcess.stderr.emit('data', 'bad process')
          fakeProcess.stderr.emit('close')
          fakeProcess.stdout.emit('close')
          fakeProcess.emit('exit')

      treeView.showSelectedEntryInFileManager()

      waitsFor ->
        atom.notifications.getNotifications().length is 1

      runs ->
        expect(atom.notifications.getNotifications()[0].getMessage()).toContain 'Opening folder'
        expect(atom.notifications.getNotifications()[0].getMessage()).toContain 'failed'
        expect(atom.notifications.getNotifications()[0].getDetail()).toContain 'bad process'

    it "handle errors thrown when spawning the OS file manager", ->
      spyOn(treeView, 'fileManagerCommandForPath').andReturn
        command: path.normalize('/this/command/does/not/exist')
        label: 'OS file manager'
        args: ['foo']

      treeView.showSelectedEntryInFileManager()

      waitsFor ->
        atom.notifications.getNotifications().length is 1

      runs ->
        expect(atom.notifications.getNotifications()[0].getMessage()).toContain 'Opening folder in OS file manager failed'
        expect(atom.notifications.getNotifications()[0].getDetail()).toContain if process.platform is 'win32' then 'cannot find the path' else 'ENOENT'

  describe "showCurrentFileInFileManager()", ->
    it "does nothing when no file is opened", ->
      expect(atom.workspace.getPaneItems().length).toBe(0)
      expect(treeView.showCurrentFileInFileManager()).toBeUndefined()

    it "does nothing when only an untitled tab is opened", ->
      waitsForPromise ->
        atom.workspace.open()
      runs ->
        workspaceElement.focus()
        expect(treeView.showCurrentFileInFileManager()).toBeUndefined()

    it "shows file in file manager when some file is opened", ->
      filePath = path.join(os.tmpdir(), 'non-project-file.txt')
      fs.writeFileSync(filePath, 'test')
      waitsForPromise ->
        atom.workspace.open(filePath)

      runs ->
        {BufferedProcess} = require 'atom'
        spyOn(BufferedProcess.prototype, 'spawn').andCallFake ->
        fileManagerProcess = treeView.showCurrentFileInFileManager()
        expect(fileManagerProcess instanceof BufferedProcess).toBeTruthy()
        fileManagerProcess.kill()

  describe "when reloading a directory with deletions and additions", ->
    it "does not throw an error (regression)", ->
      projectPath = temp.mkdirSync('atom-project')
      entriesPath = path.join(projectPath, 'entries')

      fs.mkdirSync(entriesPath)
      atom.project.setPaths([projectPath])
      treeView.roots[0].expand()
      expect(treeView.roots[0].directory.serializeExpansionState()).toEqual
        isExpanded: true
        entries:
          entries:
            isExpanded: false
            entries: {}

      fs.removeSync(entriesPath)
      treeView.roots[0].reload()
      expect(treeView.roots[0].directory.serializeExpansionState()).toEqual
        isExpanded: true
        entries: {}

      fs.mkdirSync(path.join(projectPath, 'other'))
      treeView.roots[0].reload()
      expect(treeView.roots[0].directory.serializeExpansionState()).toEqual
        isExpanded: true
        entries:
          other:
            isExpanded: false
            entries: {}

  describe "Dragging and dropping files", ->
    deltaFilePath = null
    gammaDirPath = null
    thetaFilePath = null

    beforeEach ->
      rootDirPath = fs.absolute(temp.mkdirSync('tree-view'))

      alphaFilePath = path.join(rootDirPath, "alpha.txt")
      zetaFilePath = path.join(rootDirPath, "zeta.txt")

      alphaDirPath = path.join(rootDirPath, "alpha")
      betaFilePath = path.join(alphaDirPath, "beta.txt")
      etaDirPath = path.join(alphaDirPath, "eta")

      gammaDirPath = path.join(rootDirPath, "gamma")
      deltaFilePath = path.join(gammaDirPath, "delta.txt")
      epsilonFilePath = path.join(gammaDirPath, "epsilon.txt")
      thetaDirPath = path.join(gammaDirPath, "theta")
      thetaFilePath = path.join(thetaDirPath, "theta.txt")

      fs.writeFileSync(alphaFilePath, "doesn't matter")
      fs.writeFileSync(zetaFilePath, "doesn't matter")

      fs.makeTreeSync(alphaDirPath)
      fs.writeFileSync(betaFilePath, "doesn't matter")
      fs.makeTreeSync(etaDirPath)

      fs.makeTreeSync(gammaDirPath)
      fs.writeFileSync(deltaFilePath, "doesn't matter")
      fs.writeFileSync(epsilonFilePath, "doesn't matter")
      fs.makeTreeSync(thetaDirPath)
      fs.writeFileSync(thetaFilePath, "doesn't matter")

      atom.project.setPaths([rootDirPath])

    describe "when dragging a FileView onto a DirectoryView's header", ->
      it "should add the selected class to the DirectoryView", ->
        # Dragging theta onto alphaDir
        alphaDir = findDirectoryContainingText(treeView.roots[0], 'alpha')
        alphaDir.expand()

        gammaDir = findDirectoryContainingText(treeView.roots[0], 'gamma')
        gammaDir.expand()
        deltaFile = gammaDir.entries.children[2]

        [dragStartEvent, dragEnterEvent, dropEvent] =
            eventHelpers.buildInternalDragEvents(deltaFile, alphaDir.querySelector('.header'))
        treeView.onDragStart(dragStartEvent)
        treeView.onDragEnter(dragEnterEvent)
        expect(alphaDir).toHaveClass('selected')

        # Remains selected when dragging to a child of the heading entry
        treeView.onDragEnter(dragEnterEvent)
        treeView.onDragLeave(dragEnterEvent)
        expect(alphaDir).toHaveClass('selected')

        treeView.onDragLeave(dragEnterEvent)
        expect(alphaDir).not.toHaveClass('selected')

    describe "when dropping a FileView onto a DirectoryView's header", ->
      it "should move the file to the hovered directory", ->
        # Dragging delta.txt onto alphaDir
        alphaDir = findDirectoryContainingText(treeView.roots[0], 'alpha')
        alphaDir.expand()

        gammaDir = findDirectoryContainingText(treeView.roots[0], 'gamma')
        gammaDir.expand()
        deltaFile = gammaDir.entries.children[2]

        [dragStartEvent, dragEnterEvent, dropEvent] =
            eventHelpers.buildInternalDragEvents(deltaFile, alphaDir.querySelector('.header'), alphaDir)

        runs ->
          treeView.onDragStart(dragStartEvent)
          treeView.onDrop(dropEvent)
          expect(alphaDir.children.length).toBe 2

        waitsFor "directory view contents to refresh", ->
          findDirectoryContainingText(treeView.roots[0], 'alpha').querySelectorAll('.entry').length > 2

        runs ->
          expect(findDirectoryContainingText(treeView.roots[0], 'alpha').querySelectorAll('.entry').length).toBe 3

    describe "when dropping a DirectoryView onto a DirectoryView's header", ->
      it "should move the directory to the hovered directory", ->
        # Dragging thetaDir onto alphaDir
        alphaDir = findDirectoryContainingText(treeView.roots[0], 'alpha')
        alphaDir.expand()

        gammaDir = findDirectoryContainingText(treeView.roots[0], 'gamma')
        gammaDir.expand()
        thetaDir = gammaDir.entries.children[0]
        thetaDir.expand()

        waitsForFileToOpen ->
          atom.workspace.open(thetaFilePath)

        runs ->
          [dragStartEvent, dragEnterEvent, dropEvent] =
            eventHelpers.buildInternalDragEvents(thetaDir, alphaDir.querySelector('.header'), alphaDir)
          treeView.onDragStart(dragStartEvent)
          treeView.onDrop(dropEvent)
          expect(alphaDir.children.length).toBe 2

        waitsFor "directory view contents to refresh", ->
          findDirectoryContainingText(treeView.roots[0], 'alpha').querySelectorAll('.entry').length > 2

        runs ->
          expect(findDirectoryContainingText(treeView.roots[0], 'alpha').querySelectorAll('.entry').length).toBe 3
          editor = atom.workspace.getActiveTextEditor()
          expect(editor.getPath()).toBe(thetaFilePath.replace('gamma', 'alpha'))

    describe "when dragging a file from the OS onto a DirectoryView's header", ->
      it "should move the file to the hovered directory", ->
        # Dragging delta.txt from OS file explorer onto alphaDir
        alphaDir = findDirectoryContainingText(treeView.roots[0], 'alpha')
        alphaDir.expand()

        dropEvent = eventHelpers.buildExternalDropEvent([deltaFilePath], alphaDir)

        runs ->
          treeView.onDrop(dropEvent)
          expect(alphaDir.children.length).toBe 2

        waitsFor "directory view contents to refresh", ->
          findDirectoryContainingText(treeView.roots[0], 'alpha').querySelectorAll('.entry').length > 2

        runs ->
          expect(findDirectoryContainingText(treeView.roots[0], 'alpha').querySelectorAll('.entry').length).toBe 3

    describe "when dragging a directory from the OS onto a DirectoryView's header", ->
      it "should move the directory to the hovered directory", ->
        # Dragging gammaDir from OS file explorer onto alphaDir
        alphaDir = findDirectoryContainingText(treeView.roots[0], 'alpha')
        alphaDir.expand()

        dropEvent = eventHelpers.buildExternalDropEvent([gammaDirPath], alphaDir)

        runs ->
          treeView.onDrop(dropEvent)
          expect(alphaDir.children.length).toBe 2

        waitsFor "directory view contents to refresh", ->
          findDirectoryContainingText(treeView.roots[0], 'alpha').querySelectorAll('.entry').length > 2

        runs ->
          expect(findDirectoryContainingText(treeView.roots[0], 'alpha').querySelectorAll('.entry').length).toBe 3

    describe "when dragging a file and directory from the OS onto a DirectoryView's header", ->
      it "should move the file and directory to the hovered directory", ->
        # Dragging delta.txt and gammaDir from OS file explorer onto alphaDir
        alphaDir = findDirectoryContainingText(treeView.roots[0], 'alpha')
        alphaDir.expand()

        dropEvent = eventHelpers.buildExternalDropEvent([deltaFilePath, gammaDirPath], alphaDir)

        runs ->
          treeView.onDrop(dropEvent)
          expect(alphaDir.children.length).toBe 2

        waitsFor "directory view contents to refresh", ->
          findDirectoryContainingText(treeView.roots[0], 'alpha').querySelectorAll('.entry').length > 3

        runs ->
          expect(findDirectoryContainingText(treeView.roots[0], 'alpha').querySelectorAll('.entry').length).toBe 4

  describe "the alwaysOpenExisting config option", ->
    it "defaults to unset", ->
      expect(atom.config.get("tree-view.alwaysOpenExisting")).toBeFalsy()

    describe "when a file is single-clicked", ->
      beforeEach ->
        atom.config.set "tree-view.alwaysOpenExisting", true
        jasmine.attachToDOM(workspaceElement)

      it "selects the files and opens it in the active editor, without changing focus", ->
        treeView.focus()

        waitsForFileToOpen ->
          sampleJs.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

        runs ->
          expect(sampleJs).toHaveClass 'selected'
          expect(atom.workspace.getActivePaneItem().getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.js')
          expect(treeView.list).toHaveFocus()

        waitsForFileToOpen ->
          sampleTxt.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

        runs ->
          expect(sampleTxt).toHaveClass 'selected'
          expect(treeView.element.querySelectorAll('.selected').length).toBe 1
          expect(atom.workspace.getActivePaneItem().getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.txt')
          expect(treeView.list).toHaveFocus()

    describe "opening existing opened files in existing split panes", ->
      beforeEach ->

        jasmine.attachToDOM(workspaceElement)
        waitsForFileToOpen ->
          selectEntry 'tree-view.js'
          atom.commands.dispatch(treeView.element, 'tree-view:open-selected-entry-right')

        waitsForFileToOpen ->
          selectEntry 'tree-view.txt'
          atom.commands.dispatch(treeView.element, 'tree-view:open-selected-entry-right')

      it "should have opened both panes", ->
        expect(getCenter().getPanes().length).toBe 2

      describe "tree-view:open-selected-entry", ->
        beforeEach ->
          atom.config.set "tree-view.alwaysOpenExisting", true
        describe "when the first pane is focused, a file is opened that is already open in the second pane", ->
          beforeEach ->
            firstPane = getCenter().getPanes()[0]
            firstPane.activate()
            selectEntry 'tree-view.txt'
            waitsForFileToOpen ->
              atom.commands.dispatch treeView.element, "tree-view:open-selected-entry"

          it "opens the file in the second pane and focuses it", ->
            pane = getCenter().getPanes()[1]
            item = atom.workspace.getActivePaneItem()
            expect(atom.views.getView(pane)).toHaveFocus()
            expect(item.getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.txt')

      describe "tree-view:open-selected-entry (alwaysOpenExisting off)", ->
        beforeEach ->
          atom.config.set "tree-view.alwaysOpenExisting", false


        describe "when the first pane is focused, a file is opened that is already open in the second pane", ->
          firstPane = null
          beforeEach ->
            firstPane = getCenter().getPanes()[0]
            firstPane.activate()
            selectEntry 'tree-view.txt'
            waitsForFileToOpen ->
              atom.commands.dispatch treeView.element, "tree-view:open-selected-entry"

          it "opens the file in the first pane, which was the current focus", ->
            item = atom.workspace.getActivePaneItem()
            expect(atom.views.getView(firstPane)).toHaveFocus()
            expect(item.getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.txt')

      describe "when a file that is already open in other pane is single-clicked", ->
        beforeEach ->
          atom.config.set "tree-view.alwaysOpenExisting", true

        describe "when core.allowPendingPaneItems is set to true (default)", ->
          firstPane = activePaneItem = null
          beforeEach ->
            firstPane = getCenter().getPanes()[0]
            firstPane.activate()

            treeView.focus()

            waitsForFileToOpen ->
              sampleTxt.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))

            runs ->
              activePaneItem = atom.workspace.getActivePaneItem()

          it "selects the file and retains focus on tree-view", ->
            expect(sampleTxt).toHaveClass 'selected'
            expect(treeView.element).toHaveFocus()

          it "doesn't open the file in the active pane", ->
            expect(atom.views.getView(treeView)).toHaveFocus()
            expect(activePaneItem.getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.js')

      describe "when a file is double-clicked", ->
        beforeEach ->
          atom.config.set "tree-view.alwaysOpenExisting", true
        activePaneItem = null

        beforeEach ->
          firstPane = getCenter().getPanes()[0]
          firstPane.activate()

          treeView.focus()

          waitsForFileToOpen ->
            sampleTxt.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1}))
            sampleTxt.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 2}))

          waits 100

          runs ->
            activePaneItem = atom.workspace.getActivePaneItem()

        it "opens the file and focuses it", ->

          expect(activePaneItem.getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.txt')
          expect(atom.views.getView(getCenter().getPanes()[1])).toHaveFocus()

  describe "Dragging and dropping root folders", ->
    [alphaDirPath, gammaDirPath, thetaDirPath, etaDirPath] = []
    beforeEach ->
      rootDirPath = fs.absolute(temp.mkdirSync('tree-view'))

      alphaFilePath = path.join(rootDirPath, "alpha.txt")
      zetaFilePath = path.join(rootDirPath, "zeta.txt")

      alphaDirPath = path.join(rootDirPath, "alpha")
      betaFilePath = path.join(alphaDirPath, "beta.txt")

      gammaDirPath = path.join(rootDirPath, "gamma")
      deltaFilePath = path.join(gammaDirPath, "delta.txt")
      epsilonFilePath = path.join(gammaDirPath, "epsilon.txt")

      thetaDirPath = path.join(rootDirPath, "theta")
      etaDirPath = path.join(rootDirPath, "eta")

      fs.writeFileSync(alphaFilePath, "doesn't matter")
      fs.writeFileSync(zetaFilePath, "doesn't matter")

      fs.makeTreeSync(alphaDirPath)
      fs.writeFileSync(betaFilePath, "doesn't matter")

      fs.makeTreeSync(gammaDirPath)
      fs.writeFileSync(deltaFilePath, "doesn't matter")
      fs.writeFileSync(epsilonFilePath, "doesn't matter")
      fs.makeTreeSync(thetaDirPath)
      fs.makeTreeSync(etaDirPath)

      atom.project.setPaths([alphaDirPath, gammaDirPath, thetaDirPath])

      jasmine.attachToDOM(workspaceElement)

    afterEach ->
      [alphaDirPath, gammaDirPath, thetaDirPath, etaDirPath] = []

    describe "when dragging a project root's header onto a different project root", ->
      describe "when dragging on the top part of the root", ->
        it "should add the placeholder above the directory", ->
          # Dragging gammaDir onto alphaDir
          alphaDir = treeView.roots[0]
          gammaDir = treeView.roots[1]
          [dragStartEvent, dragOverEvents, dragEndEvent] =
            eventHelpers.buildPositionalDragEvents(gammaDir.querySelector('.project-root-header'), alphaDir, '.tree-view')

          treeView.rootDragAndDrop.onDragStart(dragStartEvent)
          treeView.rootDragAndDrop.onDragOver(dragOverEvents.top)
          expect(alphaDir.previousSibling).toHaveClass('placeholder')

          # Is removed when drag ends
          treeView.rootDragAndDrop.onDragEnd(dragEndEvent)
          expect(document.querySelector('.placeholder')).not.toExist()

      describe "when dragging on the bottom part of the root", ->
        it "should add the placeholder below the directory", ->
          # Dragging gammaDir onto alphaDir
          alphaDir = treeView.roots[0]
          gammaDir = treeView.roots[1]
          [dragStartEvent, dragOverEvents, dragEndEvent] =
            eventHelpers.buildPositionalDragEvents(gammaDir.querySelector('.project-root-header'), alphaDir, '.tree-view')

          treeView.rootDragAndDrop.onDragStart(dragStartEvent)
          treeView.rootDragAndDrop.onDragOver(dragOverEvents.bottom)
          expect(alphaDir.nextSibling).toHaveClass('placeholder')

          # Is removed when drag ends
          treeView.rootDragAndDrop.onDragEnd(dragEndEvent)
          expect(document.querySelector('.placeholder')).not.toExist()

      describe "when below all entries", ->
        it "should add the placeholder below the last directory", ->
          # Dragging gammaDir onto alphaDir
          alphaDir = treeView.roots[0]
          lastDir = treeView.roots[treeView.roots.length - 1]
          [dragStartEvent, dragOverEvents, dragEndEvent] =
            eventHelpers.buildPositionalDragEvents(alphaDir.querySelector('.project-root-header'), treeView.list)

          expect(alphaDir).not.toEqual(lastDir)

          treeView.rootDragAndDrop.onDragStart(dragStartEvent)
          treeView.rootDragAndDrop.onDragOver(dragOverEvents.bottom)
          expect(lastDir.nextSibling).toHaveClass('placeholder')

          # Is removed when drag ends
          treeView.rootDragAndDrop.onDragEnd(dragEndEvent)
          expect(document.querySelector('.placeholder')).not.toExist()


    describe "when dropping a project root's header onto a different project root", ->
      describe "when dropping on the top part of the header", ->
        it "should add the placeholder above the directory", ->
          # dropping gammaDir above alphaDir
          alphaDir = treeView.roots[0]
          gammaDir = treeView.roots[1]
          [dragStartEvent, dragDropEvents] =
            eventHelpers.buildPositionalDragEvents(gammaDir.querySelector('.project-root-header'), alphaDir, '.tree-view')

          treeView.rootDragAndDrop.onDragStart(dragStartEvent)
          treeView.rootDragAndDrop.onDrop(dragDropEvents.top)
          projectPaths = atom.project.getPaths()
          expect(projectPaths[0]).toEqual(gammaDirPath)
          expect(projectPaths[1]).toEqual(alphaDirPath)

          # Is removed when drag ends
          expect(document.querySelector('.placeholder')).not.toExist()

      describe "when dropping on the bottom part of the header", ->
        it "should add the placeholder below the directory", ->
          # dropping thetaDir below alphaDir
          alphaDir = treeView.roots[0]
          thetaDir = treeView.roots[2]
          [dragStartEvent, dragDropEvents] =
            eventHelpers.buildPositionalDragEvents(thetaDir.querySelector('.project-root-header'), alphaDir, '.tree-view')

          treeView.rootDragAndDrop.onDragStart(dragStartEvent)
          treeView.rootDragAndDrop.onDrop(dragDropEvents.bottom)
          projectPaths = atom.project.getPaths()
          expect(projectPaths[0]).toEqual(alphaDirPath)
          expect(projectPaths[1]).toEqual(thetaDirPath)
          expect(projectPaths[2]).toEqual(gammaDirPath)

          # Is removed when drag ends
          expect(document.querySelector('.placeholder')).not.toExist()

    describe "when a root folder is dragged out of application", ->
      it "should carry the folder's information", ->
        gammaDir = treeView.roots[1]
        [dragStartEvent] = eventHelpers.buildPositionalDragEvents(gammaDir.querySelector('.project-root-header'))
        treeView.rootDragAndDrop.onDragStart(dragStartEvent)

        expect(dragStartEvent.dataTransfer.getData("text/plain")).toEqual gammaDirPath
        if process.platform in ['darwin', 'linux']
          expect(dragStartEvent.dataTransfer.getData("text/uri-list")).toEqual "file://#{gammaDirPath}"

    describe "when a root folder is dropped from another Atom window", ->
      it "adds the root folder to the window", ->
        alphaDir = treeView.roots[0]
        [_, dragDropEvents] = eventHelpers.buildPositionalDragEvents(null, alphaDir.querySelector('.project-root-header'), '.tree-view')

        dropEvent = dragDropEvents.bottom
        dropEvent.dataTransfer.setData('atom-tree-view-event', true)
        dropEvent.dataTransfer.setData('from-window-id', treeView.rootDragAndDrop.getWindowId() + 1)
        dropEvent.dataTransfer.setData('from-root-path', etaDirPath)

        # mock browserWindowForId
        browserWindowMock = {webContents: {send: ->}}
        spyOn(remote.BrowserWindow, 'fromId').andReturn(browserWindowMock)
        spyOn(browserWindowMock.webContents, 'send')

        treeView.rootDragAndDrop.onDrop(dropEvent)

        waitsFor ->
          browserWindowMock.webContents.send.callCount > 0

        runs ->
          expect(atom.project.getPaths()).toContain etaDirPath
          expect(document.querySelector('.placeholder')).not.toExist()


    describe "when a root folder is dropped to another Atom window", ->
      it "removes the root folder from the first window", ->
        gammaDir = treeView.roots[1]
        [dragStartEvent, dropEvent] = eventHelpers.buildPositionalDragEvents(gammaDir.querySelector('.project-root-header'))
        treeView.rootDragAndDrop.onDragStart(dragStartEvent)
        treeView.rootDragAndDrop.onDropOnOtherWindow({}, Array.from(gammaDir.parentElement.children).indexOf(gammaDir))

        expect(atom.project.getPaths()).toEqual [alphaDirPath, thetaDirPath]
        expect(document.querySelector('.placeholder')).not.toExist()

  findDirectoryContainingText = (element, text) ->
    directories = Array.from(element.querySelectorAll('.entries .directory'))
    directories.find((directory) -> directory.header.textContent is text)

  findFileContainingText = (element, text) ->
    files = Array.from(element.querySelectorAll('.entries .file'))
    files.find((file) -> file.fileName.textContent is text)

describe 'Icon class handling', ->
  it 'allows multiple classes to be passed', ->
    rootDirPath = fs.absolute(temp.mkdirSync('tree-view-root1'))

    for i in [1..3]
      filepath = path.join(rootDirPath, "file-#{i}.txt")
      fs.writeFileSync(filepath, "Nah")

    atom.project.setPaths([rootDirPath])
    workspaceElement = atom.views.getView(atom.workspace)

    providerDisposable = atom.packages.serviceHub.provide 'atom.file-icons', '1.0.0', {
      iconClassForPath: (path, context) ->
        expect(context).toBe "tree-view"
        [name, id] = path.match(/file-(\d+)\.txt$/)
        switch id
          when "1" then 'first-icon-class second-icon-class'
          when "2" then ['third-icon-class', 'fourth-icon-class']
          else "some-other-file"
    }

    waitsForPromise ->
      atom.packages.activatePackage('tree-view')

    runs ->
      treeView = atom.packages.getActivePackage("tree-view").mainModule.createView()
      files = workspaceElement.querySelectorAll('li[is="tree-view-file"]')

      expect(files[0].fileName.className).toBe('name icon first-icon-class second-icon-class')
      expect(files[1].fileName.className).toBe('name icon third-icon-class fourth-icon-class')

      providerDisposable.dispose()

      files = workspaceElement.querySelectorAll('li[is="tree-view-file"]')
      expect(files[0].fileName.className).toBe('name icon icon-file-text')
