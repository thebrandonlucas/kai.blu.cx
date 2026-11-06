module SiteBar exposing (Section(..), view)

{-| The bar on top of every page of kai.blu.cx, numbered for the keyboard:
0 the wordmark (home), 1 docs, 2 api, 3 changelog, 4 blog, 5 Discord and
6 GitHub (those two in a new tab). `site-keys.js` presses an item when its
number is typed; reference.sh puts the same bar, as static HTML, on the
generated API reference.
-}

import Html exposing (Html, a, header, img, nav, span, text)
import Html.Attributes exposing (alt, attribute, class, classList, height, href, rel, src, target, title, width)
import Html.Events exposing (preventDefaultOn)
import Json.Decode as Decode


type Section
    = Home
    | Docs
    | Changelog
    | Blog


{-| The bar, with `active` marked. On the home page, `toHome` replaces the
wordmark's navigation (it scrolls back to the top instead of reloading).
-}
view : Section -> Maybe msg -> Html msg
view active toHome =
    header [ class "bar site-bar" ]
        [ nav [ class "bar-site", attribute "aria-label" "Site" ]
            [ a
                ([ class "bar-mark", href "/", title "Kai (0)", key 0 ]
                    ++ (case toHome of
                            Just msg ->
                                [ preventDefaultOn "click" (Decode.succeed ( msg, True )) ]

                            Nothing ->
                                []
                       )
                )
                [ span [ class "bar-num" ] [ text "0" ], img [ class "bar-mark-img", src "/images/kai-mark.svg", alt "Kai" ] [] ]
            , link 1 (active == Docs) "/docs/" "docs"
            , link 2 False "/reference/std/" "api"
            , link 3 (active == Changelog) "/changelog/" "changelog"
            , link 4 (active == Blog) "/blog/" "blog"
            ]
        , nav [ class "bar-social", attribute "aria-label" "Community" ]
            [ icon 5 "https://discord.gg/SrH3w5uAa3" "Discord" "/icons/discord.svg"
            , icon 6 "https://github.com/thebrandonlucas/kai" "GitHub" "/icons/github.svg"
            ]
        ]


key : Int -> Html.Attribute msg
key n =
    attribute "data-key" (String.fromInt n)


link : Int -> Bool -> String -> String -> Html msg
link n current url label =
    a
        [ classList [ ( "bar-link", True ), ( "bar-link-active", current ) ]
        , attribute "aria-current"
            (if current then
                "page"

             else
                "false"
            )
        , href url
        , key n
        ]
        [ span [ class "bar-num" ] [ text (String.fromInt n) ], text label ]


{-| A community link: opens in a new tab.
-}
icon : Int -> String -> String -> String -> Html msg
icon n url name path =
    a [ class "bar-icon", href url, target "_blank", rel "noopener", title (name ++ " (" ++ String.fromInt n ++ ")"), attribute "aria-label" name, key n ]
        [ span [ class "bar-num" ] [ text (String.fromInt n) ]
        , img [ src path, alt "", width 18, height 18, attribute "aria-hidden" "true" ] []
        ]
