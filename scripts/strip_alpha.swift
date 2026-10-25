// Re-encodes a PNG in place without an alpha channel. Usage: swift strip_alpha.swift <file.png>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let path = CommandLine.arguments[1]
let url = URL(fileURLWithPath: path)
guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(src, 0, nil),
      let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                          bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
else { FileHandle.standardError.write(Data("cannot read \(path)\n".utf8)); exit(1) }
ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
guard let out = ctx.makeImage(),
      let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
else { exit(1) }
CGImageDestinationAddImage(dst, out, nil)
exit(CGImageDestinationFinalize(dst) ? 0 : 1)
