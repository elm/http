# HTTP

Make HTTP requests in Elm. Talk to servers.

**I very highly recommend reading through [The Official Guide](https://guide.elm-lang.org) to understand how to use this package!**


## Examples

Here are some commands you might create to send HTTP requests with this package:

```elm
import Http
import Json.Decode as D

type Msg
  = GotBook (Result Http.Error String)
  | GotItems (Result Http.Error (List String))

getBook : Cmd Msg
getBook =
  Http.get
    { url = "https://elm-lang.org/assets/public-opinion.txt"
    , expect = Http.expectString GotBook
    }

fetchItems : Cmd Msg
fetchItems =
  Http.post
    { url = "https://example.com/items.json"
    , body = Http.emptyBody
    , expect = Http.expectJson GotItems (D.list (D.field "name" D.string))
    }
```

But again, to really understand what is going on here, **read through [The Official Guide](https://guide.elm-lang.org).** It has sections describing how HTTP works and how to use it with JSON data. Reading through will take less time overall than trying to figure everything out by trial and error!