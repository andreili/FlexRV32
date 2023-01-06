GTK_FLAGS = --rcfile=../gtkwaverc

all:
	make -C run -f ../Makefile.main GTK_FLAGS=$(GTK_FLAGS) $(MAKECMDGOALS)

tests_i:
	@echo "--- Start I tests ---"
	make -C run -f ../Makefile.tests_i.mak trace=1 GTK_FLAGS=$(GTK_FLAGS) $(MAKECMDGOALS)

tests_c:
	@echo "--- Start C tests ---"
	make -C run -f ../Makefile.tests_c.mak trace=1 GTK_FLAGS=$(GTK_FLAGS) $(MAKECMDGOALS)

tests: tests_i tests_c
