module SiteBar exposing (Section(..), view)

{-| The bar on top of every page of kai.blu.cx: the wordmark (home), the
site's sections, and Discord and GitHub. reference.sh puts the same bar,
as static HTML, on the generated API reference.
-}

import Html exposing (Html, a, header, img, nav, span, text)
import Html.Attributes exposing (alt, attribute, class, classList, height, href, src, title, width)
import Html.Events exposing (onClick)


type Section
    = Home
    | Tour
    | Docs


{-| The bar, with `active` marked. `toTour` replaces the tour link's
navigation on the page that holds the tour (the home page scrolls to it
instead of loading).
-}
view : Section -> Maybe msg -> Html msg
view active toTour =
    header [ class "bar site-bar" ]
        [ nav [ class "bar-site", attribute "aria-label" "Site" ]
            [ a [ class "bar-mark", href "/", title "Kai" ] [ text "kαί" ]
            , link (active == Tour)
                (case toTour of
                    Just msg ->
                        [ href "/#2", onClick msg ]

                    Nothing ->
                        [ href "/#2" ]
                )
                "tour"
            , link (active == Docs) [ href "/docs/" ] "docs"
            , link False [ href "/reference/std/" ] "api"
            , link False [ href "https://github.com/thebrandonlucas/kai/releases" ] "changelog"
            , link False [ href "https://blu.cx/projects/kai/" ] "blog"
            ]
        , nav [ class "bar-social", attribute "aria-label" "Community" ]
            [ icon "https://discord.gg/SrH3w5uAa3" "Discord" "/icons/discord.svg"
            , icon "https://github.com/thebrandonlucas/kai" "GitHub" "/icons/github.svg"
            ]
        ]


link : Bool -> List (Html.Attribute msg) -> String -> Html msg
link current attributes label =
    a
        (classList [ ( "bar-link", True ), ( "bar-link-active", current ) ]
            :: (if current then
                    attribute "aria-current" "page"

                else
                    class ""
               )
            :: attributes
        )
        [ text label ]


icon : String -> String -> String -> Html msg
icon url name path =
    a [ class "bar-icon", href url, title name, attribute "aria-label" name ]
        [ img [ src path, alt "", width 18, height 18, attribute "aria-hidden" "true" ] [] ]
