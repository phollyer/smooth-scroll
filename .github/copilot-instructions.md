# Smooth Scroll Elm Package - AI Coding Instructions

## Project Overview
This is an Elm 0.19 package (`linuss/smooth-scroll`) that provides smooth scrolling animations to DOM elements. The core architecture separates public API (`SmoothScroll.elm`) from internal animation logic (`Internal/SmoothScroll.elm`).

## Key Architecture Patterns

### Task-Based API Design (SmoothScroll)
- All scrolling functions return `Task Dom.Error (List ())` for composable error handling
- Use `Task.attempt (always NoOp)` pattern in update functions (see `example/src/Example.elm`)
- Chain tasks with `Task.map3` and `Task.andThen` for complex viewport operations

### Subscription-Based API Design (SmoothMoveSub)
- Element positioning uses `onAnimationFrameDelta` for smooth, frame-rate independent animations
- Create `AnimationState` with `moveTo` or `moveToWithOptions`
- Subscribe to animation frames and update model with `updateAnimation`
- Apply positions via CSS `transform: translate()` in view functions

### Configuration Pattern
```elm
-- SmoothScroll: Always start with defaultConfig and override specific fields
scrollToWithOptions { defaultConfig | offset = 60, speed = 15 } "target-id"

-- SmoothMoveSub: Time-based animation configuration
moveToWithOptions { defaultConfig | speed = 500, axis = Both } "element-id" 0 0 100 200
```

### Internal Module Organization
- `Internal/SmoothScroll.elm` contains pure animation logic (`animationSteps`)
- Main module handles DOM interactions and task orchestration
- Internal modules are not exposed in `elm.json`

## Development Workflows

### Testing
- Run tests with `elm-test` from project root
- Tests focus on animation step generation logic in `Internal.SmoothScroll`
- Test edge cases: negative/zero speed, equal start/stop positions

### Examples
- Two example apps in `example/src/`: basic scrolling and container scrolling
- Example apps include source directory `../src` to import the package locally
- Run examples with `elm reactor` from the `example/` directory

### Package Structure
- Expose only `SmoothScroll` module in `elm.json`
- Keep internal implementation details in `Internal/` namespace
- Use semantic versioning for breaking changes to public API

## Critical Implementation Details

### Viewport Calculations
- Document body vs container element scrolling uses different DOM APIs
- Container scrolling requires element position relative to container bounds
- Always clamp scroll destination between 0 and max scrollable area

### Animation Systems
- **SmoothScroll**: Pre-calculated frame steps using `animationSteps` function
- **SmoothMoveSub**: Time-based interpolation with `onAnimationFrameDelta`
- Speed parameter: pixels per second for SmoothMoveSub, frame count divisor for SmoothScroll
- Easing functions from `elm-community/easing-functions` package applied to progress values

### Error Handling
- All DOM operations can fail with `Dom.Error`
- Use `Task.attempt` to handle errors gracefully in user applications
- Element IDs that don't exist will cause task failure

## Dependencies & Compatibility
- Elm 0.19.x only
- Requires `elm/browser` for DOM operations
- Uses `elm-community/easing-functions` for animation curves
- Test with `elm-explorations/test`