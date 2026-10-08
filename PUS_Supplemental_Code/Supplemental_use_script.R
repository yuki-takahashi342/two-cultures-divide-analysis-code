# Supplemental tables for the PUS manuscript. No individual records are exported.
# Run: Rscript Supplemental_use_script.R --project-root=/path/to/project --output-dir=/path/to/output
# Shares the main functions in ../R_scripts/Final_use_script.R.
source_files <- unlist(lapply(sys.frames(), function(x) x$ofile), use.names = FALSE)
self <- if (length(source_files)) tail(source_files, 1L) else
  sub("^--file=", "", commandArgs()[startsWith(commandArgs(), "--file=")])
if (length(self) != 1L) stop("Run this file with Rscript or source().")
script_dir <- dirname(normalizePath(self, mustWork = TRUE))
args <- if (length(source_files)) character() else commandArgs(trailingOnly = TRUE)
arg <- function(flag, default = NULL) {
  z <- args[startsWith(args, paste0(flag, "="))]
  if (length(z) > 1L) stop("Duplicate option: ", flag)
  if (length(z)) substring(z[1], nchar(flag) + 2) else default
}
if (any(!grepl("^--(project-root|output-dir|input|encoding)=", args))) stop("Unknown option.")
base <- file.path(dirname(script_dir), "R_scripts", "Final_use_script.R")
source(base)
root <- arg("--project-root", find_project_root(script_dir))
out <- arg("--output-dir", file.path(root, "output", "supplemental"))
check_packages()
survey <- read_survey(root, arg("--input"), arg("--encoding", "auto"))
input <- survey$file
raw <- survey$data
dir.create(out, recursive = TRUE, showWarnings = FALSE)
fa <- add_factor_scores(prepare_data(raw))
lca <- fit_lca(fa$data)
reg <- fit_regression(lca$data)
x <- lca$data
N <- nrow(x)
write <- function(d,name) write.csv(d,file.path(out,paste0(name,".csv")),row.names=FALSE,na="")
write(lca$indices,"S5_fit_indices")
write(lca$original,"S5_fit_indices_before_continuation")
write(reg$ame,"S8_average_marginal_effects")

flow <- data.frame(stage=c("Delivered survey records","Complete substantive Q7 items","Complete Q14 indicators and LCA","Gender nonresponse excluded from regression","Multinomial regression"),
  n=c(N,sum(complete.cases(x[paste0("q7_",setdiff(1:10,4))])),sum(!is.na(x$lca_class)),sum(is.na(x$gender)),reg$n))
write(flow,"S1_sample_flow")
categorical <- do.call(rbind,lapply(c("gender","edu_major_f","job4"),function(v){
  z<-table(x[[v]],useNA="ifany");data.frame(variable=v,category=ifelse(is.na(names(z)),"Not reported",names(z)),n=as.integer(z),percent=as.numeric(z)/N*100,denominator=N)
}))
write(categorical,"S2_categorical")
numvars<-c("age","finc_log","Factor1_Authoritarian","Factor2_AntiScience","Factor3_Inequality")
num<-do.call(rbind,lapply(numvars,function(v){z<-x[[v]];data.frame(variable=v,n=sum(!is.na(z)),mean=mean(z,na.rm=TRUE),sd=sd(z,na.rm=TRUE),min=min(z,na.rm=TRUE),max=max(z,na.rm=TRUE),missing=sum(is.na(z)))}))
write(num,"S2_continuous")
rawq14<-do.call(rbind,lapply(1:10,function(i){z<-find_column(raw,paste0("Q14項目",i,"."));t<-table(factor(z,levels=1:7));data.frame(field=field_names[i],code=1:7,n=as.numeric(t),percent=as.numeric(t)/N*100)}))
write(rawq14,"S2b_Q14_original_categories")
L<-unclass(fa$fa$loadings)
write(data.frame(item=rownames(L),Authoritarian=L[,"MR1"],Anti_science=L[,"MR2"],Inequality=L[,"MR3"],communality=fa$fa$communality,uniqueness=fa$fa$uniqueness),"S3_factor_loadings")
write(num[num$variable %in% tail(numvars,3),],"S4_factor_scores")
write(data.frame(statistic=c("RMSR","RMSEA","TLI","BIC","total_variance_explained"),value=c(fa$fa$rms,fa$fa$RMSEA[1],fa$fa$TLI,fa$fa$BIC,sum(L^2)/nrow(L))),"factor_fit")

m<-lca$models[["5"]]
cl<-m$predclass;post<-m$posterior
quality<-do.call(rbind,lapply(1:5,function(k){ix<-cl==k;data.frame(class=k,label=class_names[k],assigned_n=sum(ix),assigned_percent=mean(ix)*100,estimated_percent=m$P[k]*100,mean_posterior=mean(post[ix,k]),min_posterior=min(post[ix,k]),below_0_8=sum(post[ix,k]<.8))}))
write(quality,"S6_class_quality")
entropy<-1+sum(ifelse(post>0,post*log(pmax(post,1e-300)),0))/(N*log(5))
write(data.frame(normalized_entropy=entropy,mean_max_posterior=mean(apply(post,1,max)),n_max_posterior_below_0_8=sum(apply(post,1,max)<.8)),"classification_summary")
probs<-do.call(rbind,lapply(1:10,function(i){z<-as.data.frame(m$probs[[i]]);names(z)<-c("Dont_know","Not_scientific","Neither","Scientific");data.frame(class=1:5,field=field_names[i],z)}))
write(probs,"conditional_response_probabilities")
starts<-do.call(rbind,lapply(names(lca$models),function(k){z<-lca$models[[k]];a<-z$attempts;data.frame(classes=as.integer(k),retained_loglik=z$llik,retained_iterations=z$numiter,recorded_starts=length(a),best_start_hits=sum(abs(a-max(a))<1e-6),min_start_loglik=min(a),max_start_loglik=max(a))}))
write(starts,"start_diagnostics")

