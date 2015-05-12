# glg-hummingbird
Polymer element to maintain hummingbird typeahead lists in browsers' localStorage

    hummingbird = require 'hummingbird'

    Polymer 'glg-hummingbird',

## hbresults event
If no callback is provided to the `search` method, then an event `hbresults` will be fired
when results have been retrieved from the hummingbird index.

## search
Method for retrieving results from a humminbird index
* query (required) - either an ID to be looked up or string to be tokenized and searched
* callback (optional) - a function to be called on the results of a search

      search: (query, callback) ->
        hbOptions =
          scoreThreshold: @scoreThreshold ? 0
          secondarySortField: @secondarySortField
          secondarySortOrder: @secondarySortOrder
          howMany: @howMany ? 10
          startPos: @startPos ? 0

        callback = callback ? (results) ->
          @fire 'hbresults', results

        if isNaN(query)
          #lookup by fuzzy name match
          @idx.search query, callback, hbOptions
        else
          #lookup by ID
          @idx.jump query, callback, hbOptions

## upsert
Method to insert new entries into the index or update existing entries

      upsert: (doc) ->
        #TODO: Should we set a timer after each upsert to determine when to persist?
        if doc? and Object.isObject doc
          unless doc.name? and doc.id?
            console.error "Every hummingbird document must have a minimum of 'name' and 'id' properties"
          else
            @idx.add doc
        else
          console.error "Only valid javascript objects can be added to a hummingbird index"

## persist
Method to persist hummingbird index to localStorage

      persist: () ->
        #TODO: how do we know when to persist?  Do we just wait to be called?
        #TODO: maybe we set a timer on Upsert?
        localStorage.add @idx.toJson(), @indexName if @indexName?

## load
Method to load a persisted hummingbird index from localStorage

      load: () ->
        #TODO: is loading from localStorage async?
        # try to load index from localStorage if it exists
        @idx.load('path_to_persisted_index')


## Polymer Lifecycle

      created: ->

      ready: ->
        @idx = new hummingbird(@variants)
        @load()

      attached: ->

      domReady: ->

      detached: ->
