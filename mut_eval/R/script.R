data = rbbt.ruby("
require 'rbbt/workflow'

Workflow.require_workflow 'MutEval'

Log.severity = 0
MutEval.job(:features, 'R', :dataset => 'humvar').clean.run
")

library('randomForest')

names(data) <- make.names(names(data))

data[data == '?' ] = NA

rf.score <- randomForest(as.factor(Pathogenic) ~ Mutation.Assessor.FI.Score + Polyphen2.Score + SIFT.Score, data = data, na.action=na.omit)

rf.pred <- randomForest(as.factor(Pathogenic) ~ Mutation.Assessor.Prediction + Polyphen2.Prediction + SIFT.Prediction, data = data, na.action=na.omit)



