module ExampleMoveSub exposing (main)

{-| 
This example demonstrates the fully managed approach - no position tracking needed!

BENEFITS:
- ✅ No need to track AnimationState in your model
- ✅ No need to track element positions in your model
- ✅ No need to handle animation completion manually  
- ✅ Library manages ALL state automatically
- ✅ Simple startAnimation and subscriptions calls
- ✅ Get positions with getCurrentPosition when needed

DEVELOPER EXPERIENCE:
- Keep only a SmoothMoveSub.Model in your model
- Call startAnimation to begin animations (library tracks positions)
- Subscribe with SmoothMoveSub.subscriptions for smooth updates
- Use getCurrentPosition in view functions to render elements
- Library handles everything else automatically!
-}

import Browser exposing (Document)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import SmoothMoveSub exposing (Position, defaultConfig, transform, transformPosition, isAnimating)


main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias Model =
    { smoothMove : SmoothMoveSub.Model
    , lastPosition : Maybe Position
    }


type Msg
    = StartMove Float Float
    | AnimationFrame Float Position
    | NoOp


init : () -> ( Model, Cmd Msg )
init _ =
    ( { smoothMove = SmoothMoveSub.init
      , lastPosition = Nothing
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        StartMove targetX targetY ->
            let
                -- Get current position from SmoothMoveSub, defaulting to (0,0) if not found
                currentPos =
                    getCurrentPosition "moving-element" model.smoothMove
                        |> Maybe.withDefault { x = 0, y = 0 }

                newSmoothMove =
                    SmoothMoveSub.startAnimation
                        "moving-element"
                        currentPos.x
                        currentPos.y
                        targetX
                        targetY
                        model.smoothMove
            in
            ( { model | smoothMove = newSmoothMove }, Cmd.none )

        AnimationFrame deltaMs position ->
            let
                ( newSmoothMove, _ ) =
                    SmoothMoveSub.updateModel deltaMs model.smoothMove
            in
            ( { model
              | smoothMove = newSmoothMove
              , lastPosition = Just position
              }
            , Cmd.none
            )

        NoOp ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    SmoothMoveSub.subscriptions model.smoothMove AnimationFrame


view : Model -> Document Msg
view model =
    { title = "Smooth Move Example - Fully Managed Positions"
    , body =
        [ div [ style "position" "relative", style "width" "100vw", style "height" "100vh" ]
            [ let
                  currentPos =
                      getCurrentPosition "moving-element" model.smoothMove
                          |> Maybe.withDefault { x = 0, y = 0 }
              in
              div
                [ id "moving-element"
                , style "position" "absolute"
                , style "width" "50px"
                , style "height" "50px"
                , style "background-color" "blue"
                , style "border-radius" "50%"
                , style "transform" (transform currentPos.x currentPos.y)
                , style "transition" "none"
                ]
                [ div [ style "color" "white", style "text-align" "center", style "line-height" "50px", style "font-size" "12px" ]
                    [ text "A" ]
                ]
            , case model.lastPosition of
                Just position ->
                    div
                        [ id "shadow-element"
                        , style "position" "absolute"
                        , style "width" "50px"
                        , style "height" "50px"
                        , style "background-color" "rgba(255, 0, 0, 0.5)"
                        , style "border-radius" "50%"
                        , style "transform" (transformPosition position)
                        , style "transition" "none"
                        ]
                        [ div [ style "color" "white", style "text-align" "center", style "line-height" "50px", style "font-size" "12px" ]
                            [ text "B" ]
                        ]

                Nothing ->
                    text ""
            , div [ style "margin" "20px" ]
                [ button [ onClick (StartMove 100 100) ] [ text "Move to (100, 100)" ]
                , button [ onClick (StartMove 300 150) ] [ text "Move to (300, 150)" ]
                , button [ onClick (StartMove 500 300) ] [ text "Move to (500, 300)" ]
                , button [ onClick (StartMove 0 0) ] [ text "Move to (0, 0)" ]
                ]
            , div [ style "margin" "20px" ]
                [ let
                      currentPos =
                          getCurrentPosition "moving-element" model.smoothMove
                              |> Maybe.withDefault { x = 0, y = 0 }
                  in
                  text
                      ("Current position: ("
                          ++ String.fromFloat (toFloat (round (currentPos.x * 10)) / 10)
                          ++ ", "
                          ++ String.fromFloat (toFloat (round (currentPos.y * 10)) / 10)
                          ++ ")"
                      )
                , br [] []
                , text
                    (if isAnimating model.smoothMove then
                        "Animation: Running"

                     else
                        "Animation: Stopped"
                    )
                , br [] []
                , text "Blue circle (A): Uses transform function"
                , br [] []
                , text "Red circle (B): Uses transformPosition function"
                ]
            ]
        ]
    }