module Figma
    exposing
        ( personalToken
        , oauth2Token
        , getFile
        , getProjectFiles
        , getTeamProjects
        , getComments
        , postComment
        , exportPng
        , exportJpeg
        , exportSvg
        , exportWithOptions
        , AuthenticationToken
        , ProjectFile
        , TeamProject
        , Node(..)
        , NodeId
        , FileKey
        , Document
        , Canvas
        , Frame
        , Group
        , Shape
        , Rectangle
        , Slice
        , Text
        , Component
        , ComponentDescription
        , Instance
        , FileResponse
        , ExportResponse
        , User
        , Comment(..)
        , CommentData
        , ReplyData
        , Position(..)
        , BoundingBox
        , Vector
        , BlendMode(..)
        , Effect(..)
        , Shadow
        , Blur
        , TextVerticalAlign(..)
        , TextHorizontalAlign(..)
        , StrokeAlign(..)
        , ScaleMode(..)
        , LayoutVerticalConstraint(..)
        , LayoutHorizontalConstraint(..)
        , Paint(..)
        , SolidColor
        , Gradient
        , Image
        , ColorStop
        , TypeStyle
        , ExportFormat(..)
        , ExportConstraint(..)
        , ExportSetting
        )

{-| This package aims to provide a typed, Elm-friendly access to the Figma web API. The original Figma API specification [lives here](https://www.figma.com/developers/docs).


# Authentication

@docs AuthenticationToken, personalToken, oauth2Token


# Obtain a file

@docs getFile, FileKey, FileResponse


# Read and post comments

@docs getComments, postComment, Comment, CommentData, ReplyData, Position, User


# Export a file into other formats

@docs exportPng, exportJpeg, exportSvg, exportWithOptions, ExportResponse


# Obtain a list of team projects

@docs getTeamProjects, TeamProject


# Obtain the files of a single project

@docs getProjectFiles, ProjectFile


# Document


## Node types

@docs Node, NodeId, Document, Canvas, Frame, Group, Shape, Rectangle, Slice, Text, Component, ComponentDescription, Instance


## Geometry

@docs BoundingBox, Vector


## Layout

@docs LayoutHorizontalConstraint, LayoutVerticalConstraint


## Visual appearance

@docs BlendMode, Effect, Blur, Shadow, StrokeAlign, Paint, SolidColor, Image, ScaleMode, Gradient, ColorStop


## Text styling

@docs TypeStyle, TextHorizontalAlign, TextVerticalAlign


## Export constraints and settings

@docs ExportConstraint, ExportSetting, ExportFormat

-}

import Json.Decode as D exposing (Decoder)
import Json.Decode.Pipeline as D
import Json.Encode as E
import Color exposing (Color)
import Date exposing (Date)
import Dict exposing (Dict)
import Http


-- AUTHENTICATION


{-| -}
type AuthenticationToken
    = Personal String
    | OAuth2 String


{-| Create a token to be used with the Personal Access Token authentication method.
[Read more](https://www.figma.com/developers/docs#auth-dev-token).
-}
personalToken : String -> AuthenticationToken
personalToken token =
    Personal token


{-| Create a token to be used with the OAuth 2 authentication method.
[Read more](https://www.figma.com/developers/docs#auth-oauth).
-}
oauth2Token : String -> AuthenticationToken
oauth2Token token =
    OAuth2 token


authHeader : AuthenticationToken -> Http.Header
authHeader token =
    case token of
        Personal token ->
            Http.header "X-Figma-Token" token

        OAuth2 token ->
            Http.header "Authorization" ("Bearer " ++ token)



-- DOCUMENT


baseUrl =
    "https://api.figma.com"


{-| A file key.

**Note**: The *file key* can be extracted from any Figma file URL: `https://www.figma.com/file/:key/:title`, or via the `getProjectFiles` function.

-}
type alias FileKey =
    String


{-| Send a GET HTTP request and return the file referred by *key* by storing it
into a `FileResponse` record.

    import Figma as F

    F.getFile
        ( F.personalToken "your-token" )
        "your-file-key"
        FileReceived

-}
getFile : AuthenticationToken -> FileKey -> (Result Http.Error FileResponse -> msg) -> Cmd msg
getFile token fileKey msg =
    Http.send msg <|
        getFileRequest token fileKey


{-| This is useful if you need to chain together a bunch of requests
(or any other tasks) in a single command.

       import Http

       getFileRequest
           ( personalToken "your-token" )
           "your-file-key"
           |> Http.toTask

-}
getFileRequest : AuthenticationToken -> FileKey -> Http.Request FileResponse
getFileRequest token fileKey =
    let
        url =
            baseUrl ++ "/v1/files/" ++ fileKey
    in
        Http.request
            { method = "GET"
            , headers = [ authHeader token ]
            , url = url
            , body = Http.emptyBody
            , expect = Http.expectJson fileResponseDecoder
            , timeout = Nothing
            , withCredentials = False
            }


{-| The response record contains information about the document returned by the server.

  - `document` is the root node of the document.
  - `components` is a mapping from node IDs to component metadata. This helps you determine
    which components each instance comes from.

-}
type alias FileResponse =
    { schemaVersion : Int
    , name : String
    , thumbnailUrl : String
    , lastModified : Date
    , document : Node
    , components : Dict NodeId ComponentDescription
    }


fileResponseDecoder : Decoder FileResponse
fileResponseDecoder =
    D.decode FileResponse
        |> D.required "schemaVersion" D.int
        |> D.required "name" D.string
        |> D.required "thumbnailUrl" D.string
        |> D.required "lastModified" dateDecoder
        |> D.required "document" nodeDecoder
        |> D.required "components" (D.dict componentDescriptionDecoder)


{-| Send a GET HTTP request and return a list of comments left on the document.
-}
getComments : AuthenticationToken -> FileKey -> (Result Http.Error (List Comment) -> msg) -> Cmd msg
getComments token fileKey msg =
    let
        url =
            baseUrl ++ "/v1/files/" ++ fileKey ++ "/comments"
    in
        Http.send msg <|
            Http.request
                { method = "GET"
                , headers = [ authHeader token ]
                , url = url
                , body = Http.emptyBody
                , expect = Http.expectJson commentsResponseDecoder
                , timeout = Nothing
                , withCredentials = False
                }


{-| Send a POST HTTP request and  add a new comment to the document.
Return the `Comment` that was successfully posted.
-}
postComment : AuthenticationToken -> FileKey -> (Result Http.Error Comment -> msg) -> { message : String, position : Position } -> Cmd msg
postComment token fileKey msg comment =
    let
        url =
            baseUrl
                ++ "/v1/files/"
                ++ fileKey
                ++ "/comments"
    in
        Http.send msg <|
            Http.request
                { method = "POST"
                , headers = [ authHeader token ]
                , url = url
                , body = Http.jsonBody <| encodeComment comment
                , expect = Http.expectJson commentDecoder
                , timeout = Nothing
                , withCredentials = False
                }



-- postReply : AuthenticationToken -> String -> (Result Http.Error Comment -> msg) -> { parentId : String, message : String, position : Position } -> Cmd msg
-- postReply token fileKey msg comment =
--     let
--         url =
--             baseUrl
--                 ++ "/v1/files/"
--                 ++ fileKey
--                 ++ "/comments"
--     in
--         Http.send msg <|
--             Http.request
--                 { method = "POST"
--                 , headers = [ authHeader token ]
--                 , url = url
--                 , body = Http.jsonBody <| encodeReply comment
--                 , expect = Http.expectJson commentDecoder
--                 , timeout = Nothing
--                 , withCredentials = False
--                 }
-- PROJECT


{-| A single project file.
-}
type alias ProjectFile =
    { key : FileKey
    , name : String
    , thumbnailUrl : String
    , lastModified : Date
    }


{-| A single team project.
-}
type alias TeamProject =
    { id : Int
    , name : String
    }


{-| Send a GET HTTP request and return a list of files for the given project.
-}
getProjectFiles : AuthenticationToken -> Int -> (Result Http.Error (List ProjectFile) -> msg) -> Cmd msg
getProjectFiles token projectId msg =
    let
        url =
            baseUrl ++ "/v1/projects/" ++ (toString projectId) ++ "/files"
    in
        Http.send msg <|
            Http.request
                { method = "GET"
                , headers = [ authHeader token ]
                , url = url
                , body = Http.emptyBody
                , expect = Http.expectJson projectFilesDecoder
                , timeout = Nothing
                , withCredentials = False
                }


projectFilesDecoder : Decoder (List ProjectFile)
projectFilesDecoder =
    D.field "files" (D.list projectFileDecoder)


projectFileDecoder : Decoder ProjectFile
projectFileDecoder =
    D.decode ProjectFile
        |> D.required "key" D.string
        |> D.required "name" D.string
        |> D.required "thumbnail_url" D.string
        |> D.required "last_modified" dateDecoder


{-| Send a GET HTTP request and return a list of projects for the given team.

Note that this will only return projects visible to the authenticated user
or owner of the developer token.

-}
getTeamProjects : AuthenticationToken -> String -> (Result Http.Error (List TeamProject) -> msg) -> Cmd msg
getTeamProjects token teamId msg =
    let
        url =
            baseUrl ++ "/v1/teams/" ++ teamId ++ "/projects"
    in
        Http.send msg <|
            Http.request
                { method = "GET"
                , headers = [ authHeader token ]
                , url = url
                , body = Http.emptyBody
                , expect = Http.expectJson teamProjectsDecoder
                , timeout = Nothing
                , withCredentials = False
                }


teamProjectsDecoder : Decoder (List TeamProject)
teamProjectsDecoder =
    D.field "files" (D.list teamProjectDecoder)


teamProjectDecoder : Decoder TeamProject
teamProjectDecoder =
    D.decode TeamProject
        |> D.required "key" D.int
        |> D.required "name" D.string



-- EXPORT


{-| Export a list of document nodes into PNG files at 1x resolution.

If you need to specify a different scale value use `exportWithOptions`.

-}
exportPng : AuthenticationToken -> FileKey -> (Result Http.Error ExportResponse -> msg) -> List NodeId -> Cmd msg
exportPng token fileKey msg ids =
    let
        options =
            { format = PngFormat, scale = 1.0 }
    in
        exportWithOptions token fileKey msg ids options


{-| Export a list of document nodes into JPEG files at 1x resolution.

If you need to specify a different scale value use `exportWithOptions`.

-}
exportJpeg : AuthenticationToken -> FileKey -> (Result Http.Error ExportResponse -> msg) -> List NodeId -> Cmd msg
exportJpeg token fileKey msg ids =
    let
        options =
            { format = JpegFormat, scale = 1.0 }
    in
        exportWithOptions token fileKey msg ids options


{-| Export a list of document nodes into SVG files at 1x resolution.

If you need to specify a different scale value use `exportWithOptions`.

-}
exportSvg : AuthenticationToken -> FileKey -> (Result Http.Error ExportResponse -> msg) -> List NodeId -> Cmd msg
exportSvg token fileKey msg ids =
    let
        options =
            { format = SvgFormat, scale = 1.0 }
    in
        exportWithOptions token fileKey msg ids options


{-| Export a list of document nodes into the given `format` files using
the given `scale` factor automatically clamped within the 0.01–4 range.
-}
exportWithOptions :
    AuthenticationToken
    -> FileKey
    -> (Result Http.Error ExportResponse -> msg)
    -> List NodeId
    -> { format : ExportFormat, scale : Float }
    -> Cmd msg
exportWithOptions token fileKey msg ids options =
    let
        format =
            formatToString options.format

        scale =
            clamp 0.01 4 options.scale |> toString

        ids_ =
            String.join "," ids

        url =
            baseUrl
                ++ "/v1/images/"
                ++ fileKey
                ++ "?ids="
                ++ ids_
                ++ "&scale="
                ++ scale
                ++ "&format="
                ++ format
    in
        Http.send msg <|
            Http.request
                { method = "GET"
                , headers = [ authHeader token ]
                , url = url
                , body = Http.emptyBody
                , expect = Http.expectJson exportResponseDecoder
                , timeout = Nothing
                , withCredentials = False
                }


formatToString format =
    case format of
        JpegFormat ->
            "jpg"

        PngFormat ->
            "png"

        SvgFormat ->
            "svg"


{-| The response is populated with a list of tuples made of node ID's and URL's of the rendered images.

The `Nothing` values indicate that rendering of that specific node has failed. This may be due to
the node id not existing, or other reasons such has the node having no renderable components.

It is guaranteed that any node that was requested for rendering will be represented in this
map whether or not the render succeeded.

-}
type alias ExportResponse =
    List ( NodeId, Maybe String )


exportResponseDecoder : Decoder ExportResponse
exportResponseDecoder =
    D.field "images"
        (D.keyValuePairs (D.nullable D.string)
         -- |> D.andThen
         --     (\value ->
         --         D.succeed <| value -- Dict.fromList value
         --     )
        )



-- COMMENTS


{-| A comment is either a "top comment" or a reply to it.
-}
type Comment
    = Comment CommentData
    | Reply ReplyData


{-| A comment left by a user.
-}
type alias CommentData =
    { id : String
    , message : String
    , fileKey : FileKey
    , position : Position
    , user : User
    , createdAt : Date
    , resolvedAt : Maybe Date
    , orderId : Int
    }


{-| A reply to a comment.
-}
type alias ReplyData =
    { id : String
    , message : String
    , fileKey : FileKey
    , parentId : String
    , user : User
    , createdAt : Date
    , resolvedAt : Maybe Date
    }


commentsResponseDecoder : Decoder (List Comment)
commentsResponseDecoder =
    D.field "comments"
        (D.list
            (D.oneOf
                [ commentDecoder
                , replyDecoder
                ]
            )
        )


commentDecoder : Decoder Comment
commentDecoder =
    (D.decode CommentData
        |> D.required "id" D.string
        |> D.required "message" D.string
        |> D.required "file_key" D.string
        |> D.required "client_meta" positionDecoder
        |> D.required "user" userDecoder
        |> D.required "created_at" dateDecoder
        |> D.required "resolved_at" (D.nullable dateDecoder)
        |> D.required "order_id" D.int
    )
        |> D.map Comment


replyDecoder : Decoder Comment
replyDecoder =
    (D.decode ReplyData
        |> D.required "id" D.string
        |> D.required "message" D.string
        |> D.required "file_key" D.string
        |> D.required "parent_id" D.string
        |> D.required "user" userDecoder
        |> D.required "created_at" dateDecoder
        |> D.required "resolved_at" (D.nullable dateDecoder)
    )
        |> D.map Reply


encodeComment : { message : String, position : Position } -> E.Value
encodeComment comment =
    let
        position =
            case comment.position of
                AbsolutePosition vector ->
                    encodeVector vector

                RelativePositionTo frameId vector ->
                    E.object
                        [ ( "node_id", E.string <| frameId )
                        , ( "node_offset", encodeVector vector )
                        ]
    in
        E.object
            [ ( "message", E.string comment.message )
            , ( "client_meta", position )
            ]



-- USER


{-| A Figma user.
-}
type alias User =
    { handle : String
    , imageUrl : String
    }


userDecoder : Decoder User
userDecoder =
    D.decode User
        |> D.required "handle" D.string
        |> D.required "img_url" D.string



-- FIGMA NODE TYPES


{-| A node ID.
-}
type alias NodeId =
    String


{-| A Figma document is structured as a tree of nodes. It starts with a
`DocumentNode`, which contains one or more `CanvasNode`'s — called *Pages* in the UI —
which in turn contain nodes for frames, images, vector shapes, etc.
-}
type Node
    = DocumentNode Document (List Node)
    | CanvasNode Canvas (List Node)
    | FrameNode Frame (List Node)
    | GroupNode Group (List Node)
    | ShapeNode Shape
    | StarNode Shape
    | LineNode Shape
    | EllipseNode Shape
    | RegularPolygonNode Shape
    | RectangleNode Rectangle
    | BooleanOperation Shape (List Node)
    | SliceNode Slice
    | TextNode Text
    | ComponentNode Component (List Node)
    | InstanceNode Instance


{-| A reusable component node. It has the same fields of `Frame`.
-}
type alias Component =
    Frame


nodeDecoder : Decoder Node
nodeDecoder =
    D.field "type" D.string
        |> D.andThen
            (\value ->
                case value of
                    "DOCUMENT" ->
                        D.map2 DocumentNode documentDecoder childrenDecoder

                    "CANVAS" ->
                        D.map2 CanvasNode canvasDecoder childrenDecoder

                    "FRAME" ->
                        D.map2 FrameNode frameDecoder childrenDecoder

                    "GROUP" ->
                        D.map2 GroupNode frameDecoder childrenDecoder

                    "VECTOR" ->
                        D.map ShapeNode shapeDecoder

                    "STAR" ->
                        D.map StarNode shapeDecoder

                    "LINE" ->
                        D.map LineNode shapeDecoder

                    "ELLIPSE" ->
                        D.map EllipseNode shapeDecoder

                    "REGULAR_POLYGON" ->
                        D.map RegularPolygonNode shapeDecoder

                    "RECTANGLE" ->
                        D.map RectangleNode rectangleDecoder

                    "TEXT" ->
                        D.map TextNode textDecoder

                    "SLICE" ->
                        D.map SliceNode sliceDecoder

                    "COMPONENT" ->
                        D.map2 ComponentNode frameDecoder childrenDecoder

                    "INSTANCE" ->
                        D.map InstanceNode componentInstanceDecoder

                    "BOOLEAN_OPERATION" ->
                        D.map2 BooleanOperation shapeDecoder childrenDecoder
                        
                    _ ->
                        D.fail <| "Unsupported node type: " ++ value
            )


sharedNodeFields =
    D.required "id" nodeIdDecoder
        >> D.required "name" D.string
        >> D.optional "visible" D.bool True


nodeIdDecoder : Decoder NodeId
nodeIdDecoder =
    D.string
        |> D.andThen (\value -> D.succeed <| value)



-- DOCUMENT


{-| The root node of a document file.
-}
type alias Document =
    { id : NodeId
    , name : String
    , isVisible : Bool
    }


documentDecoder : Decoder Document
documentDecoder =
    D.decode Document
        |> sharedNodeFields


childrenDecoder : Decoder (List Node)
childrenDecoder =
    D.field "children" (D.list <| D.lazy (\_ -> nodeDecoder))



-- CANVAS


{-| A single page in a document.
-}
type alias Canvas =
    { id : NodeId
    , name : String
    , isVisible : Bool
    , backgroundColor : Color
    , exportSettings : List ExportSetting
    }


canvasDecoder : Decoder Canvas
canvasDecoder =
    D.decode Canvas
        |> sharedNodeFields
        |> D.required "backgroundColor" colorDecoder
        |> D.optional "exportSettings" (D.list exportSettingDecoder) []



-- FRAME


{-| A node of fixed size containing other nodes.
-}
type alias Frame =
    { id : NodeId
    , name : String
    , isVisible : Bool
    , backgroundColor : Color
    , exportSettings : List ExportSetting
    , blendMode : BlendMode
    , preserveRatio : Bool
    , horizontalConstraint : LayoutHorizontalConstraint
    , verticalConstraint : LayoutVerticalConstraint
    , transitionTo : Maybe NodeId
    , opacity : Float
    , boundingBox : BoundingBox
    , clipContent : Bool

    -- , layoutGrids : List LayoutGrid
    , effects : List Effect
    , isMask : Bool
    }


frameNodeFields =
    D.required "backgroundColor" colorDecoder
        >> D.optional "exportSettings" (D.list exportSettingDecoder) []
        >> D.required "blendMode" blendModeDecoder
        >> D.optional "preserveRatio" D.bool False
        >> D.requiredAt [ "constraints", "horizontal" ] horizontalConstraintDecoder
        >> D.requiredAt [ "constraints", "vertical" ] verticalConstraintDecoder
        >> D.optional "transitionNodeID" (D.nullable nodeIdDecoder) Nothing
        >> D.optional "opacity" D.float 1
        >> D.required "absoluteBoundingBox" boundingBoxDecoder
        >> D.required "clipsContent" D.bool
        -->> D.optional "layoutGrids" D.list  TODO
        >> D.optional "effects" (D.list effectDecoder) []
        >> D.optional "isMask" D.bool False


frameDecoder : Decoder Frame
frameDecoder =
    D.decode Frame
        |> sharedNodeFields
        |> frameNodeFields



-- GROUP


{-| A logical grouping of nodes.
-}
type alias Group =
    { id : NodeId
    , name : String
    , isVisible : Bool
    , backgroundColor : Color
    , exportSettings : List ExportSetting
    , blendMode : BlendMode
    , preserveRatio : Bool
    , horizontalConstraint : LayoutHorizontalConstraint
    , verticalConstraint : LayoutVerticalConstraint
    , transitionTo : Maybe NodeId
    , opacity : Float
    , boundingBox : BoundingBox
    , clipContent : Bool
    , effects : List Effect
    , isMask : Bool
    }


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
        |> D.optional "transitionNodeID" (D.nullable nodeIdDecoder) Nothing
        |> D.optional "opacity" D.float 1
        |> D.required "absoluteBoundingBox" boundingBoxDecoder
        |> D.required "clipsContent" D.bool
        |> D.optional "effects" (D.list effectDecoder) []
        |> D.optional "isMask" D.bool False



-- SHAPE


{-| A generic vector shape, consisting of vertices and edges.
-}
type alias Shape =
    { id : NodeId
    , name : String
    , isVisible : Bool
    , exportSettings : List ExportSetting
    , blendMode : BlendMode
    , preserveRatio : Bool
    , horizontalConstraint : LayoutHorizontalConstraint
    , verticalConstraint : LayoutVerticalConstraint
    , transitionTo : Maybe NodeId
    , opacity : Float
    , boundingBox : BoundingBox
    , effects : List Effect
    , isMask : Bool
    , fills : List Paint
    , strokes : List Paint
    , strokeWeight : Float
    , strokeAlign : StrokeAlign
    }


shapeNodeFields =
    D.optional "exportSettings" (D.list exportSettingDecoder) []
        >> D.required "blendMode" blendModeDecoder
        >> D.optional "preserveRatio" D.bool False
        >> D.requiredAt [ "constraints", "horizontal" ] horizontalConstraintDecoder
        >> D.requiredAt [ "constraints", "vertical" ] verticalConstraintDecoder
        >> D.optional "transitionNodeID" (D.nullable nodeIdDecoder) Nothing
        >> D.optional "opacity" D.float 1
        >> D.required "absoluteBoundingBox" boundingBoxDecoder
        --|> D.optional "layoutGrids" D.list  TODO
        >> D.optional "effects" (D.list effectDecoder) []
        >> D.optional "isMask" D.bool False
        >> D.optional "fills" (D.list paintDecoder) []
        >> D.required "strokes" (D.list paintDecoder)
        >> D.required "strokeWeight" D.float
        >> D.required "strokeAlign" strokeAlignDecoder


shapeDecoder : Decoder Shape
shapeDecoder =
    D.decode Shape
        |> sharedNodeFields
        |> shapeNodeFields



-- RECTANGLE


{-| A rectangular shape.
-}
type alias Rectangle =
    { id : NodeId
    , name : String
    , isVisible : Bool
    , exportSettings : List ExportSetting
    , blendMode : BlendMode
    , preserveRatio : Bool
    , horizontalConstraint : LayoutHorizontalConstraint
    , verticalConstraint : LayoutVerticalConstraint
    , transitionTo : Maybe NodeId
    , opacity : Float
    , boundingBox : BoundingBox
    , effects : List Effect
    , isMask : Bool
    , fills : List Paint
    , strokes : List Paint
    , strokeWeight : Float
    , strokeAlign : StrokeAlign
    , cornerRadius : Float
    }


rectangleDecoder : Decoder Rectangle
rectangleDecoder =
    D.decode Rectangle
        |> sharedNodeFields
        |> shapeNodeFields
        |> D.optional "cornerRadius" D.float 0



-- SLICE


{-| A rectangular region of the canvas that can be exported.
-}
type alias Slice =
    { id : NodeId
    , name : String
    , isVisible : Bool
    , exportSettings : List ExportSetting
    , boundingBox : BoundingBox
    }


sliceDecoder : Decoder Slice
sliceDecoder =
    D.decode Slice
        |> sharedNodeFields
        |> D.optional "exportSettings" (D.list exportSettingDecoder) []
        |> D.required "absoluteBoundingBox" boundingBoxDecoder



-- COMPONENT


{-| An instance of a component. Changes to the original component result
in the same changes applied to the instance.
-}
type alias Instance =
    { id : NodeId
    , name : String
    , isVisible : Bool
    , backgroundColor : Color
    , exportSettings : List ExportSetting
    , blendMode : BlendMode
    , preserveRatio : Bool
    , horizontalConstraint : LayoutHorizontalConstraint
    , verticalConstraint : LayoutVerticalConstraint
    , transitionTo : Maybe NodeId
    , opacity : Float
    , boundingBox : BoundingBox
    , clipContent : Bool

    -- , layoutGrids : List LayoutGrid
    , effects : List Effect
    , isMask : Bool
    , componentId : NodeId
    }


{-| A description of a master component. Helps you identify which
component instances are attached to.
-}
type alias ComponentDescription =
    { name : String
    , description : String
    }


componentInstanceDecoder : Decoder Instance
componentInstanceDecoder =
    D.decode Instance
        |> sharedNodeFields
        |> frameNodeFields
        |> D.required "componentId" D.string


componentDescriptionDecoder : Decoder ComponentDescription
componentDescriptionDecoder =
    D.decode ComponentDescription
        |> D.required "name" D.string
        |> D.required "description" D.string



-- BLEND MODE


{-| How a layer blends with layers below.
-}
type BlendMode
    = NormalMode
      -- Only applicable to objects with children
    | PassThroughMode
      -- Darken modes
    | DarkenMode
    | MultiplyMode
    | LinearBurnMode
    | ColorBurnMode
      -- Lighten modes
    | LightenMode
    | ScreenMode
    | LinearDodgeMode
    | ColorDodgeMode
      -- Contrast modes
    | OverlayMode
    | SoftLightMode
    | HardLightMode
      -- Inversion modes
    | DifferenceMode
    | ExclusionMode
      -- Component modes
    | HueMode
    | SaturationMode
    | ColorMode
    | LuminosityMode


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


{-| A visual effect such as a shadow or blur.
-}
type Effect
    = InnerShadowEffect Shadow
    | DropShadowEffect Shadow
    | LayerBlurEffect Blur
    | BackgroundBlurEffect Blur


{-| Shadow visual effect.
-}
type alias Shadow =
    { isVisible : Bool
    , radius : Float
    , color : Color
    , blendMode : BlendMode
    , offset : Vector
    }


{-| Blur visual effect.
-}
type alias Blur =
    { isVisible : Bool
    , radius : Float
    }


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
        |> D.required "offset" vectorDecoder


blurDecoder : Decoder Blur
blurDecoder =
    D.decode Blur
        |> D.required "visible" D.bool
        |> D.required "radius" D.float



-- TEXT & TYPE


{-| A text box.
-}
type alias Text =
    { id : NodeId
    , name : String
    , isVisible : Bool
    , exportSettings : List ExportSetting
    , blendMode : BlendMode
    , preserveRatio : Bool
    , horizontalConstraint : LayoutHorizontalConstraint
    , verticalConstraint : LayoutVerticalConstraint
    , transitionTo : Maybe NodeId
    , opacity : Float
    , boundingBox : BoundingBox
    , effects : List Effect
    , isMask : Bool
    , fills : List Paint
    , strokes : List Paint
    , strokeWeight : Float
    , strokeAlign : StrokeAlign
    , characters : String
    , style : TypeStyle
    , characterStyleOverrides : List Int

    --, styleOverrideTable : Dict Int TypeStyle  -- TODO
    }


textDecoder : Decoder Text
textDecoder =
    D.decode Text
        |> sharedNodeFields
        |> shapeNodeFields
        |> D.required "characters" D.string
        |> D.required "style" typeStyleDecoder
        |> D.required "characterStyleOverrides" (D.list D.int)


{-| Metadata for character formatting.
-}
type alias TypeStyle =
    { fontFamily : String
    , fontPostScriptName : String
    , isItalic : Bool
    , fontWeight : Int -- 100 .. 900
    , fontSize : Float
    , horizontalAlign : TextHorizontalAlign
    , verticalAlign : TextVerticalAlign
    , letterSpacing : Float
    , fills : List Paint
    , lineHeightPx : Float
    , lineHeightPercent : Float -- TODO Needed ?
    }


typeStyleDecoder : Decoder TypeStyle
typeStyleDecoder =
    D.decode TypeStyle
        |> D.required "fontFamily" D.string
        |> D.required "fontPostScriptName" D.string
        |> D.optional "italic" D.bool False
        |> D.required "fontWeight" D.int
        -- TODO Use union ^^^^^ ?
        |> D.required "fontSize" D.float
        |> D.required "textAlignHorizontal" horizontalAlignDecoder
        |> D.required "textAlignVertical" verticalAlignDecoder
        |> D.required "letterSpacing" D.float
        |> D.optional "fills" (D.list paintDecoder) []
        |> D.required "lineHeightPx" D.float
        |> D.required "lineHeightPercent" D.float


{-| Horizontal text alignment.
-}
type TextVerticalAlign
    = TopAlign
    | CenterVerticalAlign
    | BottomAlign


{-| Vertical text alignment.
-}
type TextHorizontalAlign
    = LeftAlign
    | RightAlign
    | CenterHorizontalAlign
    | JustifiedAlign


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


{-| Where stroke is drawn relative to the vector outline.
-}
type StrokeAlign
    = InsideStroke
    | OutsideStroke
    | CenterStroke


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



-- GEOMETRY


{-| A rectangle expressing a bounding box in absolute coordinates.
-}
type alias BoundingBox =
    { x : Float
    , y : Float
    , width : Float
    , height : Float
    }


boundingBoxDecoder : Decoder BoundingBox
boundingBoxDecoder =
    D.decode BoundingBox
        |> D.required "x" D.float
        |> D.required "y" D.float
        |> D.required "width" D.float
        |> D.required "height" D.float


{-| A 2D vector.
-}
type alias Vector =
    { x : Float
    , y : Float
    }


vectorDecoder : Decoder Vector
vectorDecoder =
    D.decode Vector
        |> D.required "x" D.float
        |> D.required "y" D.float


encodeVector : Vector -> E.Value
encodeVector vector =
    E.object
        [ ( "x", E.float vector.x )
        , ( "y", E.float vector.y )
        ]


{-| Specify a comment position: either the absolute coordinates on the canvas
or a relative offset within a frame.
-}
type Position
    = AbsolutePosition Vector
    | RelativePositionTo NodeId Vector


positionDecoder : Decoder Position
positionDecoder =
    D.oneOf
        [ D.map AbsolutePosition vectorDecoder
        , D.decode RelativePositionTo
            |> D.required "node_id" nodeIdDecoder
            |> D.required "node_offset" vectorDecoder
        ]



-- EXPORT SETTING


{-| Format and size to export an asset at.
-}
type alias ExportSetting =
    { suffix : String
    , format : ExportFormat
    , constraint : ExportConstraint
    }


{-| Format to export an asset to.
-}
type ExportFormat
    = PngFormat
    | JpegFormat
    | SvgFormat


{-| Sizing constraint for exports.
-}
type ExportConstraint
    = ScaleConstraint Float
    | WidthConstraint Float
    | HeightConstraint Float


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
                    "JPG" ->
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



-- LAYOUT CONSTRAINTS & GRIDS


type alias LayoutGrid =
    { -- orientation : Orientation
      sectionSize : Float
    , isVisible : Bool
    , color : Color
    }



-- type Layout
--      = ColumnsLayout Columns
--      | RowsLayout Rows
--     | GridLayout Grid
-- Positioning of grid as a string enum
-- "MIN": Grid starts at the left or top of the frame
-- "MAX": Grid starts at the right or bottom of the frame
-- "CENTER": Grid is center aligned
-- gutterSize Number
-- Spacing in between columns and rows
-- offset Number
-- Spacing before the first column or row
-- count Number
-- Number of columns or rows


{-| Vertical constraint relative to containing frame.
-}
type LayoutVerticalConstraint
    = TopConstraint
    | BottomConstraint
    | TopBottomConstraint
    | CenterVerticalConstraint
    | ScaleVerticalConstraint


{-| Horizontal constraint relative to containing frame.
-}
type LayoutHorizontalConstraint
    = LeftConstraint
    | RightConstraint
    | LeftRightConstraint
    | CenterHorizontalConstraint
    | ScaleHorizontalConstraint


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



-- PAINT


{-| A solid color, gradient, or image texture that can be applied as fills or strokes.
-}
type Paint
    = ColorPaint SolidColor
    | ImagePaint Image
    | LinearGradientPaint Gradient
    | RadialGradientPaint Gradient
    | AngularGradientPaint Gradient
      --| EmojiPaint -- TOD
    | DiamondGradientPaint Gradient


{-| Solid color of the paint.
-}
type alias SolidColor =
    { isVisible : Bool
    , opacity : Float
    , color : Color
    }


{-| A color gradient paint.
-}
type alias Gradient =
    { isVisible : Bool
    , opacity : Float
    , gradientHandlePositions : List Vector
    , gradientStops : List ColorStop
    }


{-| A image-textured paint.
-}
type alias Image =
    { isVisible : Bool
    , opacity : Float
    , scaleMode : ScaleMode
    , blendMode : BlendMode
    }


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

                    -- "EMOJI" ->
                    --     D.map EmojiPaint
                    _ ->
                        D.fail <| "Unsupported paint type: " ++ hint
            )


solidColorDecoder : Decoder SolidColor
solidColorDecoder =
    D.decode SolidColor
        |> D.optional "visible" D.bool True
        |> D.optional "opacity" D.float 1.0
        |> D.required "color" colorDecoder


gradientDecoder : Decoder Gradient
gradientDecoder =
    D.decode Gradient
        |> D.optional "visible" D.bool True
        |> D.optional "opacity" D.float 1.0
        |> D.required "gradientHandlePositions" (D.list vectorDecoder)
        |> D.required "gradientStops" (D.list colorStopDecoder)


imageDecoder : Decoder Image
imageDecoder =
    D.decode Image
        |> D.optional "visible" D.bool True
        |> D.optional "opacity" D.float 1.0
        |> D.required "scaleMode" scaleModeDecoder
        |> D.required "blendMode" blendModeDecoder


{-| Image scaling mode.
-}
type ScaleMode
    = FillMode
    | FitMode
    | TileMode
    | StretchMode


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


{-| A position color pair representing a gradient stop.
-}
type alias ColorStop =
    { position : Float
    , color : Color
    }


colorStopDecoder : Decoder ColorStop
colorStopDecoder =
    D.decode ColorStop
        |> D.required "position" D.float
        |> D.required "color" colorDecoder



-- MISC DECODERS


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


dateDecoder : Decoder Date
dateDecoder =
    let
        epoch =
            Date.fromTime 0
    in
        D.string
            |> D.andThen
                (\value ->
                    D.succeed <|
                        (Date.fromString value
                            |> Result.withDefault epoch
                        )
                )
