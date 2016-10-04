effect module Http.Progress where { subscription = MySub } exposing
  ( Progress(..)
  , progress
  , Tracker
  , tracker
  , track
  , Msg
  , update
  )


import Dict
import Http
import Http.Internal exposing ( Request(Request) )
import Task exposing (Task)
import Platform exposing (Router)
import Process



-- PROGRESS


type Progress data
  = None
  | Some { bytes : Int, bytesExpected : Int}
  | Fail Http.Error
  | Done data



-- TRACKER


type Tracker data =
  Tracker String (Progress data)


tracker : String -> Tracker data
tracker id =
  Tracker id None


progress : Tracker data -> Progress data
progress (Tracker _ prog) =
  prog



-- UPDATE TRACKER


type Msg data =
  Msg String (Progress data)


update : Msg data -> Tracker data -> Tracker data
update (Msg msgId progress) (Tracker id _ as tracker) =
  if msgId /= id then
    tracker

  else
    Tracker id progress



-- TRACK


track : (Msg data -> msg) -> Request data -> Tracker data -> Sub msg
track toMessage (Request request) (Tracker id _) =
  subscription <| Track id <|
    { request = Http.Internal.map (Done >> Msg id >> toMessage) request
    , toProgress = Some >> Msg id >> toMessage
    , toError = Fail >> Msg id >> toMessage
    }


type alias TrackedRequest msg =
  { request : Http.Internal.RawRequest msg
  , toProgress : { bytes : Int, bytesExpected : Int } -> msg
  , toError : Http.Error -> msg
  }


map : (a -> b) -> TrackedRequest a -> TrackedRequest b
map func { request, toProgress, toError } =
  { request = Http.Internal.map func request
  , toProgress = toProgress >> func
  , toError = toError >> func
  }



-- SUBSCRIPTIONS


type MySub msg =
  Track String (TrackedRequest msg)


subMap : (a -> b) -> MySub a -> MySub b
subMap func (Track id trackedRequest) =
  Track id (map func trackedRequest)



-- EFFECT MANAGER


type alias State =
  Dict.Dict String Process.Id


init : Task Never State
init =
  Task.succeed Dict.empty



-- APP MESSAGES


onEffects : Platform.Router msg Never -> List (MySub msg) -> State -> Task Never State
onEffects router subs state =
  let
    subDict =
      collectSubs subs

    leftStep id process (dead, ongoing, new) =
      ( Process.kill process :: dead
      , ongoing
      , new
      )

    bothStep id process _ (dead, ongoing, new) =
      ( dead
      , Dict.insert id process ongoing
      , new
      )

    rightStep id trackedRequest (dead, ongoing, new) =
      ( dead
      , ongoing
      , (id, trackedRequest) :: new
      )

    (dead, ongoing, new) =
      Dict.merge leftStep bothStep rightStep state subDict ([], Dict.empty, [])
  in
    Task.sequence dead
      |> Task.andThen (\_ -> spawnRequests router new ongoing)


spawnRequests : Router msg Never -> List (String, TrackedRequest msg) -> State -> Task Never State
spawnRequests router trackedRequests state =
  case trackedRequests of
    [] ->
      Task.succeed state

    (id, trackedRequest) :: others ->
      Process.spawn (toTask router trackedRequest)
        |> Task.andThen (\process -> spawnRequests router others (Dict.insert id process state))


toTask : Router msg Never -> TrackedRequest msg -> Task Never ()
toTask router { request, toProgress, toError } =
  Native.Http.toTask request (Just toProgress)
    |> Task.andThen (Platform.sendToApp router)
    |> Task.onError (Platform.sendToApp router << toError)



-- COLLECT SUBS AS DICT


type alias SubDict msg =
  Dict.Dict String (TrackedRequest msg)


collectSubs : List (MySub msg) -> SubDict msg
collectSubs subs =
  List.foldl addSub Dict.empty subs


addSub : MySub msg -> SubDict msg -> SubDict msg
addSub (Track id trackedRequest) subDict =
  let
    request =
      trackedRequest.request

    uid =
      id ++ request.method ++ request.url
  in
    Dict.insert uid trackedRequest subDict



-- SELF MESSAGES


onSelfMsg : Platform.Router msg Never -> Never -> State -> Task Never State
onSelfMsg router _ state =
  Task.succeed state
