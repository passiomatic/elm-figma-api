# Figma API with Elm

This package aims to provide a typed, Elm-friendly access to the Figma web API.

The API currently supports view-level operations on Figma files. Given a file, you can inspect its Elm representation, read or post comments, or export a rendered image of any node subtree. 

[Read the orginal Figma API specification](https://www.figma.com/developers/docs).

## Get a document file

First, let's create a authentication token and pass that to the `getFile` function, together with the file key we want to retrieve.

    import Figma as F 

    F.getFile
        ( F.personalToken "your-token" )
        "your-file-key"
        FileReceived

Then in the `update` function we can extract the `FileReceived` message payloadand store it in the model app:

    FileReceived result ->         

        case result of 
            Ok response -> 
                ( { model | documentRoot = response.document }, Cmd.none )

            Err error -> 
                let 
                    _ = Debug.log "Error while fetching file" error
                in                
                ( model, Cmd.none ) 

**Note**: The key can be extracted from any Figma file URL: `https://www.figma.com/file/:key/:title`, or via the `getFiles` function.


## Export a document node to PNG

Here we start a request to export the node with ID `1:6` into a PNG file.

    F.exportNodesAsPng 
        ( F.personalToken "your-token" ) 
        "your-file-key" 
        ExportFinished 
        [ "1:6" ]
 
Once finished the `ExportFinished` message will contain a list of `ExportedImage`, containing URL's for the rendered images. 

## Missing pieces 

* Document versions
* Export geometry data

If you need any of these features please open an issue.