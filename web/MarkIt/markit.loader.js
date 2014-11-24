(function() {

    //////////////////////    FUNCTIONS      ///////////////////////////

    function elem(id) {
        return g_document.getElementById(id);
    }


    function tags(name) {
        return g_document.getElementsByTagName(name);
    }


    function attr(node, name, value) {
        return value ? (node.setAttribute(name, value), node) : node.getAttribute(name);
    }


    function indexOf(s, s2) {
        return s.indexOf(s2);
    }


    function replace(s, pattern, s2) {
        return s.replace(pattern, s2);
    }


    function on_markit_js_loaded() {
        script = xhr.responseText;

        // XHR can't cross domains.
        if (script.length > 0) {
            //alert('got script: ' + script);

            // YUI compressor refuses to optimize scripts containing eval(),
            // so we do a trick in Makefile, where EVAL is replaced with eval.
            EVAL(replace(replace(replace(script,
                        /#v#/g, loader_version),
                        /#r#/g, markit_root),
                        /#k#/g, markit_key));
        } else {
            load_markit_js_by_script_tag();
        }
    }


    function load_markit_js_by_script_tag() {
        script = g_document.createElement('script');
        attr(attr(attr(attr(attr(attr(script,
                    'src', markit_url),
                    'r', markit_root),
                    'k', markit_key),
                    'v', loader_version),
                    'charset', 'UTF-8'),
                    'id', id);
        script.ontimeout = script.onerror = function() {
            script.ontimeout = script.onerror = null;
            script.parentNode.removeChild(script);
            alert('Can\'t load ' + markit_url);
        }

        tags('body')[0].appendChild(script);
    }


    //////////////////////     CODE          ///////////////////////////

    var g_window = window.top,              /* help YUI compressor */
        g_document = g_window.document,
        dialog = elem('markit-dialog'),
        id = 'markit-script',
        msg = 'Loading MarkIt dialog!',
        loader_version  = ##LOADER_VERSION##,
        markit_key      = '##MARKIT_KEY##',
        markit_root     = '##MARKIT_ROOT##',
        markit_url      = markit_root + '##MARKIT_URL##',   /* for short script generated by index.html */
        file_protocol   = 'file:',
        markit_url_is_local = (indexOf(markit_url, file_protocol) == 0),
        script, scripts,
        xhr,
        isXDomainRequest = 0,
        i;

    if (dialog) {
        // markit.js must load jQuery and jQuery UI first, then create dialog
        jQuery(dialog).toggle();
        return;
    }

    if (elem(id)) {
        alert(msg);
        return;
    } else {
        scripts = tags('script');

        for (i = 0; i < scripts.length; ++i) {
            if (markit_url == attr(scripts[i], 'src')) {
                alert(msg);
                return;
            }
        }
    }


    if (! (indexOf(location.href, file_protocol) != 0 && markit_url_is_local)) {
        try {
            // prefer XMLHttpRequest to script tag for privacy, as other
            // scripts in this document won't peek into our private data,
            // especially `markit_key'.

            if (g_window.XDomainRequest) {
                xhr = new XDomainRequest();
                isXDomainRequest = 1;
            } else if (g_window.XMLHttpRequest && (! markit_url_is_local || ! g_window.ActiveXObject)) {
                // XMLHttpRequest in IE7 can't request local files, so we
                // use the ActiveXObject when it is available.
                xhr = new XMLHttpRequest();     // Firefox, Opera, Safari
            } else {
                xhr = new ActiveXObject('Microsoft.XMLHTTP');   // IE 5.5+
            }

            if (isXDomainRequest) {
                xhr.timeout = 10000;
                xhr.onload = on_markit_js_loaded;
                xhr.onerror = xhr.ontimeout = load_markit_js_by_script_tag;
            }

            // stupid Firefox requires this before setting onreadystatechange
            xhr.open('GET', markit_url);

            if (! isXDomainRequest) {
                if (xhr.overrideMimeType) {
                    // avoid Firefox treating it as text/xml to report a syntax error.
                    // must be before send().
                    xhr.overrideMimeType('text/javascript; charset=UTF-8');
                }

                //if (! markit_url_is_local) {
                    // must be after open().
                    //xhr.setRequestHeader('User-Agent', 'Wget');
                //}

                xhr.onreadystatechange = function() {
                    if (xhr.readyState == 4) {
                        xhr.onreadystatechange = function() {};
                        i = xhr.status;

                        if (i == 200 || i == 0) {
                            on_markit_js_loaded();
                        } else {
                            load_markit_js_by_script_tag();
                        } // end if
                    } // end if
                } //end function
            } // end if

            xhr.send();
            return;
        } catch (e) {
            alert(e);
        } // end try
    } // end if

    load_markit_js_by_script_tag();

})()

