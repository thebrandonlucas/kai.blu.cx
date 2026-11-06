module Main exposing (main)

{-| kai.blu.cx: Kai's home page and guided tour, over Thomas Cole's "The
Arcadian or Pastoral State".

The page is a column of workspaces, one screen tall each, like a tiling
window manager's. The first is the painting with the wordmark; each tour
step after it is a glass window with its Markdown text and, if the step has
them, a Kaifile pane and a terminal pane tiled beside it.

The steps live in `public/tour/`: `tour.json` lists them in order and names
each step's files, which are fetched when the page loads, so editing the
tour needs no rebuild.

Keys: ↓ / j / PageDown next, ↑ / k / PageUp previous, 1–9 and 0 a workspace,
Home / g the first, End / G the last. Scrolling works too and snaps to a
workspace.

-}

import Browser
import Browser.Dom as Dom
import Browser.Events
import Dict exposing (Dict)
import Html exposing (Html, a, button, div, footer, h1, header, img, kbd, li, main_, nav, ol, p, pre, section, span, text)
import Html.Attributes exposing (alt, attribute, class, classList, height, href, id, src, tabindex, title, width)
import Html.Events exposing (on, onClick, preventDefaultOn)
import Html.Lazy
import Http
import Json.Decode as Decode exposing (Decoder)
import Markdown
import Process
import RocHighlight
import Task
import Time



-- MODEL


type alias Step =
    { id : String
    , title : String
    , markdown : String
    , kaifile : Maybe String
    , terminal : Maybe String
    }


{-| A step's files, by path, as they arrive.
-}
type alias Files =
    Dict String (Result String String)


type Tour
    = Loading
    | Failed String
    | Loaded (List Step)


type alias Model =
    { tour : Tour
    , files : Files
    , current : Int
    , zone : Time.Zone
    , now : Maybe Time.Posix
    , start : Int
    , instant : Bool

    -- The workspace a key or click is scrolling to, and that jump's number.
    -- Until it arrives, scroll events don't change `current`, so the bar and
    -- the hint don't flicker through the workspaces in between.
    , moving : Maybe Int
    , jump : Int
    }


{-| The flag is the page's URL fragment: `#3` opens on workspace 3.
-}
init : String -> ( Model, Cmd Msg )
init hash =
    ( { tour = Loading
      , files = Dict.empty
      , current = 0
      , zone = Time.utc
      , now = Nothing
      , start = startOf hash
      , instant = startOf hash > 0
      , moving = Nothing
      , jump = 0
      }
    , Cmd.batch
        [ Http.get { url = "tour/tour.json", expect = Http.expectJson GotTour (Decode.field "steps" (Decode.list stepDecoder)) }
        , Task.perform GotZone Time.here
        , Task.perform Tick Time.now
        , Task.attempt (\_ -> NoOp) (Dom.focus "desktop")
        ]
    )


stepDecoder : Decoder Step
stepDecoder =
    Decode.map5 Step
        (Decode.field "id" Decode.string)
        (Decode.field "title" Decode.string)
        (Decode.field "markdown" Decode.string)
        (Decode.maybe (Decode.field "kaifile" Decode.string))
        (Decode.maybe (Decode.field "terminal" Decode.string))



-- UPDATE


