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

Keys: ↓ / j / PageDown next, ↑ / k / PageUp previous, Home / g the first,
End / G the last. Scrolling works too and snaps to a workspace. The number
keys belong to the site bar (`site-keys.js`): 0 is back to the top here.

-}

import Browser
import Browser.Dom as Dom
import Browser.Events
import Dict exposing (Dict)
import Html exposing (Html, a, blockquote, button, cite, div, footer, h1, header, img, kbd, li, main_, nav, ol, p, pre, section, span, text)
import Html.Attributes exposing (alt, attribute, class, classList, height, href, id, src, tabindex, title, width)
import Html.Events exposing (on, onClick, preventDefaultOn)
import Html.Lazy
import Http
import Json.Decode as Decode exposing (Decoder)
import Markdown
import Process
import RocHighlight
import SiteBar
import Task
import Time



-- MODEL


type alias Step =
    { id : String
    , title : String
    , markdown : String
    , kaifile : Maybe String
    , terminal : Maybe String

    -- The tab shown first when the step has both (default: the Kaifile).
    , open : Pane
    }


{-| The tabs of a step's right-hand window, like a Hyprland window group.
-}
type Pane
    = KaifilePane
    | TerminalPane


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

    -- Tabs the reader switched, by step id.
    , tabs : Dict String Pane
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
      , tabs = Dict.empty
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
    Decode.map6 Step
        (Decode.field "id" Decode.string)
        (Decode.field "title" Decode.string)
        (Decode.field "markdown" Decode.string)
        (Decode.maybe (Decode.field "kaifile" Decode.string))
        (Decode.maybe (Decode.field "terminal" Decode.string))
        (Decode.maybe (Decode.field "open" Decode.string)
            |> Decode.map
                (\open ->
                    if open == Just "terminal" then
                        TerminalPane

                    else
                        KaifilePane
                )
        )



-- UPDATE


type Msg
    = GotTour (Result Http.Error (List Step))
    | GotFile String (Result Http.Error String)
    | Go Int
    | Move Int
    | Scrolled Float Float
    | Landed Int
    | ShowTab String Pane
    | ToggleTab
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

        ShowTab stepId pane ->
            ( { model | tabs = Dict.insert stepId pane model.tabs }, Cmd.none )

        ToggleTab ->
            case currentStep model of
                Just step ->
                    ( { model | tabs = Dict.insert step.id (other (paneOf model step)) model.tabs }, Cmd.none )

                Nothing ->
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
    Sub.none


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
        "Tab" ->
            -- Switches tabs only where there are two; elsewhere Tab moves focus.
            if Maybe.map hasTabs (currentStep model) == Just True then
                Just ToggleTab

            else
                Nothing

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
            Nothing


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
        [ SiteBar.view SiteBar.Home (Just (Go 0))
        , main_ [ id "workspaces", classList [ ( "workspaces", True ), ( "instant", model.instant ) ], on "scroll" scrollDecoder ]
            (hero :: stepWorkspaces model)
        , rail model
        , hint model
        ]


{-| Where you are in the tour: a dot per workspace down the right edge,
the step's number and name beside the dot you point at.
-}
rail : Model -> Html Msg
rail model =
    nav [ class "rail", attribute "aria-label" "Tour steps" ]
        [ ol []
            (List.indexedMap (railDot model.current)
                ("start" :: List.map .title (loadedSteps model))
            )
        ]


railDot : Int -> Int -> String -> Html Msg
railDot current n label =
    li []
        [ button
            [ classList [ ( "rail-dot", True ), ( "rail-dot-active", n == current ) ]
            , onClick (Go n)
            , attribute "aria-label" label
            , attribute "aria-current"
                (if n == current then
                    "step"

                 else
                    "false"
                )
            ]
            [ span [ class "rail-label" ] [ text (String.fromInt (modBy 10 (n + 1)) ++ " " ++ label) ] ]
        ]


loadedSteps : Model -> List Step
loadedSteps model =
    case model.tour of
        Loaded list ->
            list

        _ ->
            []


{-| Workspace 1: the painting, the wordmark and Emerson. Discord and
GitHub are in the site bar.
-}
hero : Html Msg
hero =
    section [ id "ws-0", class "workspace hero" ]
        [ h1 [ class "wordmark" ] [ text "kαί" ]
        , p [ class "tagline" ] [ text "A friendly frontend for determinate computing" ]
        , blockquote [ class "epigraph" ]
            [ p [] [ text "Why should we grope among the dry bones of the past, or put the living generation into masquerade out of its faded wardrobe?" ]
            , p [] [ text "The sun shines today also." ]
            , footer [] [ text "— Emerson, ", cite [] [ text "Nature" ] ]
            ]
        ]


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
            List.indexedMap (\i step -> Html.Lazy.lazy5 stepView model.files (List.length list) i step (paneOf model step)) list


