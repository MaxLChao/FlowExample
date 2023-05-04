# blog.R example
# let's load in our libraries in. 
# Here are some that I use:
libs = c('skitools', 'Flow', 'tidyverse', 'data.table', 'pbmcapply')
suppressMessages(
  suppressWarnings(sapply(libs, require, character.only = TRUE))
)

# Set our Flow directory together
flowdir = normalizePath("./Flow")

# load in our pairs
pairs = readRDS("db/pairs.rds")

# Set up HetPileup
Flow::task("~/tasks/hg19/core_dryclean/HetPileups.task")
## alter the pairs table to match the descriptions


het.jb = Job('~/tasks/hg19/core_dryclean/HetPileups.task', 
             pairs, 
             mem = 36, 
             cores = 4, 
             rootdir = flowdir, 
             update_cores = 50)

# if you're more curious on what goes into Flow::Job()
?Flow::Job()

# once ready run
srun(het.jb)
update(het.jb)
# next Strelka
# ~/tasks/hg19/core_dryclean/Strelka2.task

# Here we have a set of PONS that we can use, there is a default one provided
# but this one below is the most up to date
pairs = pairs %>%
  dplyr::mutate(dryclean_pon = "~/data/dryclean/MONSTER_PON_RAW/MONSTER_PON_RAW_SORTED/fixed.detergent.rds"
                ) %>% setkey('pair')

Flow::Task("~/tasks/hg19/core_dryclean/Strelka2.task")
# Create your job
#Job()
# srun()

# Svaba
# ~/tasks/hg19/core_dryclean/Svaba.task
Flow::Task("~/tasks/hg19/core_dryclean/Svaba.task")
# Create your job
#Job()
# srun()


# fragcounter
Flow::Task("~/tasks/hg19/core_dryclean/fragCounter.task")
# Create your job
#Job()
# srun()

# fragcounter normal
Flow::Task("~/tasks/hg19/core_dryclean/fragCounter.normal.task")
# Create your job
#Job()
# srun()

# can create a list of these jobs post srun I.E.:
# bam.jbs = list(Strelka = strelka.jb, Svaba = svaba.jb, 
#      FragTumor = frag.t.jb, FragNormal = frag.n.jb, 
#      Hets = het.jb)

## Then we can check on them via this list or separately:
# lapply(bam.jbs, function(x){
#   Flow::update(x, mc.cores =50)
# })

# single job check up
# Flow::update(het.jb)

# if all jobs are completed and good to go post finished runs:
# outs.bams = lapply(bam.jbs, function(x){
#   outputs(x)
# })
# outs.bams = outs.bams %>% purrr::reduce(merge)
# pairs = merge(pairs, outs.bams)
# setDT(pairs); setkey(pairs, 'pair')

## Here we should save the files:
staveRDS(pairs, "db/pairs.rds", note = "DATE HERE. Any note about job outputs added.")

##### POST BAM JOBS ######
# past step 1. Nice!


### Set up dryclean on tumor normal
# pairs = pairs %>%
#   dplyr::mutate(dryclean_pon = "~/data/dryclean/MONSTER_PON_RAW/MONSTER_PON_RAW_SORTED/fixed.detergent.rds",
#                 field = "reads.corrected") %>% setkey('pair')

#tumor and normal
dc.t.jb = Job('~/tasks/hg19/core_dryclean/Dryclean.task', pairs, rootdir = flowdir, 
              mem = 64, cores = 1, update_cores = 100, time = '1-00')
dc.n.jb = Job('~/tasks/hg19/core_dryclean/Dryclean.normal.task', pairs, 
              rootdir = flowdir, mem = 64, cores = 1, update_cores = 100, time = '1-00')

srun(dc.t.jb)
srun(dc.n.jb)

# MERGE the outputs back into pairs
# pairs = merge()

## CBS
# cbs.inp = pairs %>%
#   mutate(field = "foreground",
#          mask = "~/projects/gGnome/files/zc_stash/maskA_re.rds") %>%
#   setkey('pair')
# 
# cbs.jb = Job('~/tasks/hg19/core_dryclean/CBS.task', cbs.inp, rootdir = flowdir, mem = 16, 
#              cores = 1, update_cores = 100, time = '0-12')
# srun(cbs.jb)


### JabBa ###
# post all of this:
# you are ready to run JaBbA

jab.fin = pairs %>% 
  mutate(blacklist.coverage = "~/projects/gGnome/files/zc_stash/maskA_re.rds") %>%
  data.table %>% setkey('pair')

Jab.jb = Job(task = "~/tasks/JaBbA_ZC_dev.task", jab.fin,
    rootdir = flowdir,
    mem = 64, cores = 8, 
    update_cores = 100,
    time = '3-00')

srun(Jab.jb)
#update(Jab.jb, mc.cores = 100)

# MERGE
#i.e. pairs = merge(pairs, Jab.jb@outputs)

### Post JaBbA jobs ###
# check task and make sure it matches
events.jb = Job("~/tasks/Events.task",
                pairs, 
                rootdir = flowdir, 
                mem = 48, cores = 8,
                update_cores = 100,
                time = '3-00')
srun(events.jb)
# pairs = merge()
# staveRDS()

## Visualizing one of the outputs
# events = readRDS(pairs$complex[[1]])
library(gGnome)
# pick an event and plot

