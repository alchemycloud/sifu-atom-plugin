{Directory, CompositeDisposable} = require 'atom'
# require statements were moved into the provideLinter-function
_os = null
path = null
helpers = null
fs = null

module.exports =
  activate: (state) ->
# state-object as preparation for user-notifications
    @state = if state then state or {}
    # language-patterns

    require('atom-package-deps').install('language-sifu')

  deactivate: ->

  serialize: ->
    return @state

  provideLinter: ->
    # doing requirement here is lowering load-time
    if _os == null
      _os = require 'os'
      path = require 'path'
      helpers = require 'atom-linter'
      fs = require 'fs'
      @_log 'requiring modules finished.'

    @_log 'providing linter, examining javac-callability.'

    grammarScopes: ['source.sifu']
    scope: 'project'
    lintOnFly: false       # Only lint on save

    lint: (textEditor) =>
      filePath = textEditor.getPath()
      wd = path.dirname filePath
      searchDir = @getProjectRootDir() || path.dirname filePath
      @_log 'starting to lint.'

      lstats = fs.lstatSync searchDir

      args = ['validate'] # Arguments to javac

      # Execute javac
      atom.notifications.addInfo("Validating specification... it will take few seconds.")
      helpers.exec("sifu", args, {
        stream: 'stdout',
        cwd: wd,
        allowEmptyStderr: true
      })
      .then (val) =>
        @_log 'parsing:\n', val
        @parse(val, textEditor)

  parse: (javacOutput, textEditor) ->
    messages = []

    # This regex helps to estimate the column number based on the
    #   caret (^) location.
    @caretRegex ?= /^( *)\^/
    # Split into lines
    lines = javacOutput.split /\r?\n/

    for line in lines
      match = line.match /.+\[ERROR\].* (\d+).+<-(.*)/
      if !!match
        [lineNum, mess] = match[1..2]
        lineNum-- # Fix range-beginning
        messages.push
          type: "error"
          text: mess.replace /\[\d+m/g, ''
          filePath: textEditor.getPath()   # Full path to file
          range: [[lineNum, 0], [lineNum, 0]] # Set range-beginnings

      match2 = line.match /\[(\d+)\.(\d+)\] failure:(.*)/
      if !!match2
        [lineNum, lineRow, mess] = match2[1..3]
        lineNum-- # Fix range-beginning
        messages.push
          type: "error"
          text: mess.replace /\[\d+m/g, ''
          filePath: textEditor.getPath()   # Full path to file
          range: [[lineNum, 0], [lineNum, 0]] # Set range-beginnings

    @_log 'returning', messages.length, 'linter-messages.'

    atom.notifications.addInfo("Validating completed.")
    return messages

  getProjectRootDir: ->
    textEditor = atom.workspace.getActiveTextEditor()
    if !textEditor || !textEditor.getPath()
      # default to building the first one if no editor is active
      if not atom.project.getPaths().length
        return false

      return atom.project.getPaths()[0]

    # otherwise, build the one in the root of the active editor
    return atom.project.getPaths()
    .sort((a, b) -> (b.length - a.length))
    .find (p) ->
      realpath = fs.realpathSync(p)
      # TODO: The following fails if there's a symlink in the path
      return textEditor.getPath().substr(0, realpath.length) == realpath

  _log: (msgs...) ->
    javacPrefix = 'linter-javac: '
    console.log javacPrefix + msgs.join(' ')