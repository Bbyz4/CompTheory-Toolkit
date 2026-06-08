CXX = g++
AR = ar
CXXFLAGS = -Wall -Wextra -O2 -I.

SRC = $(wildcard *.cpp)
OBJ = $(SRC:.cpp=.o)

LIB = libjudge.a

all: $(LIB)

$(LIB): $(OBJ)
	$(AR) rcs $@ $^

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f $(OBJ) $(LIB)
