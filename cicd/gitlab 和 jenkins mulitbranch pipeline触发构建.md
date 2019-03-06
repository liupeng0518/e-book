---
title: gitlab 和 jenkins mulitbranch pipeline触发构建
date: 2019-03-05 09:47:19
categories: cicd
tags: [cicd, jenkins]

---

jenkins的多分支pipeline构建中，是无法在设置界面设置触发方式等配置，那么可以写在Jenkinsfile里：

```
    pipeline {
        agent {
            node {
                ...
            }
        }
        options {
            gitLabConnection('GitLab')
        }
        triggers {
            gitlab(
                triggerOnPush: true,
                triggerOnMergeRequest: true,
                branchFilterType: 'All',
                addVoteOnMergeRequest: true)
        }
        stages {
            ...
        }
    }

```
然后需要在gitlab中配置webhook，Settings -> Integrations ，如下格式：
- http://JENKINS_URL/project/PROJECT_NAME
- http://JENKINS_URL/project/FOLDER/PROJECT_NAME

参考：

https://github.com/jenkinsci/gitlab-plugin#job-trigger-configuration

https://github.com/jenkinsci/kubernetes-plugin

https://stackoverflow.com/questions/52148634/how-to-add-webhooks-in-gitlab-for-multibranch-pipeline-jenkins
