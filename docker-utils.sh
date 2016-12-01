#!/bin/bash

function docker-connect () {
  eval $(docker-machine env $1)
}

function docker-unset () {
  eval $(docker-machine env --unset)
}

function docker-cleanup () {
  docker rm `docker ps -aq`
  docker rmi `docker images -qf 'dangling=true'`
}

function docker-build () {
  local should_push=false
  local repository=
  local dockerfile=Dockerfile.prod
  local latest=true

  while [ "$1" != "" ]; do
    case $1 in
      -p | --push )           should_push=true
                              ;;
      --no-latest )           latest=false
                              ;;                              
      -r | --repository )     shift
                              repository=$1
                              ;;
      -f | --dockerfile )     shift
                              dockerfile=$1
                              ;;
    esac
    shift
  done

  # echo $should_push
  # echo $repository
  # echo $dockerfile
  # echo $latest

  [[ -z "$repository" ]] && echo 'Please provide a --repository' && return

  eval $(docker-machine env --unset)
  echo ============== BUILD ==============
  docker build -f $dockerfile .
  echo =============== TAG ===============
  image_tag=`docker images -q 2>&1 | head -n1` # "TODO: parse 'Successfully built 33342a7f50e8'"
  docker tag $image_tag $repository:$image_tag
  $latest && docker tag $image_tag $repository':latest'

  if [ $should_push == true ]
  then
  echo ============== PUSH ===============

    if gcloud docker -- push $repository
    then
      local_images=$(docker images -q $repository)
      old_images=$(printf "$local_images" | tail -n +4) # latest, t1, t2
      if [ $(wc -w <<< "$old_images") -gt 0 ]
      then
        docker rmi $(for tag in `echo $old_images`; do echo $repository':'$tag; done)
      fi
    fi

  fi
}

