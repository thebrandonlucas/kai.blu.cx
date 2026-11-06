module Docs exposing (main)

{-| kai.blu.cx/docs: the guides, in the tour's look but for reading: a
file-tree window of the pages beside a reading window that scrolls.

The pages live in `docs/pages/`: `docs.json` lists the sections and their
pages, and each page is `<slug>.md`. The URL fragment names the page
(`/docs/#settings`), so pages link to each other with `#slug`.

Keys: j / k scroll the page, h / l (or ← →) the previous and next page,
g / G its top and bottom.

-}

import Browser
import Browser.Dom as Dom
import Browser.Navigation as Nav
import Dict exposing (Dict)
import Html exposing (Html, a, div, h2, header, li, nav, p, section, span, text, ul)
import Html.Attributes exposing (attribute, class, classList, href, id, tabindex)
import Html.Events exposing (preventDefaultOn)
import Http
import Json.Decode as Decode exposing (Decoder)
import Markdown
import SiteBar
import Task
import Url exposing (Url)


type alias Page =
    { slug : String, title : String }


type alias Section =
    { title : String, pages : List Page }


type alias Model =
    { key : Nav.Key
    , sections : Result String (List Section)
    , pages : Dict String (Result String String)
    , slug : Maybe String
    }


init : () -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    ( { key = key, sections = Err "", pages = Dict.empty, slug = url.fragment }
    , Cmd.batch
        [ Http.get { url = "pages/docs.json", expect = Http.expectJson GotSections (Decode.field "sections" (Decode.list sectionDecoder)) }
        , Task.attempt (\_ -> NoOp) (Dom.focus "desktop")
        ]
    )


sectionDecoder : Decoder Section
sectionDecoder =
    Decode.map2 Section
        (Decode.field "title" Decode.string)
        (Decode.field "pages" (Decode.list (Decode.map2 Page (Decode.field "slug" Decode.string) (Decode.field "title" Decode.string))))


type Msg
    = GotSections (Result Http.Error (List Section))
    | GotPage String (Result Http.Error String)
    | Clicked Browser.UrlRequest
    | UrlChanged Url
    | Open String
    | Scroll Float
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotSections (Ok sections) ->
            fetchCurrent { model | sections = Ok sections }

        GotSections (Err _) ->
            ( { model | sections = Err "The list of pages didn't load." }, Cmd.none )

        GotPage slug result ->
            ( { model | pages = Dict.insert slug (Result.mapError (\_ -> "This page didn't load.") result) model.pages }, Cmd.none )

        Clicked (Browser.Internal url) ->
            -- Only the docs' own pages stay in this app; the rest of the
            -- site (home, tour, api) loads as a page of its own.
            if String.startsWith "/docs" url.path then
                ( model, Nav.pushUrl model.key (Url.toString url) )

            else
                ( model, Nav.load (Url.toString url) )

        Clicked (Browser.External link) ->
            ( model, Nav.load link )

        UrlChanged url ->
            fetchCurrent { model | slug = url.fragment }
                |> Tuple.mapSecond (\cmd -> Cmd.batch [ cmd, toTop ])

        Open slug ->
            ( model, Nav.pushUrl model.key ("#" ++ slug) )

        Scroll by ->
            ( model
            , Dom.getViewportOf "reading"
                |> Task.andThen (\vp -> Dom.setViewportOf "reading" 0 (vp.viewport.y + by))
                |> Task.attempt (\_ -> NoOp)
            )

        NoOp ->
            ( model, Cmd.none )


{-| Fetch the page on screen if it isn't here yet.
-}
fetchCurrent : Model -> ( Model, Cmd Msg )
fetchCurrent model =
    case current model of
        Just page ->
            if Dict.member page.slug model.pages then
                ( model, Cmd.none )

            else
                ( model, Http.get { url = "pages/" ++ page.slug ++ ".md", expect = Http.expectString (GotPage page.slug) } )

        Nothing ->
            ( model, Cmd.none )


toTop : Cmd Msg
toTop =
    Task.attempt (\_ -> NoOp) (Dom.setViewportOf "reading" 0 0)


allPages : Model -> List Page
allPages model =
    model.sections |> Result.withDefault [] |> List.concatMap .pages


{-| The page the URL names, else the first.
-}
current : Model -> Maybe Page
current model =
    let
        pages =
            allPages model
    in
    case model.slug |> Maybe.andThen (\slug -> List.filter (\p -> p.slug == slug) pages |> List.head) of
        Just page ->
            Just page

        Nothing ->
            List.head pages


{-| The pages before and after the current one.
-}
neighbours : Model -> ( Maybe Page, Maybe Page )
neighbours model =
    let
        pages =
            allPages model

        here =
            current model |> Maybe.map .slug

        go previous rest =
            case rest of
                p :: next :: more ->
                    if Just p.slug == here then
                        ( previous, Just next )

                    else
                        go (Just p) (next :: more)

                [ p ] ->
                    if Just p.slug == here then
                        ( previous, Nothing )

                    else
                        ( Nothing, Nothing )

                [] ->
                    ( Nothing, Nothing )
    in
    go Nothing pages


