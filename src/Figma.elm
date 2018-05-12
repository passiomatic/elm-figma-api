module Figma
    exposing
        ( personalToken
        , oauth2Token
        , getFile
          -- getFileWithOptions
          -- getVersions
        , getFiles
        , getProjects
        , getComments
        , postComment
        , exportNodesAsPng
        , exportNodesAsJpeg
        , exportNodesAsSvg
        , exportNodesWithOptions
        , AuthenticationToken
        , ProjectId
        , TeamId
        , Project
        , FileMeta
        , FileKey
        , ComponentMeta
        , File  
        , ExportedImage
        , User
        , Comment(..)
        , CommentData
        , ReplyData
        )

{-| This module provides end points for the Figma web API.


# Authentication

@docs AuthenticationToken, personalToken, oauth2Token


# Obtain a file

@docs FileKey, getFile, File, ComponentMeta


# Read and post comments

@docs getComments, postComment, Comment, CommentData, ReplyData, User


# Export a file into other formats

@docs exportNodesAsPng, exportNodesAsJpeg, exportNodesAsSvg, exportNodesWithOptions, ExportedImage


# Obtain a list of team projects

@docs TeamId, getProjects, Project


# Obtain the files of a single project

@docs ProjectId, getFiles, FileMeta

-}

import Json.Decode as D exposing (Decoder)
import Json.Decode.Pipeline as D
import Json.Encode as E
import Date exposing (Date)
import Dict exposing (Dict)
import Http
import Figma.Geometry exposing (..)
import Figma.Document exposing (..)
import Figma.Internal.Document exposing (..)
import Figma.Internal.Geometry exposing (..)


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


{-| A file key which univocally identifies Figma document on the server.

**Note**: The *file key* can be extracted from any Figma file URL: `https://www.figma.com/file/:key/:title`, or via the `getFiles` function.

-}
type alias FileKey =
    String


{-| Send a web request and return the file referred by *key* by storing it
into a `File` record.

    import Figma as F

    F.getFile
        ( F.personalToken "your-token" )
        "your-file-key"
        FileReceived

-}
getFile : AuthenticationToken -> FileKey -> (Result Http.Error File -> msg) -> Cmd msg
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
getFileRequest : AuthenticationToken -> FileKey -> Http.Request File
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
            , expect = Http.expectJson fileDataDecoder
            , timeout = Nothing
            , withCredentials = False
            }


{-| The file data returned by the server. In particular:

  - `document` is the root node of the document.
  - `components` is a mapping from node IDs to component metadata. This helps you determine
    which components each instance comes from.

-}
type alias File =
    { schemaVersion : Int
    , name : String
    , thumbnailUrl : String
    , lastModified : Date
    , document : Tree
    , components : Dict NodeId ComponentMeta
    }


fileDataDecoder : Decoder File
fileDataDecoder =
    D.decode File
        |> D.required "schemaVersion" D.int
        |> D.required "name" D.string
        |> D.required "thumbnailUrl" D.string
        |> D.required "lastModified" dateDecoder
        |> D.required "document" treeDecoder
        |> D.required "components" (D.dict componentMetaDecoder)


{-| Meta data for a master component. Component data is stored in a `Document.Component` record.
-}
type alias ComponentMeta =
    { name : String
    , description : String
    }


componentMetaDecoder : Decoder ComponentMeta
componentMetaDecoder =
    D.decode ComponentMeta
        |> D.required "name" D.string
        |> D.required "description" D.string


{-| Send a web request and return a list of comments left on the document.
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
                , expect = Http.expectJson commentsDecoder
                , timeout = Nothing
                , withCredentials = False
                }


