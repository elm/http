effect module Http.RateLimit where { subscription = MySub } exposing
  ( rateLimit
  , Strategy
  )


import Dict
import Http
import Http.Internal
import Platform
import Task exposing (Task)
import Time exposing (Time)



--


type Tracker data =
  Tracker String Strategy (Buffer data)


type Buffer data
  = NoResults
  | Stale data
  | Fresh data


type Response data = Fail Http.Error | Done data



-- RATE LIMIT


track : Tracker data -> Request data -> Sub data
track (Tracker id strategy _) (Request request) =
  MySub id strategy request



-- STRATEGIES


type Strategy = Strategy



-- SUBSCRIPTIONS


type MySub msg =
  MySub String Time (Http.Internal.RawRequest msg)


subMap : (a -> b) -> MySub a -> MySub b
subMap func (MySub id time request) =
  MySub id time (Http.Internal.map func request)



-- EFFECT MANAGER


type alias State =
  Dict.Dict String Info


type alias Info =
  { cooldown : Time
  , lastTask : Time
  , latest : Process.Id
  , next : Maybe (Task Never ())
  }


init : Task Never State
init =
  Task.succeed Dict.empty


onEffects : Platform.Router msg Never -> List (MySub msg) -> State -> Task Never State
onEffects router subs state =
  let
    subDict =
      collectSubs subs

    leftStep id {latest} (dead, ongoing, new) =
      ( Process.kill latest :: dead
      , ongoing
      , new
      )

    bothStep id {lastTask, } _ (dead, ongoing, new) =
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
  Dict.Dict String { cooldown : Time, request : Http.Internal.RawRequest msg }


collectSubs : List (MySub msg) -> SubDict msg
collectSubs subs =
  List.foldl addSub Dict.empty subs


addSub : MySub msg -> SubDict msg -> SubDict msg
addSub (MySub id cooldown request) subDict =
  Dict.insert id { cooldown = cooldown, request = request } subDict



-- SELF MESSAGES


onSelfMsg : Platform.Router msg Never -> Never -> State -> Task Never State
onSelfMsg router _ state =
  Task.succeed state
