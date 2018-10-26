module Http exposing
  ( Request, send
  , getString, get, post
  , request
  , Header, header
  , Body, emptyBody, stringBody, jsonBody, fileBody, bytesBody
  , multipartBody, Part, stringPart, filePart, bytesPart
  , Expect, expectString, expectJson, expectBytes, expectWhatever
  , Progress(..), track
  , Error(..)
  )

{-| Create and send HTTP requests.

Check out the [`elm/url`][url] package for help creating URLs.

[url]: /packages/elm/url/latest

# Requests
@docs Request, send

# GET
@docs getString, get

# POST
@docs post

# Custom Request
@docs request

# Header
@docs Header, header

# Body
@docs Body, emptyBody, stringBody, jsonBody, fileBody, bytesBody

# Body Parts
@docs multipartBody, Part, stringPart, filePart, bytesPart

# Expect
@docs Expect, expectString, expectJson, expectBytes, expectWhatever

# Progress
@docs Progress, track

# Error
@docs Error

-}


import Bytes exposing (Bytes)
import Bytes.Decode as Bytes
import File exposing (File)
import Http.Advanced as A
import Json.Decode as Decode
import Json.Encode as Encode
import Elm.Kernel.Http
import Task exposing (Task)



-- REQUESTS


{-| Describes an HTTP request.
-}
type Request a =
  Request
    { method : String
    , headers : List Header
    , url : String
    , body : Body
    , expect : Expect a
    , timeout : Maybe Float
    , tracker : Maybe String
    , allowCookiesFromOtherDomains : Bool
    }



-- STRINGS


{-| Create a `GET` request and interpret the response body as a `String`.

    import Http

    getWarAndPeace : Http.Request String
    getWarAndPeace =
      Http.getString "https://example.com/books/war-and-peace"

**Note:** Use [`elm/url`][url] to build URLs.

[url]: /packages/elm/url/latest
-}
getString : String -> Request String
getString url =
  Request
    { method = "GET"
    , headers = []
    , url = url
    , body = emptyBody
    , expect = expectString
    , timeout = Nothing
    , tracker = Nothing
    , allowCookiesFromOtherDomains = False
    }



-- JSON


{-| Create a `GET` request and try to decode the response body from JSON to
some Elm value.

    import Http
    import Json.Decode exposing (list, string)

    getBooks : Http.Request (List String)
    getBooks =
      Http.get "https://example.com/books" (list string)

You can learn more about how JSON decoders work [here][json] in the guide, and
you can reliably build URLs with the [`elm/url`][url] package.

[json]: https://guide.elm-lang.org/interop/json.html
[url]: /packages/elm/url/latest
-}
get : String -> Decode.Decoder a -> Request a
get url decoder =
  Request
    { method = "GET"
    , headers = []
    , url = url
    , body = emptyBody
    , expect = expectJson decoder
    , timeout = Nothing
    , tracker = Nothing
    , allowCookiesFromOtherDomains = False
    }


