import Foundation

enum DevToolsScript {
    static let bridgeName = "liquidBridge"

    static let source = """
    (function() {
      if (window.__liquidBridgeInstalled) {
        return;
      }
      window.__liquidBridgeInstalled = true;

      function serializeArg(value) {
        try {
          if (typeof value === 'string') { return value; }
          if (typeof value === 'undefined') { return 'undefined'; }
          if (value === null) { return 'null'; }
          if (value instanceof Error) { return value.message; }
          return JSON.stringify(value);
        } catch (error) {
          return String(value);
        }
      }

      function post(payload) {
        try {
          window.webkit.messageHandlers.liquidBridge.postMessage(payload);
        } catch (error) {
        }
      }

      var nativeConsole = {
        log: console.log,
        info: console.info,
        warn: console.warn,
        error: console.error,
        debug: console.debug
      };

      ['log', 'info', 'warn', 'error', 'debug'].forEach(function(level) {
        console[level] = function() {
          var parts = Array.prototype.slice.call(arguments).map(serializeArg);
          post({
            kind: 'console',
            level: level,
            message: parts.join(' ')
          });
          nativeConsole[level].apply(console, arguments);
        };
      });

      var originalFetch = window.fetch;
      if (originalFetch) {
        window.fetch = function() {
          var startedAt = Date.now();
          var request = new Request(arguments[0], arguments[1]);

          post({
            kind: 'network',
            source: 'fetch',
            method: request.method || 'GET',
            url: request.url,
            status: 'started'
          });

          return originalFetch.apply(this, arguments)
            .then(function(response) {
              post({
                kind: 'network',
                source: 'fetch',
                method: request.method || 'GET',
                url: response.url || request.url,
                status: String(response.status),
                duration: Date.now() - startedAt
              });
              return response;
            })
            .catch(function(error) {
              post({
                kind: 'network',
                source: 'fetch',
                method: request.method || 'GET',
                url: request.url,
                status: 'error: ' + serializeArg(error),
                duration: Date.now() - startedAt
              });
              throw error;
            });
        };
      }

      var open = XMLHttpRequest.prototype.open;
      var send = XMLHttpRequest.prototype.send;

      XMLHttpRequest.prototype.open = function(method, url) {
        this.__liquidMethod = method;
        this.__liquidURL = url;
        return open.apply(this, arguments);
      };

      XMLHttpRequest.prototype.send = function() {
        var xhr = this;
        var startedAt = Date.now();
        var method = xhr.__liquidMethod || 'GET';
        var url = xhr.__liquidURL || '';

        post({
          kind: 'network',
          source: 'xhr',
          method: method,
          url: url,
          status: 'started'
        });

        function complete(statusText) {
          post({
            kind: 'network',
            source: 'xhr',
            method: method,
            url: url,
            status: statusText,
            duration: Date.now() - startedAt
          });
        }

        xhr.addEventListener('load', function() {
          complete(String(xhr.status));
        });

        xhr.addEventListener('error', function() {
          complete('error');
        });

        xhr.addEventListener('abort', function() {
          complete('aborted');
        });

        return send.apply(this, arguments);
      };

      function reportVideoSource(video) {
        if (!video) { return; }
        var src = video.currentSrc || video.src || '';
        if (!src) { return; }
        post({
          kind: 'video',
          url: src
        });
      }

      document.addEventListener('play', function(event) {
        var element = event.target;
        if (!element || element.tagName !== 'VIDEO') { return; }
        reportVideoSource(element);
      }, true);

      var observer = new MutationObserver(function() {
        document.querySelectorAll('video').forEach(function(video) {
          video.addEventListener('loadedmetadata', function() {
            reportVideoSource(video);
          }, { once: true });
        });
      });

      var rootNode = document.documentElement || document.body;
      if (rootNode) {
        observer.observe(rootNode, {
          childList: true,
          subtree: true
        });
      }
    })();
    """
}
