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
  local verbose=false

  while [ "$1" != "" ]; do
    case $1 in
      -v | --verbose )        verbose=true
                              ;;
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

  if [ $verbose == true ]; then
    echo "should_push: $should_push"
    echo "repository:  $repository"
    echo "dockerfile:  $dockerfile"
    echo "latest:      $latest"
  fi

  [[ -z "$repository" ]] && echo 'Please provide a --repository' && return
  [ ! -f $dockerfile ] && echo 'Coud not find '$dockerfile && return

  eval $(docker-machine env --unset)
  build_output=$(docker build -f $dockerfile .)
  image_tag=$(tail -n 1 <<< $build_output | sed s/Successfully\ built\ //)
  docker tag $image_tag $repository:$image_tag
  $latest && docker tag $image_tag $repository':latest'

  if [ $should_push == true ]; then
    if [ gcloud docker -- push $repository ]; then
      local_images=$(docker images -q $repository)
      old_images=$(printf "$local_images" | tail -n +4) # latest, t1, t2
      $verbose && echo "Hosekeeping! Will delete the following images: $old_images"
      if [ $(wc -w <<< "$old_images") -gt 0 ]; then
        docker rmi $(for tag in `echo $old_images`; do echo $repository':'$tag; done)
      fi
    fi
  fi
}
