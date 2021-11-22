# TjekSDK

## Carthage Demo (deprecated)

* Note: Due to `swift package generate-xcodeproj` being deprecated, and the hoops needed to jump through in order to support Carthage, we can no longer guarantee support in the future. 

In order to build this demo you need to first checkout all the carthage dependencies:

```bash
$ cd Examples/CarthageDemo/
$ carthage checkout --use-submodules
```

Then you must generate xcode projects for all the SPM-only dependencies:

```bash
$ (cd Carthage/Checkouts/incito-ios && swift package generate-xcodeproj)
$ (cd Carthage/Checkouts/verso-ios && swift package generate-xcodeproj)
```

Finally, you can build the dependencies:

```bash
$ carthage build --platform iOS --use-xcframeworks
```

If you have previously built a different dependency demo, you must first clean your build folder.

> Note: For the demo to run correctly you must also supply valid keys to the `TjekSDK-Config.plist` file in the SharedSource folder. You can sign up for a free [here](https://etilbudsavis.dk/developers). 
