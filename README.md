# JMAnimatableImageView

UIImageView subclass instantiated from a GIF image data supporting variable framerates

## Setup

First instantiate your `JMAnimatedImageView` in your storyboard, xib file or in your code, and then call `setUpWithImageData()` with the GIF image NSData:

```
@IBOutlet private weak var animatedImageView: JMAnimatedImageView!

animatedImageView.setUpWithImageData(gifImageData)
```

## Animation

Simply call the UIImageView animation methods `startAnimating()` and `stopAnimating()`

Set the `repeat` boolean property to `true` if you want the animation to loop.

## Clearing

```
animatedImageView.clear()
```
