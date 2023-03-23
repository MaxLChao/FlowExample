# blog.R example
# let's load in our libraries in. 
# Here are some that I use:
libs = c('skitools', 'Flow', 'tidyverse', 'data.table', 'pbmcapply')
suppressMessages(
  suppressWarnings(sapply(libs, require, character.only = TRUE))
)

# Set our environment together
flowdir = normalizePath("./Flow")

# load in our pairs
pairs = readRDS("db/pairs.rds")

# Set up HetPileup
Flow::task("~/tasks/hg19/core/HetPileups.task")
## alter the pairs table to match the descriptions

# run the job
het.jb = Job('~/tasks/hg19/core/HetPileups.task', 
             pairs, 
             mem = 36, cores = 4, 
             rootdir = flowdir, 
             update_cores = 50)

# if you're more curious on what goes into Flow::Job()
?Flow::Job()

# once ready run
srun(het.jb)
update(het.jb)
# next Strelka
# ~/tasks/hg19/core/Strelka2.task
Flow::Task("~/tasks/hg19/core/Strelka2.task")
# Create your job
#Job()
# srun()

# Svaba
# ~/tasks/hg19/core/Svaba.task
Flow::Task("~/tasks/hg19/core/Svaba.task")
# Create your job
#Job()
# srun()


# fragcounter
Flow::Task("~/tasks/hg19/core/fragCounter.task")
# Create your job
#Job()
# srun()

# fragcounter normal
Flow::Task("~/tasks/hg19/core/fragCounter.normal.task")
# Create your job
#Job()
# srun()

# can create a list of these jobs post srun
# bam.jbs = list(Strelka = strelka.jb, Svaba = svaba.jb, 
#      FragTumor = frag.t.jb, FragNormal = frag.n.jb, 
#      Hets = het.jb)

## can check on them via this list or separately:
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
# pairs_tab = merge(pairs, outs.bams)
# setDT(pairs_tab); setkey(pairs_tab, 'pair')


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
# cbs.ent = pairs %>%
#   mutate(field = "foreground",
#          mask = "~/projects/gGnome/files/zc_stash/maskA_re.rds") %>%
#   setkey('pair')
# 
# cbs.jb = Job('~/mc_tasks/CBS_mc.task', cbs.ent, rootdir = flowdir, mem = 16, 
#              cores = 1, update_cores = 100, time = '0-12')

srun(cbs.jb)


### JabBa ###
# post all of this you are ready to run JaBbA

jab.fin = pairs %>% 
  mutate(maxna = 0.8, epgap = 1e-6, tilim = 6000, slack = 100, 
         iter = 1, field = 'foreground', 
         lp = T, ism = T,
         blacklist.coverage = "~/projects/gGnome/files/zc_stash/maskA_re.rds") %>%
  select(., -c(cbs_cov_rds,)) %>%
  dplyr::rename(cbs_cov_rds = tumor_dryclean_cov) %>%
  dplyr::rename(cov_rds = cbs_cov_rds, 
                junctionFilePath = svaba_somatic_vcf) %>%
  mutate(iter = 2, flags = "--rescue.window 10000 --rescue.all TRUE") %>%
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
#pairs = merge()
#

## Visualizing one of the outputs

# events = readRDS(pairs$complex[[1]])
library(gGnome)
# pick an event and plot

