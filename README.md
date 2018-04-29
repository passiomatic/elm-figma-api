# Figma API with Elm

A work-in-progress package to help you use the Figma web API in Elm. 

See the original API documentation [here](https://www.figma.com/developers).

## Get a document file

First, let's create a authentication token – [see here](https://www.figma.com/developers/docs#auth-dev-token) – and pass that to the `getFile` function, together with the file key we want to retrieve.

    import Figma as F 

    F.getFile
        ( F.personalToken "your-token" )
        "your-file-key"
        FileReceived

Then in your `update` function we can extract the `FileReceived` message payloadand store it in the model app:

    FileReceived result ->         

        case result of 
            Ok response -> 
                ( { model | documentRoot = response.document }, Cmd.none )

            Err error -> 
                let 
                    _ = Debug.log "Error while fetching file" error
                in                
                ( model, Cmd.none ) 

**Note**: The *file key* can be extracted from any Figma file URL: `https://www.figma.com/file/:key/:title`, or via the `getProjectFiles` function.


## Export a document node to PNG

Here we start a request to export the node with ID `1:6` into a PNG file.

    F.exportPng 
        ( F.personalToken "your-token" ) 
        "your-file-key" 
        ExportFinished 
        [ "1:6" ]
 

## To-do 

Missign pieces:

* Layout grids
* Document versions
* `TyepStyle.styleOverrideTable`
* Export geometry data

