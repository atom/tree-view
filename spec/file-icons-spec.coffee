DefaultFileIcons = require '../lib/default-file-icons'
IconServices = require '../lib/icon-services'

describe 'IconServices', ->
  describe 'FileIcons', ->
    afterEach ->
      IconServices.resetFileIcons()
      IconServices.resetElementIcons()

    it 'provides a default', ->
      expect(IconServices.fileIcons).toBeDefined()
      expect(IconServices.fileIcons).toBe(DefaultFileIcons)

    it 'allows the default to be overridden', ->
      service = new Object
      IconServices.setFileIcons service
      expect(IconServices.fileIcons).toBe(service)

    it 'allows the service to be reset to the default easily', ->
      service = new Object
      IconServices.setFileIcons service
      IconServices.resetFileIcons()
      expect(IconServices.fileIcons).toBe(DefaultFileIcons)
