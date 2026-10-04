"""Generate a self-contained Xcode project without third-party project tools."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[1]
def uid(s):return hashlib.sha256(s.encode()).hexdigest()[:24].upper()
def q(s):return json.dumps(s)
objects={}
def obj(key,body):objects[uid(key)]=body;return uid(key)
def settings(d):return '{ '+''.join(f'{k} = {q(str(v))}; ' for k,v in d.items())+'}'
def array(items):return '('+','.join(items)+',)'
app='LifeIsLearned';test=app+'Tests'
source_build=[];resource_build=[];test_build=[]
app_groups=[]
for folder in ['','Models','Services','Views','Resources']:
 refs=[]
 paths=([root/app/'LifeIsLearnedApp.swift'] if folder=='' else sorted((root/app/folder).glob('*.swift')))
 if folder=='Resources':paths=[root/app/folder/'starter.json',root/app/folder/'Assets.xcassets']
 for p in paths:
  rel=p.relative_to(root).as_posix(); typ='sourcecode.swift' if p.suffix=='.swift' else ('folder.assetcatalog' if p.suffix=='.xcassets' else 'text.json')
  ref=obj('ref:'+rel,f'{{isa = PBXFileReference; lastKnownFileType = {typ}; path = {q(p.name)}; sourceTree = "<group>";}}')
  refs.append(ref)
  build=obj('build:'+rel,f'{{isa = PBXBuildFile; fileRef = {ref};}}')
  (source_build if p.suffix=='.swift' else resource_build).append(build)
 if folder:
  app_groups.append(obj('group:'+folder,f'{{isa = PBXGroup; children = {array(refs)}; path = {q(folder)}; sourceTree = "<group>";}}'))
 else:app_groups+=refs
app_group=obj('app-group',f'{{isa = PBXGroup; children = {array(app_groups)}; path = {q(app)}; sourceTree = "<group>";}}')
test_refs=[]
for p in sorted((root/'Tests').glob('*.swift')):
 rel=p.relative_to(root).as_posix()
 ref=obj('ref:'+rel,f'{{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(p.name)}; sourceTree = "<group>";}}');test_refs.append(ref)
 test_build.append(obj('build:'+rel,f'{{isa = PBXBuildFile; fileRef = {ref};}}'))
test_group=obj('test-group',f'{{isa = PBXGroup; children = {array(test_refs)}; path = Tests; sourceTree = "<group>";}}')
product=obj('app-product',f'{{isa = PBXFileReference; explicitFileType = wrapper.application; path = {app}.app; sourceTree = BUILT_PRODUCTS_DIR;}}')
test_product=obj('test-product',f'{{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = {test}.xctest; sourceTree = BUILT_PRODUCTS_DIR;}}')
products=obj('products',f'{{isa = PBXGroup; children = {array([product,test_product])}; name = Products; sourceTree = "<group>";}}')
main_group=obj('main-group',f'{{isa = PBXGroup; children = {array([app_group,test_group,products])}; sourceTree = "<group>";}}')
def phase(key,kind,files):return obj(key,f'{{isa = {kind}; buildActionMask = 2147483647; files = {array(files) if files else "()"}; runOnlyForDeploymentPostprocessing = 0;}}')
app_phases=[phase('app-sources','PBXSourcesBuildPhase',source_build),phase('app-frameworks','PBXFrameworksBuildPhase',[]),phase('app-resources','PBXResourcesBuildPhase',resource_build)]
test_phases=[phase('test-sources','PBXSourcesBuildPhase',test_build),phase('test-frameworks','PBXFrameworksBuildPhase',[]),phase('test-resources','PBXResourcesBuildPhase',[])]
base={'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SWIFT_VERSION':'5.0','SWIFT_STRICT_CONCURRENCY':'minimal','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES'}
app_base={'PRODUCT_BUNDLE_IDENTIFIER':'com.mariosinclair.lifeislearned','PRODUCT_NAME':'$(TARGET_NAME)','CODE_SIGN_STYLE':'Automatic','GENERATE_INFOPLIST_FILE':'YES','INFOPLIST_KEY_CFBundleDisplayName':'Life Is Learned','INFOPLIST_KEY_UILaunchScreen_Generation':'YES','INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES','INFOPLIST_KEY_LSRequiresIPhoneOS':'YES','TARGETED_DEVICE_FAMILY':'1,2','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SUPPORTS_MACCATALYST':'NO','MARKETING_VERSION':'1.0','CURRENT_PROJECT_VERSION':'1','SWIFT_EMIT_LOC_STRINGS':'YES','INFOPLIST_KEY_UISupportedInterfaceOrientations':'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight','INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad':'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight'}
test_base={'PRODUCT_BUNDLE_IDENTIFIER':'com.mariosinclair.lifeislearned.tests','PRODUCT_NAME':'$(TARGET_NAME)','CODE_SIGN_STYLE':'Automatic','GENERATE_INFOPLIST_FILE':'YES','TARGETED_DEVICE_FAMILY':'1,2','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','BUNDLE_LOADER':'$(TEST_HOST)','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/LifeIsLearned.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/LifeIsLearned'}
def configs(prefix,values):
 ids=[]
 for name in ['Debug','Release']:
  d=dict(values)
  if prefix=='project':
   d.update({'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if name=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf' if name=='Debug' else 'dwarf-with-dsym'})
   if name=='Debug': d['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG'
  ids.append(obj(prefix+name,f'{{isa = XCBuildConfiguration; buildSettings = {settings(d)}; name = {name};}}'))
 return obj(prefix+'configs',f'{{isa = XCConfigurationList; buildConfigurations = {array(ids)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;}}')
project_config=configs('project',base);app_config=configs('app',app_base);test_config=configs('test',test_base)
app_target=uid('app-target');project_id=uid('project')
proxy=obj('proxy',f'{{isa = PBXContainerItemProxy; containerPortal = {project_id}; proxyType = 1; remoteGlobalIDString = {app_target}; remoteInfo = {app};}}')
dependency=obj('dependency',f'{{isa = PBXTargetDependency; target = {app_target}; targetProxy = {proxy};}}')
obj('app-target',f'{{isa = PBXNativeTarget; buildConfigurationList = {app_config}; buildPhases = {array(app_phases)}; buildRules = (); dependencies = (); name = {app}; productName = {app}; productReference = {product}; productType = "com.apple.product-type.application";}}')
test_target=obj('test-target',f'{{isa = PBXNativeTarget; buildConfigurationList = {test_config}; buildPhases = {array(test_phases)}; buildRules = (); dependencies = {array([dependency])}; name = {test}; productName = {test}; productReference = {test_product}; productType = "com.apple.product-type.bundle.unit-test";}}')
obj('project',f'{{isa = PBXProject; attributes = {{LastUpgradeCheck = 1600; TargetAttributes = {{{app_target} = {{CreatedOnToolsVersion = 16.0;}}; {test_target} = {{CreatedOnToolsVersion = 16.0; TestTargetID = {app_target};}};}};}}; buildConfigurationList = {project_config}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base,); mainGroup = {main_group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = {array([app_target,test_target])};}}')
project=root/(app+'.xcodeproj');project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{\n archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+''.join(f'{key} = {value};\n' for key,value in objects.items())+'};\n rootObject = '+project_id+';\n}\n')
scheme=project/'xcshareddata/xcschemes'/f'{app}.xcscheme';scheme.parent.mkdir(parents=True,exist_ok=True)
def ref(target,name,product):return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:{app}.xcodeproj"/>'
app_ref=ref(app_target,app,app+'.app');test_ref=ref(test_target,test,test+'.xctest')
scheme.write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_ref}</BuildActionEntry>
<BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="YES">{test_ref}</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{test_ref}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print(f'Project generated: {len(source_build)} Swift source files, {len(test_build)} test files, {len(objects)} objects.')
