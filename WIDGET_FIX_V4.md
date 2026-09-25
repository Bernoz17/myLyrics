# Widget Fix v4

Fixed the Xcode/Swift compile error:

`Switch must be exhaustive`

The widget's `WidgetRenderingMode` switch now uses a normal `default` case.
Apple documents `WidgetRenderingMode` as a type exposing the static modes
`fullColor`, `accented`, and `vibrant`; the normal default case safely handles
any other value produced by the environment. citeturn486596search0turn486596search1
