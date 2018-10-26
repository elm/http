/*

import Elm.Kernel.Platform exposing (preload)
import Elm.Kernel.Scheduler exposing (binding)

*/


var _Http_toTask = F3(function(router, toMsg, request)
{
	return __Scheduler_binding(function(callback)
	{
		__Platform_preload.add(request.__$url);
	});
});


// PAIR

var _Http_pair = F2(function(a, b) { return { $: 0, a: a, b: b }; });
var _Http_emptyBody = { $: 0 };
function _Http_coerce(x) { return x; }


// BODY PARTS

function _Http_toFormData(parts)
{
	for (var formData = new FormData(); parts.b; parts = parts.b) // WHILE_CONS
	{
		var part = parts.a;
		formData.append(part.a, part.b);
	}
	return formData;
}

var _Http_bytesToBlob = F2(function(mime, bytes)
{
	return new Blob([bytes], { type: mime });
});
