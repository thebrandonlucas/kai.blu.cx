module Changelog exposing (main)

{-| kai.blu.cx/changelog: Kai's CHANGELOG.md as of its latest release,
read from GitHub when the page loads, so a release updates this page with
no deploy. A release without the file (before it existed) shows that
release's notes instead.
-}

import Browser
import Html exposing (Html, a, div, main_, p, span, text)
import Html.Attributes exposing (attribute, class, href)
import Http
import Json.Decode as Decode
import Markdown
import SiteBar


type alias Release =
    { tag : String, notes : String, url : String }


type Model
    = Loading
    | Failed
    | Shown Release (Maybe String)


repo : String
repo =
    "thebrandonlucas/kai"


init : () -> ( Model, Cmd Msg )
init _ =
    ( Loading
    , Http.get
        { url = "https://api.github.com/repos/" ++ repo ++ "/releases/latest"
        , expect =
            Http.expectJson GotRelease
                (Decode.map3 Release
                    (Decode.field "tag_name" Decode.string)
                    (Decode.oneOf [ Decode.field "body" Decode.string, Decode.succeed "" ])
                    (Decode.field "html_url" Decode.string)
                )
        }
    )


type Msg
    = GotRelease (Result Http.Error Release)
    | GotChangelog Release (Result Http.Error String)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg _ =
    case msg of
        GotRelease (Ok release) ->
            ( Shown release Nothing
            , Http.get
                { url = "https://raw.githubusercontent.com/" ++ repo ++ "/" ++ release.tag ++ "/CHANGELOG.md"
                , expect = Http.expectString (GotChangelog release)
                }
            )

        GotRelease (Err _) ->
            ( Failed, Cmd.none )

        GotChangelog release (Ok changelog) ->
            ( Shown release (Just changelog), Cmd.none )

        GotChangelog release (Err _) ->
            ( Shown release (Just ("# Changelog\n\n## " ++ release.tag ++ "\n\n" ++ release.notes)), Cmd.none )


view : Model -> Html Msg
view model =
    div [ class "desktop" ]
        [ SiteBar.view SiteBar.Changelog Nothing
        -- The whole page, no window; data-scroll gives it site-keys.js's
        -- reading keys.
        , main_ [ class "page-full", attribute "data-scroll" "" ]
            [ p [ class "page-keys" ]
                [ text "j k scroll · "
                , a [ href ("https://github.com/" ++ repo ++ "/releases.atom") ] [ text "feed" ]
                ]
            , body model
            ]
        ]


body : Model -> Html Msg
body model =
    case model of
        Loading ->
            p [ class "loading" ] [ text "…" ]

        Failed ->
            p [ class "error" ]
                [ text "GitHub didn't answer. The changelog is also on "
                , a [ href ("https://github.com/" ++ repo ++ "/releases") ] [ text "GitHub releases" ]
                , text "."
                ]

        Shown release changelog ->
            div []
                [ case changelog of
                    Just markdown ->
                        Markdown.toHtmlWith
                            { githubFlavored = Just { tables = True, breaks = False }
                            , defaultHighlighting = Nothing
                            , sanitize = True
                            , smartypants = True
                            }
                            [ class "md" ]
                            markdown

                    Nothing ->
                        p [ class "loading" ] [ text "…" ]
                , div [ class "pager" ]
                    [ a [ class "pager-link", href release.url ] [ text ("Kai " ++ release.tag ++ " on GitHub") ]
                    , a [ class "pager-link", href ("https://github.com/" ++ repo ++ "/releases") ] [ text "all releases →" ]
                    ]
                ]


main : Program () Model Msg
main =
    Browser.element { init = init, update = update, subscriptions = \_ -> Sub.none, view = view }
