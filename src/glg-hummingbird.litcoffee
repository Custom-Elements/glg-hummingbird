# glg-hummingbird
Polymer element to maintain a hummingbird typeahead index that persists between browser restarts.

    hummingbird = require 'hummingbird'
    # shim for chrome file system access
    window.requestFileSystem = window.requestFileSystem ? window.webkitRequestFileSystem

    Polymer 'glg-hummingbird',

## Events
### hb-results
This event is emitted when there are new hummingbird results returned where the payload is the results array.

### no-hb-index
This event is emitted when attempting to load a non-existent hummingbird index from persistence or when
it found an index file but was unable to load it into hummingbird.

### hb-fs-error
This event is emitted when there is an error interacting with the file system where the payload is the error object.

### hb-loaded
This event is emitted after a persisted index is finished loading.

### hb-purged
This event is emitted after a persisted index is successfully deleted from local storage and memory.

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
          @fire 'hb-results', results
        , hbOptions

### jump
Method for retrieving a single result from a hummingbird index by ID
* id (required) - the ID of the document to be returned

      jump: (id) ->
        #lookup by ID
        @idx.jump id, (results) =>
          @fire 'hb-results', results

### upsert
Method to insert new entries into the index or update existing entries

      upsert: (doc) ->
        unless doc?.name? and doc?.id?
          console.error "glg-hb: every hummingbird document must have a minimum of 'name' and 'id' properties"
        else
          @idx.add doc

### bulkLoad
Method to insert new entries into the index or update existing entries

      bulkLoad: (docs) ->
        (@upsert doc for doc in docs)

### numItems
Method to insert new entries into the index or update existing entries

      numItems: () ->
        Object.keys(@idx?.metaStore?.root).length


### persist
Method to persist hummingbird index to localStorage

      persist: () ->
        window.requestFileSystem window.TEMPORARY, null
        , (fs) =>
          # success handler
          fs.root.getFile @indexName, {create: true}, (fileEntry) =>
            fileEntry.createWriter (fileWriter) =>
              fileWriter.onerror = @__fileErrorHandler(@indexName)
              fileWriter.onabort = () => console.debug "#{@indexName} write aborted"
              fileWriter.onprogress = () => console.debug "#{@indexName} write progress"
              fileWriter.onwritestart = () => console.debug "#{@indexName} write started"
              fileWriter.onwrite = () => console.debug "#{@indexName} writing"
              fileWriter.onwriteend = (evt) =>
                console.debug "Successfully persisted #{@indexName}"
                return
              try
                idxJson = @idx.toJSON()
                idxJsonStr = JSON.stringify(idxJson)
                fileWriter.write new Blob([idxJsonStr], {type: 'text/plain'})
              catch err
                console.error "glg-hb: unable to persist #{@indexName} index: #{JSON.stringify err}"
            , @__fileErrorHandler(@indexName)
          , @__fileErrorHandler(@indexName)
        , @__fileErrorHandler(@indexName)


### purge
Method to delete persisted file from disk

      purge: () ->
        window.requestFileSystem window.TEMPORARY, null
        , (fs) =>
          # success handler
          fs.root.getFile @indexName, { create: false }, (fileEntry) =>
            fileEntry.remove =>
              console.debug "glg-hb: purged persisted #{@indexName} index."
              @idx = new hummingbird()
              @fire 'hb-purged', @indexName
            , @__fileErrorHandler(@indexName)
          , @__fileErrorHandler(@indexName)
        , @__fileErrorHandler(@indexName)

### getCreateTime
Method that returns the timestamp for the index creation (not persist or load).
It has become the norm to incrementally add new documents to a hummingbird index, but not remove 'deleted' or obsolete documents.
Given that convention, this method enables the consuming application to determine whether the persisted index is 'old' and
should be purged from local storage and fully rebuilt from scratch to take into account documents that should no longer be in the index.

      getCreateTime: () ->
        @idx.createTime

### getLastUpdateTime
Method that returns the timestamp for the last time the index was updated (including create, add, or remove, but not persist or load)

      getLastUpdateTime: () ->
        @idx.lastUpdate

### __fileErrorHandler
Internal method to handle various filesystem errors

      __fileErrorHandler: (indexName) ->
        #closure to maintain reference to Polymer object in scope
        (err) =>
          if err.name is "NotFoundError"
            console.debug "glg-hb: #{indexName} - #{err.name}: #{err.message}"
            @fire 'no-hb-index', @indexName
          else
            console.error "glg-hb: #{indexName} - #{err.name}: #{err.message}"
            err.message = "#{@indexName}: #{err.message}"
            @fire 'hb-fs-error', err

## Polymer Lifecycle
On element creation, load the named index if it exists and make it immediately available for use.

      created: ->
        # create an empty index
        @idx = new hummingbird()
        window.requestFileSystem window.TEMPORARY, null
        , (fs) =>
          # success handler
          fs.root.getFile @indexName, {}, (fileEntry) =>
            fileEntry.file (file) =>
              reader = new FileReader()
              reader.onerror = @__fileErrorHandler(@indexName)
              reader.onloadend = (evt) ->
                # @result is the text of the file read
                if @result? and @result isnt ''
                  try
                    # if we found a persisted index, replace our empty index with it
                    console.debug "glg-hb: loading index #{_this.indexName} from localStorage"
                    _this.idx = hummingbird.Index.load JSON.parse(@result)
                    _this.fire 'hb-loaded', _this.indexName
                  catch err
                    console.error "glg-hb: unable to load persisted #{_this.indexName} index: #{JSON.stringify err}"
                    _this.fire 'no-hb-index', _this.indexName
                else
                  console.warn "glg-hb: found an empty file when trying to load persisted #{_this.indexName} index."
                  _this.fire 'no-hb-index', _this.indexName
              reader.readAsText file
            , @__fileErrorHandler(@indexName)
          , @__fileErrorHandler(@indexName)
        , @__fileErrorHandler(@indexName)

      ready: ->

      attached: ->

      domReady: ->

      detached: ->
