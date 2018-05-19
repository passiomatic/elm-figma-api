module Main exposing (main)

import Html as H exposing (Html)
import Html.Events as E
import Html.Attributes as A
import RemoteData exposing (RemoteData)
import Http
import Color exposing (Color)
import Color.Convert as Convert
import Set exposing (Set)
import Figma
import Figma.Appearance as Appearance
import Figma.Document as Document


type alias Model =
    { swatches : RemoteData Http.Error (Set Swatch)
    , fileKey : Figma.FileKey
    , apiKey : String
    }


initialModel : Model
initialModel =
    { swatches = RemoteData.NotAsked
    , fileKey = ""
    , apiKey = ""
    }


init : ( Model, Cmd Msg )
init =
    ( initialModel
    , Cmd.none
    )


type Msg
    = GetFile
    | SetFileKey String
    | SetApiKey String
    | FileReceived (Result Http.Error Figma.File)
    | Restart


{-| A swatch can be have single solid color or multiple colors (a gradient).
-}
type alias Swatch =
    List String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Restart ->
            ( { model
                | swatches = RemoteData.NotAsked
              }
            , Cmd.none
            )

        GetFile ->
            let
                authToken =
                    Figma.personalToken (String.trim model.apiKey)
            in
                ( { model
                    | swatches = RemoteData.Loading
                  }
                , Figma.getFile authToken (String.trim model.fileKey) FileReceived
                )

        FileReceived result ->
            case result of
                Ok file ->
                    ( { model
                        | swatches = RemoteData.Success (swatches file.document)
                      }
                    , Cmd.none
                    )

                Err error ->
                    ( { model
                        | swatches = RemoteData.Failure error
                      }
                    , Cmd.none
                    )

        SetFileKey value ->
            ( { model
                | fileKey = value
              }
            , Cmd.none
            )

        SetApiKey value ->
            ( { model
                | apiKey = value
              }
            , Cmd.none
            )


errorMessage : Http.Error -> ( String, String )
errorMessage error =
    case error of
        Http.BadStatus response ->
            ( "Server returned a " ++ toString response.status.code ++ " error", "" )

        Http.BadPayload explaination _ ->
            ( "Problem while decoding the server response", explaination )

        _ ->
            ( "Cannot complete your request due to a network error", "" )


view : Model -> Html Msg
view model =
    case model.swatches of
        RemoteData.Loading ->
            formPanelView True model

        RemoteData.Success swatches ->
            swatchesPanelView swatches

        _ ->
            formPanelView False model


swatches : Document.Tree -> Set Swatch
swatches document =
    Document.foldl
        (\node swatches ->
            case node of
                Document.FrameNode frame ->
                    (background frame) :: swatches

                Document.GroupNode group ->
                    (background group) :: swatches

                Document.VectorNode vector ->
                    (fills vector) ++ swatches

                Document.StarNode vector ->
                    (fills vector) ++ swatches

                Document.LineNode vector ->
                    (fills vector) ++ swatches

                Document.EllipseNode vector ->
                    (fills vector) ++ swatches

                Document.RegularPolygonNode vector ->
                    (fills vector) ++ swatches

                Document.RectangleNode rectangle ->
                    (fills rectangle) ++ swatches

                Document.BooleanOperation vector ->
                    (fills vector) ++ swatches

                Document.TextNode text ->
                    (fills text) ++ swatches

                Document.ComponentNode component ->
                    (background component) :: swatches

                Document.InstanceNode instrance ->
                    (background instrance) :: swatches

                _ ->
                    -- Ignore the other nodes
                    swatches
        )
        []
        document
        |> Set.fromList


{-| Grab the background color for node.
-}
background : { a | backgroundColor : Color } -> Swatch
background { backgroundColor } =
    let
        hex =
            Convert.colorToHex backgroundColor
    in
        [ hex ]


