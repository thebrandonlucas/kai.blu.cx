module Main exposing (main)

{-| kai.nix.fun: Kai's home page. The wordmark, the tagline and where to
find the project, over Thomas Cole's "The Arcadian or Pastoral State".
-}

import Html exposing (Html, a, h1, img, main_, nav, p, text)
import Html.Attributes exposing (alt, attribute, class, height, href, src, title, width)


main : Html msg
main =
    main_ [ class "home" ]
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