{-| Create a `POST` request and try to decode the response body from JSON to
an Elm value. For example, if we want to send a POST without any data in the
request body, it would be like this:

    import Http
    import Json.Decode exposing (list, string)

    postBooks : Http.Request (List String)
    postBooks =
      Http.post "https://example.com/books" Http.emptyBody (list string)

See [`jsonBody`](#jsonBody) to learn how to have a more interesting request
body. And check out [this section][json] of the guide to learn more about
JSON decoders.

[json]: https://guide.elm-lang.org/interop/json.html

-}
post : String -> Body -> Decode.Decoder a -> Request a
post url body decoder =
  Request
    { method = "POST"
    , headers = []
    , url = url
    , body = body
    , expect = expectJson decoder
    , timeout = Nothing
    , tracker = Nothing
    , allowCookiesFromOtherDomains = False
    }



-- CUSTOM REQUESTS


{-| Create a custom request. For example, a custom PUT request would look like
this:

    import Http exposing (Request, Body, request, expectWhatever)

    put : String -> Body -> Request ()
    put url body =
      request
        { method = "PUT"
        , headers = []
        , url = url
        , body = body
        , expect = expectWhatever
        , timeout = Nothing
        , tracker = Nothing
        }

The `timeout` is the number of milliseconds you are willing to wait before
giving up.
-}
request
  : { method : String
    , headers : List Header
    , url : String
    , body : Body
    , expect : Expect a
    , timeout : Maybe Float
    , tracker : Maybe String
    }
  -> Request a
request r =
  Request
    { method = r.method
    , headers = r.headers
    , url = r.url
    , body = r.body
    , expect = r.expect
    , timeout = r.timeout
    , tracker = r.tracker
    , allowCookiesFromOtherDomains = False
    }



-- HEADERS


{-| An HTTP header for configuring requests. See a bunch of common headers
[here](https://en.wikipedia.org/wiki/List_of_HTTP_header_fields).
-}
type Header = Header String String


{-| Create a `Header`.

    header "If-Modified-Since" "Sat 29 Oct 1994 19:43:31 GMT"
    header "Max-Forwards" "10"
    header "X-Requested-With" "XMLHttpRequest"

**Note:** In the future, we may split this out into an `Http.Headers` module
and provide helpers for cases that are common on the client-side. If this
sounds nice to you, open an issue [here][] describing the helper you want and
why you need it.

[here]: https://github.com/elm/http/issues
-}
header : String -> String -> Header
header =
  Header



-- BODY


{-| Represents the body of a `Request`.
-}
type Body = Body


{-| Create an empty body for your `Request`. This is useful for GET requests
and POST requests where you are not sending any data.
-}
emptyBody : Body
emptyBody =
  Elm.Kernel.Http.emptyBody


{-| Put some JSON value in the body of your `Request`. This will automatically
add the `Content-Type: application/json` header.
-}
jsonBody : Encode.Value -> Body
jsonBody value =
  Elm.Kernel.Http.pair "application/json" (Encode.encode 0 value)


{-| Put some string in the body of your `Request`. Defining `jsonBody` looks
like this:

    import Json.Encode as Encode

    jsonBody : Encode.Value -> Body
    jsonBody value =
      stringBody "application/json" (Encode.encode 0 value)

The first argument is a [MIME type](https://en.wikipedia.org/wiki/Media_type)
of the body. Some servers are strict about this!
-}
stringBody : String -> String -> Body
stringBody =
  Elm.Kernel.Http.pair


{-| Put some `Bytes` in the body of your `Request`. This allows you to use
[`elm/bytes`](/packages/elm/bytes/latest) to have full control over the binary
representation of the data you are sending. For example, you could create an
`archive.zip` file and send it along like this:

    import Bytes exposing (Bytes)

    zipBody : Bytes -> Body
    zipBody bytes =
      bytesBody "application/zip" bytes

The first argument is a [MIME type](https://en.wikipedia.org/wiki/Media_type)
of the body. In other scenarios you may want to use MIME types like `image/png`
or `image/jpeg` instead.

**Note:** Use [`track`](#track) to track upload progress.
-}
bytesBody : String -> Bytes -> Body
bytesBody =
  Elm.Kernel.Http.pair


{-| Use a file as the body of your `Request`. When someone uploads an image
into the browser with [`elm/file`](/packages/elm/file/latest) you can forward
it to a server.

This will automatically set the `Content-Type` to the MIME type of the file.

**Note:** Use [`track`](#track) to track upload progress.
-}
fileBody : File -> Body
fileBody =
  Elm.Kernel.Http.pair ""



-- PARTS


{-| When someone clicks submit on the `<form>`, browsers send a special HTTP
request with all the form data. Something like this:

```
POST /test.html HTTP/1.1
Host: example.org
Content-Type: multipart/form-data;boundary="7MA4YWxkTrZu0gW"

--7MA4YWxkTrZu0gW
Content-Disposition: form-data; name="title"

Trip to London
--7MA4YWxkTrZu0gW
Content-Disposition: form-data; name="album[]"; filename="parliment.jpg"

...RAW...IMAGE...BITS...
--7MA4YWxkTrZu0gW--
```

This was the only way to send files for a long time, so many servers expect
data in this format. **The `multipartBody` function lets you create these
requests.** For example, to upload a photo album all at once, you could create
a body like this:

    multipartBody
      [ stringPart "title" "Trip to London"
      , filePart "album[]" file1
      , filePart "album[]" file2
      , filePart "album[]" file3
      ]

All of the body parts need to have a name. Names can be repeated. Adding the
`[]` on repeated names is a convention from PHP. It seems weird, but I see it
enough to mention it. You do not have to do it that way, especially if your
server uses some other convention!

The `Content-Type: multipart/form-data` header is automatically set when
creating a body this way.

**Note:** Use [`track`](#track) to track upload progress.
-}
multipartBody : List Part -> Body
multipartBody parts =
  Elm.Kernel.Http.pair "" (Elm.Kernel.Http.toFormData parts)


{-| One part of a `multipartBody`.
-}
type Part = Part


{-| A part that contains `String` data.

    multipartBody
      [ stringPart "title" "Tom"
      , filePart "photo" tomPng
      ]
-}
stringPart : String -> String -> Part
stringPart =
  Elm.Kernel.Http.pair


{-| A part that contains a file. You can use
[`elm/file`](/packages/elm/file/latest) to get files loaded into the
browser. From there, you can send it along to a server like this:

    multipartBody
      [ stringPart "product" "Ikea Bekant"
      , stringPart "description" "Great desk for home office."
      , filePart "image[]" file1
      , filePart "image[]" file2
      , filePart "image[]" file3
      ]
-}
filePart : String -> File -> Part
filePart =
  Elm.Kernel.Http.pair


{-| A part that contains bytes, allowing you to use
[`elm/bytes`](/packages/elm/bytes/latest) to encode data exactly in the format
you need.

    multipartBody
      [ stringPart "title" "Tom"
      , bytesPart "photo" "image/png" bytes
      ]

**Note:** You must provide a MIME type so that the receiver has clues about
how to interpret the bytes.
-}
bytesPart : String -> String -> Bytes -> Part
bytesPart key mime bytes =
  Elm.Kernel.Http.pair key (Elm.Kernel.Http.bytesToBlob mime bytes)



-- EXPECT


{-| Logic for interpreting a response body.
-}
type Expect a = Expect


{-| Expect the response body to be a `String`.
-}
expectString : Expect String
expectString =
  Elm.Kernel.Http.pair "string" (resolve Ok)


{-| Expect the response body to be JSON.
Use [`elm/json`](/packages/elm/json/latest/) to define a decoder that turns
that JSON into Elm values.

If the decoder fails, you get a `BadBody` error. If you want richer error
information, use [`Http.Advanced`](/packages/elm/http/latest/Http-Advanced).
-}
expectJson : Decode.Decoder a -> Expect a
expectJson decoder =
  Elm.Kernel.Http.pair "string" <| resolve <|
    \string ->
      Result.mapError Decode.errorToString (Decode.decodeString decoder string)


{-| Expect the response body to be binary data.
Use [`elm/bytes`](/packages/elm/bytes/latest/) to define a decoder that turns
binary data into Elm values.

If the decoder fails, you get a `BadBody` error. If you want richer error
information, use [`Http.Advanced`](/packages/elm/http/latest/Http-Advanced).
-}
expectBytes : Bytes.Decoder a -> Expect a
expectBytes decoder =
  Elm.Kernel.Http.pair "arraybuffer" <| resolve <|
    \bytes ->
      Result.fromMaybe "unexpected bytes" (Bytes.decode decoder bytes)


{-| Do not have any expectations of the response body. Just ignore it.
-}
expectWhatever : Expect ()
expectWhatever =
  Elm.Kernel.Http.pair "string" (resolve (\_ -> Ok ()))


resolve : (body -> Result String a) -> A.Response body -> Result Error a
resolve func response =
  case response of
    A.BadUrl url -> Err (BadUrl url)
    A.Timeout -> Err (Timeout)
    A.NetworkError -> Err (NetworkError)
    A.BadStatus metadata _ -> Err (BadStatus metadata.statusCode)
    A.GoodStatus _ body -> Result.mapError BadBody (func body)


{-| A `Request` can fail in a couple ways:

- `BadUrl` means you did not provide a valid URL.
- `Timeout` means it took too long to get a response.
- `NetworkError` means the user turned off their wifi, went in a cave, etc.
- `BadStatus` means you got a response back, but the status code indicates failure.
- `BadBody` means you got a response back with a nice status code, but the body
of the response was something unexpected. The `String` in this case is a
debugging message that explains what went wrong with your JSON decoder or
whatever.

**Note:** Use [`Http.Advanced`](/packages/elm/http/latest/Http-Advanced) if
you need more information in your errors. For example, when something is not
found (404) the response also has JSON in the body that explains more. Maybe
you want to decode that JSON and show it on screen. The advanced module
supports stuff like that!
-}
type Error
  = BadUrl String
  | Timeout
  | NetworkError
  | BadStatus Int
  | BadBody String



-- SEND


{-| Send a `Request`. We could get the text of “War and Peace” like this:

    import Http

    type Msg = Click | NewBook (Result Http.Error String)

    update : Msg -> Model -> ( Model, Cmd Msg )
    update msg model =
      case msg of
        Click ->
          ( model, getWarAndPeace )

        NewBook result ->
          ...

    getWarAndPeace : Cmd Msg
    getWarAndPeace =
      Http.send NewBook <|
        Http.getString "https://example.com/books/war-and-peace.md"

For a complete example, read [the official guide](https://guide.elm-lang.org/)
up to [the section on HTTP](https://guide.elm-lang.org/effects/http.html)!
-}
send : (Result Error a -> msg) -> Request a -> Cmd msg
send toMsg (Request r) =
  A.send toMsg (A.request (Elm.Kernel.Http.coerce r))



-- PROGRESS


{-| There are two phases to HTTP requests. First you **send** a bunch of data,
then you **receive** a bunch of data. For example, say you use `fileBody` to
upload a file of 382124 bytes. From there, progress will go like this:

```
Sending 0.0
Sending 0.2
Sending 0.5
Sending 0.7
Sending 0.9
Sending 1.0
Receiving 0.0
Receiving 1.0
```

With file uploads, the **send** phase is expensive. That is what we saw in our
example! But with file downloads, the **receive** phase is expensive. Either
way, the fractions are always between `0.0` and `1.0`.

**Note:** The `Receiving` fraction is based on the [`Content-Length`][cl]
header, and in rare and annoying cases, a server may not include that header.
The `Http` module gives `Receiving 0.0` during the whole receive phase in
those cases, but you can use the progress tracking in [`Http.Advanced`][ad] to
do something else instead.

[cl]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Length
[ad]: /packages/elm/http/latest/Http-Advanced
-}
type Progress
  = Sending Float
  | Receiving Float


{-| Track the progress of a request. Create a request where
`tracker = Just "form.pdf"` and you can track it with a subscription like
`track "form.pdf" GotProgress`.

**Note:** A progress percentage cannot be determined if (1) the content has
zero bytes or (2) a response leaves off the `Content-Length` header. In those
cases, the percentage given will be `0.0`. If you want to do something fancier
in those cases, use [`Http.Advanced.track`][hat] instead!

[hat]: /packages/elm/http/latest/Http-Advanced#track
-}
track : String -> (Progress -> msg) -> Sub msg
track tracker func =
  A.track tracker (toSimpleProgress >> func)


toSimpleProgress : A.Progress -> Progress
toSimpleProgress progress =
  case progress of
    A.Sending { sent, size } ->
      if size == 0 then
        Sending 0
      else
        Sending (toFloat sent / toFloat size)

    A.Receiving { received, size } ->
      case size of
        Nothing -> Receiving 0
        Just 0 -> Receiving 0
        Just n -> Receiving (toFloat received / toFloat n)
