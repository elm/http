effect module Http.RateLimit where { subscription = MySub } exposing
  ( rateLimit
  , Msg(..)
  , Strategy
  )


{-| Make HTTP requests, but rate limit them. This way you con reduce the load
on your servers without degrading the experience for users too much.

# Rate Limiting
@docs rateLimit, Msg

# Strategies
@docs Strategy
-}


import Dict
import Http
import Http.Internal
import Platform
import Process
import Task exposing (Task)
import Time exposing (Time)



-- RATE LIMIT


{-| Subscribe to the results of rate-limited HTTP requests. The arguments are:

  1. A unique ID that groups requests. Say you have three independent sources
  of HTTP requests, and you want each source rate-limited independently. You
  want three `rateLimit` subscriptions, each with a different ID.

  2. A strategy for rate-limiting requests. More on that later!

  3. A way to turn rate-limited results into messages for your `update`.

  4. The latest `Request` you want to run. It will not get called a bunch of
  times. A `rateLimit` subscription looks at the method, URL, headers, body,
  and other settings to figure out if it has already been sent.

Together, this means you can always derive your `rateLimit` subscription
directly from your `Model`. Figure out the `Request` you care about right now
and the messages will come in.

**Note:** A good trick for creating unique IDs is to make it the name of the
module plus some additional description of what it is for.
-}
rateLimit : String -> Strategy -> (Msg data -> msg) -> Http.Request data -> Sub msg
rateLimit id strategy toMessage (Http.Internal.Request request) =
  subscription <| MySub <|
    { id = id
    , strategy = strategy
    , request = Http.Internal.map (toMessage << Success) request
    , onError = toMessage << Failure
    }



-- MESSAGES


{-| When you subscribe to the results of a rate-limited request, there are
three kinds of messages you can get back. When a request completes, you will
get a `Success` or `Failure` message. When that result becomes stale because
new requests have come in, you will get a `Waiting` message.
-}
type Msg data
  = Waiting
  | Failure Http.Error
  | Success data



-- STRATEGIES


{-| There are a couple ways to rate limit HTTP requests. Only call once
things have settled down? Never delay longer than 300 milliseconds? Etc.
-}
type Strategy = TODO



-- SUBSCRIPTIONS


type MySub msg =
  MySub
    { id : String
    , strategy : Strategy
    , request : Http.Internal.RawRequest msg
    , onError : Http.Error -> msg
    }


subMap : (a -> b) -> MySub a -> MySub b
subMap func (MySub { id, strategy, request, onError }) =
  MySub
    { id = id
    , strategy = strategy
    , request = Http.Internal.map func request
    , onError = func << onError
    }



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
  Debug.crash "TODO"


onSelfMsg : Platform.Router msg Never -> Never -> State -> Task Never State
onSelfMsg router _ state =
  Debug.crash "TODO"
