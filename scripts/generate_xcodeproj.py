import os
import uuid

def gen_id():
    return uuid.uuid4().hex[:24].upper()

def create_project():
    proj_dir = os.path.abspath("PulseBar.xcodeproj")
    os.makedirs(proj_dir, exist_ok=True)
    pbx_path = os.path.join(proj_dir, "project.pbxproj")

    # Collect source files
    src_files = []
    for root, _, files in os.walk("PulseBar"):
        for f in files:
            if f.endswith(".swift"):
                rel_path = os.path.relpath(os.path.join(root, f), ".")
                src_files.append((f, rel_path))

    test_files = []
    for root, _, files in os.walk("PulseBarTests"):
        for f in files:
            if f.endswith(".swift"):
                rel_path = os.path.relpath(os.path.join(root, f), ".")
                test_files.append((f, rel_path))

    # Generate IDs
    proj_id = gen_id()
    main_group_id = gen_id()
    sources_group_id = gen_id()
    tests_group_id = gen_id()
    products_group_id = gen_id()

    app_target_id = gen_id()
    app_product_id = gen_id()
    app_sources_build_phase_id = gen_id()
    app_frameworks_build_phase_id = gen_id()
    app_resources_build_phase_id = gen_id()

    test_target_id = gen_id()
    test_product_id = gen_id()
    test_sources_build_phase_id = gen_id()
    test_frameworks_build_phase_id = gen_id()

    # File references
    file_refs = {}
    build_files = {}

    for name, path in src_files:
        fid = gen_id()
        bid = gen_id()
        file_refs[fid] = (name, path, "sourcecode.swift")
        build_files[bid] = (fid, name)

    for name, path in test_files:
        fid = gen_id()
        bid = gen_id()
        file_refs[fid] = (name, path, "sourcecode.swift")
        build_files[bid] = (fid, name)

    # Info.plist ref
    info_plist_id = gen_id()
    file_refs[info_plist_id] = ("Info.plist", "PulseBar/Info.plist", "text.plist.xml")

    # App product ref
    file_refs[app_product_id] = ("PulseBar.app", "PulseBar.app", "wrapper.application")
    # Test product ref
    file_refs[test_product_id] = ("PulseBarTests.xctest", "PulseBarTests.xctest", "wrapper.cfbundle")

    # Config IDs
    config_list_proj = gen_id()
    config_debug_proj = gen_id()
    config_release_proj = gen_id()

    config_list_app = gen_id()
    config_debug_app = gen_id()
    config_release_app = gen_id()

    config_list_test = gen_id()
    config_debug_test = gen_id()
    config_release_test = gen_id()

    out = []
    out.append("// !$*UTF8*$!")
    out.append("{")
    out.append("\tarchiveVersion = 1;")
    out.append("\tclasses = {")
    out.append("\t};")
    out.append("\tobjectVersion = 56;")
    out.append("\tobjects = {")

    # PBXBuildFile
    out.append("/* Begin PBXBuildFile section */")
    for bid, (fid, name) in build_files.items():
        out.append(f"\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};")
    out.append("/* End PBXBuildFile section */")

    # PBXFileReference
    out.append("/* Begin PBXFileReference section */")
    for fid, (name, path, ftype) in file_refs.items():
        if ftype.startswith("wrapper"):
            out.append(f"\t\t{fid} /* {name} */ = {{isa = PBXFileReference; explicitFileType = {ftype}; includeInIndex = 0; path = {name}; sourceTree = BUILT_PRODUCTS_DIR; }};")
        else:
            out.append(f"\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; name = \"{name}\"; path = \"{path}\"; sourceTree = \"<group>\"; }};")
    out.append("/* End PBXFileReference section */")

    # PBXFrameworksBuildPhase
    out.append("/* Begin PBXFrameworksBuildPhase section */")
    out.append(f"\t\t{app_frameworks_build_phase_id} /* Frameworks */ = {{")
    out.append("\t\t\tisa = PBXFrameworksBuildPhase;")
    out.append("\t\t\tbuildActionMask = 2147483647;")
    out.append("\t\t\tfiles = (")
    out.append("\t\t\t);")
    out.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    out.append("\t\t};")
    out.append(f"\t\t{test_frameworks_build_phase_id} /* Frameworks */ = {{")
    out.append("\t\t\tisa = PBXFrameworksBuildPhase;")
    out.append("\t\t\tbuildActionMask = 2147483647;")
    out.append("\t\t\tfiles = (")
    out.append("\t\t\t);")
    out.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    out.append("\t\t};")
    out.append("/* End PBXFrameworksBuildPhase section */")

    # PBXGroup
    out.append("/* Begin PBXGroup section */")
    out.append(f"\t\t{main_group_id} = {{")
    out.append("\t\t\tisa = PBXGroup;")
    out.append("\t\t\tchildren = (")
    out.append(f"\t\t\t\t{sources_group_id} /* PulseBar */,")
    out.append(f"\t\t\t\t{tests_group_id} /* PulseBarTests */,")
    out.append(f"\t\t\t\t{products_group_id} /* Products */,")
    out.append("\t\t\t);")
    out.append("\t\t\tsourceTree = \"<group>\";")
    out.append("\t\t};")

    # Sources group
    out.append(f"\t\t{sources_group_id} /* PulseBar */ = {{")
    out.append("\t\t\tisa = PBXGroup;")
    out.append("\t\t\tchildren = (")
    for name, path in src_files:
        for fid, (fname, fpath, _) in file_refs.items():
            if fpath == path:
                out.append(f"\t\t\t\t{fid} /* {fname} */,")
    out.append(f"\t\t\t\t{info_plist_id} /* Info.plist */,")
    out.append("\t\t\t);")
    out.append("\t\t\tname = PulseBar;")
    out.append("\t\t\tsourceTree = \"<group>\";")
    out.append("\t\t};")

    # Tests group
    out.append(f"\t\t{tests_group_id} /* PulseBarTests */ = {{")
    out.append("\t\t\tisa = PBXGroup;")
    out.append("\t\t\tchildren = (")
    for name, path in test_files:
        for fid, (fname, fpath, _) in file_refs.items():
            if fpath == path:
                out.append(f"\t\t\t\t{fid} /* {fname} */,")
    out.append("\t\t\t);")
    out.append("\t\t\tname = PulseBarTests;")
    out.append("\t\t\tsourceTree = \"<group>\";")
    out.append("\t\t};")

    # Products group
    out.append(f"\t\t{products_group_id} /* Products */ = {{")
    out.append("\t\t\tisa = PBXGroup;")
    out.append("\t\t\tchildren = (")
    out.append(f"\t\t\t\t{app_product_id} /* PulseBar.app */,")
    out.append(f"\t\t\t\t{test_product_id} /* PulseBarTests.xctest */,")
    out.append("\t\t\t);")
    out.append("\t\t\tname = Products;")
    out.append("\t\t\tsourceTree = \"<group>\";")
    out.append("\t\t};")
    out.append("/* End PBXGroup section */")

    # PBXNativeTarget
    out.append("/* Begin PBXNativeTarget section */")
    out.append(f"\t\t{app_target_id} /* PulseBar */ = {{")
    out.append("\t\t\tisa = PBXNativeTarget;")
    out.append(f"\t\t\tbuildConfigurationList = {config_list_app} /* Build configuration list for PBXNativeTarget \"PulseBar\" */;")
    out.append("\t\t\tbuildPhases = (")
    out.append(f"\t\t\t\t{app_sources_build_phase_id} /* Sources */,")
    out.append(f"\t\t\t\t{app_frameworks_build_phase_id} /* Frameworks */,")
    out.append("\t\t\t);")
    out.append("\t\t\tbuildRules = (")
    out.append("\t\t\t);")
    out.append("\t\t\tdependencies = (")
    out.append("\t\t\t);")
    out.append("\t\t\tname = PulseBar;")
    out.append("\t\t\tproductName = PulseBar;")
    out.append(f"\t\t\tproductReference = {app_product_id} /* PulseBar.app */;")
    out.append("\t\t\tproductType = \"com.apple.product-type.application\";")
    out.append("\t\t};")

    out.append(f"\t\t{test_target_id} /* PulseBarTests */ = {{")
    out.append("\t\t\tisa = PBXNativeTarget;")
    out.append(f"\t\t\tbuildConfigurationList = {config_list_test} /* Build configuration list for PBXNativeTarget \"PulseBarTests\" */;")
    out.append("\t\t\tbuildPhases = (")
    out.append(f"\t\t\t\t{test_sources_build_phase_id} /* Sources */,")
    out.append(f"\t\t\t\t{test_frameworks_build_phase_id} /* Frameworks */,")
    out.append("\t\t\t);")
    out.append("\t\t\tbuildRules = (")
    out.append("\t\t\t);")
    out.append("\t\t\tdependencies = (")
    out.append("\t\t\t);")
    out.append("\t\t\tname = PulseBarTests;")
    out.append("\t\t\tproductName = PulseBarTests;")
    out.append(f"\t\t\tproductReference = {test_product_id} /* PulseBarTests.xctest */;")
    out.append("\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
    out.append("\t\t};")
    out.append("/* End PBXNativeTarget section */")

    # PBXProject
    out.append("/* Begin PBXProject section */")
    out.append(f"\t\t{proj_id} /* Project object */ = {{")
    out.append("\t\t\tisa = PBXProject;")
    out.append("\t\t\tattributes = {")
    out.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    out.append("\t\t\t\tLastUpgradeCheck = 1500;")
    out.append("\t\t\t\tTargetAttributes = {")
    out.append(f"\t\t\t\t\t{app_target_id} = {{")
    out.append("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    out.append("\t\t\t\t\t};")
    out.append(f"\t\t\t\t\t{test_target_id} = {{")
    out.append("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    out.append(f"\t\t\t\t\t\tTestTargetID = {app_target_id};")
    out.append("\t\t\t\t\t};")
    out.append("\t\t\t\t};")
    out.append("\t\t\t};")
    out.append(f"\t\t\tbuildConfigurationList = {config_list_proj} /* Build configuration list for PBXProject \"PulseBar\" */;")
    out.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    out.append("\t\t\tdevelopmentRegion = en;")
    out.append("\t\t\thasScannedForEncodings = 0;")
    out.append("\t\t\tknownRegions = (")
    out.append("\t\t\t\ten,")
    out.append("\t\t\t\tBase,")
    out.append("\t\t\t);")
    out.append(f"\t\t\tmainGroup = {main_group_id};")
    out.append(f"\t\t\tproductRefGroup = {products_group_id} /* Products */;")
    out.append("\t\t\tprojectDirPath = \"\";")
    out.append("\t\t\tprojectRoot = \"\";")
    out.append("\t\t\ttargets = (")
    out.append(f"\t\t\t\t{app_target_id} /* PulseBar */,")
    out.append(f"\t\t\t\t{test_target_id} /* PulseBarTests */,")
    out.append("\t\t\t);")
    out.append("\t\t};")
    out.append("/* End PBXProject section */")

    # PBXSourcesBuildPhase
    out.append("/* Begin PBXSourcesBuildPhase section */")
    out.append(f"\t\t{app_sources_build_phase_id} /* Sources */ = {{")
    out.append("\t\t\tisa = PBXSourcesBuildPhase;")
    out.append("\t\t\tbuildActionMask = 2147483647;")
    out.append("\t\t\tfiles = (")
    for name, path in src_files:
        for bid, (fid, bname) in build_files.items():
            if bname == name and file_refs[fid][1] == path:
                out.append(f"\t\t\t\t{bid} /* {name} in Sources */,")
    out.append("\t\t\t);")
    out.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    out.append("\t\t};")

    out.append(f"\t\t{test_sources_build_phase_id} /* Sources */ = {{")
    out.append("\t\t\tisa = PBXSourcesBuildPhase;")
    out.append("\t\t\tbuildActionMask = 2147483647;")
    out.append("\t\t\tfiles = (")
    for name, path in test_files:
        for bid, (fid, bname) in build_files.items():
            if bname == name and file_refs[fid][1] == path:
                out.append(f"\t\t\t\t{bid} /* {name} in Sources */,")
    out.append("\t\t\t);")
    out.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    out.append("\t\t};")
    out.append("/* End PBXSourcesBuildPhase section */")

    # XCBuildConfiguration
    out.append("/* Begin XCBuildConfiguration section */")
    # Project configs
    out.append(f"\t\t{config_debug_proj} /* Debug */ = {{")
    out.append("\t\t\tisa = XCBuildConfiguration;")
    out.append("\t\t\tbuildSettings = {")
    out.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
    out.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
    out.append("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;")
    out.append("\t\t\t\tSDKROOT = macosx;")
    out.append("\t\t\t\tSWIFT_VERSION = 5.0;")
    out.append("\t\t\t};")
    out.append("\t\t\tname = Debug;")
    out.append("\t\t};")

    out.append(f"\t\t{config_release_proj} /* Release */ = {{")
    out.append("\t\t\tisa = XCBuildConfiguration;")
    out.append("\t\t\tbuildSettings = {")
    out.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
    out.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
    out.append("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 14.0;")
    out.append("\t\t\t\tSDKROOT = macosx;")
    out.append("\t\t\t\tSWIFT_VERSION = 5.0;")
    out.append("\t\t\t};")
    out.append("\t\t\tname = Release;")
    out.append("\t\t};")

    # App configs
    out.append(f"\t\t{config_debug_app} /* Debug */ = {{")
    out.append("\t\t\tisa = XCBuildConfiguration;")
    out.append("\t\t\tbuildSettings = {")
    out.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
    out.append("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
    out.append("\t\t\t\tINFOPLIST_FILE = PulseBar/Info.plist;")
    out.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.pulsebar.app;")
    out.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    out.append("\t\t\t\tSWIFT_VERSION = 5.0;")
    out.append("\t\t\t};")
    out.append("\t\t\tname = Debug;")
    out.append("\t\t};")

    out.append(f"\t\t{config_release_app} /* Release */ = {{")
    out.append("\t\t\tisa = XCBuildConfiguration;")
    out.append("\t\t\tbuildSettings = {")
    out.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
    out.append("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
    out.append("\t\t\t\tINFOPLIST_FILE = PulseBar/Info.plist;")
    out.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.pulsebar.app;")
    out.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    out.append("\t\t\t\tSWIFT_VERSION = 5.0;")
    out.append("\t\t\t};")
    out.append("\t\t\tname = Release;")
    out.append("\t\t};")

    # Test configs
    out.append(f"\t\t{config_debug_test} /* Debug */ = {{")
    out.append("\t\t\tisa = XCBuildConfiguration;")
    out.append("\t\t\tbuildSettings = {")
    out.append("\t\t\t\tBUNDLE_LOADER = \"$(TEST_HOST)\";")
    out.append("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
    out.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.pulsebar.app.tests;")
    out.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    out.append("\t\t\t\tSWIFT_VERSION = 5.0;")
    out.append("\t\t\t\tTEST_HOST = \"$(BUILT_PRODUCTS_DIR)/PulseBar.app/Contents/MacOS/PulseBar\";")
    out.append("\t\t\t};")
    out.append("\t\t\tname = Debug;")
    out.append("\t\t};")

    out.append(f"\t\t{config_release_test} /* Release */ = {{")
    out.append("\t\t\tisa = XCBuildConfiguration;")
    out.append("\t\t\tbuildSettings = {")
    out.append("\t\t\t\tBUNDLE_LOADER = \"$(TEST_HOST)\";")
    out.append("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
    out.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.pulsebar.app.tests;")
    out.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    out.append("\t\t\t\tSWIFT_VERSION = 5.0;")
    out.append("\t\t\t\tTEST_HOST = \"$(BUILT_PRODUCTS_DIR)/PulseBar.app/Contents/MacOS/PulseBar\";")
    out.append("\t\t\t};")
    out.append("\t\t\tname = Release;")
    out.append("\t\t};")
    out.append("/* End XCBuildConfiguration section */")

    # XCConfigurationList
    out.append("/* Begin XCConfigurationList section */")
    out.append(f"\t\t{config_list_proj} /* Build configuration list for PBXProject \"PulseBar\" */ = {{")
    out.append("\t\t\tisa = XCConfigurationList;")
    out.append("\t\t\tbuildConfigurations = (")
    out.append(f"\t\t\t\t{config_debug_proj} /* Debug */,")
    out.append(f"\t\t\t\t{config_release_proj} /* Release */,")
    out.append("\t\t\t);")
    out.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    out.append("\t\t\tdefaultConfigurationName = Release;")
    out.append("\t\t};")

    out.append(f"\t\t{config_list_app} /* Build configuration list for PBXNativeTarget \"PulseBar\" */ = {{")
    out.append("\t\t\tisa = XCConfigurationList;")
    out.append("\t\t\tbuildConfigurations = (")
    out.append(f"\t\t\t\t{config_debug_app} /* Debug */,")
    out.append(f"\t\t\t\t{config_release_app} /* Release */,")
    out.append("\t\t\t);")
    out.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    out.append("\t\t\tdefaultConfigurationName = Release;")
    out.append("\t\t};")

    out.append(f"\t\t{config_list_test} /* Build configuration list for PBXNativeTarget \"PulseBarTests\" */ = {{")
    out.append("\t\t\tisa = XCConfigurationList;")
    out.append("\t\t\tbuildConfigurations = (")
    out.append(f"\t\t\t\t{config_debug_test} /* Debug */,")
    out.append(f"\t\t\t\t{config_release_test} /* Release */,")
    out.append("\t\t\t);")
    out.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    out.append("\t\t\tdefaultConfigurationName = Release;")
    out.append("\t\t};")
    out.append("/* End XCConfigurationList section */")

    out.append("\t};")
    out.append(f"\trootObject = {proj_id} /* Project object */;")
    out.append("}")

    with open(pbx_path, "w") as f:
        f.write("\n".join(out) + "\n")
    print("PulseBar.xcodeproj created at", pbx_path)

if __name__ == "__main__":
    create_project()
