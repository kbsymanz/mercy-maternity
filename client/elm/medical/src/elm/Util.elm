module Util
    exposing
        ( (=>)
        , calcEdd
        , dateToDateString
        , dateToDateTime
        , dateTimeToDate
        , formatDohId
        , getGA
        , maybeIntToMaybeBool
        , maybeIntToNegOne
        , nbsp
        )

import Date exposing (Date)
import Html as H exposing (Html)
import Html.Attributes as HA
import Json.Decode as JD
import Json.Encode as JE
import Time.DateTime as TDT


(=>) : a -> b -> ( a, b )
(=>) =
    (,)
infixl 0 =>


dateToDateString : Date -> String -> String
dateToDateString date sep =
    Date.month date
        |> toString
        |> flip (++) sep
        |> flip (++) (toString (Date.day date))
        |> flip (++) "-"
        |> flip (++) (toString (Date.year date))


maybeIntToNegOne : Maybe Int -> JE.Value
maybeIntToNegOne int =
    case int of
        Just i ->
            JE.int i

        Nothing ->
            JE.int -1


{-| Convert a Date object from the standard library to
a DateTime object from the elm-community/elm-time package.
-}
dateToDateTime : Date -> TDT.DateTime
dateToDateTime date =
    Date.toTime date
        |> TDT.fromTimestamp


{-| Convert a DateTime object from elm-community/elm-time
package to the standard library's Date object.
-}
dateTimeToDate : TDT.DateTime -> Date
dateTimeToDate tddate =
    TDT.toTimestamp tddate
        |> Date.fromTime


{-| Calculate the estimated due date based upon the
date of the last mentrual period.
-}
calcEdd : Maybe Date -> Maybe Date
calcEdd theLmp =
    case theLmp of
        Just lmp ->
            dateToDateTime lmp
                |> TDT.addDays 280
                |> dateTimeToDate
                |> Just

        Nothing ->
            Nothing


getGA : Date -> Date -> ( String, String )
getGA edd rdate =
    let
        -- Zero out to the day, excluding hours, minutes, etc.
        dtEdd =
            dateToDateTime edd
                |> TDT.setHour 0
                |> TDT.setMinute 0
                |> TDT.setSecond 0

        dtRdate =
            dateToDateTime rdate
                |> TDT.setHour 0
                |> TDT.setMinute 0
                |> TDT.setSecond 0

        days =
            (TDT.delta dtRdate (TDT.addDays -280 dtEdd)).days - 1

        ga =
            (toString <| days // 7, rem days 7 |> toString |> flip (++) "/7")
    in
        case TDT.compare dtRdate dtEdd of
            GT ->
                -- Limit to reasonable values.
                --if days > 322 then
                -- TESTING
                if days > 900 then
                    ( "", "" )
                else
                    ga

            EQ ->
                ( "40", "0/7" )

            LT ->
                ga


formatDohId : Maybe String -> String
formatDohId doh =
    case doh of
        Just doh ->
            (String.slice 0 2 doh)
                ++ "-"
                ++ (String.slice 2 4 doh)
                ++ "-"
                ++ (String.slice 4 6 doh)

        Nothing ->
            ""


maybeIntToMaybeBool : JD.Decoder (Maybe Bool)
maybeIntToMaybeBool =
    JD.maybe JD.int
        |> JD.map
            (\val ->
                case val of
                    Just v ->
                        if v > 0 then
                            Just True
                        else
                            Just False

                    Nothing ->
                        Nothing
            )


{-| Put a non-breaking space in between two strings within a span. Adapted from:
https://stackoverflow.com/questions/33971362/how-can-i-get-special-characters-using-elm-html-module
-}
nbsp : String -> String -> Html msg
nbsp pre post =
    H.span []
        [ H.span [] [ H.text pre ]
        , H.span [ HA.property "innerHTML" (JE.string "&nbsp;") ] []
        , H.span [] [ H.text post ]
        ]