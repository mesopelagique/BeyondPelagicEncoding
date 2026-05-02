//%attributes = {}

var $options : Object:={}
$options.targets:=["arm64_macOS_lib"]

var $result : Object:=Compile project($options)
$result:=$result