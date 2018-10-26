effect module Http.Advanced where { command = MyCmd, subscription = MySub } exposing
  ( Request, request, send
  , Header, header
  , Body, emptyBody, stringBody, fileBody, bytesBody
  , multipartBody, Part, stringPart, filePart, bytesPart
  , Expect, expectString, expectBytes, Response(..)
  , Progress(..), track
  )

{-| This is an advanced version of the [`Http`](/packages/elm/http/latest/Http)
module that gives you a little bit more control over errors, progress, and
cookies. **The docs will only point out important differences.**

# Requests
@docs Request, request, send

# Header
@docs Header, header

# Body
@docs Body, emptyBody, stringBody, fileBody, bytesBody

# Body Parts
@docs multipartBody, Part, stringPart, filePart, bytesPart

# Expect
@docs Expect, expectString, expectBytes, Response

# Progress
@docs Progress, track

-}


import Bytes exposing (Bytes)
import Dict exposing (Dict)
import Elm.Kernel.Http
import File exposing (File)
import Platform
import Process
import Task exposing (Task)



-- REQUESTS


{-| Describes an HTTP request with more control over errors and cookies.
-}
type Request x a =
  Request
    { method : String
    , headers : List Header
    , url : String
    , body : Body
    , expect : Expect x a
    , timeout : Maybe Float
    , tracker : Maybe String
    , allowCookiesFromOtherDomains : Bool
    }


{-| Create a custom request with two extra abilities:

1. The `expect` field gives you full access to the response body, so if your
server gives nice JSON on every 404, you can decode that and display it how
you want.
2. The `allowCookiesFromOtherDomains` allows responses from other domains to
set cookies. It also will include any relevant cookies in requests. This is
called [`withCredentials`][wc] in JavaScript.

**Be careful with that second ability!** Every HTTP request includes a `Host`
header identifying the domain of the sender, so any request to `facebook.com`
reveals the website that sent it. If you enable `allowCookiesFromOtherDomains`
this information can be correlated with specific users. For logged in users,
their cookie is in the request. For logged out users, their cookie is in the
request. For people without accounts, they can set a new cookie to uniquely
identify the browser and a profile can be built around that.

[wc]: https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest/withCredentials
-}
request
  : { method : String
    , headers : List Header
    , url : String
    , body : Body
    , expect : Expect x a
    , timeout : Maybe Float
    , tracker : Maybe String
    , allowCookiesFromOtherDomains : Bool
    }
  -> Request x a
request =
  Request



-- HEADERS


{-|-}
type Header = Header String String


{-|-}
header : String -> String -> Header
header =
  Header



-- BODY


{-|-}
type Body = Body


{-|-}
emptyBody : Body
emptyBody =
  Elm.Kernel.Http.emptyBody


{-|-}
stringBody : String -> String -> Body
stringBody =
  Elm.Kernel.Http.pair


{-|-}
bytesBody : String -> Bytes -> Body
bytesBody =
  Elm.Kernel.Http.pair


{-|-}
fileBody : File -> Body
fileBody =
  Elm.Kernel.Http.pair ""



-- PARTS


{-|-}
multipartBody : List Part -> Body
multipartBody parts =
  Elm.Kernel.Http.pair "" (Elm.Kernel.Http.toFormData parts)


{-|-}
type Part = Part


{-|-}
stringPart : String -> String -> Part
stringPart =
  Elm.Kernel.Http.pair


{-|-}
filePart : String -> File -> Part
filePart =
  Elm.Kernel.Http.pair


{-|-}
bytesPart : String -> String -> Bytes -> Part
bytesPart key mime bytes =
  Elm.Kernel.Http.pair key (Elm.Kernel.Http.bytesToBlob mime bytes)



-- EXPECT


{-| Logic for interpreting a response body.
-}
type Expect x a = Expect


{-|-}
expectString : (Response String -> Result x a) -> Expect x a
expectString =
  Elm.Kernel.Http.pair "string"


{-|-}
expectBytes : (Response Bytes -> Result x a) -> Expect x a
expectBytes =
  Elm.Kernel.Http.pair "arraybuffer"


