module Figma.Internal.Document
    exposing
        ( treeDecoder
        )

import Json.Decode as D exposing (Decoder)
import Json.Decode.Pipeline as D
import Figma.Document exposing (..)
import Figma.Internal.Layout exposing (..)
import Figma.Internal.Appearance exposing (..)
import Figma.Internal.Geometry exposing (..)


{-| Recursively decode the entire document tree.
-}
treeDecoder : Decoder Tree
treeDecoder =
    D.field "type" D.string
        |> D.andThen
            (\value ->
                case value of
                    "DOCUMENT" ->
                        D.map2 tree (D.map DocumentNode documentDecoder) childrenDecoder

                    "CANVAS" ->
                        D.map2 tree (D.map CanvasNode canvasDecoder) childrenDecoder

                    "FRAME" ->
                        D.map2 tree (D.map FrameNode frameDecoder) childrenDecoder

                    "GROUP" ->
                        D.map2 tree (D.map GroupNode frameDecoder) childrenDecoder

                    "VECTOR" ->
                        D.map VectorNode vectorDecoder
                            |> D.map singleton

                    "STAR" ->
                        D.map StarNode vectorDecoder
                            |> D.map singleton

                    "LINE" ->
                        D.map LineNode vectorDecoder
                            |> D.map singleton

                    "ELLIPSE" ->
                        D.map EllipseNode vectorDecoder
                            |> D.map singleton

                    "REGULAR_POLYGON" ->
                        D.map RegularPolygonNode vectorDecoder
                            |> D.map singleton

                    "RECTANGLE" ->
                        D.map RectangleNode rectangleDecoder
                            |> D.map singleton

                    "TEXT" ->
                        D.map TextNode textDecoder
                            |> D.map singleton

                    "SLICE" ->
                        D.map SliceNode sliceDecoder
                            |> D.map singleton

                    "COMPONENT" ->
                        D.map2 tree (D.map ComponentNode frameDecoder) childrenDecoder

                    "INSTANCE" ->
                        D.map singleton (D.map InstanceNode instanceDecoder)

                    "BOOLEAN_OPERATION" ->
                        D.map2 tree (D.map BooleanGroupNode booleanGroupDecoder) childrenDecoder

                    _ ->
                        D.fail <| "Unsupported node type: " ++ value
            )


sharedNodeFields =
    D.required "id" D.string
        >> D.required "name" D.string
        >> D.optional "visible" D.bool True



-- DOCUMENT


documentDecoder : Decoder Document
documentDecoder =
    D.decode Document
        |> sharedNodeFields


childrenDecoder : Decoder (List Tree)
childrenDecoder =
    D.field "children" (D.list <| D.lazy (\_ -> treeDecoder))



-- CANVAS


canvasDecoder : Decoder Canvas
canvasDecoder =
    D.decode Canvas
        |> sharedNodeFields
        |> D.required "backgroundColor" colorDecoder
        |> D.optional "exportSettings" (D.list exportSettingDecoder) []



-- FRAME


frameNodeFields =
    D.required "backgroundColor" colorDecoder
        >> D.optional "exportSettings" (D.list exportSettingDecoder) []
        >> D.required "blendMode" blendModeDecoder
        >> D.optional "preserveRatio" D.bool False
        >> D.requiredAt [ "constraints", "horizontal" ] horizontalConstraintDecoder
        >> D.requiredAt [ "constraints", "vertical" ] verticalConstraintDecoder
        >> D.optional "transitionNodeID" (D.nullable D.string) Nothing
        >> D.optional "opacity" D.float 1
        >> D.required "absoluteBoundingBox" boundingBoxDecoder
        >> D.required "clipsContent" D.bool
        >> D.optional "layoutGrids" (D.list gridDecoder) []
        >> D.optional "effects" (D.list effectDecoder) []
        >> D.optional "isMask" D.bool False


frameDecoder : Decoder Frame
frameDecoder =
    D.decode Frame
        |> sharedNodeFields
        |> frameNodeFields



-- GROUP


groupDecoder : Decoder Frame
groupDecoder =
    D.decode Frame
        |> sharedNodeFields
        |> D.required "backgroundColor" colorDecoder
        |> D.optional "exportSettings" (D.list exportSettingDecoder) []
        |> D.required "blendMode" blendModeDecoder
        |> D.optional "preserveRatio" D.bool False
        |> D.requiredAt [ "constraints", "horizontal" ] horizontalConstraintDecoder
        |> D.requiredAt [ "constraints", "vertical" ] verticalConstraintDecoder
        |> D.optional "transitionNodeID" (D.nullable D.string) Nothing
        |> D.optional "opacity" D.float 1
        |> D.required "absoluteBoundingBox" boundingBoxDecoder
        |> D.required "clipsContent" D.bool
        |> D.optional "layoutGrids" (D.list gridDecoder) []
        |> D.optional "effects" (D.list effectDecoder) []
        |> D.optional "isMask" D.bool False