s<-summary(reg$model);b<-s$coefficients;se<-s$standard.errors
coefs<-do.call(rbind,lapply(seq_len(nrow(b)),function(i){z<-b[i,]/se[i,];data.frame(class=rownames(b)[i],term=colnames(b),estimate=b[i,],std.error=se[i,],conf.low=b[i,]-qnorm(.975)*se[i,],conf.high=b[i,]+qnorm(.975)*se[i,],p.value=2*pnorm(-abs(z)))}))
write(coefs,"S7_multinomial_coefficients")
write(data.frame(n=reg$n,omitted=reg$omitted,convergence=reg$model$convergence,logLik=as.numeric(logLik(reg$model)),AIC=AIC(reg$model),residual_deviance=reg$model$deviance),"regression_fit")

# Independent additional optimization check, without replacing the primary fit.
set.seed(456)
message("Running an independent 100-start check of the five-class solution")
f<-as.formula(paste0("cbind(",paste(field_vars,collapse=","),") ~ 1"))
alt<-poLCA::poLCA(f,data=x[field_vars],nclass=5,nrep=100,maxiter=10000,tol=1e-10,na.rm=FALSE,verbose=FALSE)
perms<-as.matrix(expand.grid(rep(list(1:5),5)))
perms<-perms[apply(perms,1,function(z)length(unique(z))==5),,drop=FALSE]
loss<-apply(perms,1,function(p)sum(vapply(1:10,function(i)sum((m$probs[[i]]-alt$probs[[i]][p,,drop=FALSE])^2),numeric(1))))
perm<-perms[which.min(loss),]; aligned<-match(alt$predclass,perm)
xx<-x;xx$lca_class<-factor(aligned,levels=1:5,labels=class_names)
altreg<-fit_regression(xx)
key<-function(a)paste(a$group,a$term,a$contrast)
ix<-match(key(reg$ame),key(altreg$ame));stopifnot(!anyNA(ix))
compare<-data.frame(group=reg$ame$group,term=reg$ame$term,contrast=reg$ame$contrast,primary=reg$ame$estimate,additional=altreg$ame$estimate[ix],difference=altreg$ame$estimate[ix]-reg$ame$estimate)
write(compare,"S9_AME_optimization_comparison")
choose2<-function(z)z*(z-1)/2
t<-table(cl,aligned);a<-sum(choose2(t));r<-sum(choose2(rowSums(t)));c<-sum(choose2(colSums(t)));e<-r*c/choose2(N);ari<-(a-e)/((r+c)/2-e)
write(data.frame(model=c("Primary five-class","Additional five-class"),seed=c(123,456),starts=c(10,100),maxiter=c(1000,10000),iterations=c(m$numiter,alt$numiter),logLik=c(m$llik,alt$llik),AIC=c(m$aic,alt$aic),BIC=c(m$bic,alt$bic),best_hits=c(sum(abs(m$attempts-max(m$attempts))<1e-6),sum(abs(alt$attempts-max(alt$attempts))<1e-6))),"S9_optimization")
write(data.frame(changed_assignments=sum(cl!=aligned),ARI=ari,max_abs_AME_difference=max(abs(compare$difference)),additional_converged=alt$numiter<10000),"S9_optimization_summary")
write(data.frame(class=1:5,primary=as.numeric(table(factor(cl,levels=1:5))),additional=as.numeric(table(factor(aligned,levels=1:5)))),"S9_class_comparison")

dates<-as.data.frame(table(raw[["回答日"]]));names(dates)<-c("date","n");write(dates,"response_dates")
q7check<-find_column(raw,"Q7項目4.");write(as.data.frame(table(q7check,useNA="ifany")),"instructed_nonresponse")
condition<-find_column(raw,"Q10_rand.");write(as.data.frame(table(condition,useNA="ifany")),"survey_information_conditions")
meta<-c(paste("R",getRversion()),paste("Source file",basename(input)),paste("Source MD5",tools::md5sum(input)),paste("Primary script MD5",tools::md5sum(base)),paste("N",N),paste("Regression N",reg$n),capture.output(sessionInfo()))
writeLines(meta,file.path(out,"run_information.txt"))
cit<-unlist(lapply(c("psych","poLCA","nnet","marginaleffects"),function(p)c(p,capture.output(print(citation(p),style="text")),capture.output(toBibtex(citation(p))))))
writeLines(cit,file.path(out,"software_citations.txt"))
message("Supplemental outputs written to ",out)
