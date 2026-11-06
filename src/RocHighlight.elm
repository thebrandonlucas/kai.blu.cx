module RocHighlight exposing (line)

{-| Syntax highlighting for Roc, one line at a time: comments, strings (with
`${...}` interpolation), keywords, tags and types, function calls, numbers
and punctuation. Good enough for Kaifiles; it doesn't parse Roc.
-}

import Html exposing (Html, span, text)
import Html.Attributes exposing (class)
import Set exposing (Set)


type Kind
    = Comment
    | Str
    | Interp
    | Keyword
    | Tag
    | Call
    | Number
    | Punct
    | Plain


{-| One line of Roc as highlighted spans.
-}
line : String -> List (Html msg)
line source =
    tokens (String.toList source) [] |> List.reverse |> List.map render


render : ( Kind, String ) -> Html msg
render ( kind, chunk ) =
    case kind of
        Plain ->
            text chunk

        _ ->
            span [ class (kindClass kind) ] [ text chunk ]


kindClass : Kind -> String
kindClass kind =
    case kind of
        Comment ->
            "tok-comment"

        Str ->
            "tok-string"

        Interp ->
            "tok-interp"

        Keyword ->
            "tok-keyword"

        Tag ->
            "tok-tag"

        Call ->
            "tok-call"

        Number ->
            "tok-number"

        Punct ->
            "tok-punct"

        Plain ->
            ""


keywords : Set String
keywords =
    Set.fromList
        [ "app", "platform", "package", "module", "import", "exposing", "as"
        , "if", "else", "match", "when", "is", "expect", "dbg", "crash"
        , "var", "for", "in", "return", "and", "or", "not", "requires"
        , "provides", "packages", "exposes", "targets"
        ]


{-| Tokens in reverse order.
-}
tokens : List Char -> List ( Kind, String ) -> List ( Kind, String )
tokens chars acc =
    case chars of
        [] ->
            acc

        '#' :: _ ->
            ( Comment, String.fromList chars ) :: acc

        '"' :: rest ->
            let
                ( parts, after ) =
                    stringBody rest [] []
            in
            tokens after (List.reverse (( Str, "\"" ) :: parts ++ [ ( Str, "\"" ) ]) ++ acc)

        c :: rest ->
            if Char.isDigit c then
                let
                    ( digits, after ) =
                        span_ (\d -> Char.isAlphaNum d || d == '.' || d == '_') chars
                in
                tokens after (( Number, String.fromList digits ) :: acc)

            else if Char.isAlpha c || c == '_' || c == '$' then
                let
                    ( word, after ) =
                        span_ (\d -> Char.isAlphaNum d || d == '_' || d == '!' || d == '$') chars

                    name =
                        String.fromList word
                in
                tokens after (( wordKind name after, name ) :: acc)

            else if c == ' ' || c == '\t' then
                let
                    ( spaces, after ) =
                        span_ (\d -> d == ' ' || d == '\t') chars
                in
                tokens after (( Plain, String.fromList spaces ) :: acc)

            else
                tokens rest (( Punct, String.fromChar c ) :: acc)


wordKind : String -> List Char -> Kind
wordKind name after =
    if Set.member name keywords then
        Keyword

    else if String.left 1 name |> String.any Char.isUpper then
        Tag

    else if List.head after == Just '(' then
        Call

    else
        Plain


{-| A string's body up to its closing quote (consumed, not returned): plain
runs and `${...}` interpolations, as tokens in order, and what follows.
-}
stringBody : List Char -> List Char -> List ( Kind, String ) -> ( List ( Kind, String ), List Char )
stringBody chars run parts =
    let
        flush =
            if List.isEmpty run then
                parts

            else
                parts ++ [ ( Str, String.fromList (List.reverse run) ) ]
    in
    case chars of
        [] ->
            ( flush, [] )

        '\\' :: c :: rest ->
            stringBody rest (c :: '\\' :: run) parts

        '"' :: rest ->
            ( flush, rest )

        '$' :: '{' :: rest ->
            let
                ( inner, after ) =
                    span_ (\d -> d /= '}') rest
            in
            stringBody (List.drop 1 after) [] (flush ++ [ ( Interp, "${" ++ String.fromList inner ++ "}" ) ])

        c :: rest ->
            stringBody rest (c :: run) parts


span_ : (Char -> Bool) -> List Char -> ( List Char, List Char )
span_ keep chars =
    case chars of
        c :: rest ->
            if keep c then
                let
                    ( taken, after ) =
                        span_ keep rest
                in
                ( c :: taken, after )

            else
                ( [], chars )

        [] ->
            ( [], [] )
