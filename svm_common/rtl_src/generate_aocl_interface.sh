rm -f *.aoclib *.aoco
for f in rtl_spec*.xml; do
  echo "Processing file $f"
  fh=$(echo $f | sed -e 's/rtl_spec/host_memory_bridge/g')
  fh=$(echo $fh | sed -e 's/xml/aoco/g')
  echo $fh
  aocl library hdl-comp-pkg $f -o $fh
done
