# glg-hummingbird
Polymer element to maintain hummingbird typeahead lists in browsers' localStorage

    hummingbird = require 'hummingbird'
    # shim for chrome file system access
    window.requestFileSystem = window.requestFileSystem ? window.webkitRequestFileSystem

    Polymer 'glg-hummingbird',

## Events
### HB_RESULTS
This event is emitted when there are new hummingbird results returned where the payload is the results array.

### NO_HB_INDEX
This event is emitted when attempting to load a non-existent hummingbird index from persistence.

### FS_ERROR
This event is emitted when there is an error interacting with the file system where the payload is the error object.

## Methods
### search
Method for retrieving results from a humminbird index
* query (required) - a string to be tokenized and searched

      search: (query) ->
        hbOptions =
          scoreThreshold: @scoreThreshold ? 0
          secondarySortField: @secondarySortField
          secondarySortOrder: @secondarySortOrder
          howMany: @howMany ? 10
          startPos: @startPos ? 0

        #lookup by fuzzy name match
        @idx.search query, (results) =>
          @fire 'HB_RESULTS', results
        , hbOptions

### jump
Method for retrieving a single result from a hummingbird index by ID
* id (required) - the ID of the document to be returned

      jump: (id) ->
        #lookup by ID
        @idx.jump id, (results) =>
          @fire 'HB_RESULTS', results

### upsert
Method to insert new entries into the index or update existing entries

      upsert: (doc) ->
        unless doc?.name? and doc?.id?
          console.error "glg-hb: every hummingbird document must have a minimum of 'name' and 'id' properties"
        else
          @idx.add doc

### persist
Method to persist hummingbird index to localStorage

      persist: () ->
        window.requestFileSystem window.TEMPORARY, null
        , (fs) =>
          # success handler
          fs.root.getFile @indexName, {create: true}, (fileEntry) =>
            fileEntry.createWriter (fileWriter) =>
              fileWriter.onerror = @__fileErrorHandler()
              fileWriter.onwriteend = (evt) ->
                # Do we care to share success?
                return
              try
                fileWriter.write new Blob([JSON.stringify(@idx.toJSON())], {type: 'text/plain'})
              catch err
                console.error "glg-hb: unable to persist #{@indexName} index: #{JSON.stringify err}"
            , @__fileErrorHandler()
          , @__fileErrorHandler()
        , @__fileErrorHandler()

### __fileErrorHandler
Internal method to handle various filesystem errors

      __fileErrorHandler: () ->
        #closure to maintain reference to Polymer object in scope
        (err) =>
          switch err.code
            when FileError.QUOTA_EXCEEDED_ERR
              console.error 'glg-hb: QUOTA_EXCEEDED_ERR'
              @fire 'FS_ERROR', err
            when FileError.NOT_FOUND_ERR
              console.debug "glg-hb: no persisted index: #{JSON.stringify err}"
              @fire 'NO_HB_INDEX'
            when FileError.SECURITY_ERR
              console.error 'glg-hb: SECURITY_ERR'
              @fire 'FS_ERROR', err
            when FileError.INVALID_MODIFICATION_ERR
              console.error 'glg-hb: INVALID_MODIFICATION_ERR'
              @fire 'FS_ERROR', err
            when FileError.INVALID_STATE_ERR
              console.error 'glg-hb: INVALID_STATE_ERR'
              @fire 'FS_ERROR', err
            else
              console.error 'glg-hb: unknown file system error'
              @fire 'FS_ERROR', err

## Polymer Lifecycle

      created: ->
        # create an empty index
        @idx = new hummingbird()
        window.requestFileSystem window.TEMPORARY, null
        , (fs) =>
          # success handler
          fs.root.getFile @indexName, {}, (fileEntry) =>
            fileEntry.file (file) =>
              reader = new FileReader()
              reader.onerror = @__fileErrorHandler()
              reader.onloadend = (evt) ->
                # @result is the text of the file read
                if @result? and @result isnt ''
                  try
                    # if we found a persisted index, replace our empty index with it
                    _this.idx = hummingbird.Index.load JSON.parse(@result)
                  catch err
                    console.error "glg-hb: unable to load persisted #{_this.indexName} index: #{JSON.stringify err}"
                else
                  console.warn "glg-hb: found an empty file when trying to load persisted #{_this.indexName} index."
                  _this.__fileErrorHandler() {code:FileError.NOT_FOUND_ERR}
              reader.readAsText file
            , @__fileErrorHandler()
          , @__fileErrorHandler()
        , @__fileErrorHandler()

      ready: ->

      attached: ->

      domReady: ->

      detached: ->
