module Http.Internal exposing
  ( Request(..)
  , RawRequest
  , Expect
  , Body(..)
  , Header(..)
  , map
  )


import Elm.Kernel.Http



type Request a = Request (RawRequest a)


type alias RawRequest a =
    { method : String
    , headers : List Header
    , url : String
    , body : Body
    , expect : Expect a
    , timeout : Maybe Float
    , withCredentials : Bool
    }


type Expect a = Expect


type Body
  = EmptyBody
  | StringBody String String
  | FormDataBody ()



type Header = Header String String


map : (a -> b) -> RawRequest a -> RawRequest b
map func request =
  { request | expect = Elm.Kernel.Http.mapExpect func request.expect }


type Xhr = Xhr


isStringBody : Body -> Bool
isStringBody body =
  case body of
    StringBody _ _ ->
      True

    _ ->
      False
