#!/bin/bash
clang -S -emit-llvm rdpmc.cpp
clang -S -emit-llvm rdmsr.cpp
