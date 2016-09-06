if unsafeWindow? # для Tampermonkey
  window.$ = unsafeWindow.$
  window.etSubsets = unsafeWindow.etSubsets

Array.prototype.rastMove = (from, to)->
  @splice(to, 0, @splice(from, 1)[0]);

window.rast =

  $getTextarea: ->
    $('#wpTextbox1')

  $getCurrentInput: ->
    $(document.activeElement)

  insertion: {
    replaceSpecsymbols: (s, symbols, toFunc) ->
      res = ''
      c = undefined
      i = 0
      while i < s.length
        c = s.charAt(i)
        if rast.insertion.isEscaped(s, i)
          res += c
        else if symbols.indexOf(c) > -1
          res += toFunc(c)
        else
          res += c
        i++
      res

    isEscaped: (s, i) ->
      escSymbols = 0
      i--
      while i > -1 and s.charAt(i) == '\\'
        escSymbols++
        i--
      escSymbols % 2 == 1

    indexOfUnescaped: (s, symbol) ->
      index = -1
      i = 0
      while i < s.length
        if s.charAt(i) == symbol and !rast.insertion.isEscaped(s, i)
          index = i
          break
        i++
      index
  }

  installJQueryPlugins: ->
    $.fn.extend
      throbber: (visibility, position, size)->
        $elem = $(@)
        $throbber = $elem.data('rastThrobber')
        if $throbber
          $throbber.toggle(visibility)
        else
          size = size || '20px'
          $throbber = $('<img>')
          $throbber.attr('src', 'https://upload.wikimedia.org/wikipedia/commons/d/de/Ajax-loader.gif')
          $throbber.css('width', size)
          $throbber.css('height', size)
          $elem.data('rastThrobber', $throbber)
          $elem[position]($throbber)
          $elem.addClass('withRastThrobber')
        $elem

      asnavSelect: (id) ->
        $tabs = $(@)
        $tabs.find('.asnav-content').hide()
        $tabs.find('.asnav-tabs .asnav-selectedtab').removeClass('asnav-selectedtab')
        tabContent = $tabs.find('.asnav-tabs [data-contentid="' + id + '"]:first')
        if tabContent.length
          tabContent.addClass('asnav-selectedtab')
          $tabs.find('#' + id).show()
        else
          first = $tabs.find('.asnav-tabs [data-contentid]:first').addClass('asnav-selectedtab')
          $tabs.find('#' + first.attr('data-contentid')).show()

      etMakeTabs: (activeTabId) ->
        tabs = $(@)

        selectFunc = (a) ->
          $a = $(a)
          tabs.asnavSelect $a.attr('data-contentid')
          $a.trigger 'asNav:select', $a.attr('data-contentid')

        tabs.on 'click', '.asnav-tabs [data-contentid]', ->
          selectFunc(@)
        tabs.asnavSelect activeTabId

    $.fn.extend
      insertTag: (beginTag, endTag) ->
        @each ->
          SelReplace = undefined
          pos = undefined
          sel = undefined

          SelReplace = (s) ->
            rast.insertion.replaceSpecsymbols s, '\\$', (c) ->
              if c == '\\'
                return ''
              else if c == '$'
                return sel

          $(this).focus()
          sel = $(this).textSelection('getSelection')
          beginTag = SelReplace(beginTag)
          endTag = if endTag then SelReplace(endTag) else ''
          $(this).textSelection 'encapsulateSelection',
            pre: beginTag or ''
            peri: ''
            post: endTag or ''
            replace: true
          if endTag and sel != ''
            pos = $(this).textSelection('getCaretPosition')
            return $(this).textSelection('setSelection', start: pos - (endTag.length))

      setSelection: (text) ->
        @textSelection 'encapsulateSelection',
          post: text
          replace: true

      getSelection: (text) ->
        @textSelection 'getSelection'

  name: (constructor)->
    'rast.' + constructor.name

  # для копіювання стану (з https://github.com/pvorb/node-clone/blob/master/clone.js)
  clone: do ->
    `var clone`

    ###*
    # Clones (copies) an Object using deep copying.
    #
    # This function supports circular references by default, but if you are certain
    # there are no circular references in your object, you can save some CPU time
    # by calling clone(obj, false).
    #
    # Caution: if `circular` is false and `parent` contains circular references,
    # your program may enter an infinite loop and crash.
    #
    # @param `parent` - the object to be cloned
    # @param `circular` - set to true if the object to be cloned may contain
    #    circular references. (optional - true by default)
    # @param `depth` - set to a number if the object is only to be cloned to
    #    a particular depth. (optional - defaults to Infinity)
    # @param `prototype` - sets the prototype to be used when cloning an object.
    #    (optional - defaults to parent prototype).
    ###

    clone = (parent, circular, depth, prototype) ->
      filter = undefined
      # recurse this function so we don't reset allParents and allChildren

      _clone = (parent, depth) ->
        # cloning null always returns null
        if parent == null
          return null
        if depth == 0
          return parent
        child = undefined
        proto = undefined
        if typeof parent != 'object'
          return parent
        if clone.__isArray(parent)
          child = []
        else if clone.__isRegExp(parent)
          child = new RegExp(parent.source, __getRegExpFlags(parent))
          if parent.lastIndex
            child.lastIndex = parent.lastIndex
        else if clone.__isDate(parent)
          child = new Date(parent.getTime())
        else if useBuffer and Buffer.isBuffer(parent)
          child = new Buffer(parent.length)
          parent.copy child
          return child
        else
          if typeof prototype == 'undefined'
            proto = Object.getPrototypeOf(parent)
            child = Object.create(proto)
          else
            child = Object.create(prototype)
            proto = prototype
        if circular
          index = allParents.indexOf(parent)
          if index != -1
            return allChildren[index]
          allParents.push parent
          allChildren.push child
        for i of parent
          attrs = undefined
          if proto
            attrs = Object.getOwnPropertyDescriptor(proto, i)
          if attrs and attrs.set == null
            continue
          child[i] = _clone(parent[i], depth - 1)
        child

      if typeof circular == 'object'
        depth = circular.depth
        prototype = circular.prototype
        filter = circular.filter
        circular = circular.circular
      # maintain two arrays for circular references, where corresponding parents
      # and children have the same index
      allParents = []
      allChildren = []
      useBuffer = typeof Buffer != 'undefined'
      if typeof circular == 'undefined'
        circular = true
      if typeof depth == 'undefined'
        depth = Infinity
      _clone parent, depth

    # private utility functions

    __objToStr = (o) ->
      Object::toString.call o

    __isDate = (o) ->
      typeof o == 'object' and __objToStr(o) == '[object Date]'

    __isArray = (o) ->
      typeof o == 'object' and __objToStr(o) == '[object Array]'

    __isRegExp = (o) ->
      typeof o == 'object' and __objToStr(o) == '[object RegExp]'

    __getRegExpFlags = (re) ->
      flags = ''
      if re.global
        flags += 'g'
      if re.ignoreCase
        flags += 'i'
      if re.multiline
        flags += 'm'
      flags

    'use strict'

    ###*
    # Simple flat clone using prototype, accepts only objects, usefull for property
    # override on FLAT configuration object (no nested props).
    #
    # USE WITH CAUTION! This may not behave as you wish if you do not know how this
    # works.
    ###

    clone.clonePrototype = (parent) ->
      if parent == null
        return null

      c = ->

      c.prototype = parent
      new c

    clone.__objToStr = __objToStr
    clone.__isDate = __isDate
    clone.__isArray = __isArray
    clone.__isRegExp = __isRegExp
    clone.__getRegExpFlags = __getRegExpFlags
    clone

  focusWithoutScroll: (elem) ->
    x = undefined
    y = undefined
    x = undefined
    y = undefined
    if typeof window.pageXOffset != 'undefined'
      x = window.pageXOffset
      y = window.pageYOffset
    else if typeof window.scrollX != 'undefined'
      x = window.scrollX
      y = window.scrollY
    else if document.documentElement and typeof document.documentElement.scrollLeft != 'undefined'
      x = document.documentElement.scrollLeft
      y = document.documentElement.scrollTop
    else
      x = document.body.scrollLeft
      y = document.body.scrollTop
    elem.focus()
    if typeof x != 'undefined'
      setTimeout (->
        window.scrollTo x, y
        return
      ), 100

  processSelection: (txtFunc) ->
    $textarea = rast.$getTextarea()
    txt = $textarea.getSelection()
    $textarea.setSelection txtFunc(txt)

  perLineReplace: (str, regex, to) ->
    str = str.split('\n')
    len = str.length
    i = 0
    while i < len
      str[i] = str[i].replace(regex, to)
      i += 1
    str.join '\n'

  linkifyList: (s) ->
    rast.perLineReplace s, /[^*;#—\s,][^*\.#—;,]+/g, '[[$&]]'

  simpleList: (s) ->
    rast.perLineReplace s, /(([\*#]*)\s*)(.+)/g, '*$2 $3'

  numericList: (s) ->
    rast.perLineReplace s, /(([\*#]*)\s*)(.+)/g, '#$2 $3'

  dot: '·п'

  searchAndReplace:
    getReplaceForm: ->
      '\u0009\u0009\u0009\u0009\u0009\u0009\u0009<div id="et-replace-message">\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009<div id="et-replace-nomatch">Нема збігів</div>\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009<div id="et-replace-success">Заміни виконано</div>\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009<div id="et-replace-emptysearch">Вкажіть рядок до пошуку</div>\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009<div id="et-replace-invalidregex">Неправильний регулярний вираз</div>\u0009\u0009\u0009\u0009\u0009\u0009\u0009</div>\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009<span class="et-field-wrapper">\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009<label for="et-replace-search" style="float: left; min-width: 6em;">Шукати</label>\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009<span style="display: block; overflow: hidden;">\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009  <input type="text" id="et-replace-search" style="width: 100%;"/>\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009</span>\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009</span>\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009<div style="clear: both;"/>\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009<span class="et-field-wrapper">\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009<label for="et-replace-replace" style="float: left; min-width: 6em;">Заміна</label>\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009<span style="display: block; overflow: hidden;">\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009  <input type="text" id="et-replace-replace" style="width: 100%;"/>\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009</span>\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009</span>\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009<div style="clear: both;"/>\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009<input id="et-tool-replace-button-findnext" type="button" value="Шукати" />\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009<input id="et-tool-replace-button-replace" type="button" value="Замінити" />\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009<input id="et-tool-replace-button-replaceall" type="button" value="Замінити все" />\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009<span class="et-field-wrapper">\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009<input type="checkbox" id="et-replace-case"/>\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009<label for="et-replace-case">Враховувати регістр</label>\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009</span>\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009<span class="et-field-wrapper">\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009<input type="checkbox" id="et-replace-regex"/>\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009<label for="et-replace-regex">Регулярний вираз</label>\u0009\u0009\u0009\u0009\u0009\u0009\u0009\u0009</span>\u0009\u0009\u0009'

    replaceFormInit: ->
      comsole.log 'adsf'
      rast.searchAndReplace.offset = 0
      rast.searchAndReplace.matchIndex = 0
      $(document).off('click', '#et-tool-replace-button-findnext').on 'click', '#et-tool-replace-button-findnext', (e) ->
        rast.searchAndReplace.doSearchReplace 'find'
      $(document).off('click', '#et-tool-replace-button-replace').on 'click', '#et-tool-replace-button-replace', (e) ->
        rast.searchAndReplace.doSearchReplace 'replace'
      $(document).off('click', '#et-tool-replace-button-replaceall').on 'click', '#et-tool-replace-button-replaceall', (e) ->
        rast.searchAndReplace.doSearchReplace 'replaceAll'
      $('#et-replace-nomatch, #et-replace-success,\u0009\u0009\u0009 #et-replace-emptysearch, #et-replace-invalidregex').hide()

    doSearchReplace: (mode) ->
      offset = undefined
      textRemainder = undefined
      regex = undefined
      index = undefined
      i = undefined
      start = undefined
      end = undefined
      $('#et-replace-nomatch, #et-replace-success,\u0009\u0009\u0009 #et-replace-emptysearch, #et-replace-invalidregex').hide()
      # Search string cannot be empty
      searchStr = $('#et-replace-search').val()
      if searchStr == ''
        $('#et-replace-emptysearch').show()
        return
      # Replace string can be empty
      replaceStr = $('#et-replace-replace').val()
      # Prepare the regular expression flags
      flags = 'm'
      matchCase = $('#et-replace-case').is(':checked')
      if !matchCase
        flags += 'i'
      isRegex = $('#et-replace-regex').is(':checked')
      if !isRegex
        searchStr = mw.RegExp.escape(searchStr)
      if mode == 'replaceAll'
        flags += 'g'
      try
        regex = new RegExp(searchStr, flags)
      catch e
        $('#et-replace-invalidregex').show()
        return
      $textarea = rast.$getTextarea()
      text = $textarea.textSelection('getContents')
      match = false
      if mode != 'replaceAll'
        if mode == 'replace'
          offset = rast.searchAndReplace.matchIndex
        else
          offset = rast.searchAndReplace.offset
        textRemainder = text.substr(offset)
        match = textRemainder.match(regex)
      if !match
        # Search hit BOTTOM, continuing at TOP
        # TODO: Add a "Wrap around" option.
        offset = 0
        textRemainder = text
        match = textRemainder.match(regex)
      if !match
        $('#et-replace-nomatch').show()
        return
      if mode == 'replaceAll'
        newText = text.replace(regex, replaceStr)
        $textarea.select().textSelection 'encapsulateSelection',
          'peri': newText
          'replace': true
        $('#et-replace-success').text('Здійснено замін: ' + match.length).show()
        rast.searchAndReplace.offset = 0
        rast.searchAndReplace.matchIndex = 0
      else
        if mode == 'replace'
          actualReplacement = undefined
          if isRegex
            # If backreferences (like $1) are used, the actual actual replacement string will be different
            actualReplacement = match[0].replace(regex, replaceStr)
          else
            actualReplacement = replaceStr
          if match
            # Do the replacement
            $textarea.textSelection 'encapsulateSelection',
              'peri': actualReplacement
              'replace': true
            # Reload the text after replacement
            text = $textarea.textSelection('getContents')
          # Find the next instance
          offset = offset + match[0].length + actualReplacement.length
          textRemainder = text.substr(offset)
          match = textRemainder.match(regex)
          if match
            start = offset + match.index
            end = start + match[0].length
          else
            # If no new string was found, try searching from the beginning.
            # TODO: Add a "Wrap around" option.
            textRemainder = text
            match = textRemainder.match(regex)
            if match
              start = match.index
              end = start + match[0].length
            else
              # Give up
              start = 0
              end = 0
        else
          start = offset + match.index
          end = start + match[0].length
        rast.searchAndReplace.matchIndex = start
        $textarea.textSelection 'setSelection',
          'start': start
          'end': end
        $textarea.textSelection 'scrollToCaretPosition'
        rast.searchAndReplace.offset = end
        context = rast.searchAndReplace.context
        $textarea[0].focus()

  ieVersion: ->
          #http://james.padolsey.com/javascript/detect-ie-in-js-using-conditional-comments/
          v = 3
          div = document.createElement('div')
          all = div.getElementsByTagName('i')
          while (div.innerHTML = '<!--[if gt IE ' + ++v + ']><i></i><![endif]-->'; all[0])
            0
          if v > 4 then v else undefined

class rast.PanelDrawer

  constructor: (@$panel, @subsetWrapper, @index, @mode, @subsets, @eventsHandler)->

  draw: ->
    if @mode == 'edit'
      @drawEditMode()
    else if @mode == 'view'
      generateMethod = 'generateHtml'
      @generateHtml(@$panel, @subsetWrapper.slots, generateMethod)

  sortableSlots: ($slots)->
    $($slots).sortable
      delay: 150
      containment: $slots
      forceHelperSize: true
      forcePlaceholderSize: true
      items: '[data-id]'
      start: (event, ui)->
        copy = $(ui.item[0].outerHTML).clone()
      placeholder: {
        element: (copy, ui)->
          $('<span class="ui-state-highlight">' + copy[0].innerHTML + '</li>')
        update: ->
      }
      receive: (event, ui)=>
        slotClass = eval(ui.item.attr('data-slot-class'))
        index = $(event.target).data().sortable.currentItem.index()
        newSlot = @subsets.addSlot(slotClass, @subsetWrapper, index)
        @eventsHandler.onSlotAdded(newSlot)
      update: (event, ui)=>
        newSlotIndex = ui.item.index('[data-id]') - 1
        return if newSlotIndex < 0
        return unless $(ui.item).attr('data-id')
        slotId = parseInt($(ui.item).attr('data-id'))
        slot = @subsets.slotById(slotId)
        @rearrangeSlot(slot, newSlotIndex)
        @updatePreview()
      revert: true

  drawEditMode: ->
    # поле вводу для назви панелі
    $nameLabel = $('<label class="panelNameLabel">Назва:</label>')
    $nameInputContainer = $('<div>')
    $nameInputContainer.append($nameLabel)
    $nameInput = $('<input type="text">').val(@subsetWrapper.caption)
    $nameInput.change({ subsetWrapper: @subsetWrapper }, @eventsHandler.onTabNameChanged)
    $nameInputContainer.append($nameInput)

    $nameInputContainer.appendTo(@$panel)

    $panelRemoveButton = $('<span class="panelRemoveButton">Вилучити панель</span>')
    $panelRemoveButton.click =>
      @eventsHandler.onRemoveSubsetClick(@subsetWrapper)
    $removeIcon = $('<span class="removeIcon">')
    $nameInputContainer.append($panelRemoveButton)
    $panelRemoveButton.append($removeIcon)

    $slots = $('<div class="slots">')
    @$panel.append($slots)

    generateMethod = 'generateEditHtml'

    @sortableSlots($slots)

    if !@subsetWrapper.slots.length
      $slots.append('<span>Щоб додати комірку, сюди перетягніть потрібний вид з бічної панелі.</span>')
    else
      @generateHtml($slots, @subsetWrapper.slots, generateMethod)

    $preview = $('<div>').css('border-top', '1px solid color: #aaa').addClass('preview')
    $preview.append($('<div>Попередній перегляд:</div>'))
    $previewContent = $('<div class="content">')
    @generateHtml($previewContent, @subsetWrapper.slots, 'generateHtml')
    $preview.append($previewContent)
    @$panel.append($preview)

  generateHtml: ($slotsContainer, slots, generateMethod) ->
    for slot in slots
      $slotsContainer.append(slot[generateMethod]())

  updatePreview: (subsetWrapper)->
    $previewContent = @$panel.find('.preview .content')
    $previewContent.empty()
    @generateHtml($previewContent, @subsetWrapper.slots, 'generateHtml')

  rearrangeSlot: (slot, newSlotIndex)->
    slotIndex = @subsets.slotIndex(slot)
    @subsetWrapper.slots.rastMove(slotIndex, newSlotIndex)  

class rast.Drawer

    $editButtonIcon: ->
      $('<div class="gear">')

    $editButton: ->
      $editButton = @$editButtonIcon()
      $editButton.addClass('menuButton edit')
      $editButton.attr('title', 'Редагувати символи.')

    # кнопочки для переходу в режим редагування: [edit][save][reset]
    drawMenu: ->
      $menu = $('<div class="rastMenu">')
      $menu.addClass(@mode)
      if @mode == 'view'
        $editButton = @$editButton()
        $editButton.click(@eventsHandler.onEditClick)
        $menu.append($editButton)
      else if @mode == 'edit'
        $dot = ->
          $('<span> · </span>')

        $persistButton = $('<span class="menuButton">').attr('title', 'Символи буде збережено у Вашому особистому просторі. Для цього виконається редагування підсторінки від Вашого імени.')
        $persistButton.text('зберегти на підсторінку').click(@eventsHandler.onPersistClick)

        $saveButton = $('<span class="menuButton">').attr('title', 'Зміни збережуться тільки на час редагування сторінки і втратяться після закриття або перевантаження сторінки.')
        $saveButton.text('зберегти').click(@eventsHandler.onSaveClick)

        $cancelButton = $('<span class="menuButton">')
        $cancelButton.text('скасувати').click(@eventsHandler.onCancelClick).attr('title', 'Всі зміни цієї сесії редагування будуть відкинуті.')

        $resetButton = $('<span class="menuButton">')
        $resetButton.text('відновити звичаєві').click(@eventsHandler.onResetClick).attr('title', 'Буде відновлено набір символів за промовчанням.')

        $aboutLink = $("<a class=\"aboutLink\" target=\"_blank\" href=\"#{ @docLink }\">про додаток</a>")

        $menu.append($persistButton, $dot(), $saveButton, $dot(), $cancelButton, $dot(), $resetButton, $aboutLink)

      @$container.append($menu)

    drawTab: ($container, text)->
      $a = $('<a>')
      $adiv = $('<div>')
      $a.text(text)
      $adiv.append($a)
      $container.append($adiv)
      $adiv

    # навігація по панелях
    drawTabs: ($container)->
      i = 0
      while i < @subsets.subsets.length
        $adiv = @drawTab($container, @subsets.subsets[i].caption)
        id = 'etTabContent' + i
        $adiv.addClass('asnav-selectedtab') if @activeTab == id
        $adiv.attr('data-contentid', id)
        $adiv.click(@eventsHandler.onTabClick)
        i++
      $container

    # вся бічна частина. Включає навігація по панелях.
    drawNavigation: ->
      $outline = $('<span>').addClass('asnav-tabs').addClass('specialchars-tabs')

      $tabs = $('<div class="existingTabs">')
      @drawTabs($tabs)
      $outline.append($tabs)

      if @mode == 'edit'
        $addNewdiv = @drawTab($outline, '+ панель')
        $addNewdiv.addClass('newPanelButton')
        $addNewdiv.attr('title', 'Додати нову панель')
        $addNewdiv.click(@eventsHandler.onAddSubsetClick)

      @$container.append($outline)

      if @mode == 'edit' && @subsets.subsets.length
        @drawSlotClasses($outline)

    # [для режиму редагування] список ґудзиків, які можна створювати. Перетягуються мишкою.
    drawSlotClasses: ($outline)->
      $slots = $('<div class="slotClasses">')
      $hint = $('<div title="Щоб створити комірку, перетягніть потрібний вид в область редагування (область редагування обведена штриховим обідком).">Види комірок:</div>')
      $slots.append($hint)
      for slotClass in @slotClasses
        $slot = $('<div class="slotClass">')
        $slot.attr('data-slot-class', rast.name(slotClass))
        $slot.text(slotClass.caption)
        $slot.attr('title', 'Перетягніть на панель, щоб вставити цей вид комірки')
        $slots.append($slot)
      $outline.append($slots)

      $slots.find('.slotClass').draggable
        connectToSortable: '.etPanel .slots'
        helper: 'clone'

    draw: ->
      @$container.find('[original-title]').each (i, elem)->
        $(elem).tipsy?('hide')
      mw.loader.using ['jquery.ui.sortable', 'jquery.ui.droppable', 'jquery.ui.draggable', 'jquery.tipsy'], =>
        @$container.empty()
        @drawMenu()
        @drawMessage()
        @drawNavigation()
        @drawPanels()
        $titled = @$container.find('[title]')
        $titled.tipsy(trigger: 'manual')
        $titled.mouseenter ->
          $this = $(@)
          $this.tipsy('show')
          hideTimeout = setTimeout(
            ->
              $this.tipsy('hide')
            3000
          )
          $this.data('hideTimeout', hideTimeout)
        $titled.mouseleave ->
          $this = $(@)
          $this.tipsy('hide')
          hideTimeout = $this.data('hideTimeout')
          clearTimeout(hideTimeout) if hideTimeout

    drawMessage: ->
      @$container.append(@message)

    # власне панелі з символами
    drawPanels: ->
      $content = $('<div>').attr('id', 'etContent').addClass('overflowHidden')
      @$container.append($content)
      i = 0
      while i < @subsets.subsets.length
        $subset = @drawPanel(@subsets.subsets[i], i)
        $subsetDiv = $('<div>').attr('id', 'etTabContent' + i).attr('data-id', @subsets.subsets[i].id).appendTo($content).addClass('asnav-content').append($subset)
        i++
      @$container.etMakeTabs(true)
      @$container.append($('<div>').css('clear', 'both'))
      @$container.asnavSelect(@activeTab)

    drawPanel: (subsetWrapper, index) ->
      $panel = $('<div>').attr('id', 'spchars-' + index).addClass('etPanel')

      panelDrawer = new rast.PanelDrawer($panel, subsetWrapper, index, @mode, @subsets, @eventsHandler)
      panelDrawer.draw()
      $panel

class rast.PlainObjectParser

    @charinsertDivider: ' '

    @parseTokens: (arr, hotkeysHandler) ->
      slots = []
      for token in arr
        if typeof token == 'string'
          slots = slots.concat(@strToMultipleInsertionsSlot(token))
        else if Object::toString.call(token) == '[object Array]'
          slots.push @slotFromArr(token)
        else if typeof token == 'object'
          slot = @slotFromPlainObj(token, hotkeysHandler)
          if slot
            slots.push(slot)
      slots

    @slotFromArr: (arr) ->
      new rast.InsertionSlot(insertion: arr[0], caption: arr[1])

    @slotsFromStr: (str) ->
      tokens = str.split(' ')
      slots = []
      slot = undefined
      for token in tokens
        slot = @slotFromStr(token)
        slots.push(slot)
      slots

    @strToMultipleInsertionsSlot: (str) ->
      slots = []
      slot = new rast.MultipleInsertionsSlot(insertion: str)
      slots.push(slot)
      slots

    @lineReplace: (c) ->
      if c == '\\'
        return '\\'
      else if c == '_'
        return ' '
      return

    @slotFromStr: (token) ->

      readModifiers = ->
        res =
          bold: false
          plain: false
          italic: false
        i = token.length - 1
        c = undefined
        while i > -1 and !rast.insertion.isEscaped(token, i)
          c = token.charAt(i).toLowerCase()
          if c == 'ж'
            res.bold = true
          else if c == 'н'
            res.italic = true
          else if c == 'п'
            res.plain = true
          else
            break
          token = token.substring(0, i)
          i--
        res

      modifiers = readModifiers()
      slot = undefined
      if modifiers.plain or token == '' or token == '_'
        slot = new rast.PlainTextSlot(
          bold: modifiers.bold
          italic: modifiers.italic)
        if token == '' or token == '_'
          slot.text = @charinsertDivider + ' '
        else
          slot.text = rast.insertion.replaceSpecsymbols(token, '\\_', @lineReplace) + ' '
      else
        tags = @parseInsertion(token, '')
        slot = new rast.InsertionSlot(
          bold: modifiers.bold
          italic: modifiers.italic,
          insertion: token,
          caption: tags.caption)
      slot

    @generateLink: (obj) ->
      slot = undefined
      if obj.ins or obj.insert
        slot = new rast.InsertionSlot({})
        $.extend slot, @parseInsertion(obj.ins or obj.insert, obj.cap or obj.caption,
          bold: obj.b or obj.bold
          italic: obj.i or obj.italic)
      else if obj.func
        slot = new rast.InsertionSlot(
          clickFunc: obj.func,
          useClickFunc: true,
          caption: obj.cap or obj.caption or obj.ins)
        $.extend slot,
          bold: obj.b or obj.bold
          italic: obj.i or obj.italic
      slot

    @parseInsertion: (token, caption) ->
      tagOpen = token
      tagClose = ''
      n = rast.insertion.indexOfUnescaped(token, '+')
      if n > -1
        tagOpen = token.substring(0, n)
        tagClose = token.substring(n + 1)
      tagOpen = rast.insertion.replaceSpecsymbols(tagOpen, '\\_', @lineReplace)
      tagClose = rast.insertion.replaceSpecsymbols(tagClose, '\\_', @lineReplace)
      if !caption
        caption = tagOpen + tagClose + ' '
        caption = rast.insertion.replaceSpecsymbols(caption, '\\$', (c) ->
          if c == '$'
            return ''
          else if c == '\\'
            return ''
          return
        )
      {
        caption: caption
        tagOpen: tagOpen
        tagClose: tagClose
      }

    @slotFromPlainObj: (obj, hotkeysHandler) ->
      slot = undefined
      if obj.plain
        slot = new rast.PlainTextSlot(
          text: obj.cap or obj.caption
          bold: obj.b or obj.bold
          italic: obj.i or obj.italic)
      else if obj.html
        slot = new rast.HtmlSlot(html: obj.html, onload: obj.onload)
      else
        slot = @generateLink(obj)
        if !slot
          return
        hotkeysHandler.processShortcut slot, obj
      slot

# серіялізовний стан: всі символи + функції, які викликаються символами.
class rast.SubsetsManager

    constructor: ->
      @reset()

    slotById: (id)->
      for subset in @subsets
        for slot in subset.slots
          return slot if slot.id == id
      null

    slotIndex: (slot)->
      for subset in @subsets
        slotIndex = subset.slots.indexOf(slot)
        return slotIndex if slotIndex > -1
      null

    subsetBySlot: (slot)->
      for subset in @subsets
        return subset if subset.slots.indexOf(slot) > -1
      null

    subsetBySlotId: (slot)->
      for subset in @subsets
        for slot in subset.slots
          return subset if slot.id == id
      null

    subsetById: (id)->
      for subset in @subsets
        return subset if subset.id == id
      null

    processShortcut: (slot, obj) ->
        if obj.key
          if typeof obj.key == 'string'
            key = obj.key[0].toUpperCase()
            slot.key = key
            if obj.func
              @hotkeys[key] = obj.func
            if obj.ins or obj.insert
              @hotkeys[key] = ((a) ->
                a
              )(slot)

    addSubset: (caption, index)->
      subset = {
        caption: caption
        slots: []
        id: @uniqueSubsetId()
      }
      @insertOrAppend(@subsets, index, subset)

    deleteSubset: (subsetToBeRemoved)  ->
      @subsets = $.grep(@subsets, (subset, index)->
        subsetToBeRemoved.id != subset.id
      )

    addSlot: (slotClassOrSlot, subset, index)->
      if slotClassOrSlot instanceof rast.Slot
        slot = slotClassOrSlot
        slot.id = @uniqueSlotId()
      else
        slot = new slotClassOrSlot(id: @uniqueSlotId())
      @insertOrAppend(subset.slots, index, slot)

    deleteSlot: (slotId)->
      return unless (typeof slotId == 'number')
      slot = @slotById(slotId)
      slotIndex = @slotIndex(slot)
      subset = @subsetBySlot(slot)
      subset.slots.splice(slotIndex, 1)

    uniqueSlotId: ->
      result = @slotId
      @slotId++
      result

    uniqueSubsetId: ->
      result = @subsetId
      @subsetId++
      result

    insertOrAppend: (arr, index, item)->
      if index
        arr.splice(index, 0, item)
      else
        arr.push(item)
      item

    reset: ->
      @subsets = []
      @hotkeys = {}
      self = this
      @slotId = 0
      @subsetId = 0

    readEncodedSubsets: (encodedSubsets) ->
      results = []
      j = 0
      len = encodedSubsets.length
      while j < len
        subset = encodedSubsets[j]
        results.push @readEncodedSubset(subset)
        j++
      results

    decodeSubset: (encodedSubset) ->
      slots = rast.PlainObjectParser.parseTokens(encodedSubset.symbols, @, @)
      {
        slots: slots
        caption: encodedSubset.caption
      }

    readEncodedSubset: (encodedSubset) ->
      subset = @decodeSubset(encodedSubset)
      internalSubset = @addSubset(subset.caption)
      for slot in subset.slots
        @addSlot(slot, internalSubset)

    toJSON: ->
      @subsets

    deserialize: (subsets) ->
      $.each(subsets, (i, subset) =>
          s = @addSubset(subset.caption)
          cons = null
          slot = null
          $.each(subset.slots, (i, plainSlot) =>
            cons = eval(plainSlot['class'])
            slot = new cons(plainSlot)
            @addSlot(slot, s)
          )
      )

  # діалогове віконце. У нього вставляються поля для візуального редагування символа.
class rast.UIwindow

    @show: ($content)->
      EditDialog = (config) ->
        EditDialog.super.call this, config

      OO.inheritClass EditDialog, OO.ui.Dialog
      # Specify a title statically (or, alternatively, with data passed to the opening() method).
      EditDialog.static.title = 'Simple dialog'
      # Customize the initialize() function: This is where to add content to the dialog body and set up event handlers.

      EditDialog::initialize = ->
        # Call the parent method
        EditDialog.super::initialize.call this
        @$body.append $content
        return

      # Override the getBodyHeight() method to specify a custom height (or don't to use the automatically generated height)

      EditDialog::getBodyHeight = ->
        $content.outerHeight true

      # Make the window.
      editDialog = new EditDialog(size: 'large')
      # Create and append a window manager, which will open and close the window.
      windowManager = new (OO.ui.WindowManager)
      $('body').append windowManager.$element
      # Add the window to the window manager using the addWindows() method.
      windowManager.addWindows [ editDialog ]
      # Open the window!
      windowManager.openWindow editDialog
      editDialog

  # генерує поля для редагування символа. Для цього кожен клас символів має властивість editableAttributes.
class rast.SlotAttributesEditor

    constructor: (options)->
      @slot = options.slot
      @slotsManager = options.slotsManager
      @allInputs = []

    fieldsetForAttrs: (fieldsetName, attrs)->
      inputs = []

      for attribute in attrs
        value = @slot[attribute.name]
        type = attribute.type
        OOinput =
          if type == 'string' || type == 'text'
            fieldOptions = { value: value, multiline: type == 'text', rows: 3, autosize: true }
            {
              getValue: 'getValue',
              OOobject: new OO.ui.TextInputWidget(fieldOptions)
            }
          else if type == 'boolean'
            {
              getValue: 'getValue',
              OOobject: new OO.ui.ToggleSwitchWidget({
                value: value
              })
            }

        inputData = {
          attribute: attribute.name,
          label: attribute.caption
          input: OOinput.OOobject
          getValueFunc: OOinput.getValue
          labelAlignment: attribute.labelAlignment || 'left'
          helpText: attribute.help
        }
        if OOinput
          @allInputs.push(inputData)
          inputs.push(inputData)

      # Create a Fieldset layout.
      fieldset = new OO.ui.FieldsetLayout( {
        label: fieldsetName
      } )

      # Add field layouts that contain the form elements to the fieldset. Items can also be specified
      # with the FieldsetLayout's 'items' config option:

      fields = $.map(inputs, (inputWrapper, index)->
        new OO.ui.FieldLayout(inputWrapper.input, {
          label: inputWrapper.label,
          align: inputWrapper.labelAlignment
          help: inputWrapper.helpText
        })
      )

      fieldset.addItems(fields)
      fieldset

    startEditing: ->
      slotClass = @slot.constructor
      attrs = slotClass.editableAttributes
      $content = $('<div class="rastEditWindow">')
      if attrs.view
        fieldset = @fieldsetForAttrs('Вигляд', attrs.view)
        $content.append(fieldset.$element)
      if attrs.functionality
        fieldset = @fieldsetForAttrs('Функціонал', attrs.functionality)
        $content.append(fieldset.$element)

      saveButton = new OO.ui.ButtonWidget(icon: 'check', label: 'Зберегти')
      saveButton.on 'click', =>
        for inputWrapper in @allInputs
          @slot[inputWrapper.attribute] = inputWrapper.input[inputWrapper.getValueFunc]()
        @slotsManager.onSlotSaved()
        dialog.close()

      cancelButton = new OO.ui.ButtonWidget(icon: 'cancel', label: 'Скасувати')
      cancelButton.on 'click', ->
        dialog.close()

      removeButton = new OO.ui.ButtonWidget(icon: 'remove', label: 'Вилучити комірку')
      removeButton.on 'click', =>
        @slotsManager.onDeleteSlot?(@slot.id)
        dialog.close()

      bottomButtons = new OO.ui.HorizontalLayout( {
        items: [
          saveButton
          cancelButton
          removeButton
        ]
        classes: ['bottomButtons']
      })

      $content.append(bottomButtons.$element)

      panel = new OO.ui.PanelLayout({ $: $, padded: true, expanded: false })
      panel.$element.append($content)

      dialog = rast.UIwindow.show(panel.$element)

class rast.SlotAttributes

  constructor: (attrsObj)->
    $.extend(@, attrsObj)

  toArray: ->
    result = []
    result = result.concat(@view) if @view
    result = result.concat(@functionality) if @functionality
    result

class rast.Slot

    @editableAttributes: new rast.SlotAttributes({})

    @editorClass: rast.SlotAttributesEditor

    constructor: (options = {}) ->
      for attribute in @constructor.editableAttributes.toArray()
        @[attribute.name] = attribute.default
      $.extend @, options, 'class': 'rast.' + @constructor.name

    generateEditHtml: ->
      $element = @generateHtml()
      $($element).addClass('editedSlot')
      $element

class rast.PlainTextSlot extends rast.Slot

    @caption: 'Простий текст'

    @editableAttributes: new rast.SlotAttributes({ view:
      [
        { name: 'css', type: 'text', default: '', caption: 'CSS-стилі' }
        { name: 'text', type: 'text', default: 'текст', caption: 'Текст', labelAlignment: 'top' }
      ]
    })

    generateEditHtml: ->
      $elem = super()
      $elem.attr('title', @text)

    generateHtml: (styles)->
      $elem = $('<span>')
      $elem.text(@text)
      $elem.attr('data-id', @id)
      $elem.attr('style', styles || @css)
      if @bold
        $elem.css('font-weight', 'bold')
      if @italic
        $elem.css('font-style', 'italic')
      $elem

class rast.InsertionSlot extends rast.Slot

    @caption: 'Одна вставка'

    @editableAttributes: new rast.SlotAttributes({
      view: [
        { name: 'css', type: 'text', default: '', caption: 'CSS-стилі' }
        { name: 'caption', caption: 'Напис', type: 'text', default: 'Нова вставка' }
        { name: 'captionAsHtml', caption: 'Сприймати напис, як html-код?', type: 'boolean', default: false }
      ]
      functionality: [
        { 
          name: 'insertion', 
          caption: 'Текст вставки', 
          type: 'text', 
          default: '$', 
          labelAlignment: 'top', 
          help: '''Символ долара "$" буде замінено на виділений текст. Перший символ додавання "+" позначає місце каретки після вставлення. 
            Якщо хочете екранувати ці символи, поставте "\\" перед потрібним символом; наприклад "\\$" вставлятиме знак долара.''' 
        }
        { name: 'useClickFunc', caption: 'Замість вставляння виконати іншу дію?', type: 'boolean', default: false }
        { name: 'clickFunc', caption: 'Інша дія (при клацанні)', type: 'text', default: 'function(){  }', labelAlignment: 'top' }
      ]
    })

    @insertFunc = (insertion) ->
      rast.$getTextarea().focus()
      tags = rast.PlainObjectParser.parseInsertion(insertion, '')
      rast.$getTextarea().insertTag(tags.tagOpen, tags.tagClose)

    toJSON: ->
      copy = rast.clone(@)
      copy.clickFunc = @clickFunc.toString() if @clickFunc
      copy

    generateEditHtml: ->
      $elem = super()
      $elem.attr('title', (@useClickFunc && @clickFunc.toString()) || @insertion)
      $elem.append($('<div class="overlay">'))

    generateCommonHtml: (styles)->
      if @captionAsHtml
        $elem = $('<div>')
        $elem.append(@caption)
        $elem.attr('data-id', @id)
        $elem.attr('style', styles) if styles
        if @bold
          $elem.css('font-weight', 'bold')
        if @italic
          $elem.css('font-style', 'italic')
        $elem
      else
        $a = $('<a>')
        $a.attr('data-id', @id)
        $a.attr('style', styles) if styles
        caption = $('<div/>').text(@caption).html()
        $a.html(caption)
        if @bold
          $a.css('font-weight', 'bold')
        if @italic
          $a.css('font-style', 'italic')
        $a

    generateHtml: (styles)->
      $elem = @generateCommonHtml(styles || @css)
      $elem.click (event)=>
        event.preventDefault()
        if @useClickFunc
          eval('(' + @clickFunc + ')()')
        else
          rast.InsertionSlot.insertFunc(@insertion)
      $elem

class rast.MultipleInsertionsSlot extends rast.Slot

    @caption: 'Набір вставок'

    @editableAttributes: new rast.SlotAttributes({
      view: [
        { name: 'css', type: 'text', default: '', caption: 'CSS-стилі' }
      ]
      functionality: [
        { 
          name: 'insertion'
          caption: 'Вставки'
          type: 'text'
          default: 'вставка_1 ·п вставка_2'
          labelAlignment: 'top'
          help: '''Все, що розділене символами пробілу, вважається окремою коміркою. 
            Якщо комірка закірчується символом "п", вона вважатиметься не вставкою, а простим текстом. 
            Якщо хочете включити пробіл у вставку, пишіть нижнє підкреслення: "_". 
            Символ долара "$" буде замінено на виділений текст. Перший символ додавання "+" позначає місце каретки після вставлення. 
            Якщо хочете екранувати ці символи, поставте "\\" перед потрібним символом; наприклад "\\$" вставлятиме знак долара.''' 
        }
      ]
    })

    @insertFunc = (insertion) ->
      rast.$getTextarea().focus()
      tags = rast.PlainObjectParser.parseInsertion(insertion, '')
      rast.$getTextarea().insertTag(tags.tagOpen, tags.tagClose)

    generateEditHtml: ->
      $elem = super()
      $elem.attr('title', @insertion)
      $elem.prepend($('<div class="overlay">'))

    generateCommonHtml: (styles)->
      slots = rast.PlainObjectParser.slotsFromStr(@insertion)
      $elem = $('<div>')
      $elem.attr('data-id', @id)
      $elem.attr('style', styles) if styles
      if @bold
        $elem.css('font-weight', 'bold')
      if @italic
        $elem.css('font-style', 'italic')

      for slot in slots
        $slot = $(slot.generateHtml(styles))
        $elem.append($slot)

      $elem

    generateHtml: (styles)->
      $elem = @generateCommonHtml(styles || @css)
      $elem

class rast.HtmlSlot extends rast.Slot

    @caption: 'Довільний код'

    @editableAttributes: new rast.SlotAttributes({
      view: [
        { name: 'html', type: 'text', default: '<span>html</span>', caption: 'HTML', labelAlignment: 'top' }
      ]
      functionality: [
        { name: 'onload', type: 'text', default: 'function(){  }', caption: 'JavaScript, що виконається при ініціалізації', labelAlignment: 'top' }
      ]
    })

    toJSON: ->
      copy = rast.clone(@)
      copy.onload = @onload.toString() if @onload
      copy

    constructor: (options) ->
      super(options)
      if typeof @onload is 'string'
        @onload = eval('(' + @onload + ')')
      if typeof @onload is 'function'
        editTools.addOnloadFunc(@onload)

    generateEditHtml: ->
      $elem = super()
      $elem.attr('title', @html)

    generateHtml: ->
      $elem = $(@html)
      $wrapper = $('<div>')
      $wrapper.attr('data-id', @id)
      $wrapper.append($elem)
      $overlay = $('<div class="overlay">')
      $wrapper.append($overlay)
      $wrapper

class rast.PageStorage

  @load: (pagename, onLoaded, handler)->
    mw.loader.using 'mediawiki.api.edit', ->
        api = new (mw.Api)
        api.get(
          action: 'query'
          prop: 'revisions'
          rvprop: 'content'
          titles: pagename
        ).done((data) ->
         for pageId of data.query.pages
           if data.query.pages[pageId].revisions
             onLoaded?(data.query.pages[pageId].revisions[0]['*'])
           else
             handler.onSubpageNotFound?(pageId)
        ).fail(
          ->
            handler.onReadFromSubpageError()
        ).always(
          ->
            handler.onEndReadingSubpage()
        )

  @save: (pagename, string, handler)->
    mw.loader.using 'mediawiki.api.edit', ->
        api = new (mw.Api)
        api.postWithEditToken(
          action: 'edit'
          title: pagename
          summary: '[[Обговорення користувача:AS/rast.js|serialize]]'
          text: string
        ).done(
          ->
            handler.onSavedToSubpage()
        ).fail(
          ->
            handler.onSaveToSubpageError()
        ).always(
          ->
            handler.onEndSavingToSubpage()
        )

$ ->
  window.editTools =
    hotkeys: []
    onloadFuncs: []
    mode: 'view'
    addOnloadFunc: (func) =>
      editTools.onloadFuncs.push(func)
    fireOnloadFuncs: ->
      for func in editTools.onloadFuncs
        func()
    checkHotkey: (e) ->
      if e and e.ctrlKey
        obj = editTools.hotkeys[String.fromCharCode(e.which).toUpperCase()]
        if obj
          if typeof obj == 'object'
            obj.trigger 'click'
          else
            obj()
          return false
      true
    extraCSS: '''
    #edittools .etPanel .slots [data-id] { margin: -1px -1px 0px 0px; }
    #edittools .etPanel .slots [data-id]:hover { z-index: 1; text-decoration: none; }
    #edittools .etPanel .preview [data-id] { display: inline; padding: 0px 2px; cursor: pointer; }
    #edittools .etPanel > [data-id] { display: inline; padding: 0px 2px; cursor: pointer; }
    #edittools { min-height: 20px; } 
    #edittools .rastMenu.view { position: absolute; left: 0px; } 
    #edittools .rastMenu.edit { border-bottom: solid #aaaaaa 1px; padding: 2px 6px; } 
    #edittools .slots.ui-sortable { min-height: 4em; border-width: 1px; border-style: dashed; margin: 5px 0px; } 
    #edittools .slots.ui-sortable .emptyHint {  } 
    #edittools .editedSlot { 
      cursor: pointer; 
      min-width: 1em;
      min-height: 1em;
      border: 1px solid grey;
      margin-left: -1px;
      position: relative;
      display: block;
    }
    #edittools .editedSlot .overlay { width: 100%; height: 100%; position: absolute; top: 0px; left: 0px; } 
    #edittools .slotClass { cursor: copy; } 
    #edittools .panelRemoveButton, #edittools .menuButton { cursor: pointer; }
    #edittools .gear { 
      background-image: url('https://upload.wikimedia.org/wikipedia/commons/thumb/b/bd/Simpleicons_Interface_gear-wheel-in-black.svg/15px-Simpleicons_Interface_gear-wheel-in-black.svg.png'); 
      height: 15px;;
      width: 15px; 
      background-repeat: no-repeat;
      background-size: cover;
      display: inline-block; } 
    #edittools .ui-state-highlight { 
      min-width: 1em; 
      min-height: 1em; 
      display: inline-block;
    } 
    #edittools .ui-sortable-helper { min-width: 1em; min-height: 1em; } 
    .specialchars-tabs {float: left; background: #E0E0E0; margin-right: 7px; } 
    .specialchars-tabs a{ display: block; } 
    #edittools { border: solid #aaaaaa 1px; } 
    .mw-editTools a{ cursor: pointer; } 
    .overflowHidden { overflow: hidden; } 
    .specialchars-tabs .asnav-selectedtab{ background: #F0F0F0; } 
    #edittools .highlighted { opacity: 0.5; }
    #edittools [data-id]:hover { border-color: red; }
    #edittools .notFoundWarning { padding: 4px; }
    #edittools .newPanelButton { padding: 4px; border-bottom: solid #aaaaaa 1px; }
    #edittools .removeIcon { 
      background-image: url('https://upload.wikimedia.org/wikipedia/commons/thumb/b/b5/Ambox_delete_soft.svg/15px-Ambox_delete_soft.svg.png?uselang=uk');
      display: inline-block;
      width: 15px;
      height: 15px;
      margin: 0px 0px 2px 4px;
      vertical-align: middle;
    }
    #edittools .panelNameLabel { margin-right: 5px; }
    #edittools .panelRemoveButton { margin-left: 20px; }
    #edittools .etPanel > .slots { 
      padding: 6px 1px;
      border: 1px black dashed; 
      overflow: auto;
      max-height: 240px;
    }
    .rastEditWindow .bottomButtons { margin-top: 10px; }

    #edittools .aboutLink { float: right; }
}'''
    appendExtraCSS: ->
      mw.util.addCSS(@extraCSS)
      return
    parentId: '.mw-editTools'
    id: 'edittools'
    cookieName: 'edittool'
    createEditTools: ->
      $tabs = $('<div></div>').attr('id', @id)

      event = if rast.ieVersion() < 9 then 'mousedown' else 'click'
      self = @
      $tabs.on event, '.asnav-content .etPanel .slots [data-id]', ($e) ->
        if editTools.mode == 'edit'
          id = parseInt($(this).closest('.editedSlot').attr('data-id'))
          slot = editTools.temporarySubsets.slotById(id)
          editTools.editWindow(slot)
      $tabs

    editWindow: (slot)->
      editor = new slot.constructor.editorClass(slot: slot, slotsManager: @)
      editor.startEditing()

    onDeleteSlot: (slotId)->
      id = parseInt(slotId)
      @temporarySubsets.deleteSlot(id)
      @refresh()

    edit: ->
      @mode = 'edit'
      $('#' + @id).find('.notFoundWarning').remove()
      @refresh()

    view: ->
      @mode = 'view'
      @refresh()

    reset: ->
      @onloadFuncs = []
      @subsets.reset()

    readFromSpecialSyntaxObject: (obj)->
      return false unless obj
      @reset()
      @subsets.readEncodedSubsets(obj)
      @subsetsUpdated()
      @refresh()
      true

    subsetsUpdated: ->
      @temporarySubsets = rast.clone(@subsets, false)

    undoChanges: ->
      @temporarySubsets = rast.clone(@subsets)

    refresh: ->
      if !@created
        return

      $tabs = $('#' + @id)
      etActiveTab = $tabs.find('.existingTabs .asnav-selectedtab').attr('data-contentid') || mw.cookie.get(editTools.cookieName + 'Selected') or 'etTabContent0'

      @drawer.$container = $tabs
      @drawer.mode = @mode
      @drawer.subsets = @temporarySubsets
      @drawer.message = @message
      @message = null
      @drawer.activeTab = etActiveTab
      @drawer.draw()

      setTimeout(
        =>
          @fireOnloadFuncs()
        0  
      )
      
      $tabs.on 'asNav:select', (ev, selectedId) ->
        mw.cookie.set editTools.cookieName + 'Selected', selectedId

    save: ->
      @subsets = @temporarySubsets
      @subsetsUpdated()
      @view()

    restoreDefaults: ->
      @readFromSubpage('User:AS/defaults.js')

    init: ->
      @subsets = new rast.SubsetsManager
      @temporarySubsets = new rast.SubsetsManager

      $tabs = $('#' + @id)
      etActiveTab = $tabs.find('.existingTabs .asnav-selectedtab').attr('data-contentid') || mw.cookie.get(editTools.cookieName + 'Selected') or 'etTabContent0'

      @onSaveClick = =>
        @save()
      @onCancelClick = =>
        @undoChanges()
        @view()
      @onResetClick = =>
        @restoreDefaults()
      @onEditClick = =>
        @edit()
      @onTabNameChanged = (event)=>
        event.data.subsetWrapper.caption = $(event.target).val()
        @refresh()
      @onAddSubsetClick = =>
        subset = @temporarySubsets.addSubset('Нова панель', @temporarySubsets.subsets.length)
        @refresh()
        $tabs = $('#' + @id)
        $tabs.asnavSelect('etTabContent' + subset.id)
      @onRemoveSubsetClick = (subsetWrapper)=>
        @temporarySubsets.deleteSubset(subsetWrapper)
        @refresh()
      @onSlotAdded = =>
        @refresh()
      @onPersistClick = =>
        @save()
        $tabs = $('#' + @id)
        $tabs.throbber(true, 'prepend')
        @saveToSubpage()
      @onSlotRemoved = =>
        @refresh()

      @drawer = new rast.Drawer()
      $.extend(
        @drawer
        {
          docLink: @docLink
          onTabClick: null,
          eventsHandler: @
          slotClasses: [rast.PlainTextSlot, rast.InsertionSlot, rast.MultipleInsertionsSlot, rast.HtmlSlot]
        }
      )

      $placeholder = $(@parentId)
      return if !$placeholder.length
      @appendExtraCSS()
      $placeholder.empty().append(@createEditTools())
      $('input#wpSummary').attr 'style', 'margin-bottom:3px;' #fix margins after moving placeholder

      @created = true
      @reload()

    reload: ->
      $tabs = $('#' + @id)
      $tabs.throbber(true, 'prepend')
      @readFromSubpage()

    docLink: 'https://uk.wikipedia.org/wiki/%D0%9A%D0%BE%D1%80%D0%B8%D1%81%D1%82%D1%83%D0%B2%D0%B0%D1%87:AS/%D0%9F%D0%9F%D0%A1-2'  

    editButtonHtml: ->
      @drawer.$editButtonIcon().prop('outerHTML')

    showMessage: (html)->
      @message = html
      @refresh()

    onSubpageNotFound: ->
      unless @readFromSpecialSyntaxObject(window.etSubsets)
        @showMessage("<div class=\"notFoundWarning\">Це повідомлення від додатка <a href=\"#{ @docLink }\">Покращеної панелі спецсимволів</a> (Налаштування -> Додатки -> Редагування). Підсторінку із символами не знайдено або не вдалося завантажити. Це нормально, якщо ви ще не зберегли жодну версію. Натисніть зліва від панелі на #{ @editButtonHtml() }, щоб редагувати символи.</div>")

    serialize: ->
      JSON.stringify(@subsets, null, 2)

    subpageStorageName: 'AStools.js',

    saveToSubpage: ->
      @serializeToPage('User:' + mw.config.values.wgUserName + '/' + @subpageStorageName)

    trackingPage: 'User:AS/track'

    serializeToPage: (pagename) ->
      serializedTools = "[[#{ @trackingPage }]]<nowiki>#{ @serialize() }</nowiki>"
      rast.PageStorage.save(
        pagename,
        serializedTools
        @
      )

    subpageName: ->
      'User:' + mw.config.values.wgUserName + '/' + @subpageStorageName

    readFromSubpage: (pagename)->
      @reset()
      json = rast.PageStorage.load(
        pagename || @subpageName()
        (pagetext)=>
          pagetextWithoutNowiki = pagetext.replace(/^(\[\[[^\]]+\]\])?<nowiki>/, '').replace(/<\/nowiki>$/, '')
          serializedTools = JSON.parse(pagetextWithoutNowiki)
          @subsets.deserialize(serializedTools)
          @subsetsUpdated()
          @refresh()
        ,
        @
      )

    onReadFromSubpageError: ->
      @showMessage("<div class=\"readingSubpageError\">Не вдалося завантажити підсторінку з символами.</div>")

    onEndReadingSubpage: ->
      $tabs = $('#' + @id)
      $tabs.throbber(false)

    onSavedToSubpage: ->
      pagename = @subpageName()
      mw.notify($("<span>Збережено на <a href='#{ mw.util.getUrl(pagename) }'>#{ pagename }</a></span>"))

    onSaveToSubpageError: ->
      pagename = @subpageName()
      mw.notify($("<span>Не вдалося зберегти на <a href='#{ mw.util.getUrl(pagename) }'>#{ pagename }</a></span>"))

    onEndSavingToSubpage: ->
      $tabs = $('#' + @id)
      $tabs.throbber(false)

    setupOnEditPage: ->
      if mw.config.get('wgAction') == 'edit' or mw.config.get('wgAction') == 'submit'
        mw.loader.using ['mediawiki.cookie', 'oojs-ui', 'jquery.colorUtil'], ->
          rast.installJQueryPlugins()
          editTools.init()

    onSlotSaved: ->
      @refresh()

  # end editTools

  rast.PlainObjectParser.processShortcut = editTools.processShortcut;
  rast.PlainObjectParser.addOnloadFunc = editTools.addOnloadFunc;

  editTools.setupOnEditPage()
