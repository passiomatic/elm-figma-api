module Figma.Layout
    exposing
        ( LayoutVerticalConstraint(..)
        , LayoutHorizontalConstraint(..)
        , LayoutGrid(..)
        , Columns
        , Rows
        , Grid
        , GridAlign(..)
        )

{-|


# Layout constraints

@docs LayoutHorizontalConstraint, LayoutVerticalConstraint


# Grids

@docs LayoutGrid, Columns, Rows, Grid, GridAlign

-}

import Color exposing (Color)


{-| Guides to align and place objects within a parent container. 
-}
type LayoutGrid
    = ColumnsGrid Columns
    | RowsGrid Rows
    | SquareGrid Grid


{-| Positioning of grid within the parent container.

  - `MinAlign`: grid starts at the top (or left) of the container, filling the minimun space possible. The margin is applied before the grid.
  - `CenterAlign`: grid is center aligned. Margin value is ignored.
  - `MaxAlign`: grid stretches from the top (or left) to the bottom (or right) of the container, filling the maximun space possible. The margin is applied before and after the grid.

-}
type GridAlign
    = MinAlign  
    | CenterAlign
    | MaxAlign  


{-| A vertical grid made of columns. 
-}
type alias Columns =
    { width : Float
    , isVisible : Bool
    , color : Color
    , gutter : Float
    , margin : Float  
    , count : Int
    , align : GridAlign
    }


{-| A horizontal grid made of rows. 
-}
type alias Rows =
    { height : Float
    , isVisible : Bool
    , color : Color
    , gutter : Float
    , margin : Float 
    , count : Int
    , align : GridAlign
    }


{-| A square grid. 
-}
type alias Grid =
    { width : Float
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
