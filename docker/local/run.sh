#!/bin/bash

# Get trustedpath docker network id
NET_ID=`docker network ls -f name="trustedpath" --format {{.ID}}`

docker run -p 14200:14200 -p 14201:14201 -p 15000:15000 -p 15001:15001 -p 15306:15306 \
    -p 15991:15991 -p 15999:15999 -p 16000:16000 --network $NET_ID \
    --name vitess --rm -it vitess/local
