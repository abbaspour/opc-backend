#!/bin/bash

gsed -e 's|"/repository"|"repository"|' -i repository.yml
gsed -e 's/+}:/}:/' -i repository.yml