-- BOOLEAN


booleanGroupDecoder : Decoder BooleanGroup
booleanGroupDecoder =
    D.decode BooleanGroup
        |> sharedNodeFields
        |> vectorNodeFields
        |> D.required "booleanOperation" booleanOperationDecoder


booleanOperationDecoder : Decoder BooleanOperation
booleanOperationDecoder =
    D.string
        |> D.andThen
            (\value ->
                case value of
                    "UNION" ->
                        D.succeed UnionOperation

                    "INTERSECT" ->
                        D.succeed IntersectOperation

                    "SUBTRACT" ->
                        D.succeed SubtractOperation

                    "EXCLUDE" ->
                        D.succeed ExcludeOperation

                    value ->
                        D.fail <| "Unrecognized boolean operation value: " ++ value
            )



-- SHAPE


vectorNodeFields =
    D.optional "exportSettings" (D.list exportSettingDecoder) []
        >> D.required "blendMode" blendModeDecoder
        >> D.optional "preserveRatio" D.bool False
        >> D.requiredAt [ "constraints", "horizontal" ] horizontalConstraintDecoder
        >> D.requiredAt [ "constraints", "vertical" ] verticalConstraintDecoder
        >> D.optional "transitionNodeID" (D.nullable D.string) Nothing
        >> D.optional "opacity" D.float 1
        >> D.required "absoluteBoundingBox" boundingBoxDecoder
        >> D.optional "effects" (D.list effectDecoder) []
        >> D.optional "isMask" D.bool False
        >> D.optional "fills" (D.list paintDecoder) []
        >> D.required "strokes" (D.list paintDecoder)
        >> D.required "strokeWeight" D.float
        >> D.required "strokeAlign" strokeAlignDecoder


vectorDecoder : Decoder Vector
vectorDecoder =
    D.decode Vector
        |> sharedNodeFields
        |> vectorNodeFields



-- RECTANGLE


rectangleDecoder : Decoder Rectangle
rectangleDecoder =
    D.decode Rectangle
        |> sharedNodeFields
        |> vectorNodeFields
        |> D.optional "cornerRadius" D.float 0



-- SLICE


sliceDecoder : Decoder Slice
sliceDecoder =
    D.decode Slice
        |> sharedNodeFields
        |> D.optional "exportSettings" (D.list exportSettingDecoder) []
        |> D.required "absoluteBoundingBox" boundingBoxDecoder



-- TEXT


textDecoder : Decoder Text
textDecoder =
    D.decode Text
        |> sharedNodeFields
        |> vectorNodeFields
        |> D.required "characters" D.string
        |> D.required "style" textStyleDecoder
        |> D.required "characterStyleOverrides" (D.list D.int)
        |> D.required "styleOverrideTable" styleOverrideDecoder



-- COMPONENT


instanceDecoder : Decoder Instance
instanceDecoder =
    D.decode Instance
        |> sharedNodeFields
        |> frameNodeFields
        |> D.required "componentId" D.string



-- EXPORT SETTING


exportSettingDecoder : Decoder ExportSetting
exportSettingDecoder =
    D.decode ExportSetting
        |> D.required "suffix" D.string
        |> D.required "format" exportFormatDecoder
        |> D.required "constraint" exportConstraintDecoder


exportFormatDecoder : Decoder ExportFormat
exportFormatDecoder =
    D.string
        |> D.andThen
            (\value ->
                case value of
                    "JPEG" ->
                        D.succeed JpegFormat

                    "PNG" ->
                        D.succeed PngFormat

                    "SVG" ->
                        D.succeed SvgFormat

                    value ->
                        D.fail <| "Unrecognized export format value: " ++ value
            )


exportConstraintDecoder : Decoder ExportConstraint
exportConstraintDecoder =
    let
        value =
            D.field "value" D.float
    in
        D.field "type" D.string
            |> D.andThen
                (\type_ ->
                    case type_ of
                        "SCALE" ->
                            D.map ScaleConstraint value

                        "WIDTH" ->
                            D.map WidthConstraint value

                        "HEIGHT" ->
                            D.map HeightConstraint value

                        type_ ->
                            D.fail <| "Unrecognized export constraint type: " ++ type_
                )
