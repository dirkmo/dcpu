cmake_minimum_required(VERSION 3.12)
cmake_policy(SET CMP0074 NEW)
project(dcpu-simulator)

find_package(verilator HINTS $ENV{VERILATOR_ROOT} ${VERILATOR_ROOT})
if (NOT verilator_FOUND)
  message(FATAL_ERROR "Verilator was not found. Either install it, or set the VERILATOR_ROOT environment variable")
endif()

find_package(Curses REQUIRED)
include_directories(${CURSES_INCLUDE_DIR})

# Create a new executable target that will contain all your sources
add_executable(simulator sim.cpp dcpu.cpp)


# Add the Verilated circuit to the target
verilate(simulator TRACE # COVERAGE
INCLUDE_DIRS "../rtl" "../sim"
VERILATOR_ARGS "+define+SIM=1"
SOURCES ../rtl/dcpu.v)

target_link_libraries(simulator PUBLIC ${CURSES_LIBRARIES})

add_custom_target(assemble
    COMMAND ${PROJECT_SOURCE_DIR}/../dasm/dasm.py -i ${PROJECT_SOURCE_DIR}/forth.asm -o ${PROJECT_SOURCE_DIR}/forth
)

add_custom_target(simulate
    COMMAND ${PROJECT_BINARY_DIR}/simulator ${PROJECT_SOURCE_DIR}/forth.bin ${PROJECT_SOURCE_DIR}/forth.sim
    DEPENDS assemble
    DEPENDS simulator
    COMMENT "Executing simulation..."
)

#add_custom_target(wave
#    COMMAND gtkwave ${PROJECT_SOURCE_DIR}/sim.gtkw
#    DEPENDS sim
#)
