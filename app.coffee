'use strict'

# Templates:
T =
  frontView: '<img alt="<%= slug %>" src="<%= pic %>" />'
  thumbsView: '<div class="last"></div><ul></ul><div class="next"></div>'
  thumbView: '<img alt="" src="<%= thumb %>" class="<%= state %>" />'



class Picture extends Backbone.Model

  defaults:
    slug: ''
    thumb: ''
    pic: ''
    state: ''

  initialize: ->
    slug = @get('pic')
    try
      slug = /([^\.\/]+)\.[^\.]*?$/.exec(slug)[1]
    catch e
      console.error e
    @set 'slug', slug

  getRoute: ->
    "#pic/#{@get('slug')}"

  select: ->
    @set state: 'selected'

  deselect: ->
    @set state: ''


class Pictures extends Backbone.Collection

  url: 'pictures.json'

  model: Picture

  select: (model) ->
    @selected.deselect()  if @selected?
    @selected = model
    model.select()

  selectedPicture: ->
    @selected

  _incrementSelection: (deltaIndex) ->
    i = @selectedPicture().get 'index'
    l = @length
    (i + l + deltaIndex) % l

  selectNext: =>
    @select @at @_incrementSelection 1

  selectLast: =>
    @select @at @_incrementSelection -1


class FrontView extends Backbone.View

  template: _.template(T.frontView)

  render: ->
    @$el.html @template @model.selectedPicture().toJSON()
    @


class ThumbView extends Backbone.View

  tagName: 'li'

  template: _.template(T.thumbView)

  events:
    click: "onClick"

  render: ->
    @$el.html @template @model.toJSON()
    @

  onClick: ->
    notifier.trigger 'picture:selected', @model


class ThumbsView extends Backbone.View

  template: _.template(T.thumbsView)

  initialize: (options) ->
    @limit = options.limit

  render: ->
    l = @collection.length
    selectedIndex = @collection.selectedPicture().get('index') + l
    halfRange = Math.floor(@limit / 2)
    $el = @$el.html(@template)
    $ul = @$('ul')
    for i in [selectedIndex - halfRange .. selectedIndex + halfRange]
      t = @collection.at( i % l )
      view = new ThumbView(model: t).render()
      $ul.append view.el


class AppView extends Backbone.View

  el: $("#container")

  events:
    "click .front img": "selectNext"

  selectNext: ->
    @pictures.selectNext()

  initialize: ->
    @pictures = new Pictures
    @pictures.fetch
      async: false,
      error: (_model, resp) ->
        throw new Error "JSON sux?: " + resp.responseText

    # Used for simple prev / next pic functions:
    @pictures.each (pic, index) -> pic.set 'index', index

    @frontview = new FrontView
      el: @$('.front')
      model: @pictures

    @thumbsview = new ThumbsView
      el: @$('.thumbs')
      collection: @pictures
      limit: 7

    notifier.bind 'picture:selected', @onSelectPicture, @
    @pictures.bind 'change', @render, @


  render: ->
    app_router.navigate @pictures.selectedPicture().getRoute()
    @frontview.render()
    @thumbsview.render()

  onSelectPicture: (pic) ->
    @pictures.select pic

  onKeyDown: (e) =>
    switch e.which
      # Left key:
      when 37
        @pictures.selectLast()
        false
      # Space, Right key:
      when 32, 39
        @pictures.selectNext()
        false


class AppRouter extends Backbone.Router

  routes:
    "pic/:slug": "showPicture"
    "*args": "defaultAction"

  showPicture: (slug) ->
    console.log 'show picture', slug
    pic = app.pictures.find (pic) ->
      slug is pic.get 'slug'
    if pic
      app.pictures.select pic
    else
      alert 'Sorry... no picture at that URL.'
      @defaultAction()

  defaultAction: (args) ->
    app.pictures.select app.pictures.at 0


notifier = _.extend {}, Backbone.Events
app = new AppView
app_router = new AppRouter
Backbone.history.start()

$(window).on
  keydown: app.onKeyDown


# For convenience while developing:
window.app = app
