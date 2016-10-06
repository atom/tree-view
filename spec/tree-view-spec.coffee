_ = require 'underscore-plus'
{$, $$} = require 'atom-space-pen-views'
fs = require 'fs-plus'
path = require 'path'
temp = require('temp').track()
os = require 'os'
eventHelpers = require "./event-helpers"

DefaultFileIcons = require '../lib/default-file-icons'
FileIcons = require '../lib/file-icons'

waitsForFileToOpen = (causeFileToOpen) ->
  waitsFor (done) ->
    disposable = atom.workspace.onDidOpen ->
      disposable.dispose()
      done()
    causeFileToOpen()

clickEvent = (properties) ->
  event = $.Event('click')
  _.extend(event, properties) if properties?
  event

setupPaneFiles = ->
  rootDirPath = fs.absolute(temp.mkdirSync('tree-view'))

  dirPath = path.join(rootDirPath, "test-dir")

  fs.makeTreeSync(dirPath)
  [1..9].forEach (index) ->
    filePath = path.join(dirPath, "test-file-#{index}.txt")
    fs.writeFileSync(filePath, "#{index}. Some text.")

  return dirPath

getPaneFileName = (index) -> "test-file-#{index}.txt"

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
      treeView = $(atom.workspace.getLeftPanels()[0].getItem()).view()

      root1 = $(treeView.roots[0])
      root2 = $(treeView.roots[1])
      sampleJs = treeView.find('.file:contains(tree-view.js)')
      sampleTxt = treeView.find('.file:contains(tree-view.txt)')

      expect(treeView.roots[0].directory.watchSubscription).toBeTruthy()

  afterEach ->
    temp.cleanup()

  describe ".initialize(project)", ->
    it "renders the root directories of the project and their contents alphabetically with subdirectories first, in a collapsed state", ->
      expect(root1.find('> .header .disclosure-arrow')).not.toHaveClass('expanded')
      expect(root1.find('> .header .name')).toHaveText('root-dir1')

      rootEntries = root1.find('.entries')
      subdir0 = rootEntries.find('> li:eq(0)')
      expect(subdir0).not.toHaveClass('expanded')
      expect(subdir0.find('.name')).toHaveText('dir1')

      subdir2 = rootEntries.find('> li:eq(1)')
      expect(subdir2).not.toHaveClass('expanded')
      expect(subdir2.find('.name')).toHaveText('dir2')

      expect(subdir0.find('[data-name="dir1"]')).toExist()
      expect(subdir2.find('[data-name="dir2"]')).toExist()

      expect(rootEntries.find('> .file:contains(tree-view.js)')).toExist()
      expect(rootEntries.find('> .file:contains(tree-view.txt)')).toExist()

      expect(rootEntries.find('> .file [data-name="tree-view.js"]')).toExist()
      expect(rootEntries.find('> .file [data-name="tree-view.txt"]')).toExist()

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
        expect(treeView.hasParent()).toBeFalsy()
        expect(treeView.roots).toHaveLength(0)

      it "does not attach to the workspace or create a root node when attach() is called", ->
        treeView.attach()
        expect(treeView.hasParent()).toBeFalsy()
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
          expect(treeView.hasParent()).toBeFalsy()
          expect(treeView.roots).toHaveLength(0)

      describe "when the project is assigned a path because a new buffer is saved", ->
        it "creates a root directory view and attaches to the workspace", ->
          waitsForPromise ->
            atom.workspace.open()

          runs ->
            projectPath = temp.mkdirSync('atom-project')
            atom.workspace.getActivePaneItem().saveAs(path.join(projectPath, 'test.txt'))
            expect(treeView.hasParent()).toBeTruthy()
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
          expect(treeView.hasParent()).toBeFalsy()
          expect(treeView.roots).toHaveLength(2)

    describe "when the root view is opened to a directory", ->
      it "attaches to the workspace", ->
        waitsForPromise ->
          atom.packages.activatePackage('tree-view')

        runs ->
          treeView = atom.packages.getActivePackage("tree-view").mainModule.createView()
          expect(treeView.hasParent()).toBeTruthy()
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
      root1.find('.directory:contains(dir1)').click()

      waitsForFileToOpen ->
        sampleJs.click()

      runs ->
        atom.packages.deactivatePackage("tree-view")

      waitsForPromise ->
        atom.packages.activatePackage("tree-view")

      runs ->
        treeView = $(atom.workspace.getLeftPanels()[0].getItem()).view()
        expect(treeView).toExist()
        expect($(treeView.selectedEntry())).toMatchSelector(".file:contains(tree-view.js)")
        root1 = $(treeView.roots[0])
        expect(root1.find(".directory:contains(dir1)")).toHaveClass("expanded")

    it "restores the focus state of the tree view", ->
      jasmine.attachToDOM(workspaceElement)
      treeView.focus()
      expect(treeView.list).toMatchSelector ':focus'
      atom.packages.deactivatePackage("tree-view")

      waitsForPromise ->
        atom.packages.activatePackage("tree-view")

      runs ->
        treeView = $(atom.workspace.getLeftPanels()[0].getItem()).view()
        expect(treeView.list).toMatchSelector ':focus'

    it "restores the scroll top when toggled", ->
      workspaceElement.style.height = '5px'
      jasmine.attachToDOM(workspaceElement)
      expect(treeView).toBeVisible()
      treeView.focus()

      treeView.scrollTop(10)
      expect(treeView.scrollTop()).toBe(10)

      runs -> atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
      waitsFor -> treeView.is(':hidden')

      runs -> atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
      waitsFor -> treeView.is(':visible')

      runs -> expect(treeView.scrollTop()).toBe(10)

    it "restores the scroll left when toggled", ->
      treeView.width(5)
      jasmine.attachToDOM(workspaceElement)
      expect(treeView).toBeVisible()
      treeView.focus()

      treeView.scroller.scrollLeft(5)
      expect(treeView.scroller.scrollLeft()).toBe(5)

      runs -> atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
      waitsFor -> treeView.is(':hidden')

      runs -> atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
      waitsFor -> treeView.is(':visible')

      runs -> expect(treeView.scroller.scrollLeft()).toBe(5)

  describe "when tree-view:toggle is triggered on the root view", ->
    beforeEach ->
      jasmine.attachToDOM(workspaceElement)

    describe "when the tree view is visible", ->
      beforeEach ->
        expect(treeView).toBeVisible()

      describe "when the tree view is focused", ->
        it "hides the tree view", ->
          treeView.focus()
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
          expect(treeView).toBeHidden()

      describe "when the tree view is not focused", ->
        it "hides the tree view", ->
          $(workspaceElement).focus()
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
          expect(treeView).toBeHidden()

    describe "when the tree view is hidden", ->
      it "shows and focuses the tree view", ->
        treeView.detach()
        atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
        expect(treeView.hasParent()).toBeTruthy()
        expect(treeView.list).toMatchSelector(':focus')

    describe "when tree-view:toggle-side is triggered on the root view", ->
      describe "when the tree view is on the left", ->
        it "moves the tree view to the right", ->
          expect(treeView).toBeVisible()
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle-side')
          expect(treeView).toMatchSelector('[data-show-on-right-side="true"]')

      describe "when the tree view is on the right", ->
        beforeEach ->
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle-side')

        it "moves the tree view to the left", ->
          expect(treeView).toBeVisible()
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle-side')
          expect(treeView).toMatchSelector('[data-show-on-right-side="false"]')

      describe "when the tree view is hidden", ->
        it "shows the tree view on the other side next time it is opened", ->
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle-side')
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle')
          expect(atom.workspace.getLeftPanels().length).toBe 0
          treeView = $(atom.workspace.getRightPanels()[0].getItem()).view()
          expect(treeView).toMatchSelector('[data-show-on-right-side="true"]')

  describe "when tree-view:toggle-focus is triggered on the root view", ->
    beforeEach ->
      jasmine.attachToDOM(workspaceElement)

    describe "when the tree view is hidden", ->
      it "shows and focuses the tree view", ->
        treeView.detach()
        atom.commands.dispatch(workspaceElement, 'tree-view:toggle-focus')
        expect(treeView.hasParent()).toBeTruthy()
        expect(treeView.list).toMatchSelector(':focus')

    describe "when the tree view is shown", ->
      it "focuses the tree view", ->
        waitsForPromise ->
          atom.workspace.open() # When we call focus below, we want an editor to become focused

        runs ->
          $(workspaceElement).focus()
          expect(treeView).toBeVisible()
          atom.commands.dispatch(workspaceElement, 'tree-view:toggle-focus')
          expect(treeView).toBeVisible()
          expect(treeView.list).toMatchSelector(':focus')

      describe "when the tree view is focused", ->
        it "unfocuses the tree view", ->
          waitsForPromise ->
            atom.workspace.open() # When we call focus below, we want an editor to become focused

          runs ->
            treeView.focus()
            expect(treeView).toBeVisible()
            atom.commands.dispatch(workspaceElement, 'tree-view:toggle-focus')
            expect(treeView).toBeVisible()
            expect(treeView.list).not.toMatchSelector(':focus')

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
            expect(treeView.hasParent()).toBeTruthy()
            expect(treeView.focus).toHaveBeenCalled()

          waitsForPromise ->
            treeView.focus.reset()
            atom.workspace.open(path.join(atom.project.getPaths()[1], 'dir3', 'file3'))

          runs ->
            atom.commands.dispatch(workspaceElement, 'tree-view:reveal-active-file')
            expect(treeView.hasParent()).toBeTruthy()
            expect(treeView.focus).toHaveBeenCalled()

      describe "if the tree-view.focusOnReveal config option is false", ->
        it "shows the tree view and selects the file, but does not change the focus", ->
          atom.config.set "tree-view.focusOnReveal", false

          waitsForPromise ->
            atom.workspace.open(path.join(atom.project.getPaths()[0], 'dir1', 'file1'))

          runs ->
            atom.commands.dispatch(workspaceElement, 'tree-view:reveal-active-file')
            expect(treeView.hasParent()).toBeTruthy()
            expect(treeView.focus).not.toHaveBeenCalled()

          waitsForPromise ->
            treeView.focus.reset()
            atom.workspace.open(path.join(atom.project.getPaths()[1], 'dir3', 'file3'))

          runs ->
            atom.commands.dispatch(workspaceElement, 'tree-view:reveal-active-file')
            expect(treeView.hasParent()).toBeTruthy()
            expect(treeView.focus).not.toHaveBeenCalled()

    describe "if the current file has no path", ->
      it "shows and focuses the tree view, but does not attempt to select a specific file", ->
        waitsForPromise ->
          atom.workspace.open()

        runs ->
          expect(atom.workspace.getActivePaneItem().getPath()).toBeUndefined()
          atom.commands.dispatch(workspaceElement, 'tree-view:reveal-active-file')
          expect(treeView.hasParent()).toBeTruthy()
          expect(treeView.focus).toHaveBeenCalled()

    describe "if there is no editor open", ->
      it "shows and focuses the tree view, but does not attempt to select a specific file", ->
        expect(atom.workspace.getActivePaneItem()).toBeUndefined()
        atom.commands.dispatch(workspaceElement, 'tree-view:reveal-active-file')
        expect(treeView.hasParent()).toBeTruthy()
        expect(treeView.focus).toHaveBeenCalled()

    describe 'if there are more items than can be visible in the viewport', ->
      [rootDirPath] = []

      beforeEach ->
        rootDirPath = fs.absolute(temp.mkdirSync('tree-view-root1'))

        for i in [1..20]
          filepath = path.join(rootDirPath, "file-#{i}.txt")
          fs.writeFileSync(filepath, "doesn't matter")

        atom.project.setPaths([rootDirPath])
        treeView.height(100)
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
        expect(treeView.list).toMatchSelector(':focus')
        atom.commands.dispatch(treeView.element, 'tool-panel:unfocus')
        expect(treeView).toBeVisible()
        expect(treeView.list).not.toMatchSelector(':focus')
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
      subdir = root1.find('.entries > li:contains(dir1)')

      expect(subdir).not.toHaveClass('expanded')

      subdir.click()

      expect(subdir).toHaveClass('expanded')

      subdir.click()
      expect(subdir).not.toHaveClass('expanded')

    it "restores the expansion state of descendant directories", ->
      child = root1.find('.entries > li:contains(dir1)')
      child.click()

      grandchild = child.find('.entries > li:contains(sub-dir1)')
      grandchild.click()

      root1.click()
      expect(treeView.roots[0]).not.toHaveClass('expanded')
      root1.click()

      # previously expanded descendants remain expanded
      expect(root1.find('> .entries > li:contains(dir1) > .entries > li:contains(sub-dir1) > .entries').length).toBe 1

      # collapsed descendants remain collapsed
      expect(root1.find('> .entries > li:contains(dir2) > .entries')).not.toHaveClass('expanded')

    it "when collapsing a directory, removes change subscriptions from the collapsed directory and its descendants", ->
      child = root1.find('li:contains(dir1)')
      child.click()

      grandchild = child.find('li:contains(sub-dir1)')
      grandchild.click()

      expect(treeView.roots[0].directory.watchSubscription).toBeTruthy()
      expect(child[0].directory.watchSubscription).toBeTruthy()
      expect(grandchild[0].directory.watchSubscription).toBeTruthy()

      root1.click()

      expect(treeView.roots[0].directory.watchSubscription).toBeFalsy()
      expect(child[0].directory.watchSubscription).toBeFalsy()
      expect(grandchild[0].directory.watchSubscription).toBeFalsy()

  describe "when mouse down fires on a file or directory", ->
    it "selects the entry", ->
      dir = root1.find('li:contains(dir1)')
      expect(dir).not.toHaveClass 'selected'
      dir.mousedown()
      expect(dir).toHaveClass 'selected'

      expect(sampleJs).not.toHaveClass 'selected'
      sampleJs.mousedown()
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
          sampleJs.trigger clickEvent(originalEvent: {detail: 1})
          sampleJs.trigger clickEvent(originalEvent: {detail: 2})
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
          sampleJs.trigger clickEvent(originalEvent: {detail: 1})
          sampleJs.trigger clickEvent(originalEvent: {detail: 2})

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
            sampleJs.trigger clickEvent(originalEvent: {detail: 1})

          runs ->
            activePaneItem = atom.workspace.getActivePaneItem()

        it "selects the file and retains focus on tree-view", ->
          expect(sampleJs).toHaveClass 'selected'
          expect(treeView).toHaveFocus()

        it "opens the file in a pending state", ->
          expect(activePaneItem.getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.js')
          expect(atom.workspace.getActivePane().getPendingItem()).toEqual activePaneItem

      describe "when core.allowPendingPaneItems is set to false", ->
        beforeEach ->
          atom.config.set('core.allowPendingPaneItems', false)
          spyOn(atom.workspace, 'open')

          treeView.focus()
          sampleJs.trigger clickEvent(originalEvent: {detail: 1})

        it "selects the file and retains focus on tree-view", ->
          expect(sampleJs).toHaveClass 'selected'
          expect(treeView).toHaveFocus()

        it "does not open the file", ->
          expect(atom.workspace.open).not.toHaveBeenCalled()

      describe "when it is immediately opened with `::openSelectedEntry` afterward", ->
        it "does not open a duplicate file", ->
          # Fixes https://github.com/atom/atom/issues/11391
          openedCount = 0
          originalOpen = atom.workspace.open.bind(atom.workspace)
          spyOn(atom.workspace, 'open').andCallFake (uri, options) ->
            originalOpen(uri, options).then -> openedCount++

          sampleJs.trigger clickEvent(originalEvent: {detail: 1})
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
          sampleJs.trigger clickEvent(originalEvent: {detail: 1})
          sampleJs.trigger clickEvent(originalEvent: {detail: 2})

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

        sampleJs.trigger clickEvent(originalEvent: {detail: 1})
        sampleJs.trigger clickEvent(originalEvent: {detail: 2})

        waitsFor 'open to be called twice', ->
          openedCount is 2

        runs ->
          expect(atom.workspace.getActivePane().getItems().length).toBe 1

  describe "when a directory is single-clicked", ->
    it "is selected", ->
      subdir = root1.find('.directory:first')
      subdir.trigger clickEvent(originalEvent: {detail: 1})
      expect(subdir).toHaveClass 'selected'

  describe "when a directory is double-clicked", ->
    it "toggles the directory expansion state and does not change the focus to the editor", ->
      jasmine.attachToDOM(workspaceElement)

      subdir = null
      waitsForFileToOpen ->
        sampleJs.trigger clickEvent(originalEvent: {detail: 1})

      runs ->
        treeView.focus()
        subdir = root1.find('.directory:first')
        subdir.trigger clickEvent(originalEvent: {detail: 1})
        expect(subdir).toHaveClass 'selected'
        expect(subdir).toHaveClass 'expanded'
        subdir.trigger clickEvent(originalEvent: {detail: 2})
        expect(subdir).toHaveClass 'selected'
        expect(subdir).not.toHaveClass 'expanded'
        expect(treeView).toHaveFocus()

  describe "when an directory is alt-clicked", ->
    describe "when the directory is collapsed", ->
      it "recursively expands the directory", ->
        root1.click()
        treeView.roots[0].collapse()

        expect(treeView.roots[0]).not.toHaveClass 'expanded'
        root1.trigger clickEvent({altKey: true})
        expect(treeView.roots[0]).toHaveClass 'expanded'

        children = root1.find('.directory')
        expect(children.length).toBeGreaterThan 0
        children.each (index, child) -> expect(child).toHaveClass 'expanded'

    describe "when the directory is expanded", ->
      parent    = null
      children  = null

      beforeEach ->
        parent = root1.find('> .entries > .directory').eq(2)
        parent[0].expand()
        children = parent.find('.expanded.directory')
        children.each (index, child) ->
          child.expand()

      it "recursively collapses the directory", ->
        parent.click()
        parent[0].expand()
        expect(parent).toHaveClass 'expanded'
        children.each (index, child) ->
          $(child).click().expand()
          expect($(child)).toHaveClass 'expanded'

        parent.trigger clickEvent({altKey: true})

        expect(parent).not.toHaveClass 'expanded'
        children.each (index, child) ->
          expect(child).not.toHaveClass 'expanded'
        expect(treeView.roots[0]).toHaveClass 'expanded'

  describe "when the active item changes on the active pane", ->
    describe "when the item has a path", ->
      it "selects the entry with that path in the tree view if it is visible", ->
        waitsForFileToOpen ->
          sampleJs.click()

        waitsForPromise ->
          atom.workspace.open(atom.project.getDirectories()[0].resolve('tree-view.txt'))

        runs ->
          expect(sampleTxt).toHaveClass 'selected'
          expect(treeView.find('.selected').length).toBe 1

      it "selects the path's parent dir if its entry is not visible", ->
        waitsForPromise ->
          atom.workspace.open(path.join('dir1', 'sub-dir1', 'sub-file1'))

        runs ->
          dirView = root1.find('.directory:contains(dir1)')
          expect(dirView).toHaveClass 'selected'

      describe "when the tree-view.autoReveal config setting is true", ->
        beforeEach ->
          atom.config.set "tree-view.autoReveal", true

        it "selects the active item's entry in the tree view, expanding parent directories if needed", ->
          waitsForPromise ->
            atom.workspace.open(path.join('dir1', 'sub-dir1', 'sub-file1'))

          runs ->
            dirView = root1.find('.directory:contains(dir1)')
            fileView = root1.find('.file:contains(sub-file1)')
            expect(dirView).not.toHaveClass 'selected'
            expect(fileView).toHaveClass 'selected'
            expect(treeView.find('.selected').length).toBe 1

    describe "when the item has no path", ->
      it "deselects the previously selected entry", ->
        waitsForFileToOpen ->
          sampleJs.click()

        runs ->
          atom.workspace.getActivePane().activateItem(document.createElement("div"))
          expect(treeView.find('.selected')).not.toExist()

  describe "when a different editor becomes active", ->
    beforeEach ->
      jasmine.attachToDOM(workspaceElement)

    it "selects the file in that is open in that editor", ->
      leftEditorPane = null

      waitsForFileToOpen ->
        sampleJs.click()

      runs ->
        leftEditorPane = atom.workspace.getActivePane()
        leftEditorPane.splitRight()

      waitsForFileToOpen ->
        sampleTxt.click()

      runs ->
        expect(sampleTxt).toHaveClass('selected')
        leftEditorPane.activate()
        expect(sampleJs).toHaveClass('selected')

  describe "keyboard navigation", ->
    afterEach ->
      expect(treeView.find('.selected').length).toBeLessThan 2

    describe "core:move-down", ->
      describe "when a collapsed directory is selected", ->
        it "skips to the next directory", ->
          root1.find('.directory:eq(0)').click()

          atom.commands.dispatch(treeView.element, 'core:move-down')
          expect(root1.find('.directory:eq(1)')).toHaveClass 'selected'

      describe "when an expanded directory is selected", ->
        it "selects the first entry of the directory", ->
          subdir = root1.find('.directory:eq(1)')
          subdir.click()

          atom.commands.dispatch(treeView.element, 'core:move-down')

          expect($(subdir[0].entries).find('.entry:first')).toHaveClass 'selected'

      describe "when the last entry of an expanded directory is selected", ->
        it "selects the entry after its parent directory", ->
          subdir1 = root1.find('.directory:eq(1)')
          subdir1[0].expand()
          waitsForFileToOpen ->
            $(subdir1[0].entries).find('.entry:last').click()

          runs ->
            atom.commands.dispatch(treeView.element, 'core:move-down')
            expect(root1.find('.directory:eq(2)')).toHaveClass 'selected'

      describe "when the last directory of another last directory is selected", ->
        [nested, nested2] = []

        beforeEach ->
          nested = root1.find('.directory:eq(2)')
          expect(nested.find('.header').text()).toContain 'nested'
          nested[0].expand()
          nested2 = $(nested[0].entries).find('.entry:last')
          nested2.click()
          nested2[0].collapse()

        describe "when the directory is collapsed", ->
          it "selects the entry after its grandparent directory", ->
            atom.commands.dispatch(treeView.element, 'core:move-down')
            expect(nested.next()).toHaveClass 'selected'

        describe "when the directory is expanded", ->
          it "selects the entry after its grandparent directory", ->
            nested2[0].expand()
            nested2.find('.file').remove() # kill the .gitkeep file, which has to be there but screws the test
            atom.commands.dispatch(treeView.element, 'core:move-down')
            expect(nested.next()).toHaveClass 'selected'

      describe "when the last entry of the last directory is selected", ->
        it "does not change the selection", ->
          lastEntry = root2.find('> .entries .entry:last')
          waitsForFileToOpen ->
            lastEntry.click()

          runs ->
            atom.commands.dispatch(treeView.element, 'core:move-down')
            expect(lastEntry).toHaveClass 'selected'

    describe "core:move-up", ->
      describe "when there is an expanded directory before the currently selected entry", ->
        it "selects the last entry in the expanded directory", ->
          lastDir = root1.find('.directory:last')
          fileAfterDir = lastDir.next()
          lastDir[0].expand()
          waitsForFileToOpen ->
            fileAfterDir.click()

          runs ->
            atom.commands.dispatch(treeView.element, 'core:move-up')
            expect(lastDir.find('.entry:last')).toHaveClass 'selected'

      describe "when there is an entry before the currently selected entry", ->
        it "selects the previous entry", ->
          lastEntry = root1.find('.entry:last')
          waitsForFileToOpen ->
            lastEntry.click()

          runs ->
            atom.commands.dispatch(treeView.element, 'core:move-up')
            expect(lastEntry.prev()).toHaveClass 'selected'

      describe "when there is no entry before the currently selected entry, but there is a parent directory", ->
        it "selects the parent directory", ->
          subdir = root1.find('.directory:first')
          subdir[0].expand()
          subdir.find('> .entries > .entry:first').click()

          atom.commands.dispatch(treeView.element, 'core:move-up')

          expect(subdir).toHaveClass 'selected'

      describe "when there is no parent directory or previous entry", ->
        it "does not change the selection", ->
          root1.click()
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
        treeView.height(100)
        jasmine.attachToDOM(treeView.element)
        element.expand() for element in treeView.find('.directory')
        expect(treeView.list.outerHeight()).toBeGreaterThan treeView.scroller.outerHeight()

        expect(treeView.scrollTop()).toBe 0

        entryCount = treeView.find(".entry").length
        _.times entryCount, -> atom.commands.dispatch(treeView.element, 'core:move-down')
        expect(treeView.scrollTop()).toBeGreaterThan 0

        atom.commands.dispatch(treeView.element, 'core:move-to-top')
        expect(treeView.scrollTop()).toBe 0

      it "selects the root entry", ->
        entryCount = treeView.find(".entry").length
        _.times entryCount, -> atom.commands.dispatch(treeView.element, 'core:move-down')

        expect(treeView.roots[0]).not.toHaveClass 'selected'
        atom.commands.dispatch(treeView.element, 'core:move-to-top')
        expect(treeView.roots[0]).toHaveClass 'selected'

    describe "core:move-to-bottom", ->
      it "scrolls to the bottom", ->
        treeView.height(100)
        jasmine.attachToDOM(treeView.element)
        element.expand() for element in treeView.find('.directory')
        expect(treeView.list.outerHeight()).toBeGreaterThan treeView.scroller.outerHeight()

        expect(treeView.scrollTop()).toBe 0
        atom.commands.dispatch(treeView.element, 'core:move-to-bottom')
        expect(treeView.scrollBottom()).toBe root1.outerHeight() + root2.outerHeight()

        treeView.roots[0].collapse()
        treeView.roots[1].collapse()
        atom.commands.dispatch(treeView.element, 'core:move-to-bottom')
        expect(treeView.scrollTop()).toBe 0

      it "selects the last entry", ->
        expect(treeView.roots[0]).toHaveClass 'selected'
        atom.commands.dispatch(treeView.element, 'core:move-to-bottom')
        expect(root2.find('.entry:last')).toHaveClass 'selected'

    describe "core:page-up", ->
      it "scrolls up a page", ->
        treeView.height(5)
        jasmine.attachToDOM(treeView.element)
        element.expand() for element in treeView.find('.directory')
        expect(treeView.list.outerHeight()).toBeGreaterThan treeView.scroller.outerHeight()

        expect(treeView.scrollTop()).toBe 0
        treeView.scrollToBottom()
        scrollTop = treeView.scrollTop()
        expect(scrollTop).toBeGreaterThan 0

        atom.commands.dispatch(treeView.element, 'core:page-up')
        expect(treeView.scrollTop()).toBe scrollTop - treeView.height()

    describe "core:page-down", ->
      it "scrolls down a page", ->
        treeView.height(5)
        jasmine.attachToDOM(treeView.element)
        element.expand() for element in treeView.find('.directory')
        expect(treeView.list.outerHeight()).toBeGreaterThan treeView.scroller.outerHeight()

        expect(treeView.scrollTop()).toBe 0
        atom.commands.dispatch(treeView.element, 'core:page-down')
        expect(treeView.scrollTop()).toBe treeView.height()

    describe "movement outside of viewable region", ->
      it "scrolls the tree view to the selected item", ->
        treeView.height(100)
        jasmine.attachToDOM(treeView.element)
        element.expand() for element in treeView.find('.directory')
        expect(treeView.list.outerHeight()).toBeGreaterThan treeView.scroller.outerHeight()

        atom.commands.dispatch(treeView.element, 'core:move-down')
        expect(treeView.scrollTop()).toBe 0

        entryCount = treeView.find(".entry").length
        entryHeight = treeView.find('.file').height()

        _.times entryCount, -> atom.commands.dispatch(treeView.element, 'core:move-down')
        expect(treeView.scrollBottom()).toBeGreaterThan (entryCount * entryHeight) - 1

        _.times entryCount, -> atom.commands.dispatch(treeView.element, 'core:move-up')
        expect(treeView.scrollTop()).toBe 0

    describe "tree-view:expand-directory", ->
      describe "when a directory entry is selected", ->
        it "expands the current directory", ->
          subdir = root1.find('.directory:first')
          subdir.click()
          subdir[0].collapse()

          expect(subdir).not.toHaveClass 'expanded'
          atom.commands.dispatch(treeView.element, 'tree-view:expand-item')
          expect(subdir).toHaveClass 'expanded'

        describe "when the directory is already expanded", ->
          describe "when the directory is empty", ->
            it "does nothing", ->
              rootDirPath = fs.absolute(temp.mkdirSync('tree-view-root1'))
              fs.mkdirSync(path.join(rootDirPath, "empty-dir"))
              atom.project.setPaths([rootDirPath])
              rootView = $(treeView.roots[0])

              subdir = rootView.find('.directory:first')
              subdir.click()
              subdir[0].expand()
              expect(subdir).toHaveClass('expanded')
              expect(subdir).toHaveClass('selected')

              atom.commands.dispatch(treeView.element, 'tree-view:expand-directory')
              expect(subdir).toHaveClass('expanded')
              expect(subdir).toHaveClass('selected')

          describe "when the directory has entries", ->
            it "moves the cursor down to the first sub-entry", ->
              subdir = root1.find('.directory:first')
              subdir.click()
              subdir[0].expand()

              atom.commands.dispatch(treeView.element, 'tree-view:expand-item')
              expect(subdir.find('.entry:first')).toHaveClass('selected')

      describe "when a file entry is selected", ->
        it "does nothing", ->
          waitsForFileToOpen ->
            root1.find('.file').click()

          runs ->
            atom.commands.dispatch(treeView.element, 'tree-view:expand-directory')

    describe "tree-view:recursive-expand-directory", ->
      describe "when an collapsed root is recursively expanded", ->
        it "expands the root and all subdirectories", ->
          root1.click()
          treeView.roots[0].collapse()

          expect(treeView.roots[0]).not.toHaveClass 'expanded'
          atom.commands.dispatch(treeView.element, 'tree-view:recursive-expand-directory')
          expect(treeView.roots[0]).toHaveClass 'expanded'

          children = root1.find('.directory')
          expect(children.length).toBeGreaterThan 0
          children.each (index, child) ->
            expect(child).toHaveClass 'expanded'

    describe "tree-view:collapse-directory", ->
      subdir = null

      beforeEach ->
        subdir = root1.find('> .entries > .directory').eq(0)
        subdir[0].expand()

      describe "when an expanded directory is selected", ->
        it "collapses the selected directory", ->
          subdir.click()
          subdir[0].expand()
          expect(subdir).toHaveClass 'expanded'

          atom.commands.dispatch(treeView.element, 'tree-view:collapse-directory')

          expect(subdir).not.toHaveClass 'expanded'
          expect(treeView.roots[0]).toHaveClass 'expanded'

      describe "when a collapsed directory is selected", ->
        it "collapses and selects the selected directory's parent directory", ->
          directories = subdir.find('.directory')
          directories.click()
          directories[0].collapse()
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
            subdir.find('.file').click()

          runs ->
            atom.commands.dispatch(treeView.element, 'tree-view:collapse-directory')
            expect(subdir).not.toHaveClass 'expanded'
            expect(subdir).toHaveClass 'selected'
            expect(treeView.roots[0]).toHaveClass 'expanded'

    describe "tree-view:recursive-collapse-directory", ->
      parent    = null
      children  = null

      beforeEach ->
        parent = root1.find('> .entries > .directory').eq(2)
        parent[0].expand()
        children = parent.find('.expanded.directory')
        children.each (index, child) ->
          child.expand()

      describe "when an expanded directory is recursively collapsed", ->
        it "collapses the directory and all its child directories", ->
          parent.click()
          parent[0].expand()
          expect(parent).toHaveClass 'expanded'
          children.each (index, child) ->
            $(child).click()
            child.expand()
            expect(child).toHaveClass 'expanded'

          atom.commands.dispatch(treeView.element, 'tree-view:recursive-collapse-directory')

          expect(parent).not.toHaveClass 'expanded'
          children.each (index, child) ->
            expect(child).not.toHaveClass 'expanded'
          expect(treeView.roots[0]).toHaveClass 'expanded'

    describe "tree-view:open-selected-entry", ->
      describe "when a file is selected", ->
        it "opens the file in the editor and focuses it", ->
          jasmine.attachToDOM(workspaceElement)

          file = root1.find('.file:contains(tree-view.js)')[0]
          treeView.selectEntry(file)

          waitsForFileToOpen ->
            atom.commands.dispatch(treeView.element, 'tree-view:open-selected-entry')

          runs ->
            item = atom.workspace.getActivePaneItem()
            expect(item.getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.js')
            expect(atom.views.getView(item)).toHaveFocus()
            expect(atom.workspace.getActivePane().getPendingItem()).not.toEqual item

        it "opens pending items in a permanent state", ->
          jasmine.attachToDOM(workspaceElement)

          file = root1.find('.file:contains(tree-view.js)')[0]
          treeView.selectEntry(file)

          waitsForFileToOpen ->
            atom.commands.dispatch(treeView.element, 'tree-view:expand-item')

          runs ->
            item = atom.workspace.getActivePaneItem()
            expect(item.getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.js')
            expect(atom.workspace.getActivePane().getPendingItem()).toEqual item
            expect(atom.views.getView(item)).toHaveFocus()

            file = root1.find('.file:contains(tree-view.js)')[0]
            treeView.selectEntry(file)

          waitsForFileToOpen ->
            atom.commands.dispatch(treeView.element, 'tree-view:open-selected-entry')

          runs ->
            item = atom.workspace.getActivePaneItem()
            expect(item.getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.js')
            expect(atom.views.getView(item)).toHaveFocus()
            expect(atom.workspace.getActivePane().getPendingItem()).not.toEqual item

      describe "when a directory is selected", ->
        it "expands or collapses the directory", ->
          subdir = root1.find('.directory').first()
          subdir.click()
          subdir[0].collapse()

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
                root1.find('.file:contains(tree-view.js)').click()

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

          file = root1.find('.file:contains(tree-view.js)')[0]
          treeView.selectEntry(file)

          waitsForFileToOpen ->
            atom.commands.dispatch(treeView.element, 'tree-view:expand-item')

          runs ->
            item = atom.workspace.getActivePaneItem()
            expect(item.getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.js')
            expect(atom.workspace.getActivePane().getPendingItem()).toEqual item
            expect(atom.views.getView(item)).toHaveFocus()

      describe "when a directory is selected", ->
        it "expands the directory", ->
          subdir = root1.find('.directory').first()
          subdir.click()
          subdir[0].collapse()

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
      expect(atom.workspace.getPanes().length).toBe 9

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
            pane = atom.workspace.getPanes()[index]
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
      expect(atom.workspace.getPanes().length).toBe 9

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
              pane = atom.workspace.getPanes()[index]
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

      root1 = $(treeView.roots[0])
      dirView = $(treeView.roots[0].entries).find('.directory:contains(test-dir):first')
      dirView[0].expand()
      fileView = treeView.find('.file:contains(test-file.txt)')
      dirView2 = $(treeView.roots[0].entries).find('.directory:contains(test-dir2):last')
      dirView2[0].expand()
      fileView2 = treeView.find('.file:contains(test-file2.txt)')
      fileView3 = treeView.find('.file:contains(test-file3.txt)')
      dirView3 = $(treeView.roots[1].entries).find('.directory:contains(test-dir3):first')
      dirView3[0].expand()
      fileView4 = treeView.find('.file:contains(test-file4.txt)')
      fileView5 = treeView.find('.file:contains(test-file5.txt)')

    describe "tree-view:copy", ->
      LocalStorage = window.localStorage
      beforeEach ->
        LocalStorage.clear()

        waitsForFileToOpen ->
          fileView2.click()

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
          fileView3.addClass('selected')
          atom.commands.dispatch(treeView.element, "tree-view:copy")
          storedPaths = JSON.parse(LocalStorage['tree-view:copyPath'])

          expect(storedPaths.length).toBe 2
          expect(storedPaths[0]).toBe fileView2[0].getPath()
          expect(storedPaths[1]).toBe fileView3[0].getPath()

    describe "tree-view:cut", ->
      LocalStorage = window.localStorage

      beforeEach ->
        LocalStorage.clear()

        waitsForFileToOpen ->
          fileView2.click()

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
          fileView3.addClass('selected')
          atom.commands.dispatch(treeView.element, "tree-view:cut")
          storedPaths = JSON.parse(LocalStorage['tree-view:cutPath'])

          expect(storedPaths.length).toBe 2
          expect(storedPaths[0]).toBe fileView2[0].getPath()
          expect(storedPaths[1]).toBe fileView3[0].getPath()

    describe "tree-view:paste", ->
      LocalStorage = window.localStorage

      beforeEach ->
        LocalStorage.clear()

      describe "when attempting to paste a directory into itself", ->
        describe "when copied", ->
          it "makes a copy inside itself", ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([dirPath])

            dirView.click()

            newPath = path.join(dirPath, path.basename(dirPath))
            expect(-> atom.commands.dispatch(treeView.element, "tree-view:paste")).not.toThrow()
            expect(fs.existsSync(newPath)).toBeTruthy()

          it 'does not keep copying recursively', ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([dirPath])
            dirView.click()

            newPath = path.join(dirPath, path.basename(dirPath))
            expect(-> atom.commands.dispatch(treeView.element, "tree-view:paste")).not.toThrow()
            expect(fs.existsSync(newPath)).toBeTruthy()
            expect(fs.existsSync(path.join(newPath, path.basename(dirPath)))).toBeFalsy()

        describe "when cut", ->
          it "does nothing", ->
            LocalStorage['tree-view:cutPath'] = JSON.stringify([dirPath])
            dirView.click()

            expect(fs.existsSync(dirPath)).toBeTruthy()
            expect(fs.existsSync(path.join(dirPath, path.basename(dirPath)))).toBeFalsy()

      describe "when pasting entries which don't exist anymore", ->
        it "skips the entry which doesn't exist", ->
          filePathDoesntExist1 = path.join(dirPath2, "test-file-doesnt-exist1.txt")
          filePathDoesntExist2 = path.join(dirPath2, "test-file-doesnt-exist2.txt")

          LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath2, filePathDoesntExist1, filePath3, filePathDoesntExist2])

          fileView.click()
          atom.commands.dispatch(treeView.element, "tree-view:paste")

          expect(fs.existsSync(path.join(dirPath, path.basename(filePath2)))).toBeTruthy()
          expect(fs.existsSync(path.join(dirPath, path.basename(filePath3)))).toBeTruthy()
          expect(fs.existsSync(path.join(dirPath, path.basename(filePathDoesntExist1)))).toBeFalsy()
          expect(fs.existsSync(path.join(dirPath, path.basename(filePathDoesntExist2)))).toBeFalsy()
          expect(fs.existsSync(filePath2)).toBeTruthy()
          expect(fs.existsSync(filePath3)).toBeTruthy()

      describe "when a file has been copied", ->
        describe "when a file is selected", ->
          it "creates a copy of the original file in the selected file's parent directory", ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath])

            fileView2.click()
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            expect(fs.existsSync(path.join(dirPath2, path.basename(filePath)))).toBeTruthy()
            expect(fs.existsSync(filePath)).toBeTruthy()

          describe "when the target already exists", ->
            it "appends a number to the destination name", ->
              LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath])

              fileView.click()
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

              treeView.find('.file:contains(test.file.txt)').click()
              atom.commands.dispatch(treeView.element, "tree-view:paste")

              fileView2.click()
              atom.commands.dispatch(treeView.element, "tree-view:paste")
              expect(fs.existsSync(path.join(dirPath, path.basename(dotFilePath)))).toBeTruthy()
              expect(fs.existsSync(dotFilePath)).toBeTruthy()

            describe "when the target already exists", ->
              it "appends a number to the destination name", ->
                dotFilePath = path.join(dirPath, "test.file.txt")
                fs.writeFileSync(dotFilePath, "doesn't matter .")
                LocalStorage['tree-view:copyPath'] = JSON.stringify([dotFilePath])

                fileView.click()
                atom.commands.dispatch(treeView.element, "tree-view:paste")
                atom.commands.dispatch(treeView.element, "tree-view:paste")

                expect(fs.existsSync(path.join(dirPath, 'test0.file.txt'))).toBeTruthy()
                expect(fs.existsSync(path.join(dirPath, 'test1.file.txt'))).toBeTruthy()
                expect(fs.existsSync(dotFilePath)).toBeTruthy()

        describe "when a directory is selected", ->
          it "creates a copy of the original file in the selected directory", ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath])

            dirView2.click()
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            expect(fs.existsSync(path.join(dirPath2, path.basename(filePath)))).toBeTruthy()
            expect(fs.existsSync(filePath)).toBeTruthy()

          describe "when the target already exists", ->
            it "appends a number to the destination file name", ->
              LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath])

              dirView.click()
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

            dotDirView = $(treeView.roots[0].entries).find('.directory:contains(test\\.dir)')
            dotDirView.click()
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            expect(fs.existsSync(path.join(dotDirPath, path.basename(filePath)))).toBeTruthy()
            expect(fs.existsSync(filePath)).toBeTruthy()

          describe "when the target already exists", ->
            it "appends a number to the destination file name", ->
              dotFilePath = path.join(dotDirPath, "test.file.txt")
              fs.writeFileSync(dotFilePath, "doesn't matter .")
              LocalStorage['tree-view:copyPath'] = JSON.stringify([dotFilePath])

              dotDirView = $(treeView.roots[0].entries).find('.directory:contains(test\\.dir)')
              dotDirView.click()
              atom.commands.dispatch(treeView.element, "tree-view:paste")
              atom.commands.dispatch(treeView.element, "tree-view:paste")

              expect(fs.existsSync(path.join(dotDirPath, "test0.file.txt"))).toBeTruthy()
              expect(fs.existsSync(path.join(dotDirPath, "test1.file.txt"))).toBeTruthy()
              expect(fs.existsSync(dotFilePath)).toBeTruthy()

        describe "when pasting into a different root directory", ->
          it "creates the file", ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath4])
            dirView2.click()
            atom.commands.dispatch(treeView.element, "tree-view:paste")
            expect(fs.existsSync(path.join(dirPath2, path.basename(filePath4)))).toBeTruthy()

        describe "when pasting a file with an asterisk char '*' in to different directory", ->
          it "should successfully move the file", ->
            # Files cannot contain asterisks on Windows
            return if process.platform is "win32"

            asteriskFilePath = path.join(dirPath, "test-file-**.txt")
            fs.writeFileSync(asteriskFilePath, "doesn't matter *")
            LocalStorage['tree-view:copyPath'] = JSON.stringify([asteriskFilePath])
            dirView2.click()
            atom.commands.dispatch(treeView.element, "tree-view:paste")
            expect(fs.existsSync(path.join(dirPath2, path.basename(asteriskFilePath)))).toBeTruthy()

      describe "when nothing has been copied", ->
        it "does not paste anything", ->
          expect(-> atom.commands.dispatch(treeView.element, "tree-view:paste")).not.toThrow()

      describe "when multiple files have been copied", ->
        describe "when a file is selected", ->
          it "copies the selected files to the parent directory of the selected file", ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath2, filePath3])

            fileView.click()
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

              fileView.click()
              atom.commands.dispatch(treeView.element, "tree-view:paste")

              expect(fs.existsSync(path.join(dirPath, "test-file20.txt"))).toBeTruthy()
              expect(fs.existsSync(path.join(dirPath, "test-file30.txt"))).toBeTruthy()

      describe "when a file has been cut", ->
        describe "when a file is selected", ->
          it "creates a copy of the original file in the selected file's parent directory and removes the original", ->
            LocalStorage['tree-view:cutPath'] = JSON.stringify([filePath])

            fileView2.click()
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            expect(fs.existsSync(path.join(dirPath2, path.basename(filePath)))).toBeTruthy()
            expect(fs.existsSync(filePath)).toBeFalsy()

          describe 'when the target destination file exists', ->
            it 'does not move the cut file', ->
              LocalStorage['tree-view:cutPath'] = JSON.stringify([filePath])

              filePath3 = path.join(dirPath2, "test-file.txt")
              fs.writeFileSync(filePath3, "doesn't matter")

              fileView2.click()
              atom.commands.dispatch(treeView.element, "tree-view:paste")

              expect(fs.existsSync(filePath)).toBeTruthy()

        describe "when a directory is selected", ->
          it "creates a copy of the original file in the selected directory and removes the original", ->
            LocalStorage['tree-view:cutPath'] = JSON.stringify([filePath])

            dirView2.click()
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            expect(fs.existsSync(path.join(dirPath2, path.basename(filePath)))).toBeTruthy()
            expect(fs.existsSync(filePath)).toBeFalsy()

      describe "when multiple files have been cut", ->
        describe "when a file is selected", ->
          it "moves the selected files to the parent directory of the selected file", ->
            LocalStorage['tree-view:cutPath'] = JSON.stringify([filePath2, filePath3])

            fileView.click()
            atom.commands.dispatch(treeView.element, "tree-view:paste")

            expect(fs.existsSync(path.join(dirPath, path.basename(filePath2)))).toBeTruthy()
            expect(fs.existsSync(path.join(dirPath, path.basename(filePath3)))).toBeTruthy()
            expect(fs.existsSync(filePath2)).toBeFalsy()
            expect(fs.existsSync(filePath3)).toBeFalsy()

          describe 'when the target destination file exists', ->
            it 'does not move the cut file', ->
              LocalStorage['tree-view:cutPath'] = JSON.stringify([filePath2, filePath3])

              filePath4 = path.join(dirPath, "test-file2.txt")
              filePath5 = path.join(dirPath, "test-file3.txt")
              fs.writeFileSync(filePath4, "doesn't matter")
              fs.writeFileSync(filePath5, "doesn't matter")

              fileView.click()
              atom.commands.dispatch(treeView.element, "tree-view:paste")

              expect(fs.existsSync(filePath2)).toBeTruthy()
              expect(fs.existsSync(filePath3)).toBeTruthy()

        describe "when a directory is selected", ->
          it "creates a copy of the original file in the selected directory and removes the original", ->
            LocalStorage['tree-view:cutPath'] = JSON.stringify([filePath])

            dirView2.click()
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

          fileView2.click()
          atom.notifications.clear()
          atom.commands.dispatch(treeView.element, "tree-view:paste")

          expect(atom.notifications.getNotifications()[0].getMessage()).toContain 'Unable to paste paths'
          expect(atom.notifications.getNotifications()[0].getDetail()).toContain 'ENOENT: no such file or directory'

    describe "tree-view:add-file", ->
      [addPanel, addDialog] = []

      beforeEach ->
        jasmine.attachToDOM(workspaceElement)

        waitsForFileToOpen ->
          fileView.click()

        runs ->
          atom.commands.dispatch(treeView.element, "tree-view:add-file")
          [addPanel] = atom.workspace.getModalPanels()
          addDialog = $(addPanel.getItem()).view()

      describe "when a file is selected", ->
        it "opens an add dialog with the file's current directory path populated", ->
          expect(addDialog).toExist()
          expect(addDialog.promptText.text()).toBeTruthy()
          expect(atom.project.relativize(dirPath)).toMatch(/[^\\\/]$/)
          expect(addDialog.miniEditor.getText()).toBe(atom.project.relativize(dirPath) + path.sep)
          expect(addDialog.miniEditor.getModel().getCursorBufferPosition().column).toBe addDialog.miniEditor.getText().length
          expect(addDialog.miniEditor).toHaveFocus()

        describe "when the parent directory of the selected file changes", ->
          it "still shows the active file as selected", ->
            dirView[0].directory.emitter.emit 'did-remove-entries', {'deleted.txt': {}}
            expect(treeView.find('.selected').text()).toBe path.basename(filePath)

        describe "when the path without a trailing '#{path.sep}' is changed and confirmed", ->
          describe "when no file exists at that location", ->
            it "add a file, closes the dialog and selects the file in the tree-view", ->
              newPath = path.join(dirPath, "new-test-file.txt")

              waitsForFileToOpen ->
                addDialog.miniEditor.getModel().insertText(path.basename(newPath))
                atom.commands.dispatch addDialog.element, 'core:confirm'

              runs ->
                expect(fs.isFileSync(newPath)).toBeTruthy()
                expect(atom.workspace.getModalPanels().length).toBe 0
                expect(atom.workspace.getActivePaneItem().getPath()).toBe newPath

              waitsFor "tree view to be updated", ->
                $(dirView[0].entries).find("> .file").length > 1

              runs ->
                expect(treeView.find('.selected').text()).toBe path.basename(newPath)

            it "adds file in any project path", ->
              newPath = path.join(dirPath3, "new-test-file.txt")

              waitsForFileToOpen ->
                fileView4.click()

              waitsForFileToOpen ->
                atom.commands.dispatch(treeView.element, "tree-view:add-file")
                [addPanel] = atom.workspace.getModalPanels()
                addDialog = $(addPanel.getItem()).view()
                addDialog.miniEditor.getModel().insertText(path.basename(newPath))
                atom.commands.dispatch addDialog.element, 'core:confirm'

              runs ->
                expect(fs.isFileSync(newPath)).toBeTruthy()
                expect(atom.workspace.getModalPanels().length).toBe 0
                expect(atom.workspace.getActivePaneItem().getPath()).toBe newPath

              waitsFor "tree view to be updated", ->
                $(dirView3[0].entries).find("> .file").length > 1

              runs ->
                expect(treeView.find('.selected').text()).toBe path.basename(newPath)

          describe "when a file already exists at that location", ->
            it "shows an error message and does not close the dialog", ->
              newPath = path.join(dirPath, "new-test-file.txt")
              fs.writeFileSync(newPath, '')
              addDialog.miniEditor.getModel().insertText(path.basename(newPath))
              atom.commands.dispatch addDialog.element, 'core:confirm'

              expect(addDialog.errorMessage.text()).toContain 'already exists'
              expect(addDialog).toHaveClass('error')
              expect(atom.workspace.getModalPanels()[0]).toBe addPanel

          describe "when the project has no path", ->
            it "add a file and closes the dialog", ->
              atom.project.setPaths([])
              addDialog.close()
              atom.commands.dispatch(treeView.element, "tree-view:add-file")
              [addPanel] = atom.workspace.getModalPanels()
              addDialog = $(addPanel.getItem()).view()

              newPath = temp.path()
              addDialog.miniEditor.getModel().insertText(newPath)

              waitsForFileToOpen ->
                atom.commands.dispatch addDialog.element, 'core:confirm'

              runs ->
                expect(fs.isFileSync(newPath)).toBeTruthy()
                expect(atom.workspace.getModalPanels().length).toBe 0
                expect(atom.workspace.getActivePaneItem().getPath()).toBe fs.realpathSync(newPath)

        describe "when the path with a trailing '#{path.sep}' is changed and confirmed", ->
          it "shows an error message and does not close the dialog", ->
            addDialog.miniEditor.getModel().insertText("new-test-file" + path.sep)
            atom.commands.dispatch addDialog.element, 'core:confirm'

            expect(addDialog.errorMessage.text()).toContain 'names must not end with'
            expect(addDialog).toHaveClass('error')
            expect(atom.workspace.getModalPanels()[0]).toBe addPanel

        describe "when 'core:cancel' is triggered on the add dialog", ->
          it "removes the dialog and focuses the tree view", ->
            atom.commands.dispatch addDialog.element, 'core:cancel'
            expect(atom.workspace.getModalPanels().length).toBe 0
            expect(treeView.find(".tree-view")).toMatchSelector(':focus')

        describe "when the add dialog's editor loses focus", ->
          it "removes the dialog and focuses root view", ->
            workspaceElement.focus()
            expect(atom.workspace.getModalPanels().length).toBe 0
            expect(atom.views.getView(atom.workspace.getActivePane())).toHaveFocus()

        describe "when the path ends with whitespace", ->
          it "removes the trailing whitespace before creating the file", ->
            newPath = path.join(dirPath, "new-test-file.txt")
            addDialog.miniEditor.getModel().insertText(path.basename(newPath) + "  ")

            waitsForFileToOpen ->
              atom.commands.dispatch addDialog.element, 'core:confirm'

            runs ->
              expect(fs.isFileSync(newPath)).toBeTruthy()
              expect(atom.workspace.getActivePaneItem().getPath()).toBe newPath

      describe "when a directory is selected", ->
        it "opens an add dialog with the directory's path populated", ->
          addDialog.cancel()
          dirView.click()
          atom.commands.dispatch(treeView.element, "tree-view:add-file")
          addDialog = $(atom.workspace.getModalPanels()[0].getItem()).view()

          expect(addDialog).toExist()
          expect(addDialog.promptText.text()).toBeTruthy()
          expect(atom.project.relativize(dirPath)).toMatch(/[^\\\/]$/)
          expect(addDialog.miniEditor.getText()).toBe(atom.project.relativize(dirPath) + path.sep)
          expect(addDialog.miniEditor.getModel().getCursorBufferPosition().column).toBe addDialog.miniEditor.getText().length
          expect(addDialog.miniEditor).toHaveFocus()

      describe "when the root directory is selected", ->
        it "opens an add dialog with no path populated", ->
          addDialog.cancel()
          root1.click()
          atom.commands.dispatch(treeView.element, "tree-view:add-file")
          addDialog = $(atom.workspace.getModalPanels()[0].getItem()).view()

          expect(addDialog.miniEditor.getText()).toBe ""

      describe "when there is no entry selected", ->
        it "opens an add dialog with no path populated", ->
          addDialog.cancel()
          root1.click()
          root1.removeClass('selected')
          expect(treeView.selectedEntry()).toBeNull()
          atom.commands.dispatch(treeView.element, "tree-view:add-file")
          addDialog = $(atom.workspace.getModalPanels()[0].getItem()).view()

          expect(addDialog.miniEditor.getText()).toBe ""

      describe "when the project doesn't have a root directory", ->
        it "shows an error", ->
          addDialog.cancel()
          atom.project.setPaths([])
          atom.commands.dispatch(workspaceElement, "tree-view:add-folder")
          [addPanel] = atom.workspace.getModalPanels()
          addDialog = $(addPanel.getItem()).view()
          addDialog.miniEditor.getModel().insertText("a-file")
          atom.commands.dispatch(addDialog.element, 'core:confirm')
          expect(addDialog.text()).toContain("You must open a directory to create a file with a relative path")

    describe "tree-view:add-folder", ->
      [addPanel, addDialog] = []

      beforeEach ->
        jasmine.attachToDOM(workspaceElement)

        waitsForFileToOpen ->
          fileView.click()

        runs ->
          atom.commands.dispatch(treeView.element, "tree-view:add-folder")
          [addPanel] = atom.workspace.getModalPanels()
          addDialog = $(addPanel.getItem()).view()

      describe "when a file is selected", ->
        it "opens an add dialog with the file's current directory path populated", ->
          expect(addDialog).toExist()
          expect(addDialog.promptText.text()).toBeTruthy()
          expect(atom.project.relativize(dirPath)).toMatch(/[^\\\/]$/)
          expect(addDialog.miniEditor.getText()).toBe(atom.project.relativize(dirPath) + path.sep)
          expect(addDialog.miniEditor.getModel().getCursorBufferPosition().column).toBe addDialog.miniEditor.getText().length
          expect(addDialog.miniEditor).toHaveFocus()

        describe "when the path without a trailing '#{path.sep}' is changed and confirmed", ->
          describe "when no directory exists at the given path", ->
            it "adds a directory and closes the dialog", ->
              newPath = path.join(dirPath, 'new', 'dir')
              addDialog.miniEditor.getModel().insertText("new#{path.sep}dir")
              atom.commands.dispatch addDialog.element, 'core:confirm'
              expect(fs.isDirectorySync(newPath)).toBeTruthy()
              expect(atom.workspace.getModalPanels().length).toBe 0
              expect(atom.workspace.getActivePaneItem().getPath()).not.toBe newPath
              expect(treeView.find(".tree-view")).toMatchSelector(':focus')
              expect(dirView.find('.directory.selected:contains(new)').length).toBe 1

        describe "when the path with a trailing '#{path.sep}' is changed and confirmed", ->
          describe "when no directory exists at the given path", ->
            it "adds a directory and closes the dialog", ->
              newPath = path.join(dirPath, 'new', 'dir')
              addDialog.miniEditor.getModel().insertText("new#{path.sep}dir#{path.sep}")
              atom.commands.dispatch addDialog.element, 'core:confirm'
              expect(fs.isDirectorySync(newPath)).toBeTruthy()
              expect(atom.workspace.getModalPanels().length).toBe 0
              expect(atom.workspace.getActivePaneItem().getPath()).not.toBe newPath
              expect(treeView.find(".tree-view")).toMatchSelector(':focus')
              expect(dirView.find('.directory.selected:contains(new)').length).toBe(1)

            it "selects the created directory and does not change the expansion state of existing directories", ->
              expandedPath = path.join(dirPath, 'expanded-dir')
              fs.makeTreeSync(expandedPath)
              treeView.entryForPath(dirPath).expand()
              treeView.entryForPath(dirPath).reload()
              expandedView = treeView.entryForPath(expandedPath)
              expandedView.expand()

              newPath = path.join(dirPath, "new2") + path.sep
              addDialog.miniEditor.getModel().insertText("new2#{path.sep}")
              atom.commands.dispatch addDialog.element, 'core:confirm'
              expect(fs.isDirectorySync(newPath)).toBeTruthy()
              expect(atom.workspace.getModalPanels().length).toBe 0
              expect(atom.workspace.getActivePaneItem().getPath()).not.toBe newPath
              expect(treeView.find(".tree-view")).toMatchSelector(':focus')
              expect(dirView.find('.directory.selected:contains(new2)').length).toBe(1)
              expect(treeView.entryForPath(expandedPath).isExpanded).toBeTruthy()

            describe "when the project has no path", ->
              it "adds a directory and closes the dialog", ->
                addDialog.close()
                atom.project.setPaths([])
                atom.commands.dispatch(treeView.element, "tree-view:add-folder")
                [addPanel] = atom.workspace.getModalPanels()
                addDialog = $(addPanel.getItem()).view()

                expect(addDialog.miniEditor.getModel().getText()).toBe ''
                newPath = temp.path()
                addDialog.miniEditor.getModel().insertText(newPath)
                atom.commands.dispatch addDialog.element, 'core:confirm'
                expect(fs.isDirectorySync(newPath)).toBeTruthy()
                expect(atom.workspace.getModalPanels().length).toBe 0

          describe "when a directory already exists at the given path", ->
            it "shows an error message and does not close the dialog", ->
              newPath = path.join(dirPath, "new-dir")
              fs.makeTreeSync(newPath)
              addDialog.miniEditor.getModel().insertText("new-dir#{path.sep}")
              atom.commands.dispatch addDialog.element, 'core:confirm'

              expect(addDialog.errorMessage.text()).toContain 'already exists'
              expect(addDialog).toHaveClass('error')
              expect(atom.workspace.getModalPanels()[0]).toBe addPanel

    describe "tree-view:move", ->
      describe "when a file is selected", ->
        moveDialog = null

        beforeEach ->
          jasmine.attachToDOM(workspaceElement)

          waitsForFileToOpen ->
            fileView.click()

          runs ->
            atom.commands.dispatch(treeView.element, "tree-view:move")
            moveDialog = $(atom.workspace.getModalPanels()[0].getItem()).view()

        afterEach ->
          waits 50 # The move specs cause too many false positives because of their async nature, so wait a little bit before we cleanup

        it "opens a move dialog with the file's current path (excluding extension) populated", ->
          extension = path.extname(filePath)
          fileNameWithoutExtension = path.basename(filePath, extension)
          expect(moveDialog).toExist()
          expect(moveDialog.promptText.text()).toBe "Enter the new path for the file."
          expect(moveDialog.miniEditor.getText()).toBe(atom.project.relativize(filePath))
          expect(moveDialog.miniEditor.getModel().getSelectedText()).toBe path.basename(fileNameWithoutExtension)
          expect(moveDialog.miniEditor).toHaveFocus()

        describe "when the path is changed and confirmed", ->
          describe "when all the directories along the new path exist", ->
            it "moves the file, updates the tree view, and closes the dialog", ->
              newPath = path.join(rootDirPath, 'renamed-test-file.txt')
              moveDialog.miniEditor.setText(path.basename(newPath))

              atom.commands.dispatch moveDialog.element, 'core:confirm'

              expect(fs.existsSync(newPath)).toBeTruthy()
              expect(fs.existsSync(filePath)).toBeFalsy()
              expect(atom.workspace.getModalPanels().length).toBe 0

              waitsFor "tree view to update", ->
                root1.find('> .entries > .file:contains(renamed-test-file.txt)').length > 0

              runs ->
                dirView = $(treeView.roots[0].entries).find('.directory:contains(test-dir)')
                dirView[0].expand()
                expect($(dirView[0].entries).children().length).toBe 0

          describe "when the directories along the new path don't exist", ->
            it "creates the target directory before moving the file", ->
              newPath = path.join(rootDirPath, 'new', 'directory', 'renamed-test-file.txt')
              moveDialog.miniEditor.setText(newPath)

              atom.commands.dispatch moveDialog.element, 'core:confirm'

              waitsFor "tree view to update", ->
                root1.find('> .entries > .directory:contains(new)').length > 0

              runs ->
                expect(fs.existsSync(newPath)).toBeTruthy()
                expect(fs.existsSync(filePath)).toBeFalsy()

          describe "when a file or directory already exists at the target path", ->
            it "shows an error message and does not close the dialog", ->
              runs ->
                fs.writeFileSync(path.join(rootDirPath, 'target.txt'), '')
                newPath = path.join(rootDirPath, 'target.txt')
                moveDialog.miniEditor.setText(newPath)

                atom.commands.dispatch moveDialog.element, 'core:confirm'

                expect(moveDialog.errorMessage.text()).toContain 'already exists'
                expect(moveDialog).toHaveClass('error')
                expect(moveDialog.hasParent()).toBeTruthy()

        describe "when 'core:cancel' is triggered on the move dialog", ->
          it "removes the dialog and focuses the tree view", ->
            atom.commands.dispatch moveDialog.element, 'core:cancel'
            expect(atom.workspace.getModalPanels().length).toBe 0
            expect(treeView.find(".tree-view")).toMatchSelector(':focus')

        describe "when the move dialog's editor loses focus", ->
          it "removes the dialog and focuses root view", ->
            $(workspaceElement).focus()
            expect(atom.workspace.getModalPanels().length).toBe 0
            expect(atom.views.getView(atom.workspace.getActivePane())).toHaveFocus()

      describe "when a file is selected that's name starts with a '.'", ->
        [dotFilePath, dotFileView, moveDialog] = []

        beforeEach ->
          dotFilePath = path.join(dirPath, ".dotfile")
          fs.writeFileSync(dotFilePath, "dot")
          dirView[0].collapse()
          dirView[0].expand()
          dotFileView = treeView.find('.file:contains(.dotfile)')

          waitsForFileToOpen ->
            dotFileView.click()

          runs ->
            atom.commands.dispatch(treeView.element, "tree-view:move")
            moveDialog = $(atom.workspace.getModalPanels()[0].getItem()).view()

        it "selects the entire file name", ->
          expect(moveDialog).toExist()
          expect(moveDialog.miniEditor.getText()).toBe(atom.project.relativize(dotFilePath))
          expect(moveDialog.miniEditor.getModel().getSelectedText()).toBe '.dotfile'

      describe "when the project is selected", ->
        it "doesn't display the move dialog", ->
          treeView.roots[0].click()
          atom.commands.dispatch(treeView.element, "tree-view:move")
          expect(atom.workspace.getModalPanels().length).toBe(0)

    describe "tree-view:duplicate", ->
      describe "when a file is selected", ->
        copyDialog = null

        beforeEach ->
          jasmine.attachToDOM(workspaceElement)

          waitsForFileToOpen ->
            fileView.click()

          runs ->
            atom.commands.dispatch(treeView.element, "tree-view:duplicate")
            copyDialog = $(atom.workspace.getModalPanels()[0].getItem()).view()

        afterEach ->
          waits 50 # The copy specs cause too many false positives because of their async nature, so wait a little bit before we cleanup

        it "opens a copy dialog to duplicate with the file's current path populated", ->
          extension = path.extname(filePath)
          fileNameWithoutExtension = path.basename(filePath, extension)
          expect(copyDialog).toExist()
          expect(copyDialog.promptText.text()).toBe "Enter the new path for the duplicate."
          expect(copyDialog.miniEditor.getText()).toBe(atom.project.relativize(filePath))
          expect(copyDialog.miniEditor.getModel().getSelectedText()).toBe path.basename(fileNameWithoutExtension)
          expect(copyDialog.miniEditor).toHaveFocus()

        describe "when the path is changed and confirmed", ->
          describe "when all the directories along the new path exist", ->
            it "duplicates the file, updates the tree view, opens the new file and closes the dialog", ->
              newPath = path.join(rootDirPath, 'duplicated-test-file.txt')
              copyDialog.miniEditor.setText(path.basename(newPath))

              waitsForFileToOpen ->
                atom.commands.dispatch copyDialog.element, 'core:confirm'

              waitsFor "tree view to update", ->
                root1.find('> .entries > .file:contains(duplicated-test-file.txt)').length > 0

              runs ->
                expect(fs.existsSync(newPath)).toBeTruthy()
                expect(fs.existsSync(filePath)).toBeTruthy()
                expect(atom.workspace.getModalPanels().length).toBe 0
                dirView = $(treeView.roots[0].entries).find('.directory:contains(test-dir)')
                dirView[0].expand()
                expect($(dirView[0].entries).children().length).toBe 1
                expect(atom.workspace.getActiveTextEditor().getPath()).toBe(newPath)

          describe "when the directories along the new path don't exist", ->
            it "duplicates the tree and opens the new file", ->
              newPath = path.join(rootDirPath, 'new', 'directory', 'duplicated-test-file.txt')
              copyDialog.miniEditor.setText(newPath)

              waitsForFileToOpen ->
                atom.commands.dispatch copyDialog.element, 'core:confirm'

              waitsFor "tree view to update", ->
                root1.find('> .entries > .directory:contains(new)').length > 0

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

                expect(copyDialog.errorMessage.text()).toContain 'already exists'
                expect(copyDialog).toHaveClass('error')
                expect(copyDialog.hasParent()).toBeTruthy()

        describe "when 'core:cancel' is triggered on the copy dialog", ->
          it "removes the dialog and focuses the tree view", ->
            jasmine.attachToDOM(treeView.element)
            atom.commands.dispatch copyDialog.element, 'core:cancel'
            expect(atom.workspace.getModalPanels().length).toBe 0
            expect(treeView.find(".tree-view")).toMatchSelector(':focus')

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
          dirView[0].collapse()
          dirView[0].expand()
          dotFileView = treeView.find('.file:contains(.dotfile)')

          waitsForFileToOpen ->
            dotFileView.click()

          runs ->
            atom.commands.dispatch(treeView.element, "tree-view:duplicate")
            copyDialog = $(atom.workspace.getModalPanels()[0].getItem()).view()

        it "selects the entire file name", ->
          expect(copyDialog).toExist()
          expect(copyDialog.miniEditor.getText()).toBe(atom.project.relativize(dotFilePath))
          expect(copyDialog.miniEditor.getModel().getSelectedText()).toBe '.dotfile'

      describe "when the project is selected", ->
        it "doesn't display the copy dialog", ->
          treeView.roots[0].click()
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
            copyDialog = $(atom.workspace.getModalPanels()[0].getItem()).view()

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
        root1.click()
        atom.commands.dispatch(treeView.element, 'tree-view:remove')

        args = atom.confirm.mostRecentCall.args[0]
        expect(args.buttons).toEqual ['OK']

      it "shows the native alert dialog", ->
        spyOn(atom, 'confirm')

        waitsForFileToOpen ->
          fileView.click()

        runs ->
          atom.commands.dispatch(treeView.element, 'tree-view:remove')
          args = atom.confirm.mostRecentCall.args[0]
          expect(Object.keys(args.buttons)).toEqual ['Move to Trash', 'Cancel']

      it "shows a notification on failure", ->
        atom.notifications.clear()

        spyOn(atom, 'confirm')

        waitsForFileToOpen ->
          fileView.click()

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
            expect(notification.getMessage()).toContain 'The following file couldn\'t be moved to trash'
            expect(notification.getDetail()).toContain 'test-file.txt'

      it "does nothing when no file is selected", ->
        atom.notifications.clear()

        jasmine.attachToDOM(workspaceElement)
        treeView.focus()
        treeView.deselect()
        atom.commands.dispatch(treeView.element, 'tree-view:remove')

        expect(atom.confirm.mostRecentCall).not.toExist
        expect(atom.notifications.getNotifications().length).toBe 0

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
          entriesCountBefore = $(treeView.roots[0].entries).find('.entry').length
          fs.writeFileSync temporaryFilePath, 'hi'

        waitsFor "directory view contents to refresh", ->
          $(treeView.roots[0].entries).find('.entry').length is entriesCountBefore + 1

        runs ->
          expect($(treeView.roots[0].entries).find('.entry').length).toBe entriesCountBefore + 1
          expect($(treeView.roots[0].entries).find('.file:contains(temporary)')).toExist()
          fs.removeSync(temporaryFilePath)

        waitsFor "directory view contents to refresh", ->
          $(treeView.roots[0].entries).find('.entry').length is entriesCountBefore

  describe "project changes", ->
    beforeEach ->
      atom.project.setPaths([path1])
      treeView = $(atom.workspace.getLeftPanels()[0].getItem()).view()
      root1 = $(treeView.roots[0])

    describe "when a root folder is added", ->
      it "maintains expanded folders", ->
        root1.find('.directory:contains(dir1)').click()
        atom.project.setPaths([path1, path2])

        treeView = $(atom.workspace.getLeftPanels()[0].getItem()).view()
        expect(treeView).toExist()
        root1 = $(treeView.roots[0])
        expect(root1.find(".directory:contains(dir1)")).toHaveClass("expanded")

      it "maintains collapsed (root) folders", ->
        root1.click()
        atom.project.setPaths([path1, path2])

        treeView = $(atom.workspace.getLeftPanels()[0].getItem()).view()
        expect(treeView).toExist()
        root1 = $(treeView.roots[0])
        expect(root1).toHaveClass("collapsed")

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
        expect(treeView.find('.file:contains(ignored.txt)').length).toBe 1

        atom.config.set("tree-view.hideVcsIgnoredFiles", true)
        expect(treeView.find('.file:contains(ignored.txt)').length).toBe 0

        atom.config.set("tree-view.hideVcsIgnoredFiles", false)
        expect(treeView.find('.file:contains(ignored.txt)').length).toBe 1

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
        expect(treeView.find('.file:contains(tree-view.js)').length).toBe 1

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
      expect(treeView.find('.directory .name:contains(.git)').length).toBe 1
      expect(treeView.find('.directory .name:contains(test.js)').length).toBe 1
      expect(treeView.find('.directory .name:contains(test.txt)').length).toBe 1

      atom.config.set("tree-view.hideIgnoredNames", true)
      expect(treeView.find('.directory .name:contains(.git)').length).toBe 0
      expect(treeView.find('.directory .name:contains(test.js)').length).toBe 0
      expect(treeView.find('.directory .name:contains(test.txt)').length).toBe 1

      atom.config.set("core.ignoredNames", [])
      expect(treeView.find('.directory .name:contains(.git)').length).toBe 1
      expect(treeView.find('.directory .name:contains(test.js)').length).toBe 1
      expect(treeView.find('.directory .name:contains(test.txt)').length).toBe 1

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

      atom.project.setPaths([rootDirPath])

    it "defaults to disabled", ->
      expect(atom.config.get("tree-view.squashDirectoryNames")).toBeFalsy()

    describe "when enabled", ->
      beforeEach ->
        atom.config.set('tree-view.squashDirectoryNames', true)

      it "does not squash a file in to a DirectoryViews", ->
        zetaDir = $(treeView.roots[0].entries).find('.directory:contains(zeta):first')
        zetaDir[0].expand()
        zetaEntries = [].slice.call(zetaDir[0].children[1].children).map (element) ->
          element.innerText

        expect(zetaEntries).toEqual(["zeta.txt"])

      it "squashes two dir names when the first only contains a single dir", ->
        betaDir = $(treeView.roots[0].entries).find(".directory:contains(alpha#{path.sep}beta):first")
        betaDir[0].expand()
        betaEntries = [].slice.call(betaDir[0].children[1].children).map (element) ->
          element.innerText

        expect(betaEntries).toEqual(["beta.txt"])

      it "squashes three dir names when the first and second only contain single dirs", ->
        epsilonDir = $(treeView.roots[0].entries).find(".directory:contains(gamma#{path.sep}delta#{path.sep}epsilon):first")
        epsilonDir[0].expand()
        epsilonEntries = [].slice.call(epsilonDir[0].children[1].children).map (element) ->
          element.innerText

        expect(epsilonEntries).toEqual(["theta.txt"])

      it "does not squash a dir name when there are two child dirs ", ->
        lambdaDir = $(treeView.roots[0].entries).find('.directory:contains(lambda):first')
        lambdaDir[0].expand()
        lambdaEntries = [].slice.call(lambdaDir[0].children[1].children).map (element) ->
          element.innerText

        expect(lambdaEntries).toEqual(["iota", "kappa"])

      describe "when a directory is reloaded", ->
        it "squashes the directory names the last of which is same as an unsquashed directory", ->
          muDir = $(treeView.roots[0].entries).find('.directory:contains(mu):first')
          muDir[0].expand()
          muEntries = Array.from(muDir[0].children[1].children).map (element) -> element.innerText
          expect(muEntries).toEqual(["nu#{path.sep}xi", "xi"])

          muDir[0].expand()
          muDir[0].reload()
          muEntries = Array.from(muDir[0].children[1].children).map (element) -> element.innerText
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
      $(treeView.roots[0].entries).find('.directory:contains(dir)')[0].expand()

    describe "when the project is the repository root", ->
      it "adds a custom style", ->
        expect(treeView.find('.icon-repo').length).toBe 1

    describe "when a file is modified", ->
      it "adds a custom style", ->
        $(treeView.roots[0].entries).find('.directory:contains(dir)')[0].expand()
        expect(treeView.find('.file:contains(b.txt)')).toHaveClass 'status-modified'

    describe "when a directory if modified", ->
      it "adds a custom style", ->
        expect(treeView.find('.directory:contains(dir)')).toHaveClass 'status-modified'

    describe "when a file is new", ->
      it "adds a custom style", ->
        $(treeView.roots[0].entries).find('.directory:contains(dir2)')[0].expand()
        expect(treeView.find('.file:contains(new2)')).toHaveClass 'status-added'

    describe "when a directory is new", ->
      it "adds a custom style", ->
        expect(treeView.find('.directory:contains(dir2)')).toHaveClass 'status-added'

    describe "when a file is ignored", ->
      it "adds a custom style", ->
        expect(treeView.find('.file:contains(ignored.txt)')).toHaveClass 'status-ignored'

    describe "when a file is selected in a directory", ->
      beforeEach ->
        jasmine.attachToDOM(workspaceElement)
        treeView.focus()
        element.expand() for element in treeView.find('.directory')
        fileView = treeView.find('.file:contains(new2)')
        expect(fileView).not.toBeNull()
        fileView.click()

      describe "when the file is deleted", ->
        it "updates the style of the directory", ->
          expect(treeView.selectedEntry().getPath()).toContain(path.join('dir2', 'new2'))
          dirView = $(treeView.roots[0].entries).find('.directory:contains(dir2)')
          expect(dirView).not.toBeNull()
          spyOn(dirView[0].directory, 'updateStatus')
          spyOn(atom, 'confirm').andCallFake (dialog) ->
            dialog.buttons["Move to Trash"]()
          atom.commands.dispatch(treeView.element, 'tree-view:remove')
          expect(dirView[0].directory.updateStatus).toHaveBeenCalled()

    describe "when the project is a symbolic link to the repository root", ->
      beforeEach ->
        symlinkPath = temp.path('tree-view-project')
        fs.symlinkSync(projectPath, symlinkPath)
        atom.project.setPaths([symlinkPath])
        $(treeView.roots[0].entries).find('.directory:contains(dir)')[0].expand()

        waitsFor (done) ->
          disposable = atom.project.getRepositories()[0].onDidChangeStatuses ->
            disposable.dispose()
            done()

      describe "when a file is modified", ->
        it "updates its and its parent directories' styles", ->
          expect(treeView.find('.file:contains(b.txt)')).toHaveClass 'status-modified'
          expect(treeView.find('.directory:contains(dir)')).toHaveClass 'status-modified'

      describe "when a file loses its modified status", ->
        it "updates its and its parent directories' styles", ->
          fs.writeFileSync(modifiedFile, originalFileContent)
          atom.project.getRepositories()[0].getPathStatus(modifiedFile)

          expect(treeView.find('.file:contains(b.txt)')).not.toHaveClass 'status-modified'
          expect(treeView.find('.directory:contains(dir)')).not.toHaveClass 'status-modified'

  describe "when the resize handle is double clicked", ->
    beforeEach ->
      treeView.width(10).find('.list-tree').width 100

    it "sets the width of the tree to be the width of the list", ->
      expect(treeView.width()).toBe 10
      treeView.find('.tree-view-resize-handle').trigger 'dblclick'
      expect(treeView.width()).toBeGreaterThan 10

      treeView.width(1000)
      treeView.find('.tree-view-resize-handle').trigger 'dblclick'
      expect(treeView.width()).toBeLessThan 1000

  describe "when other panels are added", ->
    beforeEach ->
      jasmine.attachToDOM(workspaceElement)

    it "should resize normally", ->
      expect(treeView).toBeVisible()
      expect(atom.workspace.getLeftPanels().length).toBe(1)

      treeView.width(100)

      expect(treeView.width()).toBe(100)

      panel = document.createElement('div')
      panel.style.width = '100px'
      atom.workspace.addLeftPanel({item: panel, priority: 10})

      expect(atom.workspace.getLeftPanels().length).toBe(2)
      expect(treeView.width()).toBe(100)

      treeView.resizeTreeView({pageX: 250, which: 1})

      expect(treeView.width()).toBe(150)

    it "should resize normally on the right side", ->
      atom.commands.dispatch(workspaceElement, 'tree-view:toggle-side')
      expect(treeView).toMatchSelector('[data-show-on-right-side="true"]')

      expect(treeView).toBeVisible()
      expect(atom.workspace.getRightPanels().length).toBe(1)

      treeView.width(100)

      expect(treeView.width()).toBe(100)

      panel = document.createElement('div')
      panel.style.width = '100px'
      atom.workspace.addRightPanel({item: panel, priority: 10})

      expect(atom.workspace.getRightPanels().length).toBe(2)
      expect(treeView.width()).toBe(100)

      treeView.resizeTreeView({pageX: $(document.body).width() - 250, which: 1})

      expect(treeView.width()).toBe(150)

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

      dirView = $(treeView.roots[0].entries).find('.directory:contains(test-dir)')
      dirView[0].expand()
      fileView1 = treeView.find('.file:contains(test-file1.txt)')
      fileView2 = treeView.find('.file:contains(test-file2.txt)')
      fileView3 = treeView.find('.file:contains(test-file3.txt)')

    describe 'selecting multiple items', ->
      it 'switches the contextual menu to muli-select mode', ->
        fileView1.click()
        fileView2.trigger($.Event('mousedown', {shiftKey: true}))
        expect(treeView.find('.tree-view')).toHaveClass('multi-select')
        fileView3.trigger($.Event('mousedown'))
        expect(treeView.find('.tree-view')).toHaveClass('full-menu')

    describe 'selecting multiple items', ->
      it 'switches the contextual menu to muli-select mode', ->
        fileView1.click()
        fileView2.trigger($.Event('mousedown', {shiftKey: true}))
        expect(treeView.find('.tree-view')).toHaveClass('multi-select')

      describe 'using the shift key', ->
        it 'selects the items between the already selected item and the shift clicked item', ->
          fileView1.click()
          fileView3.trigger($.Event('mousedown', {shiftKey: true}))
          expect(fileView1).toHaveClass('selected')
          expect(fileView2).toHaveClass('selected')
          expect(fileView3).toHaveClass('selected')

      describe 'using the metakey(cmd) key', ->
        it 'selects the cmd clicked item in addition to the original selected item', ->
          fileView1.click()
          fileView3.trigger($.Event('mousedown', {metaKey: true}))
          expect(fileView1).toHaveClass('selected')
          expect(fileView3).toHaveClass('selected')
          expect(fileView2).not.toHaveClass('selected')

      describe 'non-darwin platform', ->
        originalPlatform = process.platform

        beforeEach ->
          # Stub platform.process so we can test non-darwin behavior
          Object.defineProperty(process, "platform", {__proto__: null, value: 'win32'})

        afterEach ->
          # Ensure that process.platform is set back to it's original value
          Object.defineProperty(process, "platform", {__proto__: null, value: originalPlatform})

        describe 'using the ctrl key', ->
          it 'selects the ctrl clicked item in addition to the original selected item', ->
            fileView1.click()
            fileView3.trigger($.Event('mousedown', {ctrlKey: true}))
            expect(fileView1).toHaveClass('selected')
            expect(fileView3).toHaveClass('selected')
            expect(fileView2).not.toHaveClass('selected')

      describe 'darwin platform', ->
        originalPlatform = process.platform

        beforeEach ->
          # Stub platform.process so we can test non-darwin behavior
          Object.defineProperty(process, "platform", {__proto__: null, value: 'darwin'})

        afterEach ->
          # Ensure that process.platform is set back to it's original value
          Object.defineProperty(process, "platform", {__proto__: null, value: originalPlatform})

        describe 'using the ctrl key', ->
          describe "previous item is selected but the ctrl clicked item is not", ->
            it 'selects the clicked item, but deselects the previous item', ->
              fileView1.click()
              fileView3.trigger($.Event('mousedown', {ctrlKey: true}))
              expect(fileView1).not.toHaveClass('selected')
              expect(fileView3).toHaveClass('selected')
              expect(fileView2).not.toHaveClass('selected')

            it 'displays the full contextual menu', ->
              fileView1.click()
              fileView3.trigger($.Event('mousedown', {ctrlKey: true}))
              expect(treeView.list).toHaveClass('full-menu')
              expect(treeView.list).not.toHaveClass('multi-select')

          describe 'previous item is selected including the ctrl clicked', ->
            it 'displays the multi-select menu', ->
              fileView1.click()
              fileView3.trigger($.Event('mousedown', {metaKey: true}))
              fileView3.trigger($.Event('mousedown', {ctrlKey: true}))
              expect(treeView.list).not.toHaveClass('full-menu')
              expect(treeView.list).toHaveClass('multi-select')

            it 'does not deselect any of the items', ->
              fileView1.click()
              fileView3.trigger($.Event('mousedown', {metaKey: true}))
              fileView3.trigger($.Event('mousedown', {ctrlKey: true}))
              expect(fileView1).toHaveClass('selected')
              expect(fileView3).toHaveClass('selected')

          describe 'when clicked item is the only item selected', ->
            it 'displays the full contextual menu', ->
              fileView1.click()
              fileView3.trigger($.Event('mousedown', {ctrlKey: true}))
              expect(treeView.list).toHaveClass('full-menu')
              expect(treeView.list).not.toHaveClass('multi-select')

          describe 'when no item is selected', ->
            it 'selects the ctrl clicked item', ->
              fileView3.trigger($.Event('mousedown', {ctrlKey: true}))
              expect(fileView3).toHaveClass('selected')

            it 'displays the full context menu', ->
              fileView3.trigger($.Event('mousedown', {ctrlKey: true}))
              expect(treeView.list).toHaveClass('full-menu')
              expect(treeView.list).not.toHaveClass('multi-select')

        describe "right-clicking", ->
          describe 'when multiple items are selected', ->
            it 'displays the multi-select context menu', ->
              fileView1.click()
              fileView3.trigger($.Event('mousedown', {metaKey: true}))
              fileView3.trigger($.Event('mousedown', {button: 2}))
              expect(fileView1).toHaveClass('selected')
              expect(fileView3).toHaveClass('selected')
              expect(treeView.list).not.toHaveClass('full-menu')
              expect(treeView.list).toHaveClass('multi-select')

          describe 'when a single item is selected', ->
            it 'displays the full context menu', ->
              fileView1.click()
              fileView3.trigger($.Event('mousedown', {button: 2}))
              expect(treeView.list).toHaveClass('full-menu')
              expect(treeView.list).not.toHaveClass('multi-select')

            it 'selects right clicked item', ->
              fileView1.click()
              fileView3.trigger($.Event('mousedown', {button: 2}))
              expect(fileView3).toHaveClass('selected')

            it 'de-selects the previously selected item', ->
              fileView1.click()
              fileView3.trigger($.Event('mousedown', {button: 2}))
              expect(fileView1).not.toHaveClass('selected')

          describe 'when no item is selected', ->
            it 'selects the right clicked item', ->
              fileView3.trigger($.Event('mousedown', {button: 2}))
              expect(fileView3).toHaveClass('selected')

            it 'shows the full context menu', ->
              fileView3.trigger($.Event('mousedown', {button: 2}))
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

      alphaDir = $(treeView.roots[0].entries).find('.directory:contains(alpha):first')
      alphaDir[0].expand()
      alphaEntries = [].slice.call(alphaDir[0].children[1].children).map (element) ->
        element.innerText

      expect(alphaEntries).toEqual(["eta", "beta.txt"])

      gammaDir = $(treeView.roots[0].entries).find('.directory:contains(gamma):first')
      gammaDir[0].expand()
      gammaEntries = [].slice.call(gammaDir[0].children[1].children).map (element) ->
        element.innerText

      expect(gammaEntries).toEqual(["theta", "delta.txt", "epsilon.txt"])

    it "sorts folders as files if the option is not set", ->
      atom.config.set "tree-view.sortFoldersBeforeFiles", false

      topLevelEntries = [].slice.call(treeView.roots[0].entries.children).map (element) ->
        element.innerText

      expect(topLevelEntries).toEqual(["alpha", "alpha.txt", "gamma", "zeta.txt"])

      alphaDir = $(treeView.roots[0].entries).find('.directory:contains(alpha):first')
      alphaDir[0].expand()
      alphaEntries = [].slice.call(alphaDir[0].children[1].children).map (element) ->
        element.innerText

      expect(alphaEntries).toEqual(["beta.txt", "eta"])

      gammaDir = $(treeView.roots[0].entries).find('.directory:contains(gamma):first')
      gammaDir[0].expand()
      gammaEntries = [].slice.call(gammaDir[0].children[1].children).map (element) ->
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
        command: '/this/command/does/not/exist'
        label: 'Finder'
        args: ['foo']

      treeView.showSelectedEntryInFileManager()

      waitsFor ->
        atom.notifications.getNotifications().length is 1

      runs ->
        expect(atom.notifications.getNotifications()[0].getMessage()).toContain 'Opening folder in Finder failed'
        expect(atom.notifications.getNotifications()[0].getDetail()).toContain 'ENOENT'

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

    describe "when dragging a FileView onto a DirectoryView's header", ->
      it "should add the selected class to the DirectoryView", ->
        # Dragging theta onto alphaDir
        alphaDir = $(treeView.roots[0].entries).find('.directory:contains(alpha):first')

        gammaDir = $(treeView.roots[0].entries).find('.directory:contains(gamma):first')
        gammaDir[0].expand()
        deltaFile = gammaDir[0].entries.children[2]

        [dragStartEvent, dragEnterEvent, dropEvent] =
            eventHelpers.buildInternalDragEvents(deltaFile, alphaDir.find('.header')[0])
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
        alphaDir = $(treeView.roots[0].entries).find('.directory:contains(alpha):first')
        alphaDir[0].expand()

        gammaDir = $(treeView.roots[0].entries).find('.directory:contains(gamma):first')
        gammaDir[0].expand()
        deltaFile = gammaDir[0].entries.children[2]

        [dragStartEvent, dragEnterEvent, dropEvent] =
            eventHelpers.buildInternalDragEvents(deltaFile, alphaDir.find('.header')[0], alphaDir[0])

        runs ->
          treeView.onDragStart(dragStartEvent)
          treeView.onDrop(dropEvent)
          expect(alphaDir[0].children.length).toBe 2

        waitsFor "directory view contents to refresh", ->
          $(treeView.roots[0].entries).find('.directory:contains(alpha):first .entry').length > 2

        runs ->
          expect($(treeView.roots[0].entries).find('.directory:contains(alpha):first .entry').length).toBe 3

    describe "when dropping a DirectoryView onto a DirectoryView's header", ->
      it "should move the directory to the hovered directory", ->
        # Dragging thetaDir onto alphaDir
        alphaDir = $(treeView.roots[0].entries).find('.directory:contains(alpha):first')
        alphaDir[0].expand()

        gammaDir = $(treeView.roots[0].entries).find('.directory:contains(gamma):first')
        gammaDir[0].expand()
        thetaDir = gammaDir[0].entries.children[0]

        [dragStartEvent, dragEnterEvent, dropEvent] =
            eventHelpers.buildInternalDragEvents(thetaDir, alphaDir.find('.header')[0], alphaDir[0])

        runs ->
          treeView.onDragStart(dragStartEvent)
          treeView.onDrop(dropEvent)
          expect(alphaDir[0].children.length).toBe 2

        waitsFor "directory view contents to refresh", ->
          $(treeView.roots[0].entries).find('.directory:contains(alpha):first .entry').length > 2

        runs ->
          expect($(treeView.roots[0].entries).find('.directory:contains(alpha):first .entry').length).toBe 3

    describe "when dragging a file from the OS onto a DirectoryView's header", ->
      it "should move the file to the hovered directory", ->
        # Dragging delta.txt from OS file explorer onto alphaDir
        alphaDir = $(treeView.roots[0].entries).find('.directory:contains(alpha):first')
        alphaDir[0].expand()

        dropEvent = eventHelpers.buildExternalDropEvent([deltaFilePath], alphaDir[0])

        runs ->
          treeView.onDrop(dropEvent)
          expect(alphaDir[0].children.length).toBe 2

        waitsFor "directory view contents to refresh", ->
          $(treeView.roots[0].entries).find('.directory:contains(alpha):first .entry').length > 2

        runs ->
          expect($(treeView.roots[0].entries).find('.directory:contains(alpha):first .entry').length).toBe 3

    describe "when dragging a directory from the OS onto a DirectoryView's header", ->
      it "should move the directory to the hovered directory", ->
        # Dragging gammaDir from OS file explorer onto alphaDir
        alphaDir = $(treeView.roots[0].entries).find('.directory:contains(alpha):first')
        alphaDir[0].expand()

        dropEvent = eventHelpers.buildExternalDropEvent([gammaDirPath], alphaDir[0])

        runs ->
          treeView.onDrop(dropEvent)
          expect(alphaDir[0].children.length).toBe 2

        waitsFor "directory view contents to refresh", ->
          $(treeView.roots[0].entries).find('.directory:contains(alpha):first .entry').length > 2

        runs ->
          expect($(treeView.roots[0].entries).find('.directory:contains(alpha):first .entry').length).toBe 3

    describe "when dragging a file and directory from the OS onto a DirectoryView's header", ->
      it "should move the file and directory to the hovered directory", ->
        # Dragging delta.txt and gammaDir from OS file explorer onto alphaDir
        alphaDir = $(treeView.roots[0].entries).find('.directory:contains(alpha):first')
        alphaDir[0].expand()

        dropEvent = eventHelpers.buildExternalDropEvent([deltaFilePath, gammaDirPath], alphaDir[0])

        runs ->
          treeView.onDrop(dropEvent)
          expect(alphaDir[0].children.length).toBe 2

        waitsFor "directory view contents to refresh", ->
          $(treeView.roots[0].entries).find('.directory:contains(alpha):first .entry').length > 3

        runs ->
          expect($(treeView.roots[0].entries).find('.directory:contains(alpha):first .entry').length).toBe 4

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
          sampleJs.trigger clickEvent(originalEvent: {detail: 1})

        runs ->
          expect(sampleJs).toHaveClass 'selected'
          expect(atom.workspace.getActivePaneItem().getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.js')
          expect(treeView.list).toHaveFocus()

        waitsForFileToOpen ->
          sampleTxt.trigger clickEvent(originalEvent: {detail: 1})

        runs ->
          expect(sampleTxt).toHaveClass 'selected'
          expect(treeView.find('.selected').length).toBe 1
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
        expect(atom.workspace.getPanes().length).toBe 2

      describe "tree-view:open-selected-entry", ->
        beforeEach ->
          atom.config.set "tree-view.alwaysOpenExisting", true
        describe "when the first pane is focused, a file is opened that is already open in the second pane", ->
          beforeEach ->
            firstPane = atom.workspace.getPanes()[0]
            firstPane.activate()
            selectEntry 'tree-view.txt'
            waitsForFileToOpen ->
              atom.commands.dispatch treeView.element, "tree-view:open-selected-entry"

          it "opens the file in the second pane and focuses it", ->
            pane = atom.workspace.getPanes()[1]
            item = atom.workspace.getActivePaneItem()
            expect(atom.views.getView(pane)).toHaveFocus()
            expect(item.getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.txt')

      describe "tree-view:open-selected-entry (alwaysOpenExisting off)", ->
        beforeEach ->
          atom.config.set "tree-view.alwaysOpenExisting", false


        describe "when the first pane is focused, a file is opened that is already open in the second pane", ->
          firstPane = null
          beforeEach ->
            firstPane = atom.workspace.getPanes()[0]
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
            firstPane = atom.workspace.getPanes()[0]
            firstPane.activate()

            treeView.focus()

            waitsForFileToOpen ->
              sampleTxt.trigger clickEvent(originalEvent: {detail: 1})

            runs ->
              activePaneItem = atom.workspace.getActivePaneItem()

          it "selects the file and retains focus on tree-view", ->
            expect(sampleTxt).toHaveClass 'selected'
            expect(treeView).toHaveFocus()

          it "doesn't open the file in the active pane", ->
            expect(atom.views.getView(treeView)).toHaveFocus()
            expect(activePaneItem.getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.js')

      describe "when a file is double-clicked", ->
        beforeEach ->
          atom.config.set "tree-view.alwaysOpenExisting", true
        activePaneItem = null

        beforeEach ->
          firstPane = atom.workspace.getPanes()[0]
          firstPane.activate()

          treeView.focus()

          waitsForFileToOpen ->
            sampleTxt.trigger clickEvent(originalEvent: {detail: 1})
            sampleTxt.trigger clickEvent(originalEvent: {detail: 2})

          waits 100

          runs ->
            activePaneItem = atom.workspace.getActivePaneItem()

        it "opens the file and focuses it", ->

          expect(activePaneItem.getPath()).toBe atom.project.getDirectories()[0].resolve('tree-view.txt')
          expect(atom.views.getView(atom.workspace.getPanes()[1])).toHaveFocus()


describe 'Icon class handling', ->
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
      iconClassForPath: (path, context) ->
        expect(context).toBe "tree-view"
        [name, id] = path.match(/file-(\d+)\.txt$/)
        switch id
          when "1" then 'first second'
          when "2" then ['first', 'second']
          else "some-other-file"

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
