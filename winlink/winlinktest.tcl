lappend auto_path .
package require winlink
winlink::link set foo.lnk -path {C:\My Documents} \
    -desc "My documents link"
array set foo [winlink::link get foo.lnk]
parray foo

puts "clearing recent and adding link to winlink.htm"
winlink::link recent -clear
winlink::link recent [file native [file normalize winlink.htm]]

puts "path user (common)"
foreach p [winlink::link path] {
    set user [winlink::link path $p]
    set common [winlink::link path -common $p]
    puts "$p $user"
    if { "$user" != "$common" } { puts "\t$common" }
}
puts "path by id: startmenu [winlink::link path 0x07]"