keyDecoder : Model -> Decoder ( Msg, Bool )
keyDecoder model =
    Decode.map3 (\k ctrl meta -> ( k, ctrl || meta ))
        (Decode.field "key" Decode.string)
        (Decode.field "ctrlKey" Decode.bool)
        (Decode.field "metaKey" Decode.bool)
        |> Decode.andThen
            (\( k, modified ) ->
                case ( modified, keyMsg model k ) of
                    ( False, Just msg ) ->
                        Decode.succeed ( msg, True )

                    _ ->
                        Decode.fail k
            )


keyMsg : Model -> String -> Maybe Msg
keyMsg model k =
    let
        ( previous, next ) =
            neighbours model
    in
    case k of
        "j" ->
            Just (Scroll 90)

        "k" ->
            Just (Scroll -90)

        "g" ->
            Just (Scroll -1.0e7)

        "G" ->
            Just (Scroll 1.0e7)

        "h" ->
            Maybe.map (Open << .slug) previous

        "ArrowLeft" ->
            Maybe.map (Open << .slug) previous

        "l" ->
            Maybe.map (Open << .slug) next

        "ArrowRight" ->
            Maybe.map (Open << .slug) next

        _ ->
            Nothing


view : Model -> Browser.Document Msg
view model =
    { title =
        case current model of
            Just page ->
                page.title ++ " · Kai docs"

            Nothing ->
                "Kai docs"
    , body =
        [ div [ id "desktop", class "desktop", tabindex 0, preventDefaultOn "keydown" (keyDecoder model) ]
            [ SiteBar.view SiteBar.Docs Nothing
            , div [ class "docs-tiling" ]
                [ tree model
                , reading model
                ]
            ]
        ]
    }


{-| The file-tree window: every page, by section, then the reference.
-}
tree : Model -> Html Msg
tree model =
    let
        here =
            current model |> Maybe.map .slug
    in
    nav [ class "window window-tree", attribute "aria-label" "Pages" ]
        [ div [ class "titlebar" ] [ span [ class "titlebar-name" ] [ text "~/docs" ] ]
        , div [ class "window-body" ]
            (case model.sections of
                Ok sections ->
                    List.map (treeSection here) sections
                        ++ [ section [ class "tree-section" ]
                                [ h2 [] [ text "reference/" ]
                                , ul []
                                    [ li [] [ a [ class "tree-page", href "/reference/std/" ] [ text "std" ] ]
                                    , li [] [ a [ class "tree-page", href "/reference/platform/" ] [ text "platform" ] ]
                                    ]
                                ]
                           ]

                Err "" ->
                    [ p [ class "loading" ] [ text "…" ] ]

                Err err ->
                    [ p [ class "error" ] [ text err ] ]
            )
        ]


treeSection : Maybe String -> Section -> Html Msg
treeSection here sec =
    section [ class "tree-section" ]
        [ h2 [] [ text (String.toLower sec.title ++ "/") ]
        , ul []
            (List.map
                (\page ->
                    li []
                        [ a
                            [ classList [ ( "tree-page", True ), ( "tree-page-active", Just page.slug == here ) ]
                            , href ("#" ++ page.slug)
                            ]
                            [ text page.title ]
                        ]
                )
                sec.pages
            )
        ]


{-| The reading window: the page, then links to the pages around it.
-}
reading : Model -> Html Msg
reading model =
    let
        ( previous, next ) =
            neighbours model
    in
    div [ class "window window-reading" ]
        [ div [ class "titlebar" ]
            [ span [ class "titlebar-name" ] [ text ("~/docs/" ++ (current model |> Maybe.map .slug |> Maybe.withDefault "") ++ ".md") ]
            , span [ class "titlebar-meta" ] [ text "j k scroll · h l page" ]
            ]
        , div [ id "reading", class "window-body" ]
            [ case current model |> Maybe.andThen (\page -> Dict.get page.slug model.pages) of
                Just (Ok markdown) ->
                    Markdown.toHtmlWith
                        { githubFlavored = Just { tables = True, breaks = False }
                        , defaultHighlighting = Nothing
                        , sanitize = False
                        , smartypants = True
                        }
                        [ class "md" ]
                        markdown

                Just (Err err) ->
                    p [ class "error" ] [ text err ]

                Nothing ->
                    p [ class "loading" ] [ text "…" ]
            , div [ class "pager" ]
                [ pagerLink "← " previous ""
                , pagerLink "" next " →"
                ]
            ]
        ]


pagerLink : String -> Maybe Page -> String -> Html msg
pagerLink before page after =
    case page of
        Just p_ ->
            a [ class "pager-link", href ("#" ++ p_.slug) ] [ text (before ++ p_.title ++ after) ]

        Nothing ->
            span [] []


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Sub.none
        , onUrlRequest = Clicked
        , onUrlChange = UrlChanged
        }