{-| Grab the color and gradient fills for node.
-}
fills : { a | fills : List Appearance.Paint } -> List Swatch
fills { fills } =
    let
        converter =
            .color >> Convert.colorToHex

        colors : Appearance.Gradient -> Swatch
        colors gradient =
            List.map converter gradient.colorStops
    in
        List.foldl
            (\value swatches ->
                case value of
                    Appearance.ColorPaint color ->
                        (converter color |> List.singleton) :: swatches

                    Appearance.LinearGradientPaint gradient ->
                        colors gradient :: swatches

                    Appearance.RadialGradientPaint gradient ->
                        colors gradient :: swatches

                    Appearance.AngularGradientPaint gradient ->
                        colors gradient :: swatches

                    Appearance.DiamondGradientPaint gradient ->
                        colors gradient :: swatches

                    _ ->
                        -- Ignore the other nodes
                        swatches
            )
            []
            fills



-- FORM PANEL


alert : Model -> Html Msg
alert model =
    case model.swatches of
        RemoteData.Failure error ->
            let
                ( summary, detail ) =
                    errorMessage error

                _ =
                    -- Log verbose error on console
                    Debug.log "Error was" detail
            in
                H.div [ A.class "alert" ]
                    [ H.text ("😯 An error occured. " ++ summary)
                    ]

        _ ->
            H.div [] []


formPanelView : Bool -> Model -> Html Msg
formPanelView isLoading model =
    H.div []
        [ H.h1 []
            [ H.text "Swatches" ]
        , H.p [ A.class "subhead" ]
            [ H.text "This page fetches a Figma file using the "
            , H.a [ A.href "https://github.com/passiomatic/elm-figma-api" ]
                [ H.text "elm-figma-api package" ]
            , H.text " and collects all the found colors and gradients used as background or ‘paint fills’. "
            , H.br [] [], H.a [ A.class "", A.href "https://github.com/passiomatic/elm-figma-api/examples/swatches" ]
                [ H.text "Check out the source code on Github" ]
            ]
        , H.hr []
            []
        , H.form [ E.onSubmit GetFile, A.class "form" ]
            [ H.div [ A.class "form-group" ]
                [ H.label [ A.class "form-label" ]
                    [ H.text "Your Figma API key" ]
                , H.input [ A.class "form-control", A.required True, A.attribute "size" "20", A.value model.apiKey, E.onInput SetApiKey ]
                    []
                ]
            , H.div [ A.class "form-group" ]
                [ H.label [ A.class "form-label" ]
                    [ H.text "File key to inspect" ]
                , H.input [ A.class "form-control", A.required True, A.attribute "size" "20", A.value model.fileKey, E.onInput SetFileKey ]
                    []
                ]
            , H.div [ A.class "form-group" ]
                [ H.button [ A.class "form-control", A.type_ "submit" ]
                    [ H.text
                        (if isLoading then
                            "Fetching..."
                         else
                            "Fetch swatches"
                        )
                    ]
                ]
            ]
        , alert model
        ]



-- SWATCHES PANEL


swatchesPanelView : Set Swatch -> Html Msg
swatchesPanelView swatches =
    let
        view swatch =
            case swatch of
                value :: [] ->
                    colorSwatchView value

                values ->
                    gradientSwatchView values
    in
        H.div []
            [ H.h1 []
                [ H.text "Found swatches in file" ]
            , H.div [ A.class "wrapper" ]
                (Set.toList swatches
                    |> List.map view
                )
            , H.hr [] []
            , H.button [ E.onClick Restart ]
                [ H.text "Try again"
                ]
            ]


colorSwatchView : String -> Html Msg
colorSwatchView hex =
    H.div [ A.class "swatch swatch--solid", A.attribute "style" ("background: " ++ hex) ]
        [ H.p [ A.class "swatch-label" ]
            [ H.text hex ]
        ]


gradientSwatchView : Swatch -> Html Msg
gradientSwatchView swatch =
    let
        hexes =
            String.join ", " swatch
    in
        H.div [ A.class "swatch swatch--gradient", A.attribute "style" ("background-image: linear-gradient(to right, " ++ hexes ++ ");") ]
            [ H.p [ A.class "swatch-label" ]
                [ H.text hexes ]
            ]


main : Program Never Model Msg
main =
    H.program
        { init = init
        , update = update
        , subscriptions = \_ -> Sub.none
        , view = view
        }
