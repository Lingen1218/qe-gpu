what:
	@echo 'First step:'
	@echo './configure "your-system"'
	@echo './configure with no arguments gives a list of supported systems'
	@echo 'Then: Edit the file make.sys , if necessary'
	@echo 'Then: make "task", where task is one of the following:'
	@echo '   pw        (basic code for scf, struct. optimization, MD)'
	@echo '   nc        (non collinear magnetic version of pw code)'
	@echo '   pp        (postprocessing programs)'
	@echo '   ph        (phonon code)'
	@echo '   d3        (third-order derivatives)'
	@echo '   pwcond    (ballistic conductance)'
	@echo '   gamma     (Gamma-only version of pw and ph)'
	@echo '   pwneb     (basic code for scf, struct. optimization, MD and NEB)'
	@echo '   upf       (utilities for pseudopotential conversion)'
	@echo '   tools     (misc tools for data analysis)'
	@echo '   tar       (create a tar file containing the distribution)'
	@echo '   clean     (remove executables and objects)'
	@echo '   veryclean (revert distribution to the original status)'
	@echo '   fpmd      (FPMD code for Car-Parrinello MD)'
	@echo '   cp        (CP code: CP MD with ultrasoft pseudopotentials)'
	@echo '   links     (creates links to executables in bin/)'

nc: pw
	( cd PWNC;  make all )

all: d3 pp pwcond gamma tools

tools: libs
	( cd pwtools ; make all )

upf: libs
	( cd upftools ; make all )

gamma: pw
	( cd Gamma; make all )

pwneb: pw
	( cd NEB; make all )

d3: ph
	( cd D3; make all )

ph: pw
	( cd PH; make all )

pp: pw
	( cd PP; make all )

pwcond: pp
	( cd PWCOND; make all )

pw: modules libs
	( cd PW; make all )

modules:
	( cd Modules; make all )

libs: modules
	( cd clib; make all ); ( cd flib; make all );

fpmd: modules libs
	( cd FPMD; make all )

cp: modules libs
	( cd CPV; make all )

links:
	test -d bin || mkdir bin
	( cd bin/ ; ln -fs ../PW/pw.x ../PW/memory.x ../NEB/pwneb.x ../PH/ph.x ../D3/d3.x ../Gamma/pwg.x ../Gamma/phcg.x ../CPV/cp.x ../FPMD/par2.x ../PP/average.x ../PP/bands.x ../PP/chdens.x ../PP/dos.x ../PP/plotrho.x ../PP/pp.x ../PP/projwfc.x ../PP/voronoy.x ../PP/plotband.x ../PWCOND/pwcond.x ../pwtools/band_plot.x ../pwtools/dynmat.x ../pwtools/fqha.x ../pwtools/matdyn.x ../pwtools/q2r.x ../pwtools/dist.x ../pwtools/ev.x ../pwtools/kpoints.x . )

clean:
	( cd PW ; make clean_ ) ; \
	( cd PWNC ; make clean_ ) ; \
	( cd PH ; make clean_ ) ; \
	( cd PP ; make clean_ ) ; \
	( cd D3 ; make clean_ ) ; \
	( cd PWCOND ; make clean_ ) ; \
	( cd Gamma ; make clean_ ) ; \
	( cd NEB ; make clean_ ) ; \
	( cd pwtools ; make clean_ ) ; \
	( cd upftools ; make clean_ ) ; \
        ( cd Modules ; make clean_ ) ; \
        ( cd install ; make clean_ ) ; \
	( cd clib ; make clean_ ) ; \
	( cd flib ; make clean_ ) ; \
	( cd FPMD ; make clean_ ) ; \
	( cd CPV ; make clean_ ) ;
# this avoids an infinite loop if one of the directories is missing
clean_:

veryclean: clean
	- /bin/rm -f make.rules make.sys */.dependencies config.log \
	             config.status */dum1 */dum2 bin/*

# build list of files to archive and pass it to tar
# don't archive CVS directories
# use xargs because arguments list may exceed the shell's limits
# must use tar rvf, NOT cvf because xargs may call tar multiple times
# for the same reason can't pipe directly to gzip
tar:
	rm -f pw.tar pw.tar.gz
	find License README */README INSTALL configure \
	     makedeps.sh moduledep.sh Makefile */Makefile Makefile.neb NEB/make.dep \
	     configure.new configure.ac config.guess config.sub \
	     install-sh make.rules.in make.sys.in \
	     */*.f90 */*.c */*.f clib/*.h include/*.h* \
	     install upftools *docs *_examples pseudo \
	     -type f | \
	grep -v /CVS/ | xargs tar rvf pw.tar
	gzip pw.tar

