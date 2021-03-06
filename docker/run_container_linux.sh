#!/bin/bash
#Copyright (C) 2018 Intel Corporation
#
#SPDX-License-Identifier: Apache-2.0

export HADOOP_USER=hadoop
export DJANGO_USER=django
export HADOOP_UID=$(id -u $HADOOP_USER)
export DJANGO_UID=$(id -u $DJANGO_USER)
export HADOOP_DIR=/home/$HADOOP_USER/docker
export WEB_DIR=/home/$DJANGO_USER/myml

export mlversion=0.1.1 
export mongoversion=3.6.4 
# default repo from Docker
export DOCKER_REPO=eyyang
export logged_in=0

# check if setup script completed
if [ $( ls /home | grep -w 'django\|hadoop' | wc -l) -lt 2 ]; then
    echo "ERROR: Please execute setup script first!"        
    exit -1
fi

# DOCKER_REPO for internal server inside proxy
if ! [ -z $DOCKER_REG ]; then
    export DOCKER_REPO=$DOCKER_REG/myml
    logged_in=$(cat ~/.docker/config.json | grep  "$DOCKER_REG"  | wc -l)
else
    # for Docker hub
    logged_in=$(cat ~/.docker/config.json | grep  'https://index.docker.io'  | wc -l)
fi
export MLAAS_IMG=$DOCKER_REPO/mlservice
export MONGO_IMG=$DOCKER_REPO/mongo
container=$1

# Check login docker reg
if [ $logged_in -ge 1 ]; then
    echo "INFO: Docker login/auth Found!" 
else
    echo "ERROR: Login to Docker hub is required!! ret="$logged_in
    echo '       Please run "docker login" or "docker login <your Docker registry server>"'
    exit -1    
fi

# network bridge
if [ ! "$(docker network ls | grep hadoop)" ]; then
    echo "INFO: Creating network bridge hadoop ... ****"
    docker network create --driver bridge hadoop
else
    echo "INFO: Network bridge hadoop exists."
fi

# hdfs & spark  slave1 
if [ -z $container ] || [ "$container" == "slave1" ]; then
    cntr=$(docker ps -a | grep slave1 | awk '{print $1}') 
    if ! [ -z $cntr ]; then
        echo "INFO: Remove container slave1"
        docker stop $cntr
        docker rm $cntr
    fi
    echo "INFO: *** Start container slave1 **********************************************"
    docker run -v $HADOOP_DIR/hadoopdata1:/home/hadoop/hadoopdata \
        -v $HADOOP_DIR/hadoop_conf1:/home/hadoop/hadoop_latest/etc/hadoop \
        -v $HADOOP_DIR/spark_conf1:/home/hadoop/spark_latest/conf \
        --network hadoop --name slave1 --hostname slave1 \
        -p 50075:50075 -e HOST_DJANGO_UID=$DJANGO_UID -e HOST_HADOOP_UID=$HADOOP_UID \
        -d -it $MLAAS_IMG:$mlversion 
fi
        
# hdfs & spark  master    
if [ -z $container ] || [ "$container" == "master" ]; then
    cntr=$(docker ps -a | grep master | awk '{print $1}') 
    if ! [ -z $cntr ]; then
        echo "INFO: Remove container master"
        docker stop $cntr
        docker rm $cntr
    fi
    echo "INFO: *** Start container master **********************************************"
    docker run -v $HADOOP_DIR//hadoopdata:/home/hadoop/hadoopdata \
        -v $HADOOP_DIR/hadoop_conf:/home/hadoop/hadoop_latest/etc/hadoop \
        -v $HADOOP_DIR/spark_conf:/home/hadoop/spark_latest/conf \
        --network hadoop --name master --hostname master \
        -p 9000:9000 -p 7077:7077 -p 8080:8080 -p 8088:8088 -p 8081:8081 -p 50070:50070 \
        -e HOST_DJANGO_UID=$DJANGO_UID -e HOST_HADOOP_UID=$HADOOP_UID \
        -d -it $MLAAS_IMG:$mlversion 
fi

# mongodb
if [ -z $container ] || [ "$container" == "mongodb" ]; then
    cntr=$(docker ps -a | grep mongodb | awk '{print $1}') 
    if ! [ -z $cntr ]; then
        echo "INFO: Remove container mongodb"
        docker stop $cntr
        docker rm $cntr
    fi
    echo "INFO: *** Start container mongodb **********************************************"
    docker run -v $HADOOP_DIR/mongo/data:/data/db \
        -v $HADOOP_DIR/mongo/backups:/backups \
        --name mongodb --network hadoop -p 27017:27017 \
        -d -it $MONGO_IMG:$mongoversion  
fi


# web
if [ -z $container ] || [ "$container" == "web" ]; then
    cntr=$(docker ps -a | grep web | awk '{print $1}') 
    if ! [ -z $cntr ]; then
        echo "INFO: Remove container web"
        docker stop $cntr
        docker rm $cntr
    fi
    echo "INFO: *** Start container web **************************************************"
    docker run -v $HADOOP_DIR/hadoop_conf1:/home/hadoop/hadoop_latest/etc/hadoop \
        -v $HADOOP_DIR/spark_conf1:/home/hadoop/spark_latest/conf \
        -v $WEB_DIR:/home/django/myml \
        --network hadoop --name web --hostname web \
        -p 8000:8000 -e HOST_DJANGO_UID=$DJANGO_UID -e HOST_HADOOP_UID=$HADOOP_UID \
        -it $MLAAS_IMG:$mlversion
fi
# docker rm $(docker ps -a | grep slave1 | awk '{print $1}')
# docker rm $(docker ps -a | grep master | awk '{print $1}')
# docker rm $(docker ps -a | grep mongodb | awk '{print $1}')
# docker rm $(docker ps -a | grep web | awk '{print $1}')