type Msg
    = GotTour (Result Http.Error (List Step))
    | GotFile String (Result Http.Error String)
    | Go Int
    | Move Int
    | Scrolled Float Float
    | Landed Int
    | GotZone Time.Zone
    | Tick Time.Posix
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotTour (Ok steps) ->
            ( { model | tour = Loaded steps }
            , Cmd.batch
                [ steps |> List.concatMap stepFiles |> List.map fetch |> Cmd.batch

                -- After the steps' workspaces are drawn: the URL's workspace.
                , if model.start > 0 then
                    Process.sleep 100 |> Task.perform (\_ -> Go model.start)

                  else
                    Cmd.none
                ]
            )

        GotTour (Err err) ->
            ( { model | tour = Failed (httpError err) }, Cmd.none )

        GotFile path result ->
            ( { model | files = Dict.insert path (Result.mapError httpError result) model.files }, Cmd.none )

        Go n ->
            goTo n model

        Move delta ->
            goTo (model.current + delta) model

        Scrolled top height ->
            if height <= 0 then
                ( model, Cmd.none )

            else
                case model.moving of
                    Just target ->
                        -- Mid-jump: wait until the jump arrives.
                        if abs (top - toFloat target * height) < 2 then
                            ( { model | moving = Nothing, current = target, instant = False }, Cmd.none )

                        else
                            ( model, Cmd.none )

                    Nothing ->
                        let
                            at =
                                round (top / height)
                        in
                        if at == model.current && not model.instant then
                            ( model, Cmd.none )

                        else
                            ( { model | current = at, instant = False }, Cmd.none )

        Landed jump ->
            -- A jump the reader interrupted by scrolling: follow the scroll again.
            if jump == model.jump then
                ( { model | moving = Nothing }, Cmd.none )

            else
                ( model, Cmd.none )

        GotZone zone ->
            ( { model | zone = zone }, Cmd.none )

        Tick now ->
            ( { model | now = Just now }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


stepFiles : Step -> List String
stepFiles step =
    step.markdown :: List.filterMap identity [ step.kaifile, step.terminal ]


fetch : String -> Cmd Msg
fetch path =
    Http.get { url = "tour/" ++ path, expect = Http.expectString (GotFile path) }


httpError : Http.Error -> String
httpError err =
    case err of
        Http.BadUrl url ->
            "bad URL " ++ url

        Http.Timeout ->
            "timed out"

        Http.NetworkError ->
            "network error"

        Http.BadStatus status ->
            "HTTP " ++ String.fromInt status

        Http.BadBody body ->
            "unreadable: " ++ body


{-| Scroll the desktop to workspace `n` (clamped). The CSS makes the scroll
smooth. `current` changes at once, and scroll events leave it alone until
the scroll arrives (or, if the reader scrolls away mid-jump, for at most
1.5 s).
-}
goTo : Int -> Model -> ( Model, Cmd Msg )
goTo n model =
    let
        target =
            clamp 0 (workspaceCount model - 1) n

        jump =
            model.jump + 1
    in
    ( { model | current = target, moving = Just target, jump = jump }
    , Cmd.batch
        [ Dom.getViewportOf "workspaces"
            |> Task.andThen (\vp -> Dom.setViewportOf "workspaces" 0 (toFloat target * vp.viewport.height))
            |> Task.attempt (\_ -> NoOp)
        , Process.sleep 1500 |> Task.perform (\_ -> Landed jump)
        ]
    )


{-| The hero plus one workspace per step.
-}
workspaceCount : Model -> Int
workspaceCount model =
    case model.tour of
        Loaded steps ->
            1 + List.length steps

        _ ->
            1



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Time.every 10000 Tick


{-| Keys, handled on the desktop (which holds focus) so the browser's own
arrow-key scrolling can be prevented.
-}
keyDecoder : Model -> Decoder ( Msg, Bool )
keyDecoder model =
    Decode.map3 (\key ctrl meta -> ( key, ctrl || meta ))
        (Decode.field "key" Decode.string)
        (Decode.field "ctrlKey" Decode.bool)
        (Decode.field "metaKey" Decode.bool)
        |> Decode.andThen
            (\( key, modified ) ->
                if modified then
                    Decode.fail "modified"

                else
                    case keyMsg model key of
                        Just msg ->
                            Decode.succeed ( msg, True )

                        Nothing ->
                            Decode.fail key
            )


keyMsg : Model -> String -> Maybe Msg
keyMsg model key =
    case key of
        "ArrowDown" ->
            Just (Move 1)

        "j" ->
            Just (Move 1)

        "PageDown" ->
            Just (Move 1)

        " " ->
            Just (Move 1)

        "ArrowUp" ->
            Just (Move -1)

        "k" ->
            Just (Move -1)

        "PageUp" ->
            Just (Move -1)

        "Home" ->
            Just (Go 0)

        "g" ->
            Just (Go 0)

        "End" ->
            Just (Go (workspaceCount model - 1))

        "G" ->
            Just (Go (workspaceCount model - 1))

        _ ->
            String.toInt key
                |> Maybe.andThen
                    (\n ->
                        if n >= 1 && n <= 9 then
                            Just (Go (n - 1))

                        else if n == 0 then
                            -- The number row's 0 is the tenth workspace.
                            Just (Go 9)

                        else
                            Nothing
                    )


scrollDecoder : Decoder Msg
scrollDecoder =
    Decode.map2 Scrolled
        (Decode.at [ "target", "scrollTop" ] Decode.float)
        (Decode.at [ "target", "clientHeight" ] Decode.float)



-- VIEW


view : Model -> Html Msg
view model =
    div
        [ id "desktop"
        , class "desktop"
        , tabindex 0
        , preventDefaultOn "keydown" (keyDecoder model)
        ]
        [ bar model
        , main_ [ id "workspaces", classList [ ( "workspaces", True ), ( "instant", model.instant ) ], on "scroll" scrollDecoder ]
            (hero :: stepWorkspaces model)
        , hint model
        ]


{-| The top bar: workspaces on the left, the clock on the right.
-}
bar : Model -> Html Msg
bar model =
    header [ class "bar" ]
        [ nav [ class "bar-workspaces", attribute "aria-label" "Tour" ]
            [ ol []
                (List.indexedMap (workspaceButton model.current)
                    ("kαί" :: List.map .title (loadedSteps model))
                )
            ]
        , div [ class "bar-status" ]
            [ span [ class "bar-host" ] [ text "kai.blu.cx" ]
            , span [ class "bar-clock" ] [ text (clock model) ]
            ]
        ]


workspaceButton : Int -> Int -> String -> Html Msg
workspaceButton current n label =
    li []
        [ button
            [ classList [ ( "ws", True ), ( "ws-active", n == current ) ]
            , onClick (Go n)
            , title label
            , attribute "aria-current"
                (if n == current then
                    "step"

                 else
                    "false"
                )
            ]
            [ span [ class "ws-num" ] [ text (String.fromInt (modBy 10 (n + 1))) ]
            , span [ class "ws-label" ] [ text label ]
            ]
        ]


clock : Model -> String
clock model =
    case model.now of
        Just now ->
            pad (Time.toHour model.zone now) ++ ":" ++ pad (Time.toMinute model.zone now)

        Nothing ->
            ""


pad : Int -> String
pad n =
    String.padLeft 2 '0' (String.fromInt n)


loadedSteps : Model -> List Step
loadedSteps model =
    case model.tour of
        Loaded list ->
            list

        _ ->
            []


{-| Workspace 1: the painting, the wordmark and where to find Kai.
-}
hero : Html Msg
hero =
    section [ id "ws-0", class "workspace hero" ]
        [ h1 [ class "wordmark" ] [ text "kαί" ]
        , p [ class "tagline" ] [ text "A friendly frontend for determinate computing" ]
        , nav [ class "social-links", attribute "aria-label" "Community" ]
            [ socialLink "https://discord.gg/SrH3w5uAa3" "Join Kai on Discord" "Discord" "icons/discord.svg"
            , socialLink "https://github.com/thebrandonlucas/kai" "Kai on GitHub" "GitHub" "icons/github.svg"
            ]
        ]


socialLink : String -> String -> String -> String -> Html msg
socialLink url label name icon =
    a [ href url, class "social-link", attribute "aria-label" label, title name ]
        [ img [ src icon, alt "", width 28, height 28, attribute "aria-hidden" "true" ] [] ]


stepWorkspaces : Model -> List (Html Msg)
stepWorkspaces model =
    case model.tour of
        Loading ->
            []

        Failed err ->
            [ section [ id "ws-1", class "workspace" ]
                [ div [ class "window" ]
                    [ titlebar "tour" "error"
                    , div [ class "window-body" ] [ p [ class "error" ] [ text ("The tour didn't load: " ++ err) ] ]
                    ]
                ]
            ]

        Loaded list ->
            -- Lazy: scrolling changes only `current`, so the windows aren't
            -- drawn again while the page scrolls.
            List.indexedMap (\i step -> Html.Lazy.lazy4 stepView model.files (List.length list) i step) list


{-| A tour step: one glass window, its text alone or tiled with a Kaifile
and a terminal.
-}
stepView : Files -> Int -> Int -> Step -> Html Msg
stepView files total i step =
    let
        n =
            i + 1

        tiles =
            List.filterMap identity
                [ Maybe.map (codeTile files) step.kaifile
                , Maybe.map (terminalTile files) step.terminal
                ]
    in
    section [ id ("ws-" ++ String.fromInt n), class "workspace" ]
        [ div [ classList [ ( "tiling", True ), ( "tiling-split", not (List.isEmpty tiles) ) ] ]
            (div [ class "window window-prose" ]
                [ titlebar ("~/tour/" ++ step.id ++ ".md") (String.fromInt n ++ "/" ++ String.fromInt total)
                , div [ class "window-body" ] [ fileView files step.markdown markdownView ]
                ]
                :: (if List.isEmpty tiles then
                        []

                    else
                        [ div [ class "stack" ] tiles ]
                   )
            )
        ]


titlebar : String -> String -> Html msg
titlebar name meta =
    div [ class "titlebar" ]
        [ span [ class "titlebar-name" ] [ text name ]
        , span [ class "titlebar-meta" ] [ text meta ]
        ]


codeTile : Files -> String -> Html msg
codeTile files path =
    div [ class "window window-code" ]
        [ titlebar "Kaifile.roc" "roc"
        , div [ class "window-body" ] [ fileView files path codeView ]
        ]


terminalTile : Files -> String -> Html msg
terminalTile files path =
    div [ class "window window-term" ]
        [ titlebar "terminal" "kai 0.0.11"
        , div [ class "window-body" ] [ fileView files path terminalView ]
        ]


fileView : Files -> String -> (String -> Html msg) -> Html msg
fileView files path render =
    case Dict.get path files of
        Just (Ok content) ->
            render content

        Just (Err err) ->
            p [ class "error" ] [ text (path ++ ": " ++ err) ]

        Nothing ->
            p [ class "loading" ] [ text "…" ]


markdownView : String -> Html msg
markdownView =
    Markdown.toHtmlWith
        { githubFlavored = Just { tables = True, breaks = False }
        , defaultHighlighting = Nothing
        , sanitize = False
        , smartypants = True
        }
        [ class "md" ]


{-| A Roc file with line numbers and syntax highlighting.
-}
codeView : String -> Html msg
codeView source =
    pre [ class "code" ]
        (String.lines (String.trimRight source)
            |> List.map (\line -> span [ class "code-line" ] (RocHighlight.line line ++ [ text "\n" ]))
        )


{-| A recorded session: lines starting with `$ ` are commands, shown after
a gold prompt; everything else is output.
-}
terminalView : String -> Html msg
terminalView transcript =
    pre [ class "term" ]
        (String.lines (String.trimRight transcript)
            |> List.map
                (\line ->
                    if String.startsWith "$ " line then
                        span [ class "term-cmd" ] [ span [ class "term-prompt" ] [ text "❯ " ], text (String.dropLeft 2 line ++ "\n") ]

                    else
                        text (line ++ "\n")
                )
        )


{-| Bottom right: the keys for back and next, each also a button.
-}
hint : Model -> Html Msg
hint model =
    let
        first =
            model.current == 0

        last =
            model.current >= workspaceCount model - 1
    in
    footer [ class "hint" ]
        (List.filterMap identity
            [ if first then
                Nothing

              else
                Just
                    (button [ class "hint-button", onClick (Move -1), attribute "aria-label" "Back" ]
                        [ span [ class "hint-arrow hint-up" ] [ text "↑" ], text "back ", kbd [] [ text "k" ], kbd [] [ text "↑" ] ]
                    )
            , if last then
                Just
                    (button [ class "hint-button", onClick (Go 0), attribute "aria-label" "Back to the start" ]
                        [ text "to the top ", kbd [] [ text "g" ] ]
                    )

              else
                Just
                    (button [ class "hint-button", onClick (Move 1), attribute "aria-label" "Next" ]
                        [ span [ class "hint-arrow" ] [ text "↓" ]
                        , text
                            (if first then
                                "take the tour "

                             else
                                "next "
                            )
                        , kbd [] [ text "j" ]
                        , kbd [] [ text "↓" ]
                        ]
                    )
            ]
        )



-- MAIN


main : Program String Model Msg
main =
    Browser.element { init = init, update = update, subscriptions = subscriptions, view = view }


{-| `#3` is workspace 3 (index 2); anything else is the first.
-}
startOf : String -> Int
startOf hash =
    String.dropLeft 1 hash |> String.toInt |> Maybe.withDefault 1 |> (\n -> n - 1)
