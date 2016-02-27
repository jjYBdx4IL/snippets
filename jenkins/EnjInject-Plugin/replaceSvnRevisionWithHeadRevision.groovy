// replace SVN_REVISION build env var with head svn revision instead of last mod svn rev
// using https://wiki.jenkins-ci.org/display/JENKINS/EnvInject+Plugin

// this currently fails because jenkins uses a too old on-disk svn layout
// (svn info complains about it if you use svn 1.8+, as of early 2016)

def pSvn = ["svn", "info", currentBuild.getWorkspace()].execute()

out.println "1"

def sout = new StringBuffer()
out.println "2"
pSvn.waitForProcessOutput(sout, out)        
out.println "3"
def currentTags = sout.toString().trim()
out.println currentTags
def mt = currentTags =~ /Revision\:\s+(\d+)/
out.println "4"

out.println mt[0][1] 

def map = [SVN_REVISION: mt[0][1]]
out.println "5"
return map
