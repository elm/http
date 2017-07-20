/*

import Dict exposing (empty, update)
import Elm.Kernel.Scheduler exposing (binding, fail, rawSpawn, succeed)
import Maybe exposing (Maybe(Just, Nothing))
import Result exposing (map)

*/

// ENCODING AND DECODING

function _Http_encodeUri(string)
{
	return encodeURIComponent(string);
}

function _Http_decodeUri(string)
{
	try
	{
		return __Maybe_Just(decodeURIComponent(string));
	}
	catch(e)
	{
		return __Maybe_Nothing;
	}
}


// SEND REQUEST

var _Http_toTask = F2(function(request, maybeProgress)
{
	return __Scheduler_binding(function(callback)
	{
		var xhr = new XMLHttpRequest();

		_Http_configureProgress(xhr, maybeProgress);

		xhr.addEventListener('error', function() {
			callback(__Scheduler_fail({ $: 'NetworkError' }));
		});
		xhr.addEventListener('timeout', function() {
			callback(__Scheduler_fail({ $: 'Timeout' }));
		});
		xhr.addEventListener('load', function() {
			callback(_Http_handleResponse(xhr, request.__$expect.__responseToResult));
		});

		try
		{
			xhr.open(request.__$method, request.__$url, true);
		}
		catch (e)
		{
			return callback(__Scheduler_fail({ $: 'BadUrl', a: request.__$url }));
		}

		_Http_configureRequest(xhr, request);
		_Http_send(xhr, request.__$body);

		return function() { xhr.abort(); };
	});
});

function _Http_configureProgress(xhr, maybeProgress)
{
	if (maybeProgress.$ === 'Nothing')
	{
		return;
	}

	xhr.addEventListener('progress', function(event) {
		if (!event.lengthComputable)
		{
			return;
		}
		__Scheduler_rawSpawn(maybeProgress.a({
			__$bytes: event.loaded,
			__$bytesExpected: event.total
		}));
	});
}

function _Http_configureRequest(xhr, request)
{
	var headers = request.__$headers;
	while (headers.$ !== '[]')
	{
		var pair = headers.a;
		xhr.setRequestHeader(pair.a, pair.b);
		headers = headers.b;
	}

	xhr.responseType = request.__$expect.__responseType;
	xhr.withCredentials = request.__$withCredentials;

	if (request.__$timeout.$ === 'Just')
	{
		xhr.timeout = request.__$timeout.a;
	}
}

function _Http_send(xhr, body)
{
	switch (body.$)
	{
		case 'EmptyBody':
			xhr.send();
			return;

		case 'StringBody':
			xhr.setRequestHeader('Content-Type', body.a);
			xhr.send(body.b);
			return;

		case 'FormDataBody':
			xhr.send(body.a);
			return;
	}
}


// RESPONSES

function _Http_handleResponse(xhr, responseToResult)
{
	var response = _Http_toResponse(xhr);

	if (xhr.status < 200 || 300 <= xhr.status)
	{
		response.body = xhr.responseText;
		return __Scheduler_fail({
			$: 'BadStatus',
			a: response
		});
	}

	var result = responseToResult(response);

	if (result.$ === 'Ok')
	{
		return __Scheduler_succeed(result.a);
	}
	else
	{
		response.body = xhr.responseText;
		return __Scheduler_fail({
			$: 'BadPayload',
			a: result.a,
			b: response
		});
	}
}

function _Http_toResponse(xhr)
{
	return {
		__$url: xhr.responseURL,
		__$status: { __$code: xhr.status, __$message: xhr.statusText },
		__$headers: _Http_parseHeaders(xhr.getAllResponseHeaders()),
		__$body: xhr.response
	};
}

function _Http_parseHeaders(rawHeaders)
{
	var headers = __Dict_empty;

	if (!rawHeaders)
	{
		return headers;
	}

	var headerPairs = rawHeaders.split('\u000d\u000a');
	for (var i = headerPairs.length; i--; )
	{
		var headerPair = headerPairs[i];
		var index = headerPair.indexOf('\u003a\u0020');
		if (index > 0)
		{
			var key = headerPair.substring(0, index);
			var value = headerPair.substring(index + 2);

			headers = A3(__Dict_update, key, function(oldValue) {
				if (oldValue.$ === 'Just')
				{
					return __Maybe_Just(value + ', ' + oldValue.a);
				}
				return __Maybe_Just(value);
			}, headers);
		}
	}

	return headers;
}


// EXPECTORS

function _Http_expectStringResponse(responseToResult)
{
	return {
		$: __0_EXPECT,
		__responseType: 'text',
		__responseToResult: responseToResult
	};
}

var _Http_mapExpect = F2(function(func, expect)
{
	return {
		$: __0_EXPECT,
		__responseType: expect.__responseType,
		__responseToResult: function(response) {
			var convertedResponse = expect.__responseToResult(response);
			return A2(__Result_map, func, convertedResponse);
		}
	};
});


// BODY

function _Http_multipart(parts)
{
	var formData = new FormData();

	while (parts.$ !== '[]')
	{
		var part = parts.a;
		formData.append(part.a, part.b);
		parts = parts.b;
	}

	return { $: 'FormDataBody', a: formData };
}
