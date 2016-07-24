window.$ = unsafeWindow.$ if unsafeWindow? # для Tampermonkey

`// jquery.textSelection.js fork
( function ( $ ) {
	/*jshint noempty:false */

	if ( document.selection && document.selection.createRange ) {
		// On IE, patch the focus() method to restore the windows' scroll position
		// (bug 32241)
		$.fn.extend({
			focus: ( function ( jqFocus ) {
				return function () {
					var $w, state, result;
					if ( arguments.length === 0 ) {
						$w = $( window );
						state = {top: $w.scrollTop(), left: $w.scrollLeft()};
						result = jqFocus.apply( this, arguments );
						window.scrollTo( state.top, state.left );
						return result;
					}
					return jqFocus.apply( this, arguments );
				};
			}( $.fn.focus ) )
		});
	}

	$.fn.etTextSelection = function ( command, options ) {
		var fn,
			context,
			hasIframe,
			needSave,
			retval;

		/**
		 * Helper function to get an IE TextRange object for an element
		 */
		function rangeForElementIE( e ) {
			if ( e.nodeName.toLowerCase() === 'input' ) {
				return e.createTextRange();
			} else {
				var sel = document.body.createTextRange();
				sel.moveToElementText( e );
				return sel;
			}
		}

		/**
		 * Helper function for IE for activating the textarea. Called only in the
		 * IE-specific code paths below; makes use of IE-specific non-standard
		 * function setActive() if possible to avoid screen flicker.
		 */
		function activateElementOnIE( element ) {
			if ( element.setActive ) {
				element.setActive(); // bug 32241: doesn't scroll
			} else {
				$( element ).focus(); // may scroll (but we patched it above)
			}
		}

		fn = {
			/**
			 * Get the contents of the textarea
			 */
			getContents: function () {
				return this.val();
			},
			/**
			 * Get the currently selected text in this textarea. Will focus the textarea
			 * in some browsers (IE/Opera)
			 */
			getSelection: function () {
				var retval, range,
					el = this.get( 0 );

				if ( $(el).is( ':hidden' ) ) {
					// Do nothing
					retval = '';
				} else if ( document.selection && document.selection.createRange ) {
					activateElementOnIE( el );
					range = document.selection.createRange();
					retval = range.text;
				} else if ( el.selectionStart || el.selectionStart === 0 ) {
					retval = el.value.substring( el.selectionStart, el.selectionEnd );
				}

				return retval;
			},
			/**
			 * Ported from skins/common/edit.js by Trevor Parscal
			 * (c) 2009 Wikimedia Foundation (GPLv2) - http://www.wikimedia.org
			 *
			 * Inserts text at the beginning and end of a text selection, optionally
			 * inserting text at the caret when selection is empty.
			 *
			 * @fixme document the options parameters
			 */
			encapsulateSelection: function ( options ) {
				return this.each( function () {
					var selText, scrollTop, insertText,
						isSample, range, range2, range3, startPos, endPos,
						pre = options.pre,
						post = options.post;

					/**
					 * Check if the selected text is the same as the insert text
					 */
					function checkSelectedText() {
						if ( !selText ) {
							selText = options.peri;
							isSample = true;
						} else if ( options.replace ) {
							selText = options.peri;
						} else {
							while ( selText.charAt( selText.length - 1 ) === ' ' ) {
								// Exclude ending space char
								selText = selText.substring( 0, selText.length - 1 );
								post += ' ';
							}
							while ( selText.charAt( 0 ) === ' ' ) {
								// Exclude prepending space char
								selText = selText.substring( 1, selText.length );
								pre = ' ' + pre;
							}
						}
					}

					/**
					 * Do the splitlines stuff.
					 *
					 * Wrap each line of the selected text with pre and post
					 */
					function doSplitLines( selText, pre, post ) {
						var i,
							insertText = '',
							selTextArr = selText.split( '\n' );
						for ( i = 0; i < selTextArr.length; i++ ) {
							insertText += pre + selTextArr[i] + post;
							if ( i !== selTextArr.length - 1 ) {
								insertText += '\n';
							}
						}
						return insertText;
					}

					isSample = false;
					if ( this.style.display === 'none' ) {
						// Do nothing
					} else if ( document.selection && document.selection.createRange ) {
						// IE

						// Note that IE9 will trigger the next section unless we check this first.
						// See bug 35201.

						activateElementOnIE( this );
						if ( context ) {
							context.fn.restoreCursorAndScrollTop();
						}
						if ( options.selectionStart !== undefined ) {
							$(this).etTextSelection( 'setSelection', { 'start': options.selectionStart, 'end': options.selectionEnd } );
						}

						selText = $(this).etTextSelection( 'getSelection' );
						scrollTop = this.scrollTop;
						range = document.selection.createRange();

						checkSelectedText();
						insertText = pre + selText + post;
						if ( options.splitlines ) {
							insertText = doSplitLines( selText, pre, post );
						}
						if ( options.ownline && range.moveStart ) {
							range2 = document.selection.createRange();
							range2.collapse();
							range2.moveStart( 'character', -1 );
							// FIXME: Which check is correct?
							if ( range2.text !== '\r' && range2.text !== '\n' && range2.text !== '' ) {
								insertText = '\n' + insertText;
								pre += '\n';
							}
							range3 = document.selection.createRange();
							range3.collapse( false );
							range3.moveEnd( 'character', 1 );
							if ( range3.text !== '\r' && range3.text !== '\n' && range3.text !== '' ) {
								insertText += '\n';
								post += '\n';
							}
						}
						range.text = insertText;
						if ( isSample && options.selectPeri && range.moveStart ) {
							range.moveStart( 'character', - post.length - selText.length );
							range.moveEnd( 'character', - post.length );
						}
						range.select();
						// Restore the scroll position
						this.scrollTop = scrollTop;
					} else if ( this.selectionStart || this.selectionStart === 0 ) {
						// Mozilla/Opera

						$(this).focus();
						if ( options.selectionStart !== undefined ) {
							$(this).etTextSelection( 'setSelection', { 'start': options.selectionStart, 'end': options.selectionEnd } );
						}

						selText = $(this).etTextSelection( 'getSelection' );
						startPos = this.selectionStart;
						endPos = this.selectionEnd;
						scrollTop = this.scrollTop;
						checkSelectedText();
						if ( options.selectionStart !== undefined
								&& endPos - startPos !== options.selectionEnd - options.selectionStart )
						{
							// This means there is a difference in the selection range returned by browser and what we passed.
							// This happens for Chrome in the case of composite characters. Ref bug #30130
							// Set the startPos to the correct position.
							startPos = options.selectionStart;
						}

						insertText = pre + selText + post;
						if ( options.splitlines ) {
							insertText = doSplitLines( selText, pre, post );
						}
						if ( options.ownline ) {
							if ( startPos !== 0 && this.value.charAt( startPos - 1 ) !== '\n' && this.value.charAt( startPos - 1 ) !== '\r' ) {
								insertText = '\n' + insertText;
								pre += '\n';
							}
							if ( this.value.charAt( endPos ) !== '\n' && this.value.charAt( endPos ) !== '\r' ) {
								insertText += '\n';
								post += '\n';
							}
						}
						if ((typeof chrome != 'undefined') && document.queryCommandSupported('insertText')) {
						    document.execCommand('insertText', false, insertText);
						}
						else {
							this.value = this.value.substring( 0, startPos ) + insertText +
							 this.value.substring( endPos, this.value.length );							
						}
						// Setting this.value scrolls the textarea to the top, restore the scroll position
						this.scrollTop = scrollTop;
						if ( window.opera ) {
							pre = pre.replace( /\r?\n/g, '\r\n' );
							selText = selText.replace( /\r?\n/g, '\r\n' );
							post = post.replace( /\r?\n/g, '\r\n' );
						}
						if ( isSample && options.selectPeri && !options.splitlines ) {
							this.selectionStart = startPos + pre.length;
							this.selectionEnd = startPos + pre.length + selText.length;
						} else {
							this.selectionStart = startPos + insertText.length;
							this.selectionEnd = this.selectionStart;
						}
					}
					$(this).trigger( 'encapsulateSelection', [ options.pre, options.peri, options.post, options.ownline,
						options.replace, options.spitlines ] );
				});
			},
			/**
			 * Ported from Wikia's LinkSuggest extension
			 * https://svn.wikia-code.com/wikia/trunk/extensions/wikia/LinkSuggest
			 * Some code copied from
			 * http://www.dedestruct.com/2008/03/22/howto-cross-browser-cursor-position-in-textareas/
			 *
			 * Get the position (in resolution of bytes not necessarily characters)
			 * in a textarea
			 *
			 * Will focus the textarea in some browsers (IE/Opera)
			 *
			 * @fixme document the options parameters
			 */
			 getCaretPosition: function ( options ) {
				function getCaret( e ) {
					var caretPos = 0,
						endPos = 0,
						preText, rawPreText, periText,
						rawPeriText, postText, rawPostText,
						// IE Support
						preFinished,
						periFinished,
						postFinished,
						// Range containing text in the selection
						periRange,
						// Range containing text before the selection
						preRange,
						// Range containing text after the selection
						postRange;

					if ( document.selection && document.selection.createRange ) {
						// IE doesn't properly report non-selected caret position through
						// the selection ranges when textarea isn't focused. This can
						// lead to saving a bogus empty selection, which then screws up
						// whatever we do later (bug 31847).
						activateElementOnIE( e );

						preFinished = false;
						periFinished = false;
						postFinished = false;
						periRange = document.selection.createRange().duplicate();

						preRange = rangeForElementIE( e );
						// Move the end where we need it
						preRange.setEndPoint( 'EndToStart', periRange );

						postRange = rangeForElementIE( e );
						// Move the start where we need it
						postRange.setEndPoint( 'StartToEnd', periRange );

						// Load the text values we need to compare
						preText = rawPreText = preRange.text;
						periText = rawPeriText = periRange.text;
						postText = rawPostText = postRange.text;

						/*
						 * Check each range for trimmed newlines by shrinking the range by 1
						 * character and seeing if the text property has changed. If it has
						 * not changed then we know that IE has trimmed a \r\n from the end.
						 */
						do {
							if ( !preFinished ) {
								if ( preRange.compareEndPoints( 'StartToEnd', preRange ) === 0 ) {
									preFinished = true;
								} else {
									preRange.moveEnd( 'character', -1 );
									if ( preRange.text === preText ) {
										rawPreText += '\r\n';
									} else {
										preFinished = true;
									}
								}
							}
							if ( !periFinished ) {
								if ( periRange.compareEndPoints( 'StartToEnd', periRange ) === 0 ) {
									periFinished = true;
								} else {
									periRange.moveEnd( 'character', -1 );
									if ( periRange.text === periText ) {
										rawPeriText += '\r\n';
									} else {
										periFinished = true;
									}
								}
							}
							if ( !postFinished ) {
								if ( postRange.compareEndPoints( 'StartToEnd', postRange ) === 0 ) {
									postFinished = true;
								} else {
									postRange.moveEnd( 'character', -1 );
									if ( postRange.text === postText ) {
										rawPostText += '\r\n';
									} else {
										postFinished = true;
									}
								}
							}
						} while ( ( !preFinished || !periFinished || !postFinished ) );
						caretPos = rawPreText.replace( /\r\n/g, '\n' ).length;
						endPos = caretPos + rawPeriText.replace( /\r\n/g, '\n' ).length;
					} else if ( e.selectionStart || e.selectionStart === 0 ) {
						// Firefox support
						caretPos = e.selectionStart;
						endPos = e.selectionEnd;
					}
					return options.startAndEnd ? [ caretPos, endPos ] : caretPos;
				}
				return getCaret( this.get( 0 ) );
			},
			/**
			 * @fixme document the options parameters
			 */
			setSelection: function ( options ) {
				return this.each( function () {
					var selection, length, newLines;
					if ( $(this).is( ':hidden' ) ) {
						// Do nothing
					} else if ( this.selectionStart || this.selectionStart === 0 ) {
						// Opera 9.0 doesn't allow setting selectionStart past
						// selectionEnd; any attempts to do that will be ignored
						// Make sure to set them in the right order
						if ( options.start > this.selectionEnd ) {
							this.selectionEnd = options.end;
							this.selectionStart = options.start;
						} else {
							this.selectionStart = options.start;
							this.selectionEnd = options.end;
						}
					} else if ( document.body.createTextRange ) {
						selection = rangeForElementIE( this );
						length = this.value.length;
						// IE doesn't count \n when computing the offset, so we won't either
						newLines = this.value.match( /\n/g );
						if ( newLines ) {
							length = length - newLines.length;
						}
						selection.moveStart( 'character', options.start );
						selection.moveEnd( 'character', -length + options.end );

						// This line can cause an error under certain circumstances (textarea empty, no selection)
						// Silence that error
						try {
							selection.select();
						} catch ( e ) { }
					}
				});
			},
			/**
			 * Ported from Wikia's LinkSuggest extension
			 * https://svn.wikia-code.com/wikia/trunk/extensions/wikia/LinkSuggest
			 *
			 * Scroll a textarea to the current cursor position. You can set the cursor
			 * position with setSelection()
			 * @param options boolean Whether to force a scroll even if the caret position
			 *  is already visible. Defaults to false
			 *
			 * @fixme document the options parameters (function body suggests options.force is a boolean, not options itself)
			 */
			scrollToCaretPosition: function ( options ) {
				function getLineLength( e ) {
					return Math.floor( e.scrollWidth / ( $.client.profile().platform === 'linux' ? 7 : 8 ) );
				}
				function getCaretScrollPosition( e ) {
					// FIXME: This functions sucks and is off by a few lines most
					// of the time. It should be replaced by something decent.
					var i, j,
						nextSpace,
						text = e.value.replace( /\r/g, '' ),
						caret = $( e ).etTextSelection( 'getCaretPosition' ),
						lineLength = getLineLength( e ),
						row = 0,
						charInLine = 0,
						lastSpaceInLine = 0;

					for ( i = 0; i < caret; i++ ) {
						charInLine++;
						if ( text.charAt( i ) === ' ' ) {
							lastSpaceInLine = charInLine;
						} else if ( text.charAt( i ) === '\n' ) {
							lastSpaceInLine = 0;
							charInLine = 0;
							row++;
						}
						if ( charInLine > lineLength ) {
							if ( lastSpaceInLine > 0 ) {
								charInLine = charInLine - lastSpaceInLine;
								lastSpaceInLine = 0;
								row++;
							}
						}
					}
					nextSpace = 0;
					for ( j = caret; j < caret + lineLength; j++ ) {
						if (
							text.charAt( j ) === ' ' ||
							text.charAt( j ) === '\n' ||
							caret === text.length
						) {
							nextSpace = j;
							break;
						}
					}
					if ( nextSpace > lineLength && caret <= lineLength ) {
						charInLine = caret - lastSpaceInLine;
						row++;
					}
					return ( $.client.profile().platform === 'mac' ? 13 : ( $.client.profile().platform === 'linux' ? 15 : 16 ) ) * row;
				}
				return this.each(function () {
					var scroll, range, savedRange, pos, oldScrollTop;
					if ( $(this).is( ':hidden' ) ) {
						// Do nothing
					} else if ( this.selectionStart || this.selectionStart === 0 ) {
						// Mozilla
						scroll = getCaretScrollPosition( this );
						if ( options.force || scroll < $(this).scrollTop() ||
								scroll > $(this).scrollTop() + $(this).height() ) {
							$(this).scrollTop( scroll );
						}
					} else if ( document.selection && document.selection.createRange ) {
						// IE / Opera
						/*
						 * IE automatically scrolls the selected text to the
						 * bottom of the textarea at range.select() time, except
						 * if it was already in view and the cursor position
						 * wasn't changed, in which case it does nothing. To
						 * cover that case, we'll force it to act by moving one
						 * character back and forth.
						 */
						range = document.body.createTextRange();
						savedRange = document.selection.createRange();
						pos = $(this).etTextSelection( 'getCaretPosition' );
						oldScrollTop = this.scrollTop;
						range.moveToElementText( this );
						range.collapse();
						range.move( 'character', pos + 1);
						range.select();
						if ( this.scrollTop !== oldScrollTop ) {
							this.scrollTop += range.offsetTop;
						} else if ( options.force ) {
							range.move( 'character', -1 );
							range.select();
						}
						savedRange.select();
					}
					$(this).trigger( 'scrollToPosition' );
				} );
			}
		};

		// Apply defaults
		switch ( command ) {
			//case 'getContents': // no params
			//case 'setContents': // no params with defaults
			//case 'getSelection': // no params
			case 'encapsulateSelection':
				options = $.extend( {
					pre: '', // Text to insert before the cursor/selection
					peri: '', // Text to insert between pre and post and select afterwards
					post: '', // Text to insert after the cursor/selection
					ownline: false, // Put the inserted text on a line of its own
					replace: false, // If there is a selection, replace it with peri instead of leaving it alone
					selectPeri: true, // Select the peri text if it was inserted (but not if there was a selection and replace==false, or if splitlines==true)
					splitlines: false, // If multiple lines are selected, encapsulate each line individually
					selectionStart: undefined, // Position to start selection at
					selectionEnd: undefined // Position to end selection at. Defaults to start
				}, options );
				break;
			case 'getCaretPosition':
				options = $.extend( {
					// Return [start, end] instead of just start
					startAndEnd: false
				}, options );
				// FIXME: We may not need character position-based functions if we insert markers in the right places
				break;
			case 'setSelection':
				options = $.extend( {
					// Position to start selection at
					start: undefined,
					// Position to end selection at. Defaults to start
					end: undefined,
					// Element to start selection in (iframe only)
					startContainer: undefined,
					// Element to end selection in (iframe only). Defaults to startContainer
					endContainer: undefined
				}, options );

				if ( options.end === undefined ) {
					options.end = options.start;
				}
				if ( options.endContainer === undefined ) {
					options.endContainer = options.startContainer;
				}
				// FIXME: We may not need character position-based functions if we insert markers in the right places
				break;
			case 'scrollToCaretPosition':
				options = $.extend( {
					force: false // Force a scroll even if the caret position is already visible
				}, options );
				break;
		}

		context = $(this).data( 'wikiEditor-context' );
		hasIframe = context !== undefined && context && context.$iframe !== undefined;

		// IE selection restore voodoo
		needSave = false;
		if ( hasIframe && context.savedSelection !== null ) {
			context.fn.restoreSelection();
			needSave = true;
		}
		retval = ( hasIframe ? context.fn : fn )[command].call( this, options );
		if ( hasIframe && needSave ) {
			context.fn.saveSelection();
		}

		return retval;
	};

}( jQuery ) );
`

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
      while i > -1 and s.charAt(i) == '/'
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
      asnavSelect: (id) ->
        $tabs = $(this)
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
            rast.insertion.replaceSpecsymbols s, '/$', (c) ->
              if c == '/'
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
      rast.searchAndReplace.offset = 0
      rast.searchAndReplace.matchIndex = 0
      $(document).on 'click', '#et-tool-replace-button-findnext', (e) ->
        rast.searchAndReplace.doSearchReplace 'find'
        return
      $(document).on 'click', '#et-tool-replace-button-replace', (e) ->
        rast.searchAndReplace.doSearchReplace 'replace'
        return
      $(document).on 'click', '#et-tool-replace-button-replaceall', (e) ->
        rast.searchAndReplace.doSearchReplace 'replaceAll'
        return
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
        $textarea.select().etTextSelection 'encapsulateSelection',
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
            $textarea.etTextSelection 'encapsulateSelection',
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

  defaultSubsets: []

  setDefaultSubsets: ->
    @defaultSubsets = [
      {
        caption: 'Оформлення'
        symbols: [
          '[[$+]] ($+) «$+»'
          [
            '|'
            '| (риска)'
          ]
          '&nb' + 'sp — ² ³ ½ € † ‰ ÷ × → … ° °C « » " # § ¶ ~ · • ↑ ↓'
          [
            '\''
            '| (апостроф)'
          ]
          '₴ (гривня)п ·п &nbsp; ·п Ǻ Ґ ґ Є є І і Ї ї ·п Ы ы Ъ ъ Э э'
          { html: '<br/>' }
          '[[$+|$]] [[+:$]] {{+|$}} [[be:$+]] [[be-x-old:$+]] [[bg:$+]] [[de:$+]] [[el:$+]] [[en:$+]] [[ja:$+]] [[fr:$+]] [[it:$+]] [[pl:$+]] [[ru:$+]] ·п {{langнп'
          [
            '{{lang-de|$+}}'
            '-de'
          ]
          [
            '{{lang-el|$+}}'
            '-el'
          ]
          [
            '{{lang-en|$+}}'
            '-en'
          ]
          [
            '{{lang-es|$+}}'
            '-es'
          ]
          [
            '{{lang-fr|$+}}'
            '-fr'
          ]
          [
            '{{lang-it|$+}}'
            '-it'
          ]
          [
            '{{lang-la|$+}}'
            '-la'
          ]
          [
            '{{lang-uk|$+}}'
            '-uk'
          ]
          [
            '{{lang-pl|$+}}'
            '-pl'
          ]
          [
            '{{lang-ru|$+}}'
            '-ru'
          ]
          '}}п ·п {{main|$+}} ·п {{Catmore|$+}} ·п {{refнп'
          [
            '{{ref-uk}}'
            '-uk'
          ]
          [
            '{{ref-en}}'
            '-en'
          ]
          [
            '{{ref-es}}'
            '-es'
          ]
          [
            '{{ref-de}}'
            '-de'
          ]
          [
            '{{ref-fr}}'
            '-fr'
          ]
          [
            '{{ref-ru}}'
            '-ru'
          ]
          '}}п ·п <ref>$+<//ref> ·п <ref_name="">$+<//ref> ·п <blockquote>$+<//blockquote>'
          { html: '<br/>' }
          '==_$+_== ·п ===_$+_=== ·п ==_Див._також_== ·п ==_Примітки_==\n{{reflist}} ·п ==_Посилання_== ·п ==_Джерела_== ·п  <br//> ·п <big>$+<//big> ·п <source_lang="+">$<//source> ·п [[Файл:$|міні|ліворуч|200пкс|+]] ·п </div>'
          @dot
          [
            '<$>+<//$>'
            '<$></$>'
          ]
          @dot
          [
            '<+>$<//>'
            '<></>'
          ]
          @dot
          'список:п'
          {
            cap: 'вікіфікувати'
            func: ->
              rast.processSelection(rast.linkifyList)
            key: 'e'
          }
          @dot
          {
            cap: 'звичайний'
            func: ->
              rast.processSelection(rast.simpleList)
          }
          @dot
          {
            cap: 'нумерований'
            func: ->
              rast.processSelection(rast.numericList)
          }
          @dot
          {
            cap: 'нижній регістр'
            func: ->
              rast.processSelection (s) ->
                s.toLowerCase()
          }
        ]
      }
      {
        caption: 'Шаблони'
        symbols: [ '{{Wikify$+}} ·п {{без_джерел+}} ·п {{Перекладена_стаття||$+}} ·п {{Disambig$+}} {{DisambigG$+}} {{Otheruses|$+}} {{Привітання}}+--~~' + '~~ <noinclude>$+<//noinclude> ·п <includeonly>$+<//includeonly> {{su' + 'bst:afd}} ·п {{{$+}}} ·п [[Категорія:Персоналії$+]] ·п [[Категорія:Персонажі_$+]] ·п [[Категорія:Зображення:$+]] · [[Користувач:$|$+]] [[Категорія:Народились_$+]] [[Категорія:Померли_$+]] [[Категорія:Музичні_колективи,_що_з\'явились_$+]] {{DEFAULTSORT:$+}}' ]
      }
      {
        caption: 'Алфавіти'
        symbols: [ 'ѣ Ѣ ѧ Ѧ ѩ Ѫ ѫ Ѭ ѭ ·р Ą ą Ć ć Ę ę Ł ł Ń ń Ó ó Ś ś Ż ż Ź ź \n Α Β Γ Δ Ε Ζ Η Θ Ι Κ Λ Μ Ν Ξ Ο Π Ρ Σ Τ Υ Φ Χ Ψ Ω Ϊ Ϋ ά έ ή ί ΰ α β γ δ ε ζ η θ ι κ λ μ ν ξ ο π ρ ς σ τ υ φ χ ψ ω ϊ ϋ ό ύ ώ' ]
      }
      {
        caption: 'Заміна'
        symbols: [{ html: '<div>' + rast.searchAndReplace.getReplaceForm() + '</div>',  onload: rast.searchAndReplace.replaceFormInit }]
      }
    ]

  ieVersion: ->
          #http://james.padolsey.com/javascript/detect-ie-in-js-using-conditional-comments/
          v = 3
          div = document.createElement('div')
          all = div.getElementsByTagName('i')
          while (div.innerHTML = '<!--[if gt IE ' + ++v + ']><i></i><![endif]-->'; all[0])
            0
          if v > 4 then v else undefined

