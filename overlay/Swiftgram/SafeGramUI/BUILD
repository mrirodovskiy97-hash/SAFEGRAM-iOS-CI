load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SafeGramUI",
    module_name = "SafeGramUI",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//Swiftgram/SafeGramCore:SafeGramCore",
        "//submodules/Display:Display",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
    ],
    visibility = ["//visibility:public"],
)
