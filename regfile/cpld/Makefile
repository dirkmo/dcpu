XTOOLS=/opt/Xilinx/14.7/ISE_DS/ISE/bin/lin64
DEVICE=xc95144xl-TQ100-10 
DEVICE_FIT=xc95144xl-10-TQ100
MODNAME=Regfile

all:
	mkdir -p xst/projnav.tmp
	@echo Synthesis
	$(XTOOLS)/xst -intstyle ise -ifn "$(MODNAME).xst" -ofn "$(MODNAME).syr"
	@echo "#######################################################"
	$(XTOOLS)/ngdbuild -intstyle ise -dd _ngo -i -p $(DEVICE) $(MODNAME).ngc $(MODNAME).ngd
	@echo "#######################################################"
	@echo Fitting
	$(XTOOLS)/cpldfit -intstyle ise -p $(DEVICE_FIT) -ofmt vhdl -optimize speed -htmlrpt -loc on -slew fast -init low -inputs 54 -pterms 25 -unused float -power std -terminate keeper $(MODNAME).ngd
	@echo "#######################################################"
	@echo Running tsim...
	$(XTOOLS)/tsim -intstyle ise $(MODNAME) $(MODNAME).nga


clean:
	rm -rf iseconfig _ngo xlnx_auto_0_xdb _xmsgs xst $(MODNAME)_html
	rm -f $(MODNAME).bld $(MODNAME)_build.xml $(MODNAME).cmd_log $(MODNAME)_envsettings.html $(MODNAME).gyd $(MODNAME).lso $(MODNAME).mfd $(MODNAME).nga $(MODNAME).ngc $(MODNAME).ngd $(MODNAME)_ngdbuild.xrpt $(MODNAME).ngr $(MODNAME).pad $(MODNAME)_pad.csv $(MODNAME).pnx $(MODNAME).rpt $(MODNAME).stx $(MODNAME)_summary.html $(MODNAME).syr $(MODNAME).tim $(MODNAME).tspec $(MODNAME).vm6 $(MODNAME).xml $(MODNAME)_xst.xrpt webtalk_pn.xml
