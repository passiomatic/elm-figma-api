module Figma.Internal.Appearance
    exposing
        ( blendModeDecoder
        , effectDecoder
        , shadowDecoder
        , blurDecoder
        , textStyleDecoder
        , styleOverrideDecoder
        , verticalAlignDecoder
        , horizontalAlignDecoder
        , strokeAlignDecoder
        , paintDecoder
        , solidColorDecoder
        , gradientDecoder
        , imageDecoder
        , colorStopDecoder
        , colorDecoder
        )

import Dict exposing (Dict)
import Color exposing (Color)
import Json.Decode as D exposing (Decoder)
import Json.Decode.Pipeline as D
import Math.Vector2 as V exposing (Vec2)
import Figma.Appearance exposing (..)


-- BLEND MODE


blendModeDecoder : Decoder BlendMode
blendModeDecoder =
    D.string
        |> D.andThen
            (\value ->
                case value of
                    "NORMAL" ->
                        D.succeed NormalMode

                    "PASS_THROUGH" ->
                        D.succeed PassThroughMode

                    "DARKEN" ->
                        D.succeed DarkenMode

                    "MULTIPLY" ->
                        D.succeed MultiplyMode

                    "LINEAR_BURN" ->
                        D.succeed LinearBurnMode

                    "COLOR_BURN" ->
                        D.succeed ColorBurnMode

                    "LIGHTEN" ->
                        D.succeed LightenMode

                    "SCREEN" ->
                        D.succeed ScreenMode

                    "LINEAR_DODGE" ->
                        D.succeed LinearDodgeMode

                    "COLOR_DODGE" ->
                        D.succeed ColorDodgeMode

                    "OVERLAY" ->
                        D.succeed OverlayMode

                    "SOFT_LIGHT" ->
                        D.succeed SoftLightMode

                    "HARD_LIGHT" ->
                        D.succeed HardLightMode

                    "DIFFERENCE" ->
                        D.succeed DifferenceMode

                    "EXCLUSION" ->
                        D.succeed ExclusionMode

                    "HUE" ->
                        D.succeed HueMode

                    "SATURATION" ->
                        D.succeed SaturationMode

                    "COLOR" ->
                        D.succeed ColorMode

                    "LUMINOSITY" ->
                        D.succeed LuminosityMode

                    value ->
                        D.fail <| "Unrecognized blend mode value: " ++ value
            )



-- EFFECT


effectDecoder : Decoder Effect
effectDecoder =
    D.field "type" D.string
        |> D.andThen
            (\value ->
                case value of
                    "INNER_SHADOW" ->
                        D.map InnerShadowEffect shadowDecoder

                    "DROP_SHADOW" ->
                        D.map DropShadowEffect shadowDecoder

                    "LAYER_BLUR" ->
                        D.map LayerBlurEffect blurDecoder

                    "BACKGROUND_BLUR" ->
                        D.map BackgroundBlurEffect blurDecoder

                    _ ->
                        D.fail <| "Unrecognized effect value: " ++ value
            )


shadowDecoder : Decoder Shadow
shadowDecoder =
    D.decode Shadow
        |> D.required "visible" D.bool
        |> D.required "radius" D.float
        |> D.required "color" colorDecoder
        |> D.required "blendMode" blendModeDecoder
        |> D.required "offset" vec2Decoder


blurDecoder : Decoder Blur
blurDecoder =
    D.decode Blur
        |> D.required "visible" D.bool
        |> D.required "radius" D.float



-- TYPOGRAPHY


textStyleDecoder : Decoder TextStyle
textStyleDecoder =
    D.decode TextStyle
        |> D.required "fontFamily" D.string
        |> D.required "fontPostScriptName" D.string
        |> D.optional "italic" D.bool False
        |> D.required "fontWeight" D.int
        |> D.required "fontSize" D.float
        |> D.required "textAlignHorizontal" horizontalAlignDecoder
        |> D.required "textAlignVertical" verticalAlignDecoder
        |> D.required "letterSpacing" D.float
        |> D.optional "fills" (D.list paintDecoder) []
        |> D.required "lineHeightPx" D.float
        |> D.required "lineHeightPercent" D.float


typeStyleOverrideDecoder : Decoder TextStyleOverride
typeStyleOverrideDecoder =
    D.decode TextStyleOverride
        |> D.optional "fontFamily" (D.maybe D.string) Nothing
        |> D.optional "fontPostScriptName" (D.maybe D.string) Nothing
        |> D.optional "italic" (D.maybe D.bool) Nothing
        |> D.optional "fontWeight" (D.maybe D.int) Nothing
        |> D.optional "fontSize" (D.maybe D.float) Nothing
        |> D.optional "textAlignHorizontal" (D.maybe horizontalAlignDecoder) Nothing
        |> D.optional "textAlignVertical" (D.maybe verticalAlignDecoder) Nothing
        |> D.optional "letterSpacing" (D.maybe D.float) Nothing
        |> D.optional "fills" (D.maybe (D.list paintDecoder)) Nothing
        |> D.optional "lineHeightPx" (D.maybe D.float) Nothing
        |> D.optional "lineHeightPercent" (D.maybe D.float) Nothing