# все, що стосується малювання
class rast.Drawer

    # кнопочки для переходу в режим редагування: [edit][save][reset]
    drawMenu: ->
      $menu = $('<div class="rastMenu">')
      $menu.addClass(@mode)
      if @mode == 'view'
        $editButton = $('<span class="menuButton">')
        $editButton.attr('title', 'редагувати символи')
        $editButton.text('р').click(@onEditClick)
        $menu.append($editButton)
      else if @mode == 'edit'
        $persistButton = $('<span class="menuButton">').attr('title', 'зміни збережуться у Вашому особистому просторі')
        $persistButton.text('зберегти').click(@onPersistClick)
        $menu.append($persistButton)
        $menu.append($('<span> · </span>'))

        $saveButton = $('<span class="menuButton">').attr('title', 'зміни втратяться після перевантаження сторінки')
        $saveButton.text('зберегти тимчасово').click(@onSaveClick)
        $menu.append($saveButton)
        $menu.append($('<span> · </span>'))

        $cancelButton = $('<span class="menuButton">')
        $cancelButton.text('скасувати').click(@onCancelClick)
        $menu.append($cancelButton)
        $menu.append($('<span> · </span>'))

        $resetButton = $('<span class="menuButton">')
        $resetButton.text('скинути все').click(@onResetClick)
        $menu.append($resetButton)

      @$container.append($menu)

    drawTab: ($container, text)->
      $a = $('<a>')
      $adiv = $('<div>')
      $a.text text
      $adiv.append $a
      $container.append $adiv
      $adiv

    # навігація по панелях
    drawTabs: ($container)->
      i = 0
      while i < @subsets.subsets.length
        $adiv = @drawTab($container, @subsets.subsets[i].caption)
        id = 'etTabContent' + i
        $adiv.addClass('asnav-selectedtab') if @activeTab == id
        $adiv.attr 'data-contentid', id
        $adiv.click @onTabClick
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
        $addNewdiv.attr('title', 'Додати нову панель')
        $addNewdiv.click(@onAddSubsetClick)

      @$container.append($outline)

      if @mode == 'edit'
        @drawTrashZone($outline)
        @drawSlotClasses($outline)

    # [для режиму редагування] список ґудзиків, які можна створювати. Перетягуються мишкою.
    drawSlotClasses: ($outline)->
      $slots = $('<div class="slotClasses">')
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
        # revert: 'invalid'

    # [для режиму редагування] щоб видалити символ, перетягни його в поле корзини.
    drawTrashZone: ($container)->
      $trashZone = $('<div style="background-image: url(\'https://upload.wikimedia.org/wikipedia/commons/b/b7/Gnome-fs-trash-full.png\'); background-size: contain; background-repeat: no-repeat; width: 100%">')
      $trashZone.attr('title', 'Перетягніть сюди комірку, щоб її вилучити')
      $(window).resize ->
        $trashZone.css('height', $trashZone.width())
      $trashZone.droppable({
        drop: (event, ui)=>
          slotId = parseInt(ui.draggable.attr('data-id'))
          @subsets.deleteSlot(slotId)
          ui.draggable.remove()
          @onSlotRemoved()
        hoverClass: 'highlighted'
      })
      $container.append($trashZone)
      $trashZone.css('height', $trashZone.width())

    constructor: (options)->
      @$container = options.$container
      @subsets = options.subsets
      @onTabClick = options.onTabClick
      @onSaveClick = options.onSaveClick
      @onCancelClick = options.onCancelClick
      @onEditClick = options.onEditClick
      @onResetClick = options.onResetClick
      @onTabNameChanged = options.onTabNameChanged
      @onAddSubsetClick = options.onAddSubsetClick
      @onRemoveSubsetClick = options.onRemoveSubsetClick
      @onSlotAdded = options.onSlotAdded
      @onPersistClick = options.onPersistClick
      @onSlotRemoved = options.onSlotRemoved
      @mode = options.mode
      @slotClasses = options.slotClasses

    draw: (options)->
      @activeTab = options.activeTab
      mw.loader.using ['jquery.ui.sortable', 'jquery.ui.droppable', 'jquery.ui.draggable'], =>
        @$container.empty()
        @drawMenu()
        @drawNavigation()
        @drawPanels()

    # власне панелі з символами
    drawPanels: ->
      $content = $('<div>').attr('id', 'etContent').addClass('overflowHidden')
      @$container.append $content
      i = 0
      while i < @subsets.subsets.length
        $subset = @drawPanel(@subsets.subsets[i], i)
        $subsetDiv = $('<div>').attr('id', 'etTabContent' + i).attr('data-id', @subsets.subsets[i].id).appendTo($content).addClass('asnav-content').attr('title', 'Клацніть, щоб вставити символи у вікно редагування').append($subset)
        i++
      @$container.etMakeTabs(true)
      @$container.append($('<div>').css('clear', 'both'))
      @$container.asnavSelect(@activeTab)

    drawPanel: (subsetWrapper, index) ->
      $panel = $('<div>').attr('id', 'spchars-' + index).addClass('etPanel')

      if @mode == 'edit'
        $panel.attr('title', 'Клацніть, щоб змінити комірку. Комірки можна перетягувати.')
        # поле вводу для назви панелі
        $nameInput = $('<input type="text">').val(subsetWrapper.caption)
        $nameInput.change { subsetWrapper: subsetWrapper }, @onTabNameChanged
        $nameInputContainer = $('<div>')
        $nameInputContainer.append($nameInput)
        $nameInputContainer.appendTo($panel)

        $panelRemoveButton = $('<span class="panelRemoveButton">Вилучити</span>')
        $panelRemoveButton.click =>
          @onRemoveSubsetClick(subsetWrapper)
        $nameInputContainer.append($panelRemoveButton)

        $slots = $('<div class="slots">')
        $panel.append($slots)

        generateMethod = 'generateEditHtml'

        copy = null
        # можливість впорядковувати символи
        $($slots).sortable
          items: '[data-id]'
          start: (event, ui)->
            copy = $(ui.item[0].outerHTML).clone()
          placeholder: {
            element: (copy, ui)->
              return $('<span class="ui-state-highlight">' + copy[0].innerHTML + '</li>')
            update: ->
          }
          receive: (event, ui)=>
            slotClass = eval(ui.item.attr('data-slot-class'))
            index = $(event.target).data().sortable.currentItem.index()
            newSlot = @subsets.addSlot(slotClass, subsetWrapper, index)
            newSlot.caption = 'нова комірка'
            @onSlotAdded(newSlot)
          update: (event, ui)=>
            newSlotIndex = ui.item.index('[data-id]') - 1
            return if newSlotIndex < 0
            return unless $(ui.item).attr('data-id')
            slotId = parseInt($(ui.item).attr('data-id'))
            slot = @subsets.slotById(slotId)
            @rearrangeSlot(slot, newSlotIndex)
            @updatePreview(subsetWrapper)
          revert: true

        @generateHtml($slots, subsetWrapper.slots, generateMethod)
        $preview = $('<div>').css('border-top', '1px solid color: #aaa').addClass('preview')
        $preview.append($('<div>Попередній перегляд:</div>'))
        $previewContent = $('<div class="content">')
        @generateHtml($previewContent, subsetWrapper.slots, 'generateHtml')
        $preview.append($previewContent)
        $panel.append($preview)
      else if @mode == 'view'
        generateMethod = 'generateHtml'
        @generateHtml($panel, subsetWrapper.slots, generateMethod)
      $panel

    updatePreview: (subsetWrapper)->
      $previewContent = @$container.find(".asnav-content[data-id=#{ subsetWrapper.id }] .preview .content")
      $previewContent.empty()
      @generateHtml $previewContent, subsetWrapper.slots, 'generateHtml'

    rearrangeSlot: (slot, newSlotIndex)->
      subset = @subsets.subsetBySlot(slot)
      slotIndex = @subsets.slotIndex(slot)
      subset.slots.rastMove(slotIndex, newSlotIndex)

    generateHtml: ($panel, slots, generateMethod) ->
      for slot in slots
        $panel.append(slot[generateMethod]())

