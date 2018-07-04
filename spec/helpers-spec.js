const path = require('path')

const helpers = require('../lib/helpers')

describe('Helpers', () => {
  describe('getFullExtension', () => {
	it('returns the extension for a simple file', () => {
	  expect(helpers.getFullExtension('filename.txt')).toBe('.txt')
	})

	it('returns the extension for a path', () => {
	  expect(helpers.getFullExtension(path.join('path', 'to', 'filename.txt'))).toBe('.txt')
	})

	it('returns the full extension for a filename with more than one extension', () => {
	  expect(helpers.getFullExtension('index.html.php')).toBe('.html.php')
	  expect(helpers.getFullExtension('archive.tar.gz.bak')).toBe('.tar.gz.bak')
	})

	it('returns no extension when the filename begins with a period', () => {
	  expect(helpers.getFullExtension('.gitconfig')).toBe('')
	  expect(helpers.getFullExtension(path.join('path', 'to', '.gitconfig'))).toBe('')
	})
  })
})