{-| Send a web request and add a new comment to the document.
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



-- PROJECT


{-| A value which uniquely identifies a project.
-}
type alias ProjectId =
    Int


{-| A value which uniquely identifies a team.
-}
type alias TeamId =
    String


{-| Meta data for a project file.
-}
type alias FileMeta =
    { key : FileKey
    , name : String
    , thumbnailUrl : String
    , lastModified : Date
    }


{-| A single team project.
-}
type alias Project =
    { id : ProjectId
    , name : String
    }


{-| Send a web request and return the list of files of the given project.
-}
getFiles : AuthenticationToken -> ProjectId -> (Result Http.Error (List FileMeta) -> msg) -> Cmd msg
getFiles token projectId msg =
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


projectFilesDecoder : Decoder (List FileMeta)
projectFilesDecoder =
    D.field "files" (D.list fileMetaDecoder)


fileMetaDecoder : Decoder FileMeta
fileMetaDecoder =
    D.decode FileMeta
        |> D.required "key" D.string
        |> D.required "name" D.string
        |> D.required "thumbnail_url" D.string
        |> D.required "last_modified" dateDecoder


{-| Send a web request and return the list of projects of the given team.

Note that this will only return projects visible to the authenticated user
or owner of the developer token.

-}
getProjects : AuthenticationToken -> TeamId -> (Result Http.Error (List Project) -> msg) -> Cmd msg
getProjects token teamId msg =
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
                , expect = Http.expectJson projectsDecoder
                , timeout = Nothing
                , withCredentials = False
                }


projectsDecoder : Decoder (List Project)
projectsDecoder =
    D.field "files" (D.list projectDecoder)


projectDecoder : Decoder Project
projectDecoder =
    D.decode Project
        |> D.required "key" D.int
        |> D.required "name" D.string



-- EXPORT


{-| Export a list of document nodes into PNG files at 1x resolution.

If you need to specify a different scale value use `exportNodesWithOptions`.

-}
exportNodesAsPng : AuthenticationToken -> FileKey -> (Result Http.Error (List ExportedImage) -> msg) -> List NodeId -> Cmd msg
exportNodesAsPng token fileKey msg ids =
    let
        options =
            { format = PngFormat, scale = 1.0 }
    in
        exportNodesWithOptions token fileKey msg ids options


{-| Export a list of document nodes into JPEG files at 1x resolution.

If you need to specify a different scale value use `exportNodesWithOptions`.

-}
exportNodesAsJpeg : AuthenticationToken -> FileKey -> (Result Http.Error (List ExportedImage) -> msg) -> List NodeId -> Cmd msg
exportNodesAsJpeg token fileKey msg ids =
    let
        options =
            { format = JpegFormat, scale = 1.0 }
    in
        exportNodesWithOptions token fileKey msg ids options


{-| Export a list of document nodes into SVG files at 1x resolution.

If you need to specify a different scale value use `exportNodesWithOptions`.

-}
exportNodesAsSvg : AuthenticationToken -> FileKey -> (Result Http.Error (List ExportedImage) -> msg) -> List NodeId -> Cmd msg
exportNodesAsSvg token fileKey msg ids =
    let
        options =
            { format = SvgFormat, scale = 1.0 }
    in
        exportNodesWithOptions token fileKey msg ids options


{-| Export a list of document nodes into the given `format` files using
the given `scale` factor automatically clamped within the 0.01–4 range.
-}
exportNodesWithOptions :
    AuthenticationToken
    -> FileKey
    -> (Result Http.Error (List ExportedImage) -> msg)
    -> List NodeId
    -> { format : ExportFormat, scale : Float }
    -> Cmd msg
exportNodesWithOptions token fileKey msg ids options =
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
                , expect = Http.expectJson exportDataDecoder
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


{-| A tuple made of the node ID and the image URL of its rendered representation.

A `Nothing` value indicates that rendering of the specific node has failed. This may be due to
the node id not existing, or other reasons such has the node having no renderable components.

-}
type alias ExportedImage =
    ( NodeId, Maybe String )


exportDataDecoder : Decoder (List ExportedImage)
exportDataDecoder =
    D.field "images" (D.keyValuePairs (D.nullable D.string))



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
    , orderId : String
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


commentsDecoder : Decoder (List Comment)
commentsDecoder =
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
        |> D.required "order_id" D.string
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
                AbsolutePosition point ->
                    encodePoint point

                RelativePositionTo frameId point ->
                    E.object
                        [ ( "node_id", E.string frameId )
                        , ( "node_offset", encodePoint point )
                        ]
    in
        E.object
            [ ( "message", E.string comment.message )
            , ( "client_meta", position )
            ]



-- USER


{-| A description of a user.
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



-- MISC DECODERS


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
