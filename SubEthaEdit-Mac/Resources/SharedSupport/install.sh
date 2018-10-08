#!/usr/bin/env ruby
require 'FileUtils'
require 'io/console' # for getch

expandedInstallScriptPath = File.expand_path(__dir__)

appBundlePath = File.expand_path("../../..", __dir__)
appBundleContentsPath = File.join(appBundlePath, "Contents")

bundleID = %x[plutil -extract CFBundleIdentifier xml1 "#{File.join(appBundleContentsPath, "Info.plist")}" -o - | plutil -p -].strip.gsub(/\A"|"\z/, '')

userAppScriptsPath = File.expand_path File.join("~/Library/Application Scripts", bundleID)

seeToolName = "see"

absoluteSeeToolPath = File.expand_path(seeToolName, __dir__)
linkedSeeTargetPath = File.join("/usr/local/bin", seeToolName)

manPage = "#{seeToolName}.1"
absoluteManPagePath = File.expand_path(manPage, __dir__)
manPageTargetPath = File.join("/usr/local/share/man/man1/", manPage)

bold="\033[1m"
stopBold="\033[0m"

print <<HERE
'#{seeToolName}' tool will be linked at #{bold}"#{linkedSeeTargetPath}"#{stopBold} to #{appBundlePath}
'#{seeToolName}' man page be linked at #{bold}"#{manPageTargetPath}"#{stopBold} to #{appBundlePath}
"Authentication" and "Terminal Here" Apple Scripts will be copied to 
#{bold}"#{userAppScriptsPath}"#{stopBold}

#{bold}Continue?#{stopBold} (y/n) 
HERE

exit unless ['y','Y',"\r"].include?(STDIN.getch)

# link see tool
FileUtils.ln_s(absoluteSeeToolPath, linkedSeeTargetPath, force: true)
# link man page
FileUtils.ln_s(absoluteManPagePath, manPageTargetPath, force: true)

# copy user scripts (needed because of sandboxing)
FileUtils.mkdir_p(userAppScriptsPath)
FileUtils.cp([File.join(__dir__, "SubEthaEdit_AuthenticatedSave.scpt"),
			  File.join(appBundleContentsPath, "Resources/Scripts/40-Open Terminal Here.scpt")], userAppScriptsPath)


print "Done.\n"