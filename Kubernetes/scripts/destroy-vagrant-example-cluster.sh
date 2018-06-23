#!/bin/bash

for i in 3 2 1; do
    (
        cd clusters/example/node0$i
        vagrant destroy -f
    )
done

