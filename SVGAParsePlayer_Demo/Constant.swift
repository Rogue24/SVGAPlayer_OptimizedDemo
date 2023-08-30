//
//  Constant.swift
//  SVGAParsePlayer_Demo
//
//  Created by aa on 2023/8/23.
//

import Foundation

var cacheDirPath: String {
    NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory, .userDomainMask, true).first ?? ""
}

func cacheFilePath(_ fileName: String) -> String {
    cacheDirPath + "/" + fileName
}

let LocalSources = [
    "Goddess",
    "heartbeat",
    cacheFilePath("Rocket.svga"),
    cacheFilePath("Rose.svga"),
]

let RemoteSources = [
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/EmptyState.svga?raw=true",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/HamburgerArrow.svga?raw=true",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/PinJump.svga?raw=true",
    "https://github.com/svga/SVGA-Samples/raw/master/Rocket.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/TwitterHeart.svga?raw=true",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/Walkthrough.svga?raw=true",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/angel.svga?raw=true",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/halloween.svga?raw=true",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/kingset.svga?raw=true",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/posche.svga?raw=true",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/rose.svga?raw=true",
]
