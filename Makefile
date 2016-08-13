GRAPHS=*.gv
PNGS=$(patsubst %.gv,%.png,$(wildcard *.gv))

all: $(PNGS) prereq_mix.png

# translation into png

prereq_mix.png: prereq_mix.txt gnu.plt
	./gnu.plt

%.png: %.gv
	dot -Tpng $< -o $@

clean:
	rm -f $(PNGS)
	rm -f $(GRAPHS)
	rm prereq_mix.png

