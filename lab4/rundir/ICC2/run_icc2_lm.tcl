exec date >> timer

# read lib
set clib_name "tsmc65"
set home "/home/linux/ieng6/ee260bwi20/public/data/libraries"
set lib "$home/db/tcbn65gpluswc.db"
set techfile "$home/techfiles/tsmcn65_8lmT2.tf"
set lef "$home/techfiles/tcbn65gplus_8lmT2.lef"

if {[file exists "ndm"]} {
	exec rm -r ndm
}
exec mkdir ndm

create_workspace -technology $techfile -scale_factor 10000 -flow "normal" ${clib_name}

read_lef $lef
read_db $lib

check_workspace
commit_workspace -force -output ndm/${clib_name}.ndm

exec date >> timer

exit

