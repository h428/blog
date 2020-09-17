#!/bin/bash

cd ..
git add .
git commit -m "update blog source"
git push origin master
cd ..
hexo clean && hexo g && hexo d
cd ./source/_posts/
