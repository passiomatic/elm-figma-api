# Figma API with Elm

This package aims to provide a typed, Elm-friendly access to the Figma web API.

The API currently supports view-level operations on Figma files. Given a file, you can inspect its Elm representation, read or post comments, or export a rendered image of any node subtree. 

## Live "Swatches" example

The example below fetches a given Figma file and collects all the found colors and gradients used as background or paint fills. 

[Try it now][1] or [view source][2]

## Get a document file

First, let's create a authentication token and pass that to the `getFile` function, together with the file key we want to retrieve.

    import Http
    import Figma as F 

    F.getFile
        ( F.personalToken "your-token" )
        "your-file-key"
        |> Http.send FileReceived

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

    import Http
    import Figma as F 
    
    F.exportNodesAsPng 
        ( F.personalToken "your-token" ) 
        "your-file-key" 
        [ "1:6" ]
        |> Http.send ExportFinished 
        
Once finished the `ExportFinished` message will contain a list of `ExportedImage`, with the URL's for the rendered images. 

## Changes from previous version

* All top module functions now return a `Http.Request` value instead of `Cmd`, so you can chain calls together. See `getFile` documentation for an example.
* Added `BooleanGroup` and `BooleanOperation`. 
* Added support for file versions.

## Missing pieces 

* Export geometry data
* Prototype transitions and easing settings 
* Styles

If you need any of these features please open an issue.

[1]: http://lab.passiomatic.com/swatches/
[2]: https://github.com/passiomatic/elm-figma-api/tree/master/examples/swatches
