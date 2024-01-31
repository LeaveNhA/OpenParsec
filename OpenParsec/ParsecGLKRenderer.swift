import GLKit
import ParsecSDK

class ParsecGLKRenderer:NSObject, GLKViewDelegate, GLKViewControllerDelegate
{
	var glkView:GLKView
	var glkViewController:GLKViewController

	init(_ view:GLKView, _ viewController:GLKViewController)
	{
		glkView = view
		glkViewController = viewController

		super.init()

		glkView.delegate = self
		glkViewController.delegate = self
	}

	deinit
	{
		glkView.delegate = nil
		glkViewController.delegate = nil
	}

	func glkView(_ view:GLKView, drawIn rect:CGRect)
	{
		CParsec.pollAudio()
		CParsec.setFrame(view.frame.size.width, view.frame.size.height, view.contentScaleFactor)
		CParsec.renderFrame(.metal)
		glFinish()
	}

	func glkViewControllerUpdate(_ controller:GLKViewController) { }
}
