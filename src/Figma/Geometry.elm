module Figma.Geometry
    exposing
        ( BoundingBox
        , Point
        , Position(..)
        )

{-| 
 
@docs BoundingBox, Point, Position
 
-}

type alias NodeId = 
    String -- Just to please the compiler


{-| Specify a position: either the absolute coordinates on the canvas
or a relative offset within a frame.

Curently used only for comments.
-}
type Position
    = AbsolutePosition Point
    | RelativePositionTo NodeId Point




{-| A rectangle expressing a bounding box in absolute coordinates.
-}
type alias BoundingBox =
    { x : Float
    , y : Float
    , width : Float
    , height : Float
    }
 

{-| A 2D point.  
-}
type alias Point =
    { x : Float, y : Float }
 