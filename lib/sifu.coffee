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

      @_log 'starting to lint.'

      args = ['validate', '-f', filePath.split(/\//).pop()] # Arguments to javac

      # Execute javac
      atom.notifications.addInfo("validating specification... it should take a few seconds...")
      helpers.exec("sifu", args, {
        stream: 'stdout',
        cwd: wd,
        allowEmptyStderr: true
      })
      .then (val) =>
        @_log 'parsing:\n', val
        @parse(val, textEditor)

  parse: (javacOutput, textEditor) ->
    errors = []

    # This regex helps to estimate the column number based on the
    #   caret (^) location.
    @caretRegex ?= /^( *)\^/
    # Split into lines
    lines = javacOutput.split /\r?\n/

    for line in lines
      match = line.match /.*\[ERROR\][^ ]* (\d+).+<-(.*)/
      if !!match
        [lineNum, mess] = match[1..2]
        lineNum-- # Fix range-beginning
        errors.push
          type: "error"
          text: mess.replace /\[\d+m/g, ''
          filePath: textEditor.getPath()   # Full path to file
          range: [[lineNum, 0], [lineNum, 0]] # Set range-beginnings

      match2 = line.match /\[(\d+)\.(\d+)\] failure:(.*)/
      if !!match2
        [lineNum, lineRow, mess] = match2[1..3]
        lineNum-- # Fix range-beginning
        errors.push
          type: "error"
          text: mess.replace /\[\d+m/g, ''
          filePath: textEditor.getPath()   # Full path to file
          range: [[lineNum, 0], [lineNum, 0]] # Set range-beginnings

      match3 = line.match /.*\[ERROR\][^ ]*Unknown(.*)/
      if !!match3
        mess = match3[1]
        errors.push
          type: "error"
          text: 'Unknown internal error occurred.', ''
          filePath: textEditor.getPath()   # Full path to file
          range: [[0, 0], [0, 0]] # Set range-beginnings

    @_log 'returning', errors.length, 'linter-messages.'

    if (errors.length == 0)
      atom.notifications.addInfo("Validating completed without errors.")
    else
      atom.notifications.addError("Validation failed!")

    return errors

  _log: (msgs...) ->
    javacPrefix = 'linter-javac: '
    console.log javacPrefix + msgs.join(' ')