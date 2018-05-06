module Figma
    exposing
        ( personalToken
        , oauth2Token
        , getFile
        -- getFileWithOptions
        -- getFileVersions
        , getProjectFiles
        , getTeamProjects
        , getComments
        , postComment
        , exportPng
        , exportJpeg
        , exportSvg
        , exportWithOptions
        , AuthenticationToken
        , ProjectId
        , TeamId
        , Project
        , FileInfo
        , FileKey
        , ComponentInfo
        , FileResponse
        , ExportResponse
        , User
        , Comment(..)
        , CommentData
        , ReplyData
        )

{-| This package aims to provide a typed, Elm-friendly access to the Figma web API.

The API currently supports view-level operations on Figma files. Given a file, you can inspect an Elm representation
of it or export any node subtree within the file as an image. Future versions of the API will unlock greater functionality,
but the file object will remain at the heart of it.

[Read the orginal Figma API specification](https://www.figma.com/developers/docs).


# Authentication

@docs AuthenticationToken, personalToken, oauth2Token


# Obtain a file

@docs FileKey, getFile, FileResponse, ComponentInfo


# Read and post comments

@docs getComments, postComment, Comment, CommentData, ReplyData, User


# Export a file into other formats

@docs exportPng, exportJpeg, exportSvg, exportWithOptions, ExportResponse


# Obtain a list of team projects

@docs TeamId, getTeamProjects, Project


# Obtain the files of a single project

@docs ProjectId, getProjectFiles, FileInfo

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

**Note**: The *file key* can be extracted from any Figma file URL: `https://www.figma.com/file/:key/:title`, or via the `getProjectFiles` function.

-}
type alias FileKey =
    String


{-| Send a web request and return the file referred by *key* by storing it
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


{-| The document data returned by the server. In particular:

  - `document` is the root node of the document.
  - `components` is a mapping from node IDs to component metadata. This helps you determine
    which components each instance comes from.

-}
type alias FileResponse =
    { schemaVersion : Int
    , name : String
    , thumbnailUrl : String
    , lastModified : Date
    , document : Tree
    , components : Dict NodeId ComponentInfo
    }


fileResponseDecoder : Decoder FileResponse
fileResponseDecoder =
    D.decode FileResponse
        |> D.required "schemaVersion" D.int
        |> D.required "name" D.string
        |> D.required "thumbnailUrl" D.string
        |> D.required "lastModified" dateDecoder
        |> D.required "document" treeDecoder
        |> D.required "components" (D.dict componentDescriptionDecoder)


{-| Metadata for a master component. 
-}
type alias ComponentInfo =
    { name : String
    , description : String
    }


componentDescriptionDecoder : Decoder ComponentInfo
componentDescriptionDecoder =
    D.decode ComponentInfo
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
                , expect = Http.expectJson commentsResponseDecoder
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


{-| Metadata for a project file.
-}
type alias FileInfo =
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
getProjectFiles : AuthenticationToken -> ProjectId -> (Result Http.Error (List FileInfo) -> msg) -> Cmd msg
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


projectFilesDecoder : Decoder (List FileInfo)
projectFilesDecoder =
    D.field "files" (D.list projectFileDecoder)


projectFileDecoder : Decoder FileInfo
projectFileDecoder =
    D.decode FileInfo
        |> D.required "key" D.string
        |> D.required "name" D.string
        |> D.required "thumbnail_url" D.string
        |> D.required "last_modified" dateDecoder


{-| Send a web request and return the list of projects of the given team.

Note that this will only return projects visible to the authenticated user
or owner of the developer token.

-}
getTeamProjects : AuthenticationToken -> TeamId -> (Result Http.Error (List Project) -> msg) -> Cmd msg
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
