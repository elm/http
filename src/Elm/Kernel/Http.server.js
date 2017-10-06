/*

import Elm.Kernel.Platform exposing (preload)
import Elm.Kernel.Scheduler exposing (binding)

*/


var _Http_toTask = F2(function(request, maybeProgress)
{
	return __Scheduler_binding(function(callback)
	{
		__Platform_preload.add(request.__$url);
	});
});


function _Http_expectStringResponse(responseToResult)
{
	return {
		$: __0_EXPECT,
		__responseType: 'text',
		__responseToResult: responseToResult
	};
}


function _Http_multipart()
{
	return { $: 'FormDataBody', a: new FormData() };
}


var _Http_mapExpect = F2(function(func, expect)
{
	return expect;
});

