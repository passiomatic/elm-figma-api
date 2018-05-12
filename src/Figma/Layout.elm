module Figma.Layout
    exposing
        ( LayoutVerticalConstraint(..)
        , LayoutHorizontalConstraint(..)
        , LayoutGrid(..)
        , Columns
        , Rows
        , Grid
        , GridVerticalAlign(..)
        , GridHorizontalAlign(..)
        )

{-|


# Layout constraints

@docs LayoutHorizontalConstraint, LayoutVerticalConstraint


# Grids

@docs LayoutGrid, Columns, Rows, Grid, GridHorizontalAlign, GridVerticalAlign

-}

import Color exposing (Color)


{-| -}
type LayoutGrid
    = ColumnsGrid Columns
    | RowsGrid Rows
    | SquareGrid Grid


{-| -}
type GridVerticalAlign
    = TopAlign
    | BottomAlign
    | CenterVerticalAlign


{-| -}
type GridHorizontalAlign
    = LeftAlign
    | RightAlign
    | CenterHorizontalAlign


{-| -}
type alias Columns =
    { width : Float
    , isVisible : Bool
    , color : Color
    , gutter : Float
    , marginBefore : Float
    , count : Int
    , align : GridHorizontalAlign
    }


{-| -}
type alias Rows =
    { height : Float
    , isVisible : Bool
    , color : Color
    , gutter : Float
    , marginBefore : Float
    , count : Int
    , align : GridVerticalAlign
    }


{-| -}
type alias Grid =
    { width : Float -- TODO : Size
    , isVisible : Bool
    , color : Color
    }


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