styleOverrideDecoder : Decoder (Dict Int TextStyleOverride)
styleOverrideDecoder =
    let
        toInt =
            String.toInt >> Result.withDefault 0
    in
        (D.keyValuePairs typeStyleOverrideDecoder)
            |> D.andThen
                (\values ->
                    List.map (\( id, value ) -> ( toInt id, value )) values
                        |> Dict.fromList
                        |> D.succeed
                )


verticalAlignDecoder : Decoder TextVerticalAlign
verticalAlignDecoder =
    D.string
        |> D.andThen
            (\value ->
                case value of
                    "TOP" ->
                        D.succeed TopAlign

                    "CENTER" ->
                        D.succeed CenterVerticalAlign

                    "BOTTOM" ->
                        D.succeed BottomAlign

                    value ->
                        D.fail <| "Unrecognized text alignment value: " ++ value
            )


horizontalAlignDecoder : Decoder TextHorizontalAlign
horizontalAlignDecoder =
    D.string
        |> D.andThen
            (\value ->
                case value of
                    "LEFT" ->
                        D.succeed LeftAlign

                    "RIGHT" ->
                        D.succeed RightAlign

                    "CENTER" ->
                        D.succeed CenterHorizontalAlign

                    "JUSTIFIED" ->
                        D.succeed JustifiedAlign

                    value ->
                        D.fail <| "Unrecognized text alignment value: " ++ value
            )



-- STROKE ALIGN


strokeAlignDecoder : Decoder StrokeAlign
strokeAlignDecoder =
    D.string
        |> D.andThen
            (\value ->
                case value of
                    "INSIDE" ->
                        D.succeed InsideStroke

                    "OUTSIDE" ->
                        D.succeed OutsideStroke

                    "CENTER" ->
                        D.succeed CenterStroke

                    value ->
                        D.fail <| "Unrecognized stroke align value: " ++ value
            )



-- PAINT


paintDecoder : Decoder Paint
paintDecoder =
    D.field "type" D.string
        |> D.andThen
            (\hint ->
                case hint of
                    "SOLID" ->
                        D.map ColorPaint solidColorDecoder

                    "GRADIENT_LINEAR" ->
                        D.map LinearGradientPaint gradientDecoder

                    "GRADIENT_RADIAL" ->
                        D.map RadialGradientPaint gradientDecoder

                    "GRADIENT_ANGULAR" ->
                        D.map AngularGradientPaint gradientDecoder

                    "GRADIENT_DIAMOND" ->
                        D.map DiamondGradientPaint gradientDecoder

                    "IMAGE" ->
                        D.map ImagePaint imageDecoder

                    "EMOJI" ->
                        D.succeed EmojiPaint

                    _ ->
                        D.fail <| "Unsupported paint type: " ++ hint
            )


solidColorDecoder : Decoder SolidColor
solidColorDecoder =
    D.decode SolidColor
        |> D.optional "visible" D.bool True
        |> D.optional "opacity" D.float 1.0
        |> D.required "color" colorDecoder
        |> D.required "blendMode" blendModeDecoder


gradientDecoder : Decoder Gradient
gradientDecoder =
    D.decode Gradient
        |> D.optional "visible" D.bool True
        |> D.optional "opacity" D.float 1.0
        |> D.required "gradientHandlePositions" (D.index 0 vec2Decoder)
        |> D.required "gradientHandlePositions" (D.index 1 vec2Decoder)
        |> D.required "gradientHandlePositions" (D.index 2 vec2Decoder)
        |> D.required "gradientStops" (D.list colorStopDecoder)
        |> D.required "blendMode" blendModeDecoder


imageDecoder : Decoder Image
imageDecoder =
    D.decode Image
        |> D.optional "visible" D.bool True
        |> D.optional "opacity" D.float 1.0
        |> D.required "scaleMode" scaleModeDecoder
        |> D.required "blendMode" blendModeDecoder


scaleModeDecoder : Decoder ScaleMode
scaleModeDecoder =
    D.string
        |> D.andThen
            (\value ->
                case value of
                    "FILL" ->
                        D.succeed FillMode

                    "FIT" ->
                        D.succeed FitMode

                    "TILE" ->
                        D.succeed TileMode

                    "STRETCH" ->
                        D.succeed StretchMode

                    value ->
                        D.fail <| "Unrecognized scale mode value: " ++ value
            )


colorStopDecoder : Decoder ColorStop
colorStopDecoder =
    D.decode ColorStop
        |> D.required "position" D.float
        |> D.required "color" colorDecoder


colorDecoder : Decoder Color
colorDecoder =
    let
        color r g b a =
            Color.rgba
                (r * 255 |> round)
                (g * 255 |> round)
                (b * 255 |> round)
                a
    in
        D.map4 color
            (D.field "r" D.float)
            (D.field "g" D.float)
            (D.field "b" D.float)
            (D.field "a" D.float)



-- MISC DECODERS


vec2Decoder : Decoder Vec2
vec2Decoder =
    D.decode V.vec2
        |> D.required "x" D.float
        |> D.required "y" D.float
