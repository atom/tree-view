{_, $, $$, fs, RootView} = require 'atom'
TreeView = require '../lib/tree-view'
path = require 'path'
temp = require 'temp'

waitsForFileToOpen = (fn) ->
  openHandler = jasmine.createSpy()
  runs ->
    rootView.one "uri-opened", openHandler
    fn()

  waitsFor ->
    openHandler.callCount == 1

describe "TreeView", ->
  [treeView, sampleJs, sampleTxt] = []

  beforeEach ->
    project.setPath(project.resolve('tree-view'))
    window.rootView = new RootView

    atom.activatePackage("tree-view")
    rootView.trigger 'tree-view:toggle'
    treeView = rootView.find(".tree-view").view()
    treeView.root = treeView.find('ol > li:first').view()
    sampleJs = treeView.find('.file:contains(tree-view.js)')
    sampleTxt = treeView.find('.file:contains(tree-view.txt)')

    expect(treeView.root.directory.subscriptionCount()).toBeGreaterThan 0

  describe ".initialize(project)", ->
    it "renders the root of the project and its contents alphabetically with subdirectories first in a collapsed state", ->
      expect(treeView.root.find('> .header .disclosure-arrow')).not.toHaveClass('expanded')
      expect(treeView.root.find('> .header .name')).toHaveText('tree-view')

      rootEntries = treeView.root.find('.entries')
      subdir0 = rootEntries.find('> li:eq(0)')
      expect(subdir0).not.toHaveClass('expanded')
      expect(subdir0.find('.name')).toHaveText('dir1')
      expect(subdir0.find('.entries')).not.toExist()

      subdir2 = rootEntries.find('> li:eq(1)')
      expect(subdir2).not.toHaveClass('expanded')
      expect(subdir2.find('.name')).toHaveText('dir2')
      expect(subdir2.find('.entries')).not.toExist()

      expect(rootEntries.find('> .file:contains(tree-view.js)')).toExist()
      expect(rootEntries.find('> .file:contains(tree-view.txt)')).toExist()

    it "selects the rootview", ->
      expect(treeView.selectedEntry()).toEqual treeView.root

    describe "when the project has no path", ->
      beforeEach ->
        project.setPath(undefined)
        atom.deactivatePackage("tree-view")
        treeView = atom.activatePackage("tree-view").mainModule.createView()

      it "does not attach to the root view or create a root node when initialized", ->
        expect(treeView.hasParent()).toBeFalsy()
        expect(treeView.root).not.toExist()

      it "does not attach to the root view or create a root node when attach() is called", ->
        treeView.attach()
        expect(treeView.hasParent()).toBeFalsy()
        expect(treeView.root).not.toExist()

      it "serializes without throwing an exception", ->
        expect(-> treeView.serialize()).not.toThrow()

      describe "when the project is assigned a path because a new buffer is saved", ->
        it "creates a root directory view but does not attach to the root view", ->
          rootView.openSync()
          rootView.getActivePaneItem().saveAs("/tmp/test.txt")
          expect(treeView.hasParent()).toBeFalsy()
          expect(treeView.root.getPath()).toBe '/tmp'
          expect(treeView.root.parent()).toMatchSelector(".tree-view")

    describe "when the root view is opened to a file path", ->
      it "does not attach to the root view but does create a root node when initialized", ->
        atom.deactivatePackage("tree-view")
        atom.packageStates = {}
        rootView.openSync('tree-view.js')
        treeView = atom.activatePackage("tree-view").mainModule.createView()
        expect(treeView.hasParent()).toBeFalsy()
        expect(treeView.root).toExist()

    describe "when the root view is opened to a directory", ->
      it "attaches to the root view", ->
        treeView = atom.activatePackage("tree-view").mainModule.createView()
        expect(treeView.hasParent()).toBeTruthy()
        expect(treeView.root).toExist()

    describe "when the project is a .git folder", ->
      it "does not create the tree view", ->
        dotGit = path.join(temp.mkdirSync('repo'), '.git')
        fs.makeTree(dotGit)
        project.setPath(dotGit)
        atom.deactivatePackage("tree-view")
        atom.packageStates = {}
        {treeView} = atom.activatePackage("tree-view").mainModule
        expect(treeView).toBeFalsy()

  describe "serialization", ->
    it "restores expanded directories and selected file when deserialized", ->
      treeView.root.find('.directory:contains(dir1)').view().click()

      waitsForFileToOpen ->
        sampleJs.click()

      runs ->
        atom.deactivatePackage("tree-view")
        atom.activatePackage("tree-view")
        treeView = rootView.find(".tree-view").view()

        expect(treeView).toExist()
        expect(treeView.selectedEntry()).toMatchSelector(".file:contains(tree-view.js)")
        expect(treeView.find(".directory:contains(dir1)")).toHaveClass("expanded")

    it "restores the focus state of the tree view", ->
      rootView.attachToDom()
      treeView.focus()
      expect(treeView.list).toMatchSelector ':focus'
      atom.deactivatePackage("tree-view")
      atom.activatePackage("tree-view")
      treeView = rootView.find(".tree-view").view()
      expect(treeView.list).toMatchSelector ':focus'

    it "restores the scroll top when toggled", ->
      rootView.height(5)
      rootView.attachToDom()
      expect(treeView).toBeVisible()
      treeView.focus()

      treeView.scrollTop(10)
      expect(treeView.scrollTop()).toBe(10)

      rootView.trigger 'tree-view:toggle'
      expect(treeView).toBeHidden()
      rootView.trigger 'tree-view:toggle'
      expect(treeView).toBeVisible()
      expect(treeView.scrollTop()).toBe(10)

  describe "when tree-view:toggle is triggered on the root view", ->
    beforeEach ->
      rootView.attachToDom()

    describe "when the tree view is visible", ->
      beforeEach ->
        expect(treeView).toBeVisible()

      describe "when the tree view is focused", ->
        it "hides the tree view", ->
          treeView.focus()
          rootView.trigger 'tree-view:toggle'
          expect(treeView).toBeHidden()

      describe "when the tree view is not focused", ->
        it "shifts focus to the tree view", ->
          rootView.openSync() # When we call focus below, we want an editor to become focused
          rootView.focus()
          rootView.trigger 'tree-view:toggle'
          expect(treeView).toBeVisible()
          expect(treeView.list).toMatchSelector(':focus')

    describe "when the tree view is hidden", ->
      it "shows and focuses the tree view", ->
        treeView.detach()
        rootView.trigger 'tree-view:toggle'
        expect(treeView.hasParent()).toBeTruthy()
        expect(treeView.list).toMatchSelector(':focus')

  describe "when tree-view:reveal-current-file is triggered on the root view", ->
    beforeEach ->
      treeView.detach()
      spyOn(treeView, 'focus')

    describe "if the current file has a path", ->
      it "shows and focuses the tree view and selects the file", ->
        rootView.openSync('dir1/file1')
        rootView.trigger 'tree-view:reveal-active-file'
        expect(treeView.hasParent()).toBeTruthy()
        expect(treeView.focus).toHaveBeenCalled()
        expect(treeView.selectedEntry().getPath()).toMatch /dir1\/file1$/

    describe "if the current file has no path", ->
      it "shows and focuses the tree view, but does not attempt to select a specific file", ->
        rootView.openSync()
        expect(rootView.getActivePaneItem().getPath()).toBeUndefined()
        rootView.trigger 'tree-view:reveal-active-file'
        expect(treeView.hasParent()).toBeTruthy()
        expect(treeView.focus).toHaveBeenCalled()

    describe "if there is no editor open", ->
      it "shows and focuses the tree view, but does not attempt to select a specific file", ->
        expect(rootView.getActivePaneItem()).toBeUndefined()
        rootView.trigger 'tree-view:reveal-active-file'
        expect(treeView.hasParent()).toBeTruthy()
        expect(treeView.focus).toHaveBeenCalled()

  describe "when tool-panel:unfocus is triggered on the tree view", ->
    it "surrenders focus to the root view but remains open", ->
      rootView.openSync() # When we trigger 'tool-panel:unfocus' below, we want an editor to become focused
      rootView.attachToDom()
      treeView.focus()
      expect(treeView.list).toMatchSelector(':focus')
      treeView.trigger 'tool-panel:unfocus'
      expect(treeView).toBeVisible()
      expect(treeView.list).not.toMatchSelector(':focus')
      expect(rootView.getActiveView().isFocused).toBeTruthy()

  describe "when core:close is triggered on the tree view", ->
    it "detaches the TreeView, focuses the RootView and does not bubble the core:close event", ->
      treeView.attach()
      treeView.focus()
      rootViewCloseHandler = jasmine.createSpy('rootViewCloseHandler')
      rootView.on 'core:close', rootViewCloseHandler
      spyOn(rootView, 'focus')

      treeView.trigger('core:close')
      expect(rootView.focus).toHaveBeenCalled()
      expect(rootViewCloseHandler).not.toHaveBeenCalled()
      expect(treeView.hasParent()).toBeFalsy()

  describe "when a directory's disclosure arrow is clicked", ->
    it "expands / collapses the associated directory", ->
      subdir = treeView.root.find('.entries > li:contains(dir1)').view()

      expect(subdir).not.toHaveClass('expanded')
      expect(subdir.find('.entries')).not.toExist()

      subdir.click()

      expect(subdir).toHaveClass('expanded')
      expect(subdir.find('.entries')).toExist()

      subdir.click()
      expect(subdir).not.toHaveClass('expanded')
      expect(subdir.find('.entries')).not.toExist()

    it "restores the expansion state of descendant directories", ->
      child = treeView.root.find('.entries > li:contains(dir1)').view()
      child.click()

      grandchild = child.find('.entries > li:contains(sub-dir1)').view()
      grandchild.click()

      treeView.root.click()
      expect(treeView.root.find('.entries')).not.toExist()
      treeView.root.click()

      # previously expanded descendants remain expanded
      expect(treeView.root.find('> .entries > li:contains(dir1) > .entries > li:contains(sub-dir1) > .entries').length).toBe 1

      # collapsed descendants remain collapsed
      expect(treeView.root.find('> .entries > li.contains(dir2) > .entries')).not.toExist()

    it "when collapsing a directory, removes change subscriptions from the collapsed directory and its descendants", ->
      child = treeView.root.entries.find('li:contains(dir1)').view()
      child.click()

      grandchild = child.entries.find('li:contains(sub-dir1)').view()
      grandchild.click()

      expect(treeView.root.directory.subscriptionCount()).toBe 1
      expect(child.directory.subscriptionCount()).toBe 1
      expect(grandchild.directory.subscriptionCount()).toBe 1

      treeView.root.click()

      expect(treeView.root.directory.subscriptionCount()).toBe 0
      expect(child.directory.subscriptionCount()).toBe 0
      expect(grandchild.directory.subscriptionCount()).toBe 0

  describe "when mouse down fires on a file or directory", ->
    it "selects then entry", ->
      dir = treeView.root.entries.find('li:contains(dir1)').view()
      expect(dir).not.toHaveClass 'selected'
      dir.mousedown()
      expect(dir).toHaveClass 'selected'

      expect(sampleJs).not.toHaveClass 'selected'
      sampleJs.mousedown()
      expect(sampleJs).toHaveClass 'selected'

  describe "when a file is single-clicked", ->
    it "selects the files and opens it in the active editor, without changing focus", ->
      expect(rootView.getActiveView()).toBeUndefined()

      waitsForFileToOpen ->
        sampleJs.trigger clickEvent(originalEvent: { detail: 1 })

      runs ->
        expect(sampleJs).toHaveClass 'selected'
        expect(rootView.getActiveView().getPath()).toBe project.resolve('tree-view.js')
        expect(rootView.getActiveView().isFocused).toBeFalsy()

      waitsForFileToOpen ->
        sampleTxt.trigger clickEvent(originalEvent: { detail: 1 })

      runs ->
        expect(sampleTxt).toHaveClass 'selected'
        expect(treeView.find('.selected').length).toBe 1
        expect(rootView.getActiveView().getPath()).toBe project.resolve('tree-view.txt')
        expect(rootView.getActiveView().isFocused).toBeFalsy()

  describe "when a file is double-clicked", ->
    it "selects the file and opens it in the active editor on the first click, then changes focus to the active editor on the second", ->
      waitsForFileToOpen ->
        sampleJs.trigger clickEvent(originalEvent: { detail: 1 })

      runs ->
        expect(sampleJs).toHaveClass 'selected'
        expect(rootView.getActiveView().getPath()).toBe project.resolve('tree-view.js')
        expect(rootView.getActiveView().isFocused).toBeFalsy()

        sampleJs.trigger clickEvent(originalEvent: { detail: 2 })
        expect(rootView.getActiveView().isFocused).toBeTruthy()

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
        expect(rootView.getActiveView().isFocused).toBeFalsy()

  describe "when the active item changes on the active pane", ->
    describe "when the item has a path", ->
      it "selects the entry with that path in the tree view if it is visible", ->
        waitsForFileToOpen ->
          sampleJs.click()

        runs ->
          rootView.openSync(project.resolve('tree-view.txt'))
          expect(sampleTxt).toHaveClass 'selected'
          expect(treeView.find('.selected').length).toBe 1

      it "selects the path's parent dir if its entry is not visible", ->
        rootView.openSync('dir1/sub-dir1/sub-file1')
        dirView = treeView.root.find('.directory:contains(dir1)').view()
        expect(dirView).toHaveClass 'selected'

    describe "when the item has no path", ->
      it "deselects the previously selected entry", ->
        waitsForFileToOpen ->
          sampleJs.click()

        runs ->
          rootView.getActivePane().showItem($$ -> @div('hello'))
          expect(rootView.find('.selected')).not.toExist()

  describe "when a different editor becomes active", ->
    it "selects the file in that is open in that editor", ->
      leftEditor = null
      rightEditor = null

      waitsForFileToOpen ->
        sampleJs.click()

      runs ->
        leftEditor = rootView.getActiveView()
        rightEditor = leftEditor.splitRight()

      waitsForFileToOpen ->
        sampleTxt.click()

      runs ->
        expect(sampleTxt).toHaveClass('selected')
        leftEditor.focus()
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
            expect(treeView.root.find('.entries > .entry:eq(2)')).toHaveClass 'selected'

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
        it "opens the file in the editor and focuses it", ->
          waitsForFileToOpen ->
            treeView.root.find('.file:contains(tree-view.js)').click()

          waitsForFileToOpen ->
            treeView.root.trigger 'tree-view:open-selected-entry'

          runs ->
            expect(rootView.getActiveView().getPath()).toBe project.resolve('tree-view.js')
            expect(rootView.getActiveView().isFocused).toBeTruthy()

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
          expect(rootView.getActiveView()).toBeUndefined()

  describe "file modification", ->
    [dirView, fileView, rootDirPath, dirPath, filePath] = []

    beforeEach ->
      atom.deactivatePackage('tree-view')

      rootDirPath = path.join(fs.absolute("/tmp"), "atom-tests")
      fs.remove(rootDirPath) if fs.exists(rootDirPath)

      dirPath = path.join(rootDirPath, "test-dir")
      filePath = path.join(dirPath, "test-file.txt")
      fs.makeTree(rootDirPath)
      fs.makeTree(dirPath)
      fs.writeSync(filePath, "doesn't matter")

      project.setPath(rootDirPath)

      atom.activatePackage('tree-view')
      rootView.trigger 'tree-view:toggle'
      treeView = rootView.find(".tree-view").view()
      dirView = treeView.root.entries.find('.directory:contains(test-dir)').view()
      dirView.expand()
      fileView = treeView.find('.file:contains(test-file.txt)').view()

    afterEach ->
      fs.remove(rootDirPath) if fs.exists(rootDirPath)

    describe "tree-view:add", ->
      addDialog = null

      beforeEach ->
        waitsForFileToOpen ->
          fileView.click()

        runs ->
          treeView.trigger "tree-view:add"
          addDialog = rootView.find(".tree-view-dialog").view()

      describe "when a file is selected", ->
        it "opens an add dialog with the file's current directory path populated", ->
          expect(addDialog).toExist()
          expect(addDialog.promptText.text()).toBeTruthy()
          expect(project.relativize(dirPath)).toMatch(/[^\/]$/)
          expect(addDialog.miniEditor.getText()).toBe(project.relativize(dirPath) + "/")
          expect(addDialog.miniEditor.getCursorBufferPosition().column).toBe addDialog.miniEditor.getText().length
          expect(addDialog.miniEditor.isFocused).toBeTruthy()

        describe "when parent directory of the selected file changes", ->
          it "active file is still shown as selected in the tree view", ->
            directoryChangeHandler = jasmine.createSpy("directory-change")
            dirView.on "tree-view:directory-modified", directoryChangeHandler

            dirView.directory.trigger 'contents-changed'
            expect(directoryChangeHandler).toHaveBeenCalled()
            expect(treeView.find('.selected').text()).toBe path.basename(filePath)

        describe "when the path without a trailing '/' is changed and confirmed", ->
          describe "when no file exists at that location", ->
            it "add a file, closes the dialog and selects the file in the tree-view", ->
              newPath = path.join(dirPath, "new-test-file.txt")
              addDialog.miniEditor.insertText(path.basename(newPath))

              waitsForFileToOpen ->
                addDialog.trigger 'core:confirm'

              runs ->
                expect(fs.exists(newPath)).toBeTruthy()
                expect(fs.isFileSync(newPath)).toBeTruthy()
                expect(addDialog.parent()).not.toExist()
                expect(rootView.getActiveView().getPath()).toBe newPath

              waitsFor "tree view to be updated", ->
                dirView.entries.find("> .file").length > 1

              runs ->
                expect(treeView.find('.selected').text()).toBe path.basename(newPath)

          describe "when a file already exists at that location", ->
            it "shows an error message and does not close the dialog", ->
              newPath = path.join(dirPath, "new-test-file.txt")
              fs.writeSync(newPath, '')
              addDialog.miniEditor.insertText(path.basename(newPath))
              addDialog.trigger 'core:confirm'

              expect(addDialog.promptText.text()).toContain 'Error'
              expect(addDialog.promptText.text()).toContain 'already exists'
              expect(addDialog).toHaveClass('error')
              expect(addDialog.hasParent()).toBeTruthy()

        describe "when the path with a trailing '/' is changed and confirmed", ->
          describe "when no file or directory exists at the given path", ->
            it "adds a directory and closes the dialog", ->
              treeView.attachToDom()
              newPath = path.join(dirPath, "new/dir")
              addDialog.miniEditor.insertText("new/dir/")
              addDialog.trigger 'core:confirm'
              expect(fs.exists(newPath)).toBeTruthy()
              expect(fs.isDirectorySync(newPath)).toBeTruthy()
              expect(addDialog.parent()).not.toExist()
              expect(rootView.getActiveView().getPath()).not.toBe newPath
              expect(treeView.find(".tree-view")).toMatchSelector(':focus')
              expect(rootView.getActiveView().isFocused).toBeFalsy()
              expect(dirView.find('.directory.selected:contains(new)').length).toBe(1)

            it "selects the created directory", ->
              treeView.attachToDom()
              newPath = path.join(dirPath, "new2/")
              addDialog.miniEditor.insertText("new2/")
              addDialog.trigger 'core:confirm'
              expect(fs.exists(newPath)).toBeTruthy()
              expect(fs.isDirectorySync(newPath)).toBeTruthy()
              expect(addDialog.parent()).not.toExist()
              expect(rootView.getActiveView().getPath()).not.toBe newPath
              expect(treeView.find(".tree-view")).toMatchSelector(':focus')
              expect(rootView.getActiveView().isFocused).toBeFalsy()
              expect(dirView.find('.directory.selected:contains(new2)').length).toBe(1)

          describe "when a file or directory already exists at the given path", ->
            it "shows an error message and does not close the dialog", ->
              newPath = path.join(dirPath, "new-dir")
              fs.makeTree(newPath)
              addDialog.miniEditor.insertText("new-dir/")
              addDialog.trigger 'core:confirm'

              expect(addDialog.promptText.text()).toContain 'Error'
              expect(addDialog.promptText.text()).toContain 'already exists'
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
            rootView.attachToDom()
            rootView.focus()
            expect(addDialog.parent()).not.toExist()
            expect(rootView.getActiveView().isFocused).toBeTruthy()

      describe "when a directory is selected", ->
        it "opens an add dialog with the directory's path populated", ->
          addDialog.cancel()
          dirView.click()
          treeView.trigger "tree-view:add"
          addDialog = rootView.find(".tree-view-dialog").view()

          expect(addDialog).toExist()
          expect(addDialog.promptText.text()).toBeTruthy()
          expect(project.relativize(dirPath)).toMatch(/[^\/]$/)
          expect(addDialog.miniEditor.getText()).toBe(project.relativize(dirPath) + "/")
          expect(addDialog.miniEditor.getCursorBufferPosition().column).toBe addDialog.miniEditor.getText().length
          expect(addDialog.miniEditor.isFocused).toBeTruthy()

      describe "when the root directory is selected", ->
        it "opens an add dialog with no path populated", ->
          addDialog.cancel()
          treeView.root.click()
          treeView.trigger "tree-view:add"
          addDialog = rootView.find(".tree-view-dialog").view()

          expect(addDialog.miniEditor.getText().length).toBe 0

      describe "when there is no entry selected", ->
        it "opens an add dialog with no path populated", ->
          addDialog.cancel()
          treeView.root.click()
          treeView.root.removeClass('selected')
          expect(treeView.selectedEntry()).toBeUndefined()
          treeView.trigger "tree-view:add"
          addDialog = rootView.find(".tree-view-dialog").view()

          expect(addDialog.miniEditor.getText().length).toBe 0

    describe "tree-view:move", ->
      describe "when a file is selected", ->
        moveDialog = null

        beforeEach ->
          waitsForFileToOpen ->
            fileView.click()

          runs ->
            treeView.trigger "tree-view:move"
            moveDialog = rootView.find(".tree-view-dialog").view()

        afterEach ->
          waits 50 # The move specs cause too many false positives because of their async nature, so wait a little bit before we cleanup

        it "opens a move dialog with the file's current path (excluding extension) populated", ->
          extension = path.extname(filePath)
          fileNameWithoutExtension = path.basename(filePath, extension)
          expect(moveDialog).toExist()
          expect(moveDialog.promptText.text()).toBe "Enter the new path for the file."
          expect(moveDialog.miniEditor.getText()).toBe(project.relativize(filePath))
          expect(moveDialog.miniEditor.getSelectedText()).toBe path.basename(fileNameWithoutExtension)
          expect(moveDialog.miniEditor.isFocused).toBeTruthy()

        describe "when the path is changed and confirmed", ->
          describe "when all the directories along the new path exist", ->
            it "moves the file, updates the tree view, and closes the dialog", ->
              newPath = path.join(rootDirPath, 'renamed-test-file.txt')
              moveDialog.miniEditor.setText(newPath)

              moveDialog.trigger 'core:confirm'

              expect(fs.exists(newPath)).toBeTruthy()
              expect(fs.exists(filePath)).toBeFalsy()
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
                expect(fs.exists(newPath)).toBeTruthy()
                expect(fs.exists(filePath)).toBeFalsy()

          describe "when a file or directory already exists at the target path", ->
            it "shows an error message and does not close the dialog", ->
              runs ->
                fs.writeSync(path.join(rootDirPath, 'target.txt'), '')
                newPath = path.join(rootDirPath, 'target.txt')
                moveDialog.miniEditor.setText(newPath)

                moveDialog.trigger 'core:confirm'

                expect(moveDialog.promptText.text()).toContain 'Error'
                expect(moveDialog.promptText.text()).toContain 'already exists'
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
            rootView.attachToDom()
            rootView.focus()
            expect(moveDialog.parent()).not.toExist()
            expect(rootView.getActiveView().isFocused).toBeTruthy()

      describe "when a file is selected that's name starts with a '.'", ->
        [dotFilePath, dotFileView, moveDialog] = []

        beforeEach ->
          dotFilePath = path.join(dirPath, ".dotfile")
          fs.writeSync(dotFilePath, "dot")
          dirView.collapse()
          dirView.expand()
          dotFileView = treeView.find('.file:contains(.dotfile)').view()

          waitsForFileToOpen ->
            dotFileView.click()

          runs ->
            treeView.trigger "tree-view:move"
            moveDialog = rootView.find(".tree-view-dialog").view()

        it "selects the entire file name", ->
          expect(moveDialog).toExist()
          expect(moveDialog.miniEditor.getText()).toBe(project.relativize(dotFilePath))
          expect(moveDialog.miniEditor.getSelectedText()).toBe '.dotfile'

      describe "when the project is selected", ->
        it "doesn't display the move dialog", ->
          treeView.root.click()
          treeView.trigger "tree-view:move"
          expect(rootView.find(".tree-view-dialog").view()).not.toExist()

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
      temporaryFilePath = path.join(project.getPath(), 'temporary')
      if fs.exists(temporaryFilePath)
        fs.remove(temporaryFilePath)
        waits(20)

    afterEach ->
      fs.remove(temporaryFilePath) if fs.exists(temporaryFilePath)

    describe "when a file is added or removed in an expanded directory", ->
      it "updates the directory view to display the directory's new contents", ->
        entriesCountBefore = null

        runs ->
          expect(fs.exists(temporaryFilePath)).toBeFalsy()
          entriesCountBefore = treeView.root.entries.find('.entry').length
          fs.writeSync temporaryFilePath, 'hi'

        waitsFor "directory view contens to refresh", ->
          treeView.root.entries.find('.entry').length == entriesCountBefore + 1

        runs ->
          expect(treeView.root.entries.find('.entry').length).toBe entriesCountBefore + 1
          expect(treeView.root.entries.find('.file:contains(temporary)')).toExist()
          fs.remove(temporaryFilePath)

        waitsFor "directory view contens to refresh", ->
          treeView.root.entries.find('.entry').length == entriesCountBefore

  describe "the hideVcsIgnoredFiles config option", ->
    describe "when the project's path is the repository's working directory", ->
      [dotGit, ignoreFile, ignoredFile, projectPath] = []

      beforeEach ->
        projectPath = path.resolve(project.getPath(), '..', 'git', 'working-dir')
        dotGit = path.join(projectPath, '.git')
        fs.move(path.join(projectPath, 'git.git'), dotGit)
        ignoreFile = path.join(projectPath, '.gitignore')
        fs.writeSync(ignoreFile, 'ignored.txt')
        ignoredFile = path.join(projectPath, 'ignored.txt')
        fs.writeSync(ignoredFile, 'ignored text')
        project.setPath(projectPath)
        config.set "tree-view.hideVcsIgnoredFiles", false

      afterEach ->
        fs.move(dotGit, path.join(projectPath, 'git.git'))
        fs.remove(ignoreFile)
        fs.remove(ignoredFile)

      it "hides git-ignored files if the option is set, but otherwise shows them", ->
        expect(treeView.find('.file:contains(ignored.txt)').length).toBe 1

        config.set("tree-view.hideVcsIgnoredFiles", true)
        expect(treeView.find('.file:contains(ignored.txt)').length).toBe 0

        config.set("tree-view.hideVcsIgnoredFiles", false)
        expect(treeView.find('.file:contains(ignored.txt)').length).toBe 1

    describe "when the project's path is a subfolder of the repository's working directory", ->
      [ignoreFile] = []

      beforeEach ->
        ignoreFile = path.join(project.getPath(), '.gitignore')
        fs.writeSync(ignoreFile, 'tree-view.js')
        config.set("tree-view.hideVcsIgnoredFiles", true)

      afterEach ->
        fs.remove(ignoreFile)

      it "does not hide git ignored files", ->
        expect(treeView.find('.file:contains(tree-view.js)').length).toBe 1

  describe "Git status decorations", ->
    [ignoreFile, ignoredFile, newDir, newFile, modifiedFile, originalFileContent, projectPath] = []

    beforeEach ->
      config.set "core.hideGitIgnoredFiles", false
      projectPath = project.resolve('../git/working-dir')
      fs.move(path.join(projectPath, 'git.git'), path.join(projectPath, '.git'))
      project.setPath(projectPath)

      newDir = path.join(project.getPath(), 'dir2')
      newFile = path.join(newDir, 'new2')
      fs.writeSync(newFile, '')
      project.getRepo().getPathStatus(newFile)

      ignoreFile = path.join(project.getPath(), '.gitignore')
      fs.writeSync(ignoreFile, 'ignored.txt')
      ignoredFile = path.join(project.getPath(), 'ignored.txt')
      fs.writeSync(ignoredFile, '')

      modifiedFile = path.join(project.resolve('dir'), 'b.txt')
      originalFileContent = fs.read(modifiedFile)
      fs.writeSync modifiedFile, 'ch ch changes'
      project.getRepo().getPathStatus(modifiedFile)

      treeView.updateRoot()
      treeView.root.entries.find('.directory:contains(dir)').view().expand()

    afterEach ->
      fs.remove(ignoreFile)
      fs.remove(ignoredFile)
      fs.remove(newDir)
      fs.writeSync modifiedFile, originalFileContent
      fs.move(path.join(projectPath, '.git'), path.join(projectPath, 'git.git'))

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