class rast.PlainObjectParser

    @parseTokens: (arr, hotkeysHandler) ->
      len = arr.length
      slots = []
      i = 0
      while i < len
        if typeof arr[i] == 'string'
          slots = slots.concat(@slotsFromStr(arr[i]))
        else if Object::toString.call(arr[i]) == '[object Array]'
          slots.push @slotFromArr(arr[i])
        else if typeof arr[i] == 'object'
          slot = @slotFromPlainObj(arr[i], hotkeysHandler)
          if slot
            slots.push(slot)
        i += 1
      slots

    @slotFromArr: (arr) ->
      new rast.InsertTagSlot(@parseInsertion(arr[0], arr[1]))

    @slotsFromStr: (str) ->
      tokens = str.split(' ')
      slots = []
      slot = undefined
      i = 0
      while i < tokens.length
        slot = @slotFromStr(tokens[i])
        slots.push slot
        i++
      slots

    @lineReplace: (c) ->
      if c == '/'
        return '/'
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
          slot.text = EditTools.charinsertDivider + ' '
        else
          slot.text = rast.insertion.replaceSpecsymbols(token, '/_', @lineReplace) + ' '
      else
        slot = new rast.InsertTagSlot(
          bold: modifiers.bold
          italic: modifiers.italic)
        $.extend slot, @parseInsertion(token, '')
      slot

    @generateLink: (obj) ->
      slot = undefined
      if obj.ins or obj.insert
        slot = new rast.InsertTagSlot({})
        $.extend slot, @parseInsertion(obj.ins or obj.insert, obj.cap or obj.caption,
          bold: obj.b or obj.bold
          italic: obj.i or obj.italic)
      else if obj.func
        slot = new rast.LinkSlot(
          func: obj.func
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
      tagOpen = rast.insertion.replaceSpecsymbols(tagOpen, '/_', @lineReplace)
      tagClose = rast.insertion.replaceSpecsymbols(tagClose, '/_', @lineReplace)
      if !caption
        caption = tagOpen + tagClose + ' '
        caption = rast.insertion.replaceSpecsymbols(caption, '/$', (c) ->
          if c == '$'
            return ''
          else if c == '/'
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

    removeSubset: (subsetToBeRemoved)  ->
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
      slot = @slotById(slotId)
      slotIndex = @slotIndex(slot)
      subset = @subsetBySlot(slot)
      subset.slots.splice(slotIndex, 1);

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
      MyDialog = (config) ->
        MyDialog.super.call this, config

      OO.inheritClass MyDialog, OO.ui.Dialog
      # Specify a title statically (or, alternatively, with data passed to the opening() method).
      MyDialog.static.title = 'Simple dialog'
      # Customize the initialize() function: This is where to add content to the dialog body and set up event handlers.

      MyDialog::initialize = ->
        # Call the parent method
        MyDialog.super::initialize.call this
        @$body.append $content
        return

      # Override the getBodyHeight() method to specify a custom height (or don't to use the automatically generated height)

      MyDialog::getBodyHeight = ->
        $content.outerHeight true

      # Make the window.
      myDialog = new MyDialog(size: 'medium')
      # Create and append a window manager, which will open and close the window.
      windowManager = new (OO.ui.WindowManager)
      $('body').append windowManager.$element
      # Add the window to the window manager using the addWindows() method.
      windowManager.addWindows [ myDialog ]
      # Open the window!
      windowManager.openWindow myDialog
      myDialog

  # генерує поля для редагування символа. Для цього кожен клас символів має властивість editableAttributes.
class rast.SlotAttributesEditor

    constructor: (@slot)->

    startEditing: ->
      slot = @slot
      slotClass = slot.constructor
      inputs = []

      for attribute in slotClass.editableAttributes
        value = slot[attribute.name]
        type = attribute.type
        OOinput =
          if type == 'string' || type == 'text'
            fieldOptions = { value: value, multiline: type == 'text' }
            {
              getValue: 'getValue',
              OOobject: new OO.ui.TextInputWidget(fieldOptions)
            }
          else if type == 'boolean'
            {
              getValue: 'isSelected',
              OOobject: new OO.ui.CheckboxInputWidget( {
                value: true,
                selected: value
              })
            }

        inputs.push({ attribute: attribute.name, label: attribute.name, input: OOinput.OOobject, getValueFunc: OOinput.getValue }) if OOinput

      # Create a Fieldset layout.
      fieldset = new OO.ui.FieldsetLayout( {
        label: 'Редагування комірки'
      } );

      # Add field layouts that contain the form elements to the fieldset. Items can also be specified
      # with the FieldsetLayout's 'items' config option:

      fields = $.map(inputs, (inputWrapper, index)->
        new OO.ui.FieldLayout(inputWrapper.input, {
          label: inputWrapper.label,
          align: 'left'
        } )
      )

      fieldset.addItems(fields);

      $content = $('<div>')
      $content.append(fieldset.$element)

      dialog = rast.UIwindow.show($content)

      saveButton = new OO.ui.ButtonWidget(icon: 'check', label: 'Зберегти')
      saveButton.on 'click', ->
        for inputWrapper in inputs
          slot[inputWrapper.attribute] = inputWrapper.input[inputWrapper.getValueFunc]()
        EditTools.refresh()
        dialog.close()
      $content.append(saveButton.$element)

      cancelButton = new OO.ui.ButtonWidget(icon: 'cancel', label: 'Скасувати')
      cancelButton.on 'click', ->
        dialog.close()

      $content.append(cancelButton.$element)

  # символ
class rast.Slot

    @editableAttributes: []

    @editorClass: rast.SlotAttributesEditor

    editWindow: ->
      editor = new @constructor.editorClass(@)
      editor.startEditing()

    constructor: (options = {}) ->
      for attribute in @constructor.editableAttributes
        @[attribute.name] = attribute.default
      $.extend @, options, 'class': 'rast.' + @constructor.name

    generateEditHtml: ->
      $element = @generateHtml()
      $($element).addClass('editedSlot')
      $element

class rast.PlainTextSlot extends rast.Slot

    @caption: 'Простий текст'

    @editableAttributes: [
      { name: 'bold', type: 'boolean', default: false }
      { name: 'italic', type: 'boolean', default: false }
      { name: 'text', type: 'string', default: 'Plain text' }
    ]

    generateHtml: ->
      $elem = $('<span>')
      $elem.text(@text)
      $elem.attr('data-id', @id)
      if @bold
        $elem.css('font-weight', 'bold')
      if @italic
        $elem.css('font-style', 'italic')
      $elem


class rast.LinkSlot extends rast.Slot

    @caption: 'Посилання'

    generateEditHtml: ->
      $a = @generateCommonHtml()
      $a.addClass('editedSlot')

    generateCommonHtml: ->
      $a = $('<a>')
      $a.attr('data-id', @id)
      caption = $('<div/>').text(@caption).html()
      $a.html(caption)
      if @bold
        $a.css('font-weight', 'bold')
      if @italic
        $a.css('font-style', 'italic')
      $a

    generateHtml: ->
      $a = @generateCommonHtml()
      $a.click (event)=>
        event.preventDefault()
        @func.apply($(event.target))
      $a

    toJSON: ->
      copy = rast.clone(@)
      copy.func = @func.toString() if @func
      copy

    constructor: (options = {}) ->
      super(options)
      if @func
        @func = eval('(' + @func + ')')

class rast.InsertionSlot extends rast.Slot

    @caption: 'Вставка'

    @editableAttributes: [
      { name: 'bold', caption: 'Жирний', type: 'boolean', default: false }
      { name: 'italic', caption: 'Похилий', type: 'boolean', default: false }
      { name: 'caption', caption: 'Напис', type: 'string', default: 'Нова вставка' }
      { name: 'insertion', caption: 'Текст вставки', type: 'string', default: '$' }
    ]

    constructor: (options) ->
      super(options)

    @insertFunc = (insertion) ->
      rast.$getTextarea().focus()
      tags = rast.PlainObjectParser.parseInsertion(insertion, '')
      rast.$getTextarea().insertTag(tags.tagOpen, tags.tagClose)

    generateEditHtml: ->
      $a = @generateCommonHtml()
      $a.addClass('editedSlot')

    generateCommonHtml: ->
      $a = $('<a>')
      $a.attr('data-id', @id)
      caption = $('<div/>').text(@caption).html()
      $a.html(caption)
      if @bold
        $a.css('font-weight', 'bold')
      if @italic
        $a.css('font-style', 'italic')
      $a

    generateHtml: ->
      $a = @generateCommonHtml()
      $a.click (event)=>
        event.preventDefault()
        rast.InsertionSlot.insertFunc(@insertion)
      $a

class rast.InsertTagSlot extends rast.LinkSlot

    @caption: 'Тег'

    @insertTagFunc = (open, close) ->
      rast.$getTextarea().focus()
      rast.$getTextarea().insertTag(open, close)

    @editableAttributes: [
      { name: 'bold', type: 'boolean', default: false }
      { name: 'italic', type: 'boolean', default: false }
      { name: 'caption', type: 'string', default: 'New insertion' }
      { name: 'tagOpen', type: 'string', default: 'Start' }
      { name: 'tagClose', type: 'string', default: 'End' }
    ]

    generateHtml: ->
      $a = @generateCommonHtml()
      $a.click (event)=>
        event.preventDefault()
        rast.InsertTagSlot.insertTagFunc(@tagOpen, @tagClose)
      $a

class rast.HtmlSlot extends rast.Slot

    @caption: 'Довільний код'

    @editableAttributes: [
      { name: 'html', type: 'text', default: '<span>html</span>' }
      { name: 'onload', type: 'text', default: 'function(){  }' }
    ]

    toJSON: ->
      copy = rast.clone(@)
      copy.onload = @onload.toString() if @onload
      copy

    constructor: (options) ->
      super(options)
      if typeof @onload is 'string'
        @onload = eval('(' + @onload + ')')
      if typeof @onload is 'function'
        EditTools.addOnloadFunc(@onload)

    generateHtml: ->
      $elem = $(@html)
      $elem.attr('data-id', @id)
      $elem

class rast.PageStorage

  @load: (pagename, onLoaded, onNotFound)->
    mw.loader.using 'mediawiki.api.edit', ->
        api = new (mw.Api)
        api.get(
          action: 'query'
          prop: 'revisions'
          rvprop: 'content'
          titles: pagename
        ).done (data) ->
         for pageId of data.query.pages
           if data.query.pages[pageId].revisions
             onLoaded?(data.query.pages[pageId].revisions[0]['*'])
           else
             onNotFound?(pageId)

  @save: (pagename, string)->
    mw.loader.using 'mediawiki.api.edit', ->
        api = new (mw.Api)
        api.postWithEditToken
          action: 'edit'
          title: pagename
          summary: '[[Обговорення користувача:AS/rast.js|serialize]]'
          text: string

$ ->
  window.EditTools =
    hotkeys: []
    onloadFuncs: []
    mode: 'view'
    addOnloadFunc: (func) =>
      EditTools.onloadFuncs.push(func)
    fireOnloadFuncs: ->
      for func in EditTools.onloadFuncs
        func()
    checkHotkey: (e) ->
      if e and e.ctrlKey
        obj = EditTools.hotkeys[String.fromCharCode(e.which).toUpperCase()]
        if obj
          if typeof obj == 'object'
            obj.trigger 'click'
          else
            obj()
          return false
      true
    charinsertDivider: ' '
    extraCSS: '#edittools { min-height: 20px; } #edittools .rastMenu.view { position: absolute; left: 0px; } #edittools .slots.ui-sortable { min-height: 4em; border-width: 1px; border-style: dashed; } #edittools .editedSlot { cursor: move; min-width: 10px; border-left: 1px solid black; border-top: 1px solid black; border-bottom: 1px solid black; } #edittools .slotClass { cursor: copy; } #edittools .panelRemoveButton, #edittools .menuButton { cursor: pointer; } #edittools .ui-state-highlight { height: 1em; line-height: 1em; } #edittools [data-id]{ display: inline-block } .specialchars-tabs {float: left; background: #E0E0E0; margin-right: 7px; } .specialchars-tabs a{ display: block; } #edittools { border: solid #aaaaaa 1px; } .mw-editTools a{ cursor: pointer; } .overflowHidden { overflow: hidden; } .specialchars-tabs .asnav-selectedtab{ background: #F0F0F0; } #edittools .highlighted { opacity: 0.5; }'
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
      $tabs.on event, '.asnav-content .etPanel [data-id]', ($e) ->
        if EditTools.mode == 'edit'
          id = parseInt($(this).closest('.editedSlot').attr('data-id'))
          slot = EditTools.temporarySubsets.slotById(id)
          slot.editWindow()
      $tabs

    edit: ->
      @mode = 'edit'
      @refresh()

    view: ->
      @mode = 'view'
      @refresh()

    reset: ->
      @onloadFuncs = []
      @subsets.reset()

    readFromEtSubsets: ->
      @reset()
      @subsets.readEncodedSubsets(rast.defaultSubsets)
      @subsetsUpdated()
      @refresh()

    subsetsUpdated: ->
      @temporarySubsets = rast.clone(@subsets, false)

    undoChanges: ->
      @temporarySubsets = rast.clone(@subsets)

    refresh: ->
      if !@created
        return

      $tabs = $('#' + @id)
      etActiveTab = $tabs.find('.existingTabs .asnav-selectedtab').attr('data-contentid') || mw.cookie.get(EditTools.cookieName + 'Selected') or 'etTabContent0'

      refocus = ($e) ->
        rast.focusWithoutScroll(rast.$getTextarea())

      drawer = new rast.Drawer(
        $container: $tabs,
        subsets: @temporarySubsets,
        onTabClick: null,
        mode: @mode,
        onSaveClick: =>
          @save()
        onCancelClick: =>
          @undoChanges()
          @view()
        onResetClick: =>
          rast.setDefaultSubsets()
          @readFromEtSubsets()
        onEditClick: =>
          @edit()
        onTabNameChanged: (event)=>
          event.data.subsetWrapper.caption = $(event.target).val()
          @refresh()
        onAddSubsetClick: =>
          subset = @temporarySubsets.addSubset('Нова панель', @temporarySubsets.subsets.length)
          @refresh()
          $tabs.asnavSelect('etTabContent' + subset.id)
        onRemoveSubsetClick: (subsetWrapper)=>
          @temporarySubsets.removeSubset(subsetWrapper)
          @refresh()
        onSlotAdded: =>
          @refresh()
        onPersistClick: =>
          @save()
          @saveToSubpage()
        onSlotRemoved: =>
          @refresh()
        slotClasses: [rast.PlainTextSlot, rast.InsertionSlot, rast.InsertTagSlot, rast.HtmlSlot]
        )
      drawer.draw({ activeTab: etActiveTab })

      @fireOnloadFuncs()
      $tabs.on 'asNav:select', (ev, selectedId) ->
        mw.cookie.set EditTools.cookieName + 'Selected', selectedId

    save: ->
      @subsets = @temporarySubsets
      @subsetsUpdated()
      @view()

    restoreDefaults: ->
      rast.setDefaultSubsets()
      @readFromEtSubsets()

    setup: ->
      EditTools.subsets = new rast.SubsetsManager
      EditTools.temporarySubsets = new rast.SubsetsManager
      $placeholder = $(EditTools.parentId)
      if !$placeholder.length
        return
      EditTools.appendExtraCSS()
      $placeholder.empty().append EditTools.createEditTools()
      $('input#wpSummary').attr 'style', 'margin-bottom:3px;' #fix margins after moving placeholder

      EditTools.created = true
      EditTools.refresh()
      EditTools.reload()

    reload: ->
      @readFromSubpage(=>
        @readFromEtSubsets()
      )

    init: ->
      if mw.config.get('wgAction') == 'edit' or mw.config.get('wgAction') == 'submit'
        mw.loader.using 'jquery.colorUtil', EditTools.setup

    serialize: ->
      JSON.stringify(@subsets, null, 2)

    subpageStorageName: 'AStools.js',

    saveToSubpage: ->
      @serializeToPage('User:' + mw.config.values.wgUserName + '/' + @subpageStorageName)

    serializeToPage: (pagename) ->
      serializedTools = "<nowiki>#{ @serialize() }</nowiki>"
      rast.PageStorage.save(pagename, serializedTools)

    readFromSubpage: (onNotFound) ->
      @reset()
      json = rast.PageStorage.load('User:' + mw.config.values.wgUserName + '/' + @subpageStorageName,
        (pagetext)=>
          pagetextWithoutNowiki = pagetext.replace(/^<nowiki>/, '').replace(/<\/nowiki>$/, '')
          serializedTools = JSON.parse(pagetextWithoutNowiki)
          @subsets.deserialize(serializedTools)
          @subsetsUpdated()
          @refresh()
        onNotFound
      )
  # end EditTools

  rast.PlainObjectParser.processShortcut = EditTools.processShortcut;
  rast.PlainObjectParser.addOnloadFunc = EditTools.addOnloadFunc;

  mw.loader.using ['mediawiki.cookie', 'oojs-ui', 'jquery.ui.droppable'], ->
    rast.installJQueryPlugins()
    EditTools.init()