{-| A `Response` can come back a couple different ways:

- `BadUrl` means you did not provide a valid URL.
- `Timeout` means it took too long to get a response.
- `NetworkError` means the user turned off their wifi, went in a cave, etc.
- `BadResponse` means you got a response back, but the status code indicates failure.
- `GoodResponse` means you got a response back with a nice status code!

The type of `body` depends on whether you use [`expectString`](#expectString)
or [`expectBytes`](#expectBytes).
-}
type Response body
  = BadUrl String
  | Timeout
  | NetworkError
  | BadStatus Metadata body
  | GoodStatus Metadata body


{-| Extra information about the response:

- `url` of the server that actually responded (so you can detect redirects)
- `statusCode` like `200` or `404`
- `statusText` describing what the `statusCode` means a little
- `headers` like `Content-Length` and `Expires`

**Note:** It is possible for a response to have the same header multiple times.
In that case, all the values end up in a single entry in the `headers`
dictionary. The values are separated by commas, following the rules outlined
[here](https://stackoverflow.com/questions/4371328/are-duplicate-http-response-headers-acceptable).
-}
type alias Metadata =
  { url : String
  , statusCode : Int
  , statusText : String
  , headers : Dict String String
  }



-- SEND


{-|-}
send : (Result x a -> msg) -> Request x a -> Cmd msg
send toMsg req =
  command (MyCmd (Elm.Kernel.Http.coerce toMsg) (Elm.Kernel.Http.coerce req))



-- PROGRESS


{-| The progress information is actually a bit more complicated than what we
saw in the `Http` module. Instead of giving a nice fraction, the browser
actually provides the expected `size` of the body in bytes and the number of
bytes that have been `sent` or `received` so far.

Confusing things about this include:

1. The `size` can always be zero. If you are not sending a body! So you have
to be warry of divide by zero errors.
2. In the `Receiving` phase, the `size` is based on the [`Content-Length`][cl]
header which may be missing.

So it is not always possible to compute a meaningful progress percentage. The
simpler [`Http.track`](/packages/elm/http/latest/Http#track) subscription just
gives `0.0` in those cases, but maybe you want to show a looped loading
animation and the number of bytes downloaded so far. That way you get some
motion even though you do not know when it will be done.

[cl]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Length
-}
type Progress
  = Sending { sent : Int, size : Int }
  | Receiving { received : Int, size : Maybe Int }


{-| Track the progress of a request, but with more information about exactly
how many bytes have been transferred so far.
-}
track : String -> (Progress -> msg) -> Sub msg
track toMsg req =
  subscription (MySub toMsg req)



-- COMMANDS and SUBSCRIPTIONS


type MyCmd msg =
  MyCmd (Result Never Never -> msg) (Request Never Never)


cmdMap : (a -> b) -> MyCmd a -> MyCmd b
cmdMap func (MyCmd toMsg req) =
  MyCmd (toMsg >> func) req


type MySub msg =
  MySub String (Progress -> msg)


subMap : (a -> b) -> MySub a -> MySub b
subMap func (MySub tracker toMsg) =
  MySub tracker (toMsg >> func)



-- EFFECT MANAGER


type alias State msg =
  List (MySub msg)


init : Task Never (State msg)
init =
  Task.succeed []


type alias MyRouter msg =
  Platform.Router msg SelfMsg


-- APP MESSAGES


onEffects : MyRouter msg -> List (MyCmd msg) -> List (MySub msg) -> State msg -> Task Never (State msg)
onEffects router cmds subs _ =
  Task.sequence (List.map (spawn router) cmds)
    |> Task.andThen (\_ -> Task.succeed subs)


spawn : MyRouter msg -> MyCmd msg -> Task x Process.Id
spawn router (MyCmd toMsg (Request req)) =
  Process.spawn (Elm.Kernel.Http.toTask router toMsg req)



-- SELF MESSAGES


type alias SelfMsg =
  (String, Progress)


onSelfMsg : MyRouter msg -> SelfMsg -> State msg -> Task Never (State msg)
onSelfMsg router (tracker, progress) state =
  Task.sequence (List.filterMap (maybeSend router tracker progress) state)
    |> Task.andThen (\_ -> Task.succeed state)


maybeSend : MyRouter msg -> String -> Progress -> MySub msg -> Maybe (Task x ())
maybeSend router desiredTracker progress (MySub actualTracker toMsg) =
  if desiredTracker == actualTracker then
    Just (Platform.sendToApp router (toMsg progress))
  else
    Nothing
