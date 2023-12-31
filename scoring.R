rawdata = read.csv("mmse.csv",header=T,sep=",")
rawdata %>% select(C401:C419,year,gender) -> dat
#C417: Klosa자료상 읽기성공시 1, 눈감기 성공시 3으로 코딩되어 2점 만점을 갖는 문항으로 입력되어있지만
#MMSE의 채점 규칙에 따라 눈감기까지 성공해야만 점수 획득하는 1점 만점을 갖는 이분 문항으로 수정하여 사용함. 
#401 시간지남력 - 연월일 0123 
#402 시간지남력 - 요일 01
#403 시간지남력- 계절 01
#404 장소지남력 - 현위치 01
#405 장소지남력 - 시/구/동/번지 01234
#406 기억력 테스트(3단어) 0123
#407 주의 집중 및 계산 (뺄셈 1) 01
#408 주의 집중 및 계산 (뺄셈 2) 01
#409 주의 집중 및 계산 (뺄셈 3) 01
#410 주의 집중 및 계산 (뺄셈 4) 01
#411 주의 집중 및 계산 (뺄셈 5) 01
#412 기억력 테스트(3단어 재확인) 0123
#413 소지품의 용도 (소지품 1) 01
#414 소지품의 용도 (소지품 2) 01
#415 따라서 말하기 01
#416 명령시행_종이 뒤집기, 접기, 건네주기 0123
#417 명령시행_읽고 눈감기 01
#418 명령시행_기분 또는 날씨에 대해 쓰기 01
#419 명령시행_제시된 그림 똑같이 그리기01
# 5 오답
# -9 모르겠음: 0 처리
# -8 응답거부: NA 처리
dat$C417 = ifelse(dat$C417==3,1,
                 ifelse(dat$C417==1,0,dat$C417))
#데이터 변환
response19 = dat %>% 
  mutate(across(starts_with("c"),
                ~ case_when(
                  .==-8 ~ NA_real_,
                  .==-9 ~ 0,
                  .== 5 ~ 0,
                  TRUE ~ .)),
         age = 2018 - year,.keep = "unused") %>%
  filter(complete.cases(across(starts_with("c"))))
#5문항
response05 = response19 %>% mutate(C401 = C401+C402+C403+C404+C405,
                                C402 = C406,
                                C403 = C407+C408+C409+C410+C411,
                                C404 = C412,
                                C405 = C413+C414+C415+C416+C417+C418+C419,
                                .keep = "unused")
############################
#####점수산출시작###########
############################

#SUM score
score.SUM = rowSums(response05[,1:5])
#CFA factor score
model.cfa = 'F1 =~ C401 + C402 + C403 + C404 + C405'
results.cfa = cfa(model=model.cfa,data = response05[,1:5],
                 estimator = "MLM")
summary(results.cfa, fit.measures = T,standardized = T, rsquare=TRUE)
score.CFA = lavPredict(results.cfa,method = "regression",fsm = T)

#PCM
model.pcm = 'F1 = 1-19
              CONSTRAIN = (1-19, a1)' 
results.pcm = mirt(data=response19[,1:19], model=model.pcm, itemtype="gpcm", SE=TRUE, verbose=FALSE)
coef.pcm = coef(results.pcm, IRTpars=TRUE, simplify=TRUE)
score.PCM = fscores(results.pcm,method = 'EAP')
itemfit.PCM = itemfit(results.pcm,'infit')
M2(results.pcm)

#GPCM
model.gpcm = 'F1 = 1-19' 
results.gpcm = mirt(data=response19[,1:19], model=model.gpcm, itemtype="gpcm", SE=TRUE, verbose=FALSE)
coef.gpcm = coef(results.gpcm,IRTpars=TRUE,simplify = T)
score.GPCM = fscores(results.gpcm,method = 'EAP')
itemfit.GPCM = itemfit(results.gpcm,'infit')
M2(results.gpcm)


#점수 취합
score.frame = setNames(data.frame(score.SUM, score.CFA, score.PCM, score.GPCM, response19$age, response19$gender), 
         c("SUM", "CFA", "PCM", "GPCM", "age", "gender"))

#23/24 기준으로 기준점 설정
cutoff = mean(score.frame$SUM < 24)

#23/24 기준으로 마커
quantiles = score.frame %>% 
  summarise(
    qSUM = quantile(SUM, cutoff),
    qCFA = quantile(CFA, cutoff),
    qPCM = quantile(PCM, cutoff),
    qGPCM = quantile(GPCM, cutoff))

sf = score.frame %>%
  mutate(
    markerSUM = ifelse(SUM <= quantiles$qSUM, '1', '0'),
    markerCFA = ifelse(CFA <= quantiles$qCFA, '1', '0'),
    markerPCM = ifelse(PCM <= quantiles$qPCM, '1', '0'),
    markerGPCM = ifelse(GPCM <= quantiles$qGPCM, '1', '0'),
    agegroup = case_when(
      age >= 85 ~ '4',
      age >= 75 ~ '3',
      age >= 65 ~ '2',
      age >= 55 ~ '1')) %>%
  mutate_at(vars(c(starts_with("marker"), "gender","agegroup")), as.factor)
