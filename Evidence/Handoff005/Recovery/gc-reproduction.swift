import Foundation
let fm=FileManager.default
let root=fm.temporaryDirectory.appendingPathComponent("LIL-Recovery-Repro-"+UUID().uuidString)
let actual=root.appendingPathComponent("actual-long-documents")
let alias=root.appendingPathComponent("docs")
try fm.createDirectory(at:actual.appendingPathComponent("Packages/book"),withIntermediateDirectories:true)
try fm.createSymbolicLink(at:alias,withDestinationURL:actual)
let packages=alias.appendingPathComponent("Packages")
let payload=packages.appendingPathComponent("book/installed.json")
try Data("synthetic installed payload".utf8).write(to:payload)
let referenced:Set<String>=["Packages/book/installed.json"]
let enumerator=fm.enumerator(at:packages,includingPropertiesForKeys:[.isRegularFileKey])!
var report:[String:Any]=["fixture":"synthetic temporary directory only","installedExistsBefore":fm.fileExists(atPath:payload.path)]
for case let url as URL in enumerator {
 guard try url.resourceValues(forKeys:[.isRegularFileKey]).isRegularFile == true else {continue}
 let relative="Packages/"+url.path.dropFirst(packages.path.count+1)
 report["oldRelativePathMatched"]=referenced.contains(relative)
 report["canonicalURLMatched"]=url.standardizedFileURL.resolvingSymlinksInPath()==payload.standardizedFileURL.resolvingSymlinksInPath()
 if !referenced.contains(relative) {try fm.removeItem(at:url)}
}
report["installedExistsAfterOldCollector"]=fm.fileExists(atPath:payload.path)
print(String(data:try JSONSerialization.data(withJSONObject:report,options:[.sortedKeys,.prettyPrinted]),encoding:.utf8)!)
try fm.removeItem(at:root)