{-| A tour step: one glass window with its text, tiled beside a window
group holding its Kaifile and terminal as tabs, if it has them.
-}
stepView : Files -> Int -> Int -> Step -> Pane -> Html Msg
stepView files total i step pane =
    let
        n =
            i + 1

        tabs =
            List.filterMap identity
                [ Maybe.map (\path -> ( KaifilePane, path )) step.kaifile
                , Maybe.map (\path -> ( TerminalPane, path )) step.terminal
                ]
    in
    section [ id ("ws-" ++ String.fromInt n), class "workspace" ]
        [ div [ classList [ ( "tiling", True ), ( "tiling-split", not (List.isEmpty tabs) ) ] ]
            (div [ class "window window-prose" ]
                [ titlebar ("~/tour/" ++ step.id ++ ".md") (String.fromInt n ++ "/" ++ String.fromInt total)
                , div [ class "window-body" ] [ fileView files step.markdown markdownView ]
                ]
                :: (if List.isEmpty tabs then
                        []

                    else
                        [ windowGroup files step.id pane tabs ]
                   )
            )
        ]


{-| One window, several tabs; the shown one fills the window.
-}
windowGroup : Files -> String -> Pane -> List ( Pane, String ) -> Html Msg
windowGroup files stepId pane tabs =
    let
        shown =
            if List.any (\( p, _ ) -> p == pane) tabs then
                pane

            else
                List.head tabs |> Maybe.map Tuple.first |> Maybe.withDefault KaifilePane
    in
    div [ classList [ ( "window", True ), ( "window-group", True ), ( "window-term", shown == TerminalPane ), ( "window-code", shown == KaifilePane ) ] ]
        [ div [ class "tabbar", attribute "role" "tablist" ]
            (List.map
                (\( p, _ ) ->
                    button
                        [ classList [ ( "tab", True ), ( "tab-active", p == shown ) ]
                        , attribute "role" "tab"
                        , attribute "aria-selected"
                            (if p == shown then
                                "true"

                             else
                                "false"
                            )
                        , onClick (ShowTab stepId p)
                        ]
                        [ text (paneName p) ]
                )
                tabs
                ++ [ span [ class "tabbar-meta" ]
                        [ if List.length tabs > 1 then
                            kbd [] [ text "Tab" ]

                          else
                            text ""
                        , text (" " ++ paneMeta shown)
                        ]
                   ]
            )
        , div [ class "window-body" ]
            (List.filterMap
                (\( p, path ) ->
                    if p == shown then
                        Just
                            (fileView files
                                path
                                (if p == KaifilePane then
                                    codeView

                                 else
                                    terminalView
                                )
                            )

                    else
                        Nothing
                )
                tabs
            )
        ]


paneName : Pane -> String
paneName pane =
    case pane of
        KaifilePane ->
            "Kaifile.roc"

        TerminalPane ->
            "terminal"


paneMeta : Pane -> String
paneMeta pane =
    case pane of
        KaifilePane ->
            "roc"

        TerminalPane ->
            "kai 0.0.11"


other : Pane -> Pane
other pane =
    case pane of
        KaifilePane ->
            TerminalPane

        TerminalPane ->
            KaifilePane


{-| The tab a step shows: the reader's choice, else the step's own.
-}
paneOf : Model -> Step -> Pane
paneOf model step =
    Dict.get step.id model.tabs |> Maybe.withDefault step.open


hasTabs : Step -> Bool
hasTabs step =
    step.kaifile /= Nothing && step.terminal /= Nothing


{-| The step on screen (workspace 1 is the hero, not a step).
-}
currentStep : Model -> Maybe Step
currentStep model =
    loadedSteps model |> List.drop (model.current - 1) |> List.head |> Maybe.andThen (\s -> if model.current >= 1 then Just s else Nothing)


titlebar : String -> String -> Html msg
titlebar name meta =
    div [ class "titlebar" ]
        [ span [ class "titlebar-name" ] [ text name ]
        , span [ class "titlebar-meta" ] [ text meta ]
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


{-| A Roc file with line numbers and syntax highlighting. The app header's
package URLs are long and the same in every Kaifile, so the header is
folded to one line (hover for the URLs); the numbers stay the file's.
-}
codeView : String -> Html msg
codeView source =
    pre [ class "code" ] (codeLines 1 (String.lines (String.trimRight source)))


codeLines : Int -> List String -> List (Html msg)
codeLines n lines =
    case lines of
        [] ->
            []

        first :: rest ->
            if String.startsWith "app [" first && String.endsWith "{" first then
                let
                    ( body, after ) =
                        splitAt (\l -> String.trim l == "}") rest

                    folded =
                        String.join "\n" (List.map String.trim body)
                in
                codeLine n
                    (RocHighlight.line (String.dropRight 1 first)
                        ++ [ text "{ ", span [ class "fold", title folded ] [ text "⋯" ], text " }" ]
                    )
                    :: codeLines (n + List.length body + 2) (List.drop 1 after)

            else
                codeLine n (RocHighlight.line first) :: codeLines (n + 1) rest


codeLine : Int -> List (Html msg) -> Html msg
codeLine n content =
    span [ class "code-line" ] (span [ class "ln" ] [ text (String.fromInt n) ] :: content ++ [ text "\n" ])


{-| The lines before the first one `stop` accepts, and the rest from it.
-}
splitAt : (String -> Bool) -> List String -> ( List String, List String )
splitAt stop lines =
    case lines of
        [] ->
            ( [], [] )

        l :: rest ->
            if stop l then
                ( [], lines )

            else
                let
                    ( before, after ) =
                        splitAt stop rest
                in
                ( l :: before, after )


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
