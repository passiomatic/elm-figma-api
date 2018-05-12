module Figma.Internal.Layout
    exposing
        ( verticalConstraintDecoder
        , horizontalConstraintDecoder
        , gridDecoder
        )

import Json.Decode as D exposing (Decoder)
import Json.Decode.Pipeline as D
import Figma.Layout exposing (..)
import Figma.Internal.Appearance exposing (..)


-- GRIDS


gridDecoder : Decoder LayoutGrid
gridDecoder =
    D.field "pattern" D.string
        |> D.andThen
            (\value ->
                case value of
                    "COLUMNS" ->
                        D.map ColumnsGrid columnsGridDecoder

                    "ROWS" ->
                        D.map RowsGrid rowsGridDecoder

                    "GRID" ->
                        D.map SquareGrid squareGridDecoder

                    _ ->
                        D.fail <| "Unrecognized grid pattern value: " ++ value
            )


columnsGridDecoder : Decoder Columns
columnsGridDecoder =
    D.decode Columns
        |> D.required "sectionSize" D.float
        |> D.required "visible" D.bool
        |> D.required "color" colorDecoder
        |> D.required "gutterSize" D.float
        |> D.required "offset" D.float
        |> D.required "count" D.int
        |> D.required "alignment" alignDecoder


rowsGridDecoder : Decoder Rows
rowsGridDecoder =
    D.decode Rows
        |> D.required "sectionSize" D.float
        |> D.required "visible" D.bool
        |> D.required "color" colorDecoder
        |> D.required "gutterSize" D.float
        |> D.required "offset" D.float
        |> D.required "count" D.int
        |> D.required "alignment" alignDecoder


squareGridDecoder : Decoder Grid
squareGridDecoder =
    D.decode Grid
        |> D.required "sectionSize" D.float
        |> D.required "visible" D.bool
        |> D.required "color" colorDecoder


alignDecoder : Decoder GridAlign
alignDecoder =
    D.string
        |> D.andThen
            (\value ->
                case value of
                    "MIN" ->
                        D.succeed MinAlign

                    "STRETCH" ->
                        D.succeed MaxAlign

                    "CENTER" ->
                        D.succeed CenterAlign

                    value ->
                        D.fail <| "Unrecognized grid align value: " ++ value
            )



-- CONSTRAINTS


verticalConstraintDecoder : Decoder LayoutVerticalConstraint
verticalConstraintDecoder =
    D.string
        |> D.andThen
            (\value ->
                case value of
                    "TOP" ->
                        D.succeed TopConstraint

                    "BOTTOM" ->
                        D.succeed BottomConstraint

                    "TOP_BOTTOM" ->
                        D.succeed TopBottomConstraint

                    "CENTER" ->
                        D.succeed CenterVerticalConstraint

                    "SCALE" ->
                        D.succeed ScaleVerticalConstraint

                    value ->
                        D.fail <| "Unrecognized layout constraint value: " ++ value
            )


horizontalConstraintDecoder : Decoder LayoutHorizontalConstraint
horizontalConstraintDecoder =
    D.string
        |> D.andThen
            (\value ->
                case value of
                    "LEFT" ->
                        D.succeed LeftConstraint

                    "RIGHT" ->
                        D.succeed RightConstraint

                    "LEFT_RIGHT" ->
                        D.succeed LeftRightConstraint

                    "CENTER" ->
                        D.succeed CenterHorizontalConstraint

                    "SCALE" ->
                        D.succeed ScaleHorizontalConstraint

                    value ->
                        D.fail <| "Unrecognized layout constraint value: " ++ value
            )
