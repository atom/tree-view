DefaultFileIcons = require '../lib/default-file-icons'
getIconServices = require '../lib/get-icon-services'

describe 'IconServices', ->
  describe 'FileIcons', ->
    afterEach ->
      getIconServices().resetFileIcons()
      getIconServices().resetElementIcons()

    it 'provides a default', ->
      expect(getIconServices().fileIcons).toBeDefined()
      expect(getIconServices().fileIcons).toBe(DefaultFileIcons)

    it 'allows the default to be overridden', ->
      service = new Object
      getIconServices().setFileIcons service
      expect(getIconServices().fileIcons).toBe(service)

    it 'allows the service to be reset to the default easily', ->
      service = new Object
      getIconServices().setFileIcons service
      getIconServices().resetFileIcons()
      expect(getIconServices().fileIcons).toBe(DefaultFileIcons)
