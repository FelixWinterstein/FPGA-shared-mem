LIBNAME=custom_library
aocl library create -name $LIBNAME -vendor Imperial -version 1.0 *.aoco
aocl library list ${LIBNAME}.aoclib
