DefaultFileIcons = require '../lib/default-file-icons'
IconServices = require '../lib/icon-services'

describe 'IconServices', ->
  describe 'FileIcons', ->
    afterEach ->
      IconServices.set "file-icons", new DefaultFileIcons

    it 'provides a default', ->
      expect(IconServices.get "file-icons").toBeDefined()
      expect(IconServices.get "file-icons").not.toBeNull()

    it 'allows the default to be overridden', ->
      service = new Object
      IconServices.set "file-icons", service

      expect(IconServices.get "file-icons").toBe(service)

    it 'allows the service to be reset to the default easily', ->
      service = new Object
      IconServices.set "file-icons", service
      IconServices.reset "file-icons"

      expect(IconServices.get "file-icons").not.toBe(service)
