_ = require 'underscore-plus'
{$, $$, WorkspaceView} = require 'atom'
fs = require 'fs-plus'
TreeView = require '../lib/tree-view'
path = require 'path'
temp = require 'temp'
wrench = require 'wrench'
os = require 'os'

waitsForFileToOpen = (fn) ->
  openHandler = jasmine.createSpy()
  runs ->
    atom.workspaceView.one "uri-opened", openHandler
    fn()

  waitsFor ->
    openHandler.callCount == 1

describe "TreeView", ->
  [treeView, sampleJs, sampleTxt] = []

  beforeEach ->
    tempPath = fs.realpathSync(temp.mkdirSync('atom'))
    fixturesPath = atom.project.getPath()
    wrench.copyDirSyncRecursive(fixturesPath, tempPath, forceDelete: true)
    atom.project.setPath(path.join(tempPath, 'tree-view'))

    atom.workspaceView = new WorkspaceView

    waitsForPromise ->
      atom.packages.activatePackage("tree-view")

    runs ->
      atom.workspaceView.trigger 'tree-view:toggle'
      treeView = atom.workspaceView.find(".tree-view").view()
      treeView.root = treeView.find('ol > li:first').view()
      sampleJs = treeView.find('.file:contains(tree-view.js)')
      sampleTxt = treeView.find('.file:contains(tree-view.txt)')

      expect(treeView.root.directory.getSubscriptionCount()).toBeGreaterThan 0

  describe ".initialize(project)", ->
    it "renders the root of the project and its contents alphabetically with subdirectories first in a collapsed state", ->
      expect(treeView.root.find('> .header .disclosure-arrow')).not.toHaveClass('expanded')
      expect(treeView.root.find('> .header .name')).toHaveText('tree-view')

      rootEntries = treeView.root.find('.entries')
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

    it "selects the rootview", ->
      expect(treeView.selectedEntry()).toEqual treeView.root

    describe "when the project has no path", ->
      beforeEach ->
        atom.project.setPath(undefined)
        atom.packages.deactivatePackage("tree-view")

        waitsForPromise ->
          atom.packages.activatePackage("tree-view")

        runs ->
          treeView = atom.packages.getActivePackage("tree-view").mainModule.createView()

      it "does not attach to the root view or create a root node when initialized", ->
        expect(treeView.hasParent()).toBeFalsy()
        expect(treeView.root).not.toExist()

      it "does not attach to the root view or create a root node when attach() is called", ->
        treeView.attach()
        expect(treeView.hasParent()).toBeFalsy()
        expect(treeView.root).not.toExist()

      it "serializes without throwing an exception", ->
        expect(-> treeView.serialize()).not.toThrow()

      it "does not throw an exception when files are opened", ->
        filePath = path.join(os.tmpdir(), 'non-project-file.txt')
        fs.writeFileSync(filePath, 'test')

        expect(-> atom.workspaceView.openSync(filePath)).not.toThrow()

      it "does not reveal the active file", ->
        filePath = path.join(os.tmpdir(), 'non-project-file.txt')
        fs.writeFileSync(filePath, 'test')
        atom.workspaceView.openSync(filePath)

        atom.workspaceView.trigger 'tree-view:reveal-active-file'
        expect(treeView.hasParent()).toBeFalsy()
        expect(treeView.root).not.toExist()

      describe "when the project is assigned a path because a new buffer is saved", ->
        it "creates a root directory view but does not attach to the root view", ->
          atom.workspaceView.openSync()
          projectPath = temp.mkdirSync('atom-project')
          atom.workspace.getActivePaneItem().saveAs(path.join(projectPath, 'test.txt'))
          expect(treeView.hasParent()).toBeFalsy()
          expect(fs.absolute(treeView.root.getPath())).toBe fs.absolute(projectPath)
          expect(treeView.root.parent()).toMatchSelector(".tree-view")

    describe "when the root view is opened to a file path", ->
      it "does not attach to the root view but does create a root node when initialized", ->
        atom.packages.deactivatePackage("tree-view")
        atom.packages.packageStates = {}
        atom.workspaceView.openSync('tree-view.js')

        waitsForPromise ->
          atom.packages.activatePackage('tree-view')

        runs ->
          treeView = atom.packages.getActivePackage("tree-view").mainModule.createView()
          expect(treeView.hasParent()).toBeFalsy()
          expect(treeView.root).toExist()

    describe "when the root view is opened to a directory", ->
      it "attaches to the root view", ->
        waitsForPromise ->
          atom.packages.activatePackage('tree-view')

        runs ->
          treeView = atom.packages.getActivePackage("tree-view").mainModule.createView()
          expect(treeView.hasParent()).toBeTruthy()
          expect(treeView.root).toExist()

    describe "when the project is a .git folder", ->
      it "does not create the tree view", ->
        dotGit = path.join(temp.mkdirSync('repo'), '.git')
        fs.makeTreeSync(dotGit)
        atom.project.setPath(dotGit)
        atom.packages.deactivatePackage("tree-view")
        atom.packages.packageStates = {}

        waitsForPromise ->
          atom.packages.activatePackage('tree-view')

        runs ->
          {treeView} = atom.packages.getActivePackage("tree-view").mainModule
          expect(treeView).toBeFalsy()

  describe "serialization", ->
    it "restores expanded directories and selected file when deserialized", ->
      treeView.root.find('.directory:contains(dir1)').view().click()

      waitsForFileToOpen ->
        sampleJs.click()

      runs ->
        atom.packages.deactivatePackage("tree-view")

      waitsForPromise ->
          atom.packages.activatePackage("tree-view")

      runs ->
          treeView = atom.workspaceView.find(".tree-view").view()
          expect(treeView).toExist()
          expect(treeView.selectedEntry()).toMatchSelector(".file:contains(tree-view.js)")
          expect(treeView.find(".directory:contains(dir1)")).toHaveClass("expanded")

    it "restores the focus state of the tree view", ->
      atom.workspaceView.attachToDom()
      treeView.focus()
      expect(treeView.list).toMatchSelector ':focus'
      atom.packages.deactivatePackage("tree-view")

      waitsForPromise ->
        atom.packages.activatePackage("tree-view")

      runs ->
        treeView = atom.workspaceView.find(".tree-view").view()
        expect(treeView.list).toMatchSelector ':focus'

    it "restores the scroll top when toggled", ->
      atom.workspaceView.height(5)
      atom.workspaceView.attachToDom()
      expect(treeView).toBeVisible()
      treeView.focus()

      treeView.scrollTop(10)
      expect(treeView.scrollTop()).toBe(10)

      runs -> atom.workspaceView.trigger 'tree-view:toggle'
      waitsFor -> treeView.is(':hidden')

      runs -> atom.workspaceView.trigger 'tree-view:toggle'
      waitsFor -> treeView.is(':visible')

      runs -> expect(treeView.scrollTop()).toBe(10)

    it "restores the scroll left when toggled", ->
      atom.workspaceView.width(5)
      atom.workspaceView.attachToDom()
      expect(treeView).toBeVisible()
      treeView.focus()

      treeView.scroller.scrollLeft(5)
      expect(treeView.scroller.scrollLeft()).toBe(5)

      runs -> atom.workspaceView.trigger 'tree-view:toggle'
      waitsFor -> treeView.is(':hidden')

      runs -> atom.workspaceView.trigger 'tree-view:toggle'
      waitsFor -> treeView.is(':visible')

      runs -> expect(treeView.scroller.scrollLeft()).toBe(5)

  describe "when tree-view:toggle is triggered on the root view", ->
    beforeEach ->
      atom.workspaceView.attachToDom()

    describe "when the tree view is visible", ->
      beforeEach ->
        expect(treeView).toBeVisible()

      describe "when the tree view is focused", ->
        it "hides the tree view", ->
          treeView.focus()
          atom.workspaceView.trigger 'tree-view:toggle'
          expect(treeView).toBeHidden()

      describe "when the tree view is not focused", ->
        it "hides the tree view", ->
          treeView.focus()
          atom.workspaceView.trigger 'tree-view:toggle'
          expect(treeView).toBeHidden()

    describe "when the tree view is hidden", ->
      it "shows and focuses the tree view", ->
        treeView.detach()
        atom.workspaceView.trigger 'tree-view:toggle'
        expect(treeView.hasParent()).toBeTruthy()
        expect(treeView.list).toMatchSelector(':focus')

    describe "when tree-view:toggle-side is triggered on the root view", ->
      beforeEach ->
        atom.workspaceView.attachToDom()

      describe "when the tree view is on the left", ->
        it "should be moved to the right", ->
          expect(treeView).toBeVisible()
          atom.workspaceView.trigger 'tree-view:toggle-side'
          expect(treeView).toMatchSelector('[data-show-on-right-side="true"]')
      describe "when the tree view is on the right", ->
        beforeEach ->
          atom.workspaceView.trigger 'tree-view:toggle-side'

        it "should be moved to the left", ->
          expect(treeView).toBeVisible()
          atom.workspaceView.trigger 'tree-view:toggle-side'
          expect(treeView).toMatchSelector('[data-show-on-right-side="false"]')

  describe "when tree-view:toggle-focus is triggered on the root view", ->
    beforeEach ->
      atom.workspaceView.attachToDom()

    describe "when the tree view is hidden", ->
      it "shows and focuses the tree view", ->
        treeView.detach()
        atom.workspaceView.trigger 'tree-view:toggle-focus'
        expect(treeView.hasParent()).toBeTruthy()
        expect(treeView.list).toMatchSelector(':focus')

    describe "when the tree view is shown", ->
      it "focuses the tree view", ->
        atom.workspaceView.openSync() # When we call focus below, we want an editor to become focused
        atom.workspaceView.focus()
        expect(treeView).toBeVisible()
        atom.workspaceView.trigger 'tree-view:toggle-focus'
        expect(treeView).toBeVisible()
        expect(treeView.list).toMatchSelector(':focus')

      describe "when the tree view is focused", ->
        it "unfocuses the tree view", ->
          atom.workspaceView.openSync() # When we call focus below, we want an editor to become focused
          treeView.focus()
          expect(treeView).toBeVisible()
          atom.workspaceView.trigger 'tree-view:toggle-focus'
          expect(treeView).toBeVisible()
          expect(treeView.list).not.toMatchSelector(':focus')

  describe "when tree-view:reveal-current-file is triggered on the root view", ->
    beforeEach ->
      treeView.detach()
      spyOn(treeView, 'focus')

    describe "if the current file has a path", ->
      it "shows and focuses the tree view and selects the file", ->
        atom.workspaceView.openSync(path.join('dir1', 'file1'))
        atom.workspaceView.trigger 'tree-view:reveal-active-file'
        expect(treeView.hasParent()).toBeTruthy()
        expect(treeView.focus).toHaveBeenCalled()
        expect(treeView.selectedEntry().getPath()).toMatch new RegExp("dir1#{_.escapeRegExp(path.sep)}file1$")

    describe "if the current file has no path", ->
      it "shows and focuses the tree view, but does not attempt to select a specific file", ->
        atom.workspaceView.openSync()
        expect(atom.workspace.getActivePaneItem().getPath()).toBeUndefined()
        atom.workspaceView.trigger 'tree-view:reveal-active-file'
        expect(treeView.hasParent()).toBeTruthy()
        expect(treeView.focus).toHaveBeenCalled()

    describe "if there is no editor open", ->
      it "shows and focuses the tree view, but does not attempt to select a specific file", ->
        expect(atom.workspace.getActivePaneItem()).toBeUndefined()
        atom.workspaceView.trigger 'tree-view:reveal-active-file'
        expect(treeView.hasParent()).toBeTruthy()
        expect(treeView.focus).toHaveBeenCalled()

  describe "when tool-panel:unfocus is triggered on the tree view", ->
    it "surrenders focus to the root view but remains open", ->
      atom.workspaceView.openSync() # When we trigger 'tool-panel:unfocus' below, we want an editor to become focused
      atom.workspaceView.attachToDom()
      treeView.focus()
      expect(treeView.list).toMatchSelector(':focus')
      treeView.trigger 'tool-panel:unfocus'
      expect(treeView).toBeVisible()
      expect(treeView.list).not.toMatchSelector(':focus')
      expect(atom.workspaceView.getActiveView().isFocused).toBeTruthy()

  describe "copy path commands", ->
    [pathToSelect, relativizedPath] = []

    beforeEach ->
      pathToSelect = path.join(treeView.root.directory.path, 'dir1', 'file1')
      relativizedPath = atom.project.relativize(pathToSelect)
      spyOn(atom.clipboard, 'write')

    describe "when tree-view:copy-full-path is triggered on the tree view", ->
      it "copies the selected path to the clipboard", ->
        treeView.selectedPath = pathToSelect
        treeView.trigger 'tree-view:copy-full-path'
        expect(atom.clipboard.write).toHaveBeenCalledWith(pathToSelect)

      describe "when there is no selected path", ->
        beforeEach ->
          treeView.selectedPath = null

        it "does nothing", ->
          treeView.trigger 'tree-view:copy-full-path'
          expect(atom.clipboard.write).not.toHaveBeenCalled()

    describe "when tree-view:copy-project-path is triggered on the tree view", ->
      it "copies the relativized selected path to the clipboard", ->
        treeView.selectedPath = pathToSelect
        treeView.trigger 'tree-view:copy-project-path'
        expect(atom.clipboard.write).toHaveBeenCalledWith(relativizedPath)

      describe "when there is no selected path", ->
        beforeEach ->
          treeView.selectedPath = null

        it "does nothing", ->
          treeView.trigger 'tree-view:copy-project-path'
          expect(atom.clipboard.write).not.toHaveBeenCalled()

  describe "when a directory's disclosure arrow is clicked", ->
    it "expands / collapses the associated directory", ->
      subdir = treeView.root.find('.entries > li:contains(dir1)').view()

      expect(subdir).not.toHaveClass('expanded')

      subdir.click()

      expect(subdir).toHaveClass('expanded')

      subdir.click()
      expect(subdir).not.toHaveClass('expanded')

    it "restores the expansion state of descendant directories", ->
      child = treeView.root.find('.entries > li:contains(dir1)').view()
      child.click()

      grandchild = child.find('.entries > li:contains(sub-dir1)').view()
      grandchild.click()

      treeView.root.click()
      expect(treeView.root).not.toHaveClass('expanded')
      treeView.root.click()

      # previously expanded descendants remain expanded
      expect(treeView.root.find('> .entries > li:contains(dir1) > .entries > li:contains(sub-dir1) > .entries').length).toBe 1

      # collapsed descendants remain collapsed
      expect(treeView.root.find('> .entries > li:contains(dir2) > .entries')).not.toHaveClass('expanded')

    it "when collapsing a directory, removes change subscriptions from the collapsed directory and its descendants", ->
      child = treeView.root.entries.find('li:contains(dir1)').view()
      child.click()

      grandchild = child.entries.find('li:contains(sub-dir1)').view()
      grandchild.click()

      expect(treeView.root.directory.directory.getSubscriptionCount('contents-changed')).toBe 1
      expect(child.directory.directory.getSubscriptionCount('contents-changed')).toBe 1
      expect(grandchild.directory.directory.getSubscriptionCount('contents-changed')).toBe 1

      treeView.root.click()

      expect(treeView.root.directory.directory.getSubscriptionCount('contents-changed')).toBe 0
      expect(child.directory.directory.getSubscriptionCount('contents-changed')).toBe 0
      expect(grandchild.directory.directory.getSubscriptionCount('contents-changed')).toBe 0

  describe "when mouse down fires on a file or directory", ->
    it "selects the entry", ->
      dir = treeView.root.entries.find('li:contains(dir1)').view()
      expect(dir).not.toHaveClass 'selected'
      dir.mousedown()
      expect(dir).toHaveClass 'selected'

      expect(sampleJs).not.toHaveClass 'selected'
      sampleJs.mousedown()
      expect(sampleJs).toHaveClass 'selected'

  describe "when a file is single-clicked", ->
    it "selects the files and opens it in the active editor, without changing focus", ->
      expect(atom.workspaceView.getActiveView()).toBeUndefined()

      waitsForFileToOpen ->
        sampleJs.trigger clickEvent(originalEvent: { detail: 1 })

      runs ->
        expect(sampleJs).toHaveClass 'selected'
        expect(atom.workspace.getActivePaneItem().getPath()).toBe atom.project.resolve('tree-view.js')
        expect(atom.workspaceView.getActiveView().isFocused).toBeFalsy()

      waitsForFileToOpen ->
        sampleTxt.trigger clickEvent(originalEvent: { detail: 1 })

      runs ->
        expect(sampleTxt).toHaveClass 'selected'
        expect(treeView.find('.selected').length).toBe 1
        expect(atom.workspace.getActivePaneItem().getPath()).toBe atom.project.resolve('tree-view.txt')
        expect(atom.workspaceView.getActiveView().isFocused).toBeFalsy()

  describe "when a file is double-clicked", ->
    beforeEach ->
      atom.workspaceView.attachToDom()

    it "selects the file and opens it in the active editor on the first click, then changes focus to the active editor on the second", ->
      runs -> treeView.focus()

      waitsForFileToOpen ->
        sampleJs.trigger clickEvent(originalEvent: { detail: 1 })

      runs ->
        expect(sampleJs).toHaveClass 'selected'
        expect(atom.workspace.getActivePaneItem().getPath()).toBe atom.project.resolve('tree-view.js')
        expect(atom.workspaceView.getActiveView().isFocused).toBeFalsy()

        sampleJs.trigger clickEvent(originalEvent: { detail: 2 })
        expect(atom.workspaceView.getActiveView().isFocused).toBeTruthy()

  describe "when a directory is single-clicked", ->
    it "is selected", ->
      subdir = treeView.root.find('.directory:first').view()
      subdir.trigger clickEvent(originalEvent: { detail: 1 })
      expect(subdir).toHaveClass 'selected'

  describe "when a directory is double-clicked", ->
    it "toggles the directory expansion state and does not change the focus to the editor", ->
      subdir = null
      waitsForFileToOpen ->
        sampleJs.trigger clickEvent(originalEvent: { detail: 1 })

      runs ->
        subdir = treeView.root.find('.directory:first').view()
        subdir.trigger clickEvent(originalEvent: { detail: 1 })
        expect(subdir).toHaveClass 'selected'
        expect(subdir).toHaveClass 'expanded'
        subdir.trigger clickEvent(originalEvent: { detail: 2 })
        expect(subdir).toHaveClass 'selected'
        expect(subdir).not.toHaveClass 'expanded'
        expect(atom.workspaceView.getActiveView().isFocused).toBeFalsy()

  describe "when the active item changes on the active pane", ->
    describe "when the item has a path", ->
      it "selects the entry with that path in the tree view if it is visible", ->
        waitsForFileToOpen ->
          sampleJs.click()

        runs ->
          atom.workspaceView.openSync(atom.project.resolve('tree-view.txt'))
          expect(sampleTxt).toHaveClass 'selected'
          expect(treeView.find('.selected').length).toBe 1

      it "selects the path's parent dir if its entry is not visible", ->
        atom.workspaceView.openSync('dir1/sub-dir1/sub-file1')
        dirView = treeView.root.find('.directory:contains(dir1)').view()
        expect(dirView).toHaveClass 'selected'

    describe "when the item has no path", ->
      it "deselects the previously selected entry", ->
        waitsForFileToOpen ->
          sampleJs.click()

        runs ->
          atom.workspaceView.getActivePane().showItem($$ -> @div('hello'))
          expect(atom.workspaceView.find('.selected')).not.toExist()

  describe "when a different editor becomes active", ->
    beforeEach ->
      atom.workspaceView.attachToDom()

    it "selects the file in that is open in that editor", ->
      leftEditorView = null
      rightEditorView = null

      waitsForFileToOpen ->
        sampleJs.click()

      runs ->
        leftEditorView = atom.workspaceView.getActiveView()
        rightEditorView = leftEditorView.splitRight()

      waitsForFileToOpen ->
        sampleTxt.click()

      runs ->
        expect(sampleTxt).toHaveClass('selected')
        leftEditorView.focus()
        expect(sampleJs).toHaveClass('selected')

  describe "keyboard navigation", ->
    afterEach ->
      expect(treeView.find('.selected').length).toBeLessThan 2

    describe "core:move-down", ->
      describe "when a collapsed directory is selected", ->
        it "skips to the next directory", ->
          treeView.root.find('.directory:eq(0)').click()

          treeView.trigger 'core:move-down'
          expect(treeView.root.find('.directory:eq(1)')).toHaveClass 'selected'

      describe "when an expanded directory is selected", ->
        it "selects the first entry of the directory", ->
          subdir = treeView.root.find('.directory:eq(1)').view()
          subdir.click()

          treeView.trigger 'core:move-down'

          expect(subdir.entries.find('.entry:first')).toHaveClass 'selected'

      describe "when the last entry of an expanded directory is selected", ->
        it "selects the entry after its parent directory", ->
          subdir1 = treeView.root.find('.directory:eq(1)').view()
          subdir1.expand()
          waitsForFileToOpen ->
            subdir1.entries.find('.entry:last').click()

          runs ->
            treeView.trigger 'core:move-down'
            expect(treeView.root.find('.directory:eq(2)')).toHaveClass 'selected'

      describe "when the last directory of another last directory is selected", ->
        [nested, nested2] = []

        beforeEach ->
          nested = treeView.root.find('.directory:eq(2)').view()
          expect(nested.find('.header').text()).toContain 'nested'
          nested.expand()
          nested2 = nested.entries.find('.entry:last').view()
          nested2.click()
          nested2.collapse()

        describe "when the directory is collapsed", ->
          it "selects the entry after its grandparent directory", ->
            treeView.trigger 'core:move-down'
            expect(nested.next()).toHaveClass 'selected'

        describe "when the directory is expanded", ->
          it "selects the entry after its grandparent directory", ->
            nested2.expand()
            nested2.find('.file').remove() # kill the .gitkeep file, which has to be there but screws the test
            treeView.trigger 'core:move-down'
            expect(nested.next()).toHaveClass 'selected'

      describe "when the last entry of the last directory is selected", ->
        it "does not change the selection", ->
          lastEntry = treeView.root.find('> .entries .entry:last')
          waitsForFileToOpen ->
            lastEntry.click()

          runs ->
            treeView.trigger 'core:move-down'
            expect(lastEntry).toHaveClass 'selected'

    describe "core:move-up", ->
      describe "when there is an expanded directory before the currently selected entry", ->
        it "selects the last entry in the expanded directory", ->
          lastDir = treeView.root.find('.directory:last').view()
          fileAfterDir = lastDir.next().view()
          lastDir.expand()
          waitsForFileToOpen ->
            fileAfterDir.click()

          runs ->
            treeView.trigger 'core:move-up'
            expect(lastDir.find('.entry:last')).toHaveClass 'selected'

      describe "when there is an entry before the currently selected entry", ->
        it "selects the previous entry", ->
          lastEntry = treeView.root.find('.entry:last')
          waitsForFileToOpen ->
            lastEntry.click()

          runs ->
            treeView.trigger 'core:move-up'
            expect(lastEntry.prev()).toHaveClass 'selected'

      describe "when there is no entry before the currently selected entry, but there is a parent directory", ->
        it "selects the parent directory", ->
          subdir = treeView.root.find('.directory:first').view()
          subdir.expand()
          subdir.find('> .entries > .entry:first').click()

          treeView.trigger 'core:move-up'

          expect(subdir).toHaveClass 'selected'

      describe "when there is no parent directory or previous entry", ->
        it "does not change the selection", ->
          treeView.root.click()
          treeView.trigger 'core:move-up'
          expect(treeView.root).toHaveClass 'selected'

    describe "core:move-to-top", ->
      it "scrolls to the top", ->
        treeView.height(100)
        treeView.attachToDom()
        $(element).view().expand() for element in treeView.find('.directory')
        expect(treeView.list.outerHeight()).toBeGreaterThan treeView.scroller.outerHeight()

        expect(treeView.scrollTop()).toBe 0

        entryCount = treeView.find(".entry").length
        _.times entryCount, -> treeView.moveDown()
        expect(treeView.scrollTop()).toBeGreaterThan 0

        treeView.trigger 'core:move-to-top'
        expect(treeView.scrollTop()).toBe 0

      it "selects the root entry", ->
        entryCount = treeView.find(".entry").length
        _.times entryCount, -> treeView.moveDown()

        expect(treeView.root).not.toHaveClass 'selected'
        treeView.trigger 'core:move-to-top'
        expect(treeView.root).toHaveClass 'selected'

    describe "core:move-to-bottom", ->
      it "scrolls to the bottom", ->
        treeView.height(100)
        treeView.attachToDom()
        $(element).view().expand() for element in treeView.find('.directory')
        expect(treeView.list.outerHeight()).toBeGreaterThan treeView.scroller.outerHeight()

        expect(treeView.scrollTop()).toBe 0
        treeView.trigger 'core:move-to-bottom'
        expect(treeView.scrollBottom()).toBe treeView.root.outerHeight()

        treeView.root.collapse()
        treeView.trigger 'core:move-to-bottom'
        expect(treeView.scrollTop()).toBe 0

      it "selects the last entry", ->
        expect(treeView.root).toHaveClass 'selected'
        treeView.trigger 'core:move-to-bottom'
        expect(treeView.root.find('.entry:last')).toHaveClass 'selected'

    describe "core:page-up", ->
      it "scrolls up a page", ->
        treeView.height(5)
        treeView.attachToDom()
        $(element).view().expand() for element in treeView.find('.directory')
        expect(treeView.list.outerHeight()).toBeGreaterThan treeView.scroller.outerHeight()

        expect(treeView.scrollTop()).toBe 0
        treeView.scrollToBottom()
        scrollTop = treeView.scrollTop()
        expect(scrollTop).toBeGreaterThan 0

        treeView.trigger 'core:page-up'
        expect(treeView.scrollTop()).toBe scrollTop - treeView.height()

    describe "core:page-down", ->
      it "scrolls down a page", ->
        treeView.height(5)
        treeView.attachToDom()
        $(element).view().expand() for element in treeView.find('.directory')
        expect(treeView.list.outerHeight()).toBeGreaterThan treeView.scroller.outerHeight()

        expect(treeView.scrollTop()).toBe 0
        treeView.trigger 'core:page-down'
        expect(treeView.scrollTop()).toBe treeView.height()

    describe "movement outside of viewable region", ->
      it "scrolls the tree view to the selected item", ->
        treeView.height(100)
        treeView.attachToDom()
        $(element).view().expand() for element in treeView.find('.directory')
        expect(treeView.list.outerHeight()).toBeGreaterThan treeView.scroller.outerHeight()

        treeView.moveDown()
        expect(treeView.scrollTop()).toBe 0

        entryCount = treeView.find(".entry").length
        entryHeight = treeView.find('.file').height()

        _.times entryCount, -> treeView.moveDown()
        expect(treeView.scrollBottom()).toBeGreaterThan (entryCount * entryHeight) - 1

        _.times entryCount, -> treeView.moveUp()
        expect(treeView.scrollTop()).toBe 0

    describe "tree-view:expand-directory", ->
      describe "when a directory entry is selected", ->
        it "expands the current directory", ->
          subdir = treeView.root.find('.directory:first').view()
          subdir.click()
          subdir.collapse()

          expect(subdir).not.toHaveClass 'expanded'
          treeView.trigger 'tree-view:expand-directory'
          expect(subdir).toHaveClass 'expanded'

      describe "when a file entry is selected", ->
        it "does nothing", ->
          waitsForFileToOpen ->
            treeView.root.find('.file').click()

          runs ->
            treeView.trigger 'tree-view:expand-directory'

    describe "tree-view:collapse-directory", ->
      subdir = null

      beforeEach ->
        subdir = treeView.root.find('> .entries > .directory').eq(0).view()
        subdir.expand()

      describe "when an expanded directory is selected", ->
        it "collapses the selected directory", ->
          subdir.click().expand()
          expect(subdir).toHaveClass 'expanded'

          treeView.trigger 'tree-view:collapse-directory'

          expect(subdir).not.toHaveClass 'expanded'
          expect(treeView.root).toHaveClass 'expanded'

      describe "when a collapsed directory is selected", ->
        it "collapses and selects the selected directory's parent directory", ->
          subdir.find('.directory').view().click().collapse()
          treeView.trigger 'tree-view:collapse-directory'

          expect(subdir).not.toHaveClass 'expanded'
          expect(subdir).toHaveClass 'selected'
          expect(treeView.root).toHaveClass 'expanded'

      describe "when collapsed root directory is selected", ->
        it "does not raise an error", ->
          treeView.root.collapse()
          treeView.selectEntry(treeView.root)

          treeView.trigger 'tree-view:collapse-directory'

      describe "when a file is selected", ->
        it "collapses and selects the selected file's parent directory", ->
          waitsForFileToOpen ->
            subdir.find('.file').click()

          runs ->
            treeView.trigger 'tree-view:collapse-directory'
            expect(subdir).not.toHaveClass 'expanded'
            expect(subdir).toHaveClass 'selected'
            expect(treeView.root).toHaveClass 'expanded'

    describe "tree-view:open-selected-entry", ->
      describe "when a file is selected", ->
        beforeEach ->
          atom.workspaceView.attachToDom()

        it "opens the file in the editor and focuses it", ->
          waitsForFileToOpen ->
            treeView.root.find('.file:contains(tree-view.js)').click()

          waitsForFileToOpen ->
            treeView.root.trigger 'tree-view:open-selected-entry'

          runs ->
            expect(atom.workspace.getActivePaneItem().getPath()).toBe atom.project.resolve('tree-view.js')
            expect(atom.workspaceView.getActiveView().isFocused).toBeTruthy()

      describe "when a directory is selected", ->
        it "expands or collapses the directory", ->
          subdir = treeView.root.find('.directory').first().view()
          subdir.click().collapse()

          expect(subdir).not.toHaveClass 'expanded'
          treeView.root.trigger 'tree-view:open-selected-entry'
          expect(subdir).toHaveClass 'expanded'
          treeView.root.trigger 'tree-view:open-selected-entry'
          expect(subdir).not.toHaveClass 'expanded'

      describe "when nothing is selected", ->
        it "does nothing", ->
          treeView.root.trigger 'tree-view:open-selected-entry'
          expect(atom.workspaceView.getActiveView()).toBeUndefined()

  describe "file modification", ->
    [dirView, fileView, dirView2, fileView2, fileView3, rootDirPath, dirPath, filePath, dirPath2, filePath2, filePath3] = []

    beforeEach ->
      atom.packages.deactivatePackage('tree-view')

      rootDirPath = fs.absolute(temp.mkdirSync('tree-view'))

      dirPath = path.join(rootDirPath, "test-dir")
      filePath = path.join(dirPath, "test-file.txt")

      dirPath2 = path.join(rootDirPath, "test-dir2")
      filePath2 = path.join(dirPath2, "test-file2.txt")
      filePath3 = path.join(dirPath2, "test-file3.txt")

      fs.makeTreeSync(dirPath)
      fs.writeFileSync(filePath, "doesn't matter")

      fs.makeTreeSync(dirPath2)
      fs.writeFileSync(filePath2, "doesn't matter")
      fs.writeFileSync(filePath3, "doesn't matter")

      atom.project.setPath(rootDirPath)

      waitsForPromise ->
        atom.packages.activatePackage('tree-view')

      runs ->
        atom.workspaceView.trigger 'tree-view:toggle'
        treeView = atom.workspaceView.find(".tree-view").view()
        dirView = treeView.root.entries.find('.directory:contains(test-dir)').view()
        dirView.expand()
        fileView = treeView.find('.file:contains(test-file.txt)').view()
        dirView2 = treeView.root.entries.find('.directory:contains(test-dir2)').view()
        dirView2.expand()
        fileView2 = treeView.find('.file:contains(test-file2.txt)').view()
        fileView3 = treeView.find('.file:contains(test-file3.txt)').view()


    describe "tree-view:copy", ->
      LocalStorage = window.localStorage
      beforeEach ->
        atom.workspaceView.attachToDom()
        LocalStorage.clear()

        waitsForFileToOpen ->
          fileView2.click()

        runs ->
          treeView.trigger "tree-view:copy"

      describe "when a file is selected", ->
        it "saves the selected file/directory path to localStorage['tree-view:copyPath']", ->
          expect(LocalStorage['tree-view:copyPath']).toBeTruthy()

        it "Clears the localStorage['tree-view:cutPath']", ->
          LocalStorage.clear()
          LocalStorage['tree-view:cutPath'] = "I live!"
          treeView.trigger "tree-view:copy"
          expect(LocalStorage['tree-view:cutPath']).toBeFalsy

      describe 'when multiple files are selected', ->
        it 'saves the selected item paths in localStorage', ->
          fileView3.addClass('selected')
          treeView.trigger "tree-view:copy"
          storedPaths = JSON.parse(LocalStorage['tree-view:copyPath'])

          expect(storedPaths.length).toBe 2
          expect(storedPaths[0]).toBe fileView2.getPath()
          expect(storedPaths[1]).toBe fileView3.getPath()

    describe "tree-view:cut", ->
      LocalStorage = window.localStorage
      beforeEach ->
        atom.workspaceView.attachToDom()
        LocalStorage.clear()

        waitsForFileToOpen ->
          fileView2.click()

        runs ->
          treeView.trigger "tree-view:cut"

      describe "when a file is selected", ->
        it "saves the selected file/directory path to localStorage['tree-view:cutPath']", ->
          expect(LocalStorage['tree-view:cutPath']).toBeTruthy()

        it "Clears the localStorage['tree-view:copyPath']", ->
          LocalStorage.clear()
          LocalStorage['tree-view:copyPath'] = "I live to CUT!"
          treeView.trigger "tree-view:cut"
          expect(LocalStorage['tree-view:copyPath']).toBeFalsy()

      describe 'when multiple files are selected', ->
        it 'saves the selected item paths in localStorage', ->
          LocalStorage.clear()
          fileView3.addClass('selected')
          treeView.trigger "tree-view:cut"
          storedPaths = JSON.parse(LocalStorage['tree-view:cutPath'])

          expect(storedPaths.length).toBe 2
          expect(storedPaths[0]).toBe fileView2.getPath()
          expect(storedPaths[1]).toBe fileView3.getPath()

    describe "tree-view:paste", ->
      LocalStorage = window.localStorage
      beforeEach ->
        atom.workspaceView.attachToDom()
        LocalStorage.clear()

      describe "when attempting to paste a directory into itself", ->
        describe "when copied", ->
          it "makes a copy inside itself", ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([dirPath])
            dirView.click()

            newPath = path.join(dirPath, path.basename(dirPath))
            expect( -> treeView.trigger("tree-view:paste") ).not.toThrow(new Error)
            expect(fs.existsSync(newPath)).toBeTruthy()

          it 'does not keep copying recursively', ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([dirPath])
            dirView.click()

            newPath = path.join(dirPath, path.basename(dirPath))
            expect( -> treeView.trigger("tree-view:paste") ).not.toThrow(new Error)
            expect(fs.existsSync(newPath)).toBeTruthy()
            expect(fs.existsSync(path.join(newPath, path.basename(dirPath)))).toBeFalsy()

        describe "when cut", ->
          it "does nothing", ->
            LocalStorage['tree-view:cutPath'] = JSON.stringify([dirPath])
            dirView.click()

            expect(fs.existsSync(dirPath)).toBeTruthy()
            expect(fs.existsSync(path.join(dirPath, path.basename(dirPath)))).toBeFalsy()

      describe "when a file has been copied", ->
        describe "when a file is selected", ->
          it "creates a copy of the original file in the selected file's parent directory", ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath])

            fileView2.click()
            treeView.trigger "tree-view:paste"

            expect(fs.existsSync("#{dirPath2}/#{filePath.split('/').pop()}")).toBeTruthy()
            expect(fs.existsSync(filePath)).toBeTruthy()

          describe 'when target already exists', ->
            it 'appends a number to the destination name', ->
              LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath])

              fileView.click()
              treeView.trigger "tree-view:paste"
              treeView.trigger "tree-view:paste"

              fileArr = filePath.split('/').pop().split('.')
              numberedFileName0 = "#{dirPath}/#{fileArr[0]}0.#{fileArr[1]}"
              numberedFileName1 = "#{dirPath}/#{fileArr[0]}1.#{fileArr[1]}"
              expect(fs.existsSync(numberedFileName0)).toBeTruthy()
              expect(fs.existsSync(numberedFileName1)).toBeTruthy()
              expect(fs.existsSync(filePath)).toBeTruthy()

        describe "when a directory is selected", ->
          it "creates a copy of the original file in the selected directory", ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath])

            dirView2.click()
            treeView.trigger "tree-view:paste"

            expect(fs.existsSync("#{dirPath2}/#{filePath.split('/').pop()}")).toBeTruthy()
            expect(fs.existsSync(filePath)).toBeTruthy()

          describe 'when target already exists', ->
            it 'appends a number to the destination directory name', ->
              LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath])

              dirView.click()
              treeView.trigger "tree-view:paste"
              treeView.trigger "tree-view:paste"

              fileArr = filePath.split('/').pop().split('.')
              numberedFileName0 = "#{dirPath}/#{fileArr[0]}0.#{fileArr[1]}"
              numberedFileName1 = "#{dirPath}/#{fileArr[0]}1.#{fileArr[1]}"
              expect(fs.existsSync(numberedFileName0)).toBeTruthy()
              expect(fs.existsSync(numberedFileName1)).toBeTruthy()
              expect(fs.existsSync(filePath)).toBeTruthy()

          describe "when nothing has been copied", ->
            it "does not paste anything", ->
              expect(-> treeView.trigger("tree-view:paste")).not.toThrow()

      describe "when multiple files have been copied", ->
        describe "when a file is selected", ->
          it "copies the selected files to the parent directory of the selected file", ->
            LocalStorage['tree-view:copyPath'] = JSON.stringify([filePath2, filePath3])

            fileView.click()
            treeView.trigger "tree-view:paste"

            expect(fs.existsSync("#{dirPath}/#{filePath2.split('/').pop()}")).toBeTruthy()
            expect(fs.existsSync("#{dirPath}/#{filePath3.split('/').pop()}")).toBeTruthy()
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
              treeView.trigger "tree-view:paste"

              expect(fs.existsSync(path.join(dirPath, "test-file20.txt"))).toBeTruthy()
              expect(fs.existsSync(path.join(dirPath, "test-file30.txt"))).toBeTruthy()

      describe "when a file has been cut", ->
        describe "when a file is selected", ->
          it "creates a copy of the original file in the selected file's parent directory and removes the original", ->
            LocalStorage['tree-view:cutPath'] = JSON.stringify([filePath])

            fileView2.click()
            treeView.trigger "tree-view:paste"

            expect(fs.existsSync("#{dirPath2}/#{filePath.split('/').pop()}")).toBeTruthy()
            expect(fs.existsSync(filePath)).toBeFalsy()

          describe 'when the target destination file exists', ->
            it 'does not move the cut file', ->
              LocalStorage['tree-view:cutPath'] = JSON.stringify([filePath])

              filePath3 = path.join(dirPath2, "test-file.txt")
              fs.writeFileSync(filePath3, "doesn't matter")

              fileView2.click()
              treeView.trigger "tree-view:paste"

              expect(fs.existsSync(filePath)).toBeTruthy()

        describe "when a directory is selected", ->
          it "creates a copy of the original file in the selected directory and removes the original", ->
            LocalStorage['tree-view:cutPath'] = JSON.stringify([filePath])

            dirView2.click()
            treeView.trigger "tree-view:paste"

            expect(fs.existsSync("#{dirPath2}/#{filePath.split('/').pop()}")).toBeTruthy()
            expect(fs.existsSync(filePath)).toBeFalsy()

      describe "when multiple files have been cut", ->
        describe "when a file is selected", ->
          it "moves the selected files to the parent directory of the selected file", ->
            LocalStorage['tree-view:cutPath'] = JSON.stringify([filePath2, filePath3])

            fileView.click()
            treeView.trigger "tree-view:paste"

            expect(fs.existsSync("#{dirPath}/#{filePath2.split('/').pop()}")).toBeTruthy()
            expect(fs.existsSync("#{dirPath}/#{filePath3.split('/').pop()}")).toBeTruthy()
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
              treeView.trigger "tree-view:paste"

              expect(fs.existsSync(filePath2)).toBeTruthy()
              expect(fs.existsSync(filePath3)).toBeTruthy()

        describe "when a directory is selected", ->
          it "creates a copy of the original file in the selected directory and removes the original", ->
            LocalStorage['tree-view:cutPath'] = JSON.stringify([filePath])

            dirView2.click()
            treeView.trigger "tree-view:paste"

            expect(fs.existsSync("#{dirPath2}/#{filePath.split('/').pop()}")).toBeTruthy()
            expect(fs.existsSync(filePath)).toBeFalsy()


    describe "tree-view:add", ->
      addDialog = null

      beforeEach ->
        atom.workspaceView.attachToDom()

        waitsForFileToOpen ->
          fileView.click()

        runs ->
          treeView.trigger "tree-view:add-file"
          addDialog = atom.workspaceView.find(".tree-view-dialog").view()

      describe "when a file is selected", ->
        it "opens an add dialog with the file's current directory path populated", ->
          expect(addDialog).toExist()
          expect(addDialog.promptText.text()).toBeTruthy()
          expect(atom.project.relativize(dirPath)).toMatch(/[^\/]$/)
          expect(addDialog.miniEditor.getText()).toBe(atom.project.relativize(dirPath) + "/")
          expect(addDialog.miniEditor.getEditor().getCursorBufferPosition().column).toBe addDialog.miniEditor.getText().length
          expect(addDialog.miniEditor.isFocused).toBeTruthy()

        describe "when the parent directory of the selected file changes", ->
          it "the active file is still shown as selected in the tree view", ->
            directoryModifiedHandler = jasmine.createSpy("directory-modified")
            dirView.on "tree-view:directory-modified", directoryModifiedHandler

            dirView.directory.emit 'entry-removed', {name: 'deleted.txt'}
            expect(directoryModifiedHandler).toHaveBeenCalled()
            expect(treeView.find('.selected').text()).toBe path.basename(filePath)

        describe "when the path without a trailing '/' is changed and confirmed", ->
          describe "when no file exists at that location", ->
            it "add a file, closes the dialog and selects the file in the tree-view", ->
              newPath = path.join(dirPath, "new-test-file.txt")
              addDialog.miniEditor.insertText(path.basename(newPath))

              waitsForFileToOpen ->
                addDialog.trigger 'core:confirm'

              runs ->
                expect(fs.existsSync(newPath)).toBeTruthy()
                expect(fs.isFileSync(newPath)).toBeTruthy()
                expect(addDialog.parent()).not.toExist()
                expect(atom.workspace.getActivePaneItem().getPath()).toBe newPath

              waitsFor "tree view to be updated", ->
                dirView.entries.find("> .file").length > 1

              runs ->
                expect(treeView.find('.selected').text()).toBe path.basename(newPath)

          describe "when a file already exists at that location", ->
            it "shows an error message and does not close the dialog", ->
              newPath = path.join(dirPath, "new-test-file.txt")
              fs.writeFileSync(newPath, '')
              addDialog.miniEditor.insertText(path.basename(newPath))
              addDialog.trigger 'core:confirm'

              expect(addDialog.errorMessage.text()).toContain 'already exists'
              expect(addDialog).toHaveClass('error')
              expect(addDialog.hasParent()).toBeTruthy()

        describe "when the path with a trailing '/' is changed and confirmed", ->
          it "shows an error message and does not close the dialog", ->
            addDialog.miniEditor.insertText("new-test-file/")
            addDialog.trigger 'core:confirm'

            expect(addDialog.errorMessage.text()).toContain 'names must not end with'
            expect(addDialog).toHaveClass('error')
            expect(addDialog.hasParent()).toBeTruthy()

        describe "when 'core:cancel' is triggered on the add dialog", ->
          it "removes the dialog and focuses the tree view", ->
            treeView.attachToDom()
            addDialog.trigger 'core:cancel'
            expect(addDialog.parent()).not.toExist()
            expect(treeView.find(".tree-view")).toMatchSelector(':focus')

        describe "when the add dialog's editor loses focus", ->
          it "removes the dialog and focuses root view", ->
            atom.workspaceView.attachToDom()
            atom.workspaceView.focus()
            expect(addDialog.parent()).not.toExist()
            expect(atom.workspaceView.getActiveView().isFocused).toBeTruthy()

      describe "when a directory is selected", ->
        it "opens an add dialog with the directory's path populated", ->
          addDialog.cancel()
          dirView.click()
          treeView.trigger "tree-view:add-file"
          addDialog = atom.workspaceView.find(".tree-view-dialog").view()

          expect(addDialog).toExist()
          expect(addDialog.promptText.text()).toBeTruthy()
          expect(atom.project.relativize(dirPath)).toMatch(/[^\/]$/)
          expect(addDialog.miniEditor.getText()).toBe(atom.project.relativize(dirPath) + "/")
          expect(addDialog.miniEditor.getEditor().getCursorBufferPosition().column).toBe addDialog.miniEditor.getText().length
          expect(addDialog.miniEditor.isFocused).toBeTruthy()

      describe "when the root directory is selected", ->
        it "opens an add dialog with no path populated", ->
          addDialog.cancel()
          treeView.root.click()
          treeView.trigger "tree-view:add-file"
          addDialog = atom.workspaceView.find(".tree-view-dialog").view()

          expect(addDialog.miniEditor.getText().length).toBe 0

      describe "when there is no entry selected", ->
        it "opens an add dialog with no path populated", ->
          addDialog.cancel()
          treeView.root.click()
          treeView.root.removeClass('selected')
          expect(treeView.selectedEntry()).toBeUndefined()
          treeView.trigger "tree-view:add-file"
          addDialog = atom.workspaceView.find(".tree-view-dialog").view()

          expect(addDialog.miniEditor.getText().length).toBe 0

    describe "tree-view:add-folder", ->
      addDialog = null

      beforeEach ->
        atom.workspaceView.attachToDom()

        waitsForFileToOpen ->
          fileView.click()

        runs ->
          treeView.trigger "tree-view:add-folder"
          addDialog = atom.workspaceView.find(".tree-view-dialog").view()

      describe "when a file is selected", ->
        it "opens an add dialog with the file's current directory path populated", ->
          expect(addDialog).toExist()
          expect(addDialog.promptText.text()).toBeTruthy()
          expect(atom.project.relativize(dirPath)).toMatch(/[^\/]$/)
          expect(addDialog.miniEditor.getText()).toBe(atom.project.relativize(dirPath) + "/")
          expect(addDialog.miniEditor.getEditor().getCursorBufferPosition().column).toBe addDialog.miniEditor.getText().length
          expect(addDialog.miniEditor.isFocused).toBeTruthy()

        describe "when the path without a trailing '/' is changed and confirmed", ->
          describe "when no directory exists at the given path", ->
            it "adds a directory and closes the dialog", ->
              treeView.attachToDom()
              newPath = path.join(dirPath, "new/dir")
              addDialog.miniEditor.insertText("new/dir")
              addDialog.trigger 'core:confirm'
              expect(fs.existsSync(newPath)).toBeTruthy()
              expect(fs.isDirectorySync(newPath)).toBeTruthy()
              expect(addDialog.parent()).not.toExist()
              expect(atom.workspace.getActivePaneItem().getPath()).not.toBe newPath
              expect(treeView.find(".tree-view")).toMatchSelector(':focus')
              expect(atom.workspaceView.getActiveView().isFocused).toBeFalsy()
              expect(dirView.find('.directory.selected:contains(new)').length).toBe(1)

        describe "when the path with a trailing '/' is changed and confirmed", ->
          describe "when no directory exists at the given path", ->
            it "adds a directory and closes the dialog", ->
              treeView.attachToDom()
              newPath = path.join(dirPath, "new/dir")
              addDialog.miniEditor.insertText("new/dir/")
              addDialog.trigger 'core:confirm'
              expect(fs.existsSync(newPath)).toBeTruthy()
              expect(fs.isDirectorySync(newPath)).toBeTruthy()
              expect(addDialog.parent()).not.toExist()
              expect(atom.workspace.getActivePaneItem().getPath()).not.toBe newPath
              expect(treeView.find(".tree-view")).toMatchSelector(':focus')
              expect(atom.workspaceView.getActiveView().isFocused).toBeFalsy()
              expect(dirView.find('.directory.selected:contains(new)').length).toBe(1)

            it "selects the created directory and does not change the expansion state of existing directories", ->
              expandedPath = path.join(dirPath, 'expanded-dir')
              fs.makeTreeSync(expandedPath)
              treeView.entryForPath(dirPath).expand()
              treeView.entryForPath(dirPath).reload()
              expandedView = treeView.entryForPath(expandedPath)
              expandedView.expand()

              treeView.attachToDom()
              newPath = path.join(dirPath, "new2/")
              addDialog.miniEditor.insertText("new2/")
              addDialog.trigger 'core:confirm'
              expect(fs.existsSync(newPath)).toBeTruthy()
              expect(fs.isDirectorySync(newPath)).toBeTruthy()
              expect(addDialog.parent()).not.toExist()
              expect(atom.workspace.getActivePaneItem().getPath()).not.toBe newPath
              expect(treeView.find(".tree-view")).toMatchSelector(':focus')
              expect(atom.workspaceView.getActiveView().isFocused).toBeFalsy()
              expect(dirView.find('.directory.selected:contains(new2)').length).toBe(1)
              expect(treeView.entryForPath(expandedPath).isExpanded).toBeTruthy()

          describe "when a directory already exists at the given path", ->
            it "shows an error message and does not close the dialog", ->
              newPath = path.join(dirPath, "new-dir")
              fs.makeTreeSync(newPath)
              addDialog.miniEditor.insertText("new-dir/")
              addDialog.trigger 'core:confirm'

              expect(addDialog.errorMessage.text()).toContain 'already exists'
              expect(addDialog).toHaveClass('error')
              expect(addDialog.hasParent()).toBeTruthy()

    describe "tree-view:move", ->
      describe "when a file is selected", ->
        moveDialog = null

        beforeEach ->
          atom.workspaceView.attachToDom()

          waitsForFileToOpen ->
            fileView.click()

          runs ->
            treeView.trigger "tree-view:move"
            moveDialog = atom.workspaceView.find(".tree-view-dialog").view()

        afterEach ->
          waits 50 # The move specs cause too many false positives because of their async nature, so wait a little bit before we cleanup

        it "opens a move dialog with the file's current path (excluding extension) populated", ->
          extension = path.extname(filePath)
          fileNameWithoutExtension = path.basename(filePath, extension)
          expect(moveDialog).toExist()
          expect(moveDialog.promptText.text()).toBe "Enter the new path for the file."
          expect(moveDialog.miniEditor.getText()).toBe(atom.project.relativize(filePath))
          expect(moveDialog.miniEditor.getEditor().getSelectedText()).toBe path.basename(fileNameWithoutExtension)
          expect(moveDialog.miniEditor.isFocused).toBeTruthy()

        describe "when the path is changed and confirmed", ->
          describe "when all the directories along the new path exist", ->
            it "moves the file, updates the tree view, and closes the dialog", ->
              newPath = path.join(rootDirPath, 'renamed-test-file.txt')
              moveDialog.miniEditor.setText(newPath)

              moveDialog.trigger 'core:confirm'

              expect(fs.existsSync(newPath)).toBeTruthy()
              expect(fs.existsSync(filePath)).toBeFalsy()
              expect(moveDialog.parent()).not.toExist()

              waitsFor "tree view to update", ->
                treeView.root.find('> .entries > .file:contains(renamed-test-file.txt)').length > 0

              runs ->
                dirView = treeView.root.entries.find('.directory:contains(test-dir)').view()
                dirView.expand()
                expect(dirView.entries.children().length).toBe 0

          describe "when the directories along the new path don't exist", ->
            it "creates the target directory before moving the file", ->
              newPath = path.join(rootDirPath, 'new/directory', 'renamed-test-file.txt')
              moveDialog.miniEditor.setText(newPath)

              moveDialog.trigger 'core:confirm'

              waitsFor "tree view to update", ->
                treeView.root.find('> .entries > .directory:contains(new)').length > 0

              runs ->
                expect(fs.existsSync(newPath)).toBeTruthy()
                expect(fs.existsSync(filePath)).toBeFalsy()

          describe "when a file or directory already exists at the target path", ->
            it "shows an error message and does not close the dialog", ->
              runs ->
                fs.writeFileSync(path.join(rootDirPath, 'target.txt'), '')
                newPath = path.join(rootDirPath, 'target.txt')
                moveDialog.miniEditor.setText(newPath)

                moveDialog.trigger 'core:confirm'

                expect(moveDialog.errorMessage.text()).toContain 'already exists'
                expect(moveDialog).toHaveClass('error')
                expect(moveDialog.hasParent()).toBeTruthy()

        describe "when 'core:cancel' is triggered on the move dialog", ->
          it "removes the dialog and focuses the tree view", ->
            treeView.attachToDom()
            moveDialog.trigger 'core:cancel'
            expect(moveDialog.parent()).not.toExist()
            expect(treeView.find(".tree-view")).toMatchSelector(':focus')

        describe "when the move dialog's editor loses focus", ->
          it "removes the dialog and focuses root view", ->
            atom.workspaceView.attachToDom()
            atom.workspaceView.focus()
            expect(moveDialog.parent()).not.toExist()
            expect(atom.workspaceView.getActiveView().isFocused).toBeTruthy()

      describe "when a file is selected that's name starts with a '.'", ->
        [dotFilePath, dotFileView, moveDialog] = []

        beforeEach ->
          dotFilePath = path.join(dirPath, ".dotfile")
          fs.writeFileSync(dotFilePath, "dot")
          dirView.collapse()
          dirView.expand()
          dotFileView = treeView.find('.file:contains(.dotfile)').view()

          waitsForFileToOpen ->
            dotFileView.click()

          runs ->
            treeView.trigger "tree-view:move"
            moveDialog = atom.workspaceView.find(".tree-view-dialog").view()

        it "selects the entire file name", ->
          expect(moveDialog).toExist()
          expect(moveDialog.miniEditor.getText()).toBe(atom.project.relativize(dotFilePath))
          expect(moveDialog.miniEditor.getEditor().getSelectedText()).toBe '.dotfile'

      describe "when the project is selected", ->
        it "doesn't display the move dialog", ->
          treeView.root.click()
          treeView.trigger "tree-view:move"
          expect(atom.workspaceView.find(".tree-view-dialog").view()).not.toExist()

    describe "tree-view:duplicate", ->
      describe "when a file is selected", ->
        copyDialog = null

        beforeEach ->
          atom.workspaceView.attachToDom()

          waitsForFileToOpen ->
            fileView.click()

          runs ->
            treeView.trigger "tree-view:duplicate"
            copyDialog = atom.workspaceView.find(".tree-view-dialog").view()

        afterEach ->
          waits 50 # The copy specs cause too many false positives because of their async nature, so wait a little bit before we cleanup

        it "opens a copy dialog to duplicate with the file's current path populated", ->
          extension = path.extname(filePath)
          fileNameWithoutExtension = path.basename(filePath, extension)
          expect(copyDialog).toExist()
          expect(copyDialog.promptText.text()).toBe "Enter the new path for the duplicate."
          expect(copyDialog.miniEditor.getText()).toBe(atom.project.relativize(filePath))
          expect(copyDialog.miniEditor.getEditor().getSelectedText()).toBe path.basename(fileNameWithoutExtension)
          expect(copyDialog.miniEditor.isFocused).toBeTruthy()

        describe "when the path is changed and confirmed", ->
          describe "when all the directories along the new path exist", ->
            it "duplicates the file, updates the tree view, and closes the dialog", ->
              newPath = path.join(rootDirPath, 'duplicated-test-file.txt')
              copyDialog.miniEditor.setText(newPath)

              copyDialog.trigger 'core:confirm'

              waitsFor "tree view to update", ->
                treeView.root.find('> .entries > .file:contains(duplicated-test-file.txt)').length > 0

              runs ->
                treeView.trigger "tree-view:duplicate"
                expect(fs.existsSync(newPath)).toBeTruthy()
                expect(fs.existsSync(filePath)).toBeTruthy()
                expect(copyDialog.parent()).not.toExist()
                dirView = treeView.root.entries.find('.directory:contains(test-dir)').view()
                dirView.expand()
                expect(dirView.entries.children().length).toBe 1

          describe "when the directories along the new path don't exist", ->
            it "duplicates the tree", ->
              newPath = path.join(rootDirPath, 'new/directory', 'duplicated-test-file.txt')
              copyDialog.miniEditor.setText(newPath)

              copyDialog.trigger 'core:confirm'

              waitsFor "tree view to update", ->
                treeView.root.find('> .entries > .directory:contains(new)').length > 0

              waitsFor "new path to exist", -> fs.existsSync(newPath)

              runs ->
                expect(fs.existsSync(filePath)).toBeTruthy()

          describe "when a file or directory already exists at the target path", ->
            it "shows an error message and does not close the dialog", ->
              runs ->
                fs.writeFileSync(path.join(rootDirPath, 'target.txt'), '')
                newPath = path.join(rootDirPath, 'target.txt')
                copyDialog.miniEditor.setText(newPath)

                copyDialog.trigger 'core:confirm'

                expect(copyDialog.errorMessage.text()).toContain 'already exists'
                expect(copyDialog).toHaveClass('error')
                expect(copyDialog.hasParent()).toBeTruthy()

        describe "when 'core:cancel' is triggered on the copy dialog", ->
          it "removes the dialog and focuses the tree view", ->
            treeView.attachToDom()
            copyDialog.trigger 'core:cancel'
            expect(copyDialog.parent()).not.toExist()
            expect(treeView.find(".tree-view")).toMatchSelector(':focus')

        describe "when the duplicate dialog's editor loses focus", ->
          it "removes the dialog and focuses root view", ->
            atom.workspaceView.attachToDom()
            atom.workspaceView.focus()
            expect(copyDialog.parent()).not.toExist()
            expect(atom.workspaceView.getActiveView().isFocused).toBeTruthy()

      describe "when a file is selected that's name starts with a '.'", ->
        [dotFilePath, dotFileView, copyDialog] = []

        beforeEach ->
          dotFilePath = path.join(dirPath, ".dotfile")
          fs.writeFileSync(dotFilePath, "dot")
          dirView.collapse()
          dirView.expand()
          dotFileView = treeView.find('.file:contains(.dotfile)').view()

          waitsForFileToOpen ->
            dotFileView.click()

          runs ->
            treeView.trigger "tree-view:duplicate"
            copyDialog = atom.workspaceView.find(".tree-view-dialog").view()

        it "selects the entire file name", ->
          expect(copyDialog).toExist()
          expect(copyDialog.miniEditor.getText()).toBe(atom.project.relativize(dotFilePath))
          expect(copyDialog.miniEditor.getEditor().getSelectedText()).toBe '.dotfile'

      describe "when the project is selected", ->
        it "doesn't display the copy dialog", ->
          treeView.root.click()
          treeView.trigger "tree-view:duplicate"
          expect(atom.workspaceView.find(".tree-view-dialog").view()).not.toExist()

      describe "when the editor has focus", ->
        copyDialog = null

        beforeEach ->
          atom.workspaceView.openSync('tree-view.js')
          editorView = atom.workspaceView.getActiveView()
          editorView.trigger "tree-view:duplicate"
          copyDialog = atom.workspaceView.find(".tree-view-dialog").view()

        it "duplicates the current file", ->
          expect(copyDialog.miniEditor.getText()).toBe('tree-view.js')

    describe "tree-view:remove", ->
      it "shows the native alert dialog", ->
        spyOn(atom, 'confirm')
        waitsForFileToOpen ->
          fileView.click()
        runs ->
          treeView.trigger 'tree-view:remove'
          expect(atom.confirm).toHaveBeenCalled()

  describe "file system events", ->
    temporaryFilePath = null

    beforeEach ->
      atom.project.setPath(fs.absolute(temp.mkdirSync('tree-view')))
      temporaryFilePath = path.join(atom.project.getPath(), 'temporary')

    describe "when a file is added or removed in an expanded directory", ->
      it "updates the directory view to display the directory's new contents", ->
        entriesCountBefore = null

        runs ->
          expect(fs.existsSync(temporaryFilePath)).toBeFalsy()
          entriesCountBefore = treeView.root.entries.find('.entry').length
          fs.writeFileSync temporaryFilePath, 'hi'

        waitsFor "directory view contens to refresh", ->
          treeView.root.entries.find('.entry').length == entriesCountBefore + 1

        runs ->
          expect(treeView.root.entries.find('.entry').length).toBe entriesCountBefore + 1
          expect(treeView.root.entries.find('.file:contains(temporary)')).toExist()
          fs.removeSync(temporaryFilePath)

        waitsFor "directory view contens to refresh", ->
          treeView.root.entries.find('.entry').length == entriesCountBefore

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

        atom.project.setPath(projectPath)
        atom.config.set "tree-view.hideVcsIgnoredFiles", false

      it "hides git-ignored files if the option is set, but otherwise shows them", ->
        expect(treeView.find('.file:contains(ignored.txt)').length).toBe 1

        atom.config.set("tree-view.hideVcsIgnoredFiles", true)
        expect(treeView.find('.file:contains(ignored.txt)').length).toBe 0

        atom.config.set("tree-view.hideVcsIgnoredFiles", false)
        expect(treeView.find('.file:contains(ignored.txt)').length).toBe 1

    describe "when the project's path is a subfolder of the repository's working directory", ->
      beforeEach ->
        fixturePath = path.join(__dirname, 'fixtures', 'tree-view')
        projectPath = temp.mkdirSync('tree-view-project')
        fs.copySync(fixturePath, projectPath)
        ignoreFile = path.join(projectPath, '.gitignore')
        fs.writeFileSync(ignoreFile, 'tree-view.js')

        atom.project.setPath(projectPath)
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
      atom.project.setPath(projectPath)
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

  describe "Git status decorations", ->
    beforeEach ->
      projectPath = fs.realpathSync(temp.mkdirSync('tree-view-project'))
      workingDirFixture = path.join(__dirname, 'fixtures', 'git', 'working-dir')
      fs.copySync(workingDirFixture, projectPath)
      fs.moveSync(path.join(projectPath, 'git.git'), path.join(projectPath, '.git'))
      atom.project.setPath(projectPath)

      newDir = path.join(projectPath, 'dir2')
      fs.mkdirSync(newDir)

      newFile = path.join(newDir, 'new2')
      fs.writeFileSync(newFile, '')
      atom.project.getRepo().getPathStatus(newFile)

      ignoreFile = path.join(projectPath, '.gitignore')
      fs.writeFileSync(ignoreFile, 'ignored.txt')
      ignoredFile = path.join(projectPath, 'ignored.txt')
      fs.writeFileSync(ignoredFile, '')

      modifiedFile = path.join(projectPath, 'dir', 'b.txt')
      originalFileContent = fs.readFileSync(modifiedFile, 'utf8')
      fs.writeFileSync modifiedFile, 'ch ch changes'
      atom.project.getRepo().getPathStatus(modifiedFile)

      treeView.updateRoot()
      treeView.root.entries.find('.directory:contains(dir)').view().expand()

    describe "when the project is the repository root", ->
      it "adds a custom style", ->
        expect(treeView.find('.icon-repo').length).toBe 1

    describe "when a file is modified", ->
      it "adds a custom style", ->
        treeView.root.entries.find('.directory:contains(dir)').view().expand()
        expect(treeView.find('.file:contains(b.txt)')).toHaveClass 'status-modified'

    describe "when a directory if modified", ->
      it "adds a custom style", ->
        expect(treeView.find('.directory:contains(dir)')).toHaveClass 'status-modified'

    describe "when a file is new", ->
      it "adds a custom style", ->
        treeView.root.entries.find('.directory:contains(dir2)').view().expand()
        expect(treeView.find('.file:contains(new2)')).toHaveClass 'status-added'

    describe "when a directory is new", ->
      it "adds a custom style", ->
        expect(treeView.find('.directory:contains(dir2)')).toHaveClass 'status-added'

    describe "when a file is ignored", ->
      it "adds a custom style", ->
        expect(treeView.find('.file:contains(ignored.txt)')).toHaveClass 'status-ignored'

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

  describe "selecting items", ->
    [dirView, fileView1, fileView2, fileView3, treeView, rootDirPath, dirPath, filePath1, filePath2, filePath3] = []

    beforeEach ->
      atom.packages.deactivatePackage('tree-view')

      rootDirPath = fs.absolute(temp.mkdirSync('tree-view'))

      dirPath = path.join(rootDirPath, "test-dir")
      filePath1 = path.join(dirPath, "test-file1.txt")
      filePath2 = path.join(dirPath, "test-file2.txt")
      filePath3 = path.join(dirPath, "test-file3.txt")

      fs.makeTreeSync(dirPath)
      fs.writeFileSync(filePath1, "doesn't matter")
      fs.writeFileSync(filePath2, "doesn't matter")
      fs.writeFileSync(filePath3, "doesn't matter")

      atom.project.setPath(rootDirPath)

      waitsForPromise ->
        atom.packages.activatePackage('tree-view')

      runs ->
        atom.workspaceView.trigger 'tree-view:toggle'
        treeView = atom.workspaceView.find(".tree-view").view()
        dirView = treeView.root.entries.find('.directory:contains(test-dir)').view()
        dirView.expand()
        fileView1 = treeView.find('.file:contains(test-file1.txt)').view()
        fileView2 = treeView.find('.file:contains(test-file2.txt)').view()
        fileView3 = treeView.find('.file:contains(test-file3.txt)').view()

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
          Object.defineProperty(process, "platform", {__proto__:null, value: 'win32'})

        afterEach ->
          # Ensure that process.platform is set back to it's original value
          Object.defineProperty(process, "platform", {__proto__:null, value: originalPlatform})

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
          Object.defineProperty(process, "platform", {__proto__:null, value: 'darwin'})

        afterEach ->
          # Ensure that process.platform is set back to it's original value
          Object.defineProperty(process, "platform", {__proto__:null, value: originalPlatform})

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
