SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/**************************************************************
Title: J0100_LOR_VAS_Status_tracking

Date(yyyy/MM/dd)  Author   Ver  Purposes
2021/07/21        KenLizX  1.0  New Report
2021/10/26		  JackyHsu 1.1  新增QC與上架狀態更新與狀態更新時間 (JH01)
2021/12/06		  KenLizX  1.2  Modified field J0100_02_OrderDate (KL01)
2021/12/09		  KenLizX  1.3  Modified condition and Added field (KL02)
2021/12/21		  KenLizX  1.3  Modified script (KL03)
2022/01/06		  KenLizX  1.4  Modified script (KL04)
2022/03/02		  KenLizX  1.5  Modified script (KL05)
2023/01/13    TedPeng 1.6  WMS-21289 Fine Tune script (TP01)
Remark :
Project : LFPM-979 Sprint 4

Sch
Orderdate filter : Orderdate -3 ~ Orderdate
Every Day
Time : 08:00, 11:00

On Demind
Parameter : Orderdate (Interval),Externworkorderkey,Division (multi)
Limit : Orderdate 2 mouth

**************************************************************/
/****************************************************************************/
/* [TW]Data Source for YHDC2 VAS Dashboard									*/
/* https://jiralfl.atlassian.net/browse/WMS-18439							*/
/* Updates:																	*/
/* Date         Author		Ver.	Purposes								*/
/* 29-Nov-2021	KenLizX		1.0		Created									*/
/* 30-Nov-2021  BLLim		1.1		Fine-tuning								*/
/* 06-Dec-2021  BLLim		1.2		Remove RIGHT() function					*/
/* 10-Dec-2021  BLLim		1.3		Modified condition and Added field		*/
/****************************************************************************/

CREATE   PROC [BI].[nsp_VAS_YHDC2](
	@PARAM_StartDate DATETIME = NULL
   ,@PARAM_EndDate   DATETIME = NULL
)AS
BEGIN
	SET NOCOUNT ON;  -- keeps the output generated to a minimum 
	SET ANSI_NULLS OFF;
	SET QUOTED_IDENTIFIER OFF;
	SET CONCAT_NULL_YIELDS_NULL OFF;
	
	/*********************************************
	Init 
	**********************************************/
	DECLARE @PARAM_StorerKey NVARCHAR(15) = ''
	
	DECLARE @PARAM_WorkDate_Str NVARCHAR(11)
		,@PARAM_WorkDate_End NVARCHAR(11)
		--,@S_Refno_str varchar(10)
		--,@S_Refno_end varchar(10)
		--,@S_Division varchar(120)

	/*Set @PARAM_WorkDate_Str = convert(nvarchar(20),getdate()-1,112)
	Set @PARAM_WorkDate_End = convert(nvarchar(20),getdate()+3,112)*/
	
	IF @PARAM_StartDate IS NULL OR @PARAM_StartDate = '1900-01-01 00:00:00.000'
		SET @PARAM_StartDate = GETDATE()-6 --(KL05)
		--SET @PARAM_StartDate = GETDATE()-1 --(KL05)
	IF @PARAM_EndDate IS NULL OR @PARAM_EndDate = '1900-01-01 00:00:00.000'
		SET @PARAM_EndDate = GETDATE() --(KL05)
		--SET @PARAM_EndDate = GETDATE()+3 --(KL05)
	
	SET @PARAM_WorkDate_Str = ISNULL(CONVERT(NVARCHAR(20),@PARAM_StartDate,112),'')
	SET @PARAM_WorkDate_End = ISNULL(CONVERT(NVARCHAR(20),@PARAM_EndDate,112),'')
	
	DECLARE @nRowCnt INT = 0
		, @Proc      NVARCHAR(128) = isnull(object_name(@@procid),'')
		, @cParamOut NVARCHAR(4000)= ''
		, @cParamIn  NVARCHAR(4000)= '{ "PARAM_StartDate":"'+ISNULL(CONVERT(NVARCHAR(19),@PARAM_StartDate,121),'')+'"'
									+ ', "PARAM_ENDDate":"'+ISNULL(CONVERT(NVARCHAR(19),@PARAM_EndDate,121),'')+'"'
									+ ' }'
									
	DECLARE @tVarLogId TABLE (LogId INT);
	INSERT dbO.ExecutiONLog (ClientId, SP, ParamIn) OUTPUT INSERTED.LogId INTO @tVarLogId VALUES (@PARAM_StorerKey, @Proc, @cParamIn);
	
	DECLARE @Stmt NVARCHAR(MAX) = '' -- for storing dynamic SQL Statement

	--Set @S_Refno_str = ''
	--Set @S_Refno_end = ''
	--set @S_Division = ''

	--DECLARE @c_SQL NVARCHAR(4000)
	--	,@c_ErrCode int = 0

	IF OBJECT_ID('tempdb..#TEMP') Is Not NULL 
		Drop table #TEMP
	IF OBJECT_ID('tempdb..#Interruption') Is Not NULL 
		Drop table #Interruption
	IF OBJECT_ID('tempdb..#Interruption_Final') Is Not NULL 
		Drop table #Interruption_Final
	IF OBJECT_ID('tempdb..#TEMP_FINAL') Is Not NULL 
		Drop table #TEMP_FINAL
	IF OBJECT_ID('tempdb..#QualityOfProducts') Is Not NULL 
		Drop table #QualityOfProducts
	IF OBJECT_ID('tempdb..#ITRN') Is Not NULL 
		Drop table #ITRN	
	IF OBJECT_ID('tempdb..#WORKORDERSTEPS') Is Not NULL 
		Drop table #WORKORDERSTEPS	
	IF OBJECT_ID('tempdb..#QCstatus') Is Not NULL 
		Drop table #QCstatus	

	/*********************************************
	Validation 
	**********************************************/
	--IF DateDiff(d, Cast(@PARAM_WorkDate_Str as Datetime) ,Cast(@PARAM_WorkDate_End as Datetime) ) > 62
	--Begin 
	--	Set @c_ErrCode = 1
	--End

	/*********************************************
	Get VAS operation
	**********************************************/
	Select Storerkey,Facility,TRIM(WOS.HostStepNumber) AS HostStepNumber,Instructions
	Into #WORKORDERSTEPS
	From dbo.WORKORDERROUTING WOR with (NOLOCK)
	Inner Join dbo.WORKORDERSTEPS WOS with (NOLOCK)
		On WOR.MASTERWORKORDER = WOS.MASTERWORKORDER
		And TRIM(ISNULL(WOS.HostStepNumber,'')) <> ''
	Where WOR.Storerkey = 'LOR'
	And WOR.MasterWorkOrder = 'LORSTD' --(KL03)

	/*********************************************
	Get Order
	**********************************************/

	Select 
		[J0100_01_OrderMonth] = Format(IQC.UserDefine06,'MM') + N'月', --開單月份
		[J0100_02_OrderDate] = Convert(char(10),IQC.UserDefine06,111) , --開單日期
		[J0100_03_ExternWorkOrderkey] = IQC.Refno, --工單號碼
		[J0100_04_ExternStatus] = Case When WO.ExternWorkOrderkey is null Then 1 Else WO.ExternStatus End, --狀態
		[J0100_05_Remark] = IQC.UserDefine05, --備註
		[J0100_06_Brand] = IQC.UserDefine03, --品牌
		[J0100_07_Division] = Trim(IQC.UserDefine09), --Division
		[J0100_08_WkOrdUdef6] = convert(char(19),IQCD.UserDefine06,20), --預計完成日期
		[J0100_09_Sort] = IQC.UserDefine10 , --加工分類
		[J0100_10_WkOrdUdef7] = convert(char(19),IQC.UserDefine07,20), --WMS入帳日期
		[J0100_11_ASN_No] = IQCD.UserDefine10, --LOR ASN#
		[J0100_12_INV_No] = IQC.UserDefine01, --LOR INV#
		[J0100_13_SKU] = IQCD.SKU, --SKU
		[J0100_14_Descr] = SKU.Descr, --Descr
		[J0100_15_FormLoc] = IQCD.FromLoc, --Loc(儲位)
		[J0100_16_Qty] = IQCD.Qty, --加工數量
		[J0100_17_Lottable04] = Convert(char(10),Lotattribute.Lottable04,111), --產品效期
		[J0100_18_CaseCnt] = Pack.CaseCnt, --Casecnt(出貨入數)
		[J0100_19_Lottable02] = Lotattribute.Lottable02, --生產批號
		[J0100_20_Lottable03] = Lotattribute.Lottable03, --產地
		[J0100_21_WkOrdUdef2] = Case When WO.WkOrdUdef2 IS NULL Then IQC.UserDefine02 Else WO.WkOrdUdef2 End, --加工動作代碼  
		[J0100_22_Instructions] = Case When ISNULL(WOS.Instructions,'') = '' Then N'未維護加工動作' Else WOS.Instructions End , --加工動作
		[J0100_23_WkOrdUdef8] = Case When WO.WkOrdUdef8 IS NULL Then IQC.UserDefine08 Else WO.WkOrdUdef8 End, --加工廠商  
		[J0100_24_WkOrdUdef4] = IQC.UserDefine04, --類型
		[J0100_25_EndDownTime] = '', --最後完工日期
		[J0100_26_Non_Defective] = 0, --良品數量
		[J0100_27_Defective] = 0, --不良品
		[J0100_28_shortage] = 0, --短缺
		[J0100_29_Excess] = 0, --溢收
		[J0100_30_Abnormal_rate] = 0, --異常率%
		[J0100_31_Difference] = 0, --差異
		[J0100_32_WorkStation] = MAX(WOJ.WorkStation), --工作臺號
		[J0100_33_NoOfAssignedWorker] = sum(WOJ.NoOfAssignedWorker), --加工人數
		[J0100_34_Start_Date] = min(convert(char(19),WOJ.Start_Production,20))   , --工單開始日期時間
		[J0100_35_End_Date] = MAX(convert(char(19),WOJ.End_Production,20))  , --工單結束日期時間
		[J0100_36_Completed_Qty] = MAX(WOJ.QtyCompleted) , --工單完成數量
		[J0100_37_Interruption_Date] = N'' , --工單中斷日期時間
		[J0100_38_Restart_Date] = N'' , --工單再開始日期時間
		[J0100_39_Interruption_Reason] = N'' , --工單中斷原因
		[J0100_40_Interruption_Qty] = N'' , --工單中斷數量
		[J0100_41_innerPack] = Sku.innerPack, --中包裝入數
		[J0100_42_FromID] = IQCD.FromID, --可移動單位
		[J0100_43_ToLoc] = IQCD.ToLoc, --Loc(儲位)
		[J0100_44_WOEditdate] = wo.EditDate, --狀態更改時間 /*QC狀態判斷(JH01)*/ 
		[J0100_45_fromlot] = IQCD.FromLot --(KL03)
	Into #TEMP
	From dbo.InventoryQC AS IQC with (NOLOCK)
	Inner Join dbo.InventoryQCDetail AS IQCD with (NOLOCK)
		On IQC.QC_Key = IQCD.QC_Key 
	Left Join dbo.WorkOrder AS WO with (NOLOCK)
		On IQC.Refno = WO.ExternWorkOrderkey
		And WO.Storerkey = IQC.Storerkey
	Left Join dbo.WorkOrderDetail AS WOD with (NOLOCK)
		On WO.WorkOrderKey = WOD.WorkOrderKey 
	Inner Join dbo.SKU AS SKU with (NOLOCK)
		On SKU.Storerkey = IQC.Storerkey
		And SKU.SKU = IQCD.SKU
	Inner Join dbo.PACK AS PACK with (NOLOCK)
		On PACK.Packkey = SKU.Packkey
	Inner Join dbo.LOTATTRIBUTE AS Lotattribute with (NOLOCK)
		On Lotattribute.Storerkey = IQC.Storerkey
		And Lotattribute.Lot = IQCD.FromLot
	Left Join #WORKORDERSTEPS WOS with (NOLOCK)
		On WOS.Storerkey = IQC.StorerKey
		And Trim(WOS.HostStepNumber) = TRIM(IQC.UserDefine02)
	Left Join dbo.WorkOrderJob WOJ with (NOLOCK)
		On WOJ.WorkOrderKey = WO.ExternWorkOrderkey
	Where IQC.Storerkey = 'LOR' And IQC.Reason = 'A2A' 
	--And 0 = @c_ErrCode
	--And Cast(Convert(char(10),IQCD.UserDefine06,112) as Datetime)  Between  @PARAM_WorkDate_Str And @PARAM_WorkDate_End --(KL02) (KL05)
	And Cast(Convert(char(10),IQC.UserDefine06,112) as Datetime)  Between  @PARAM_WorkDate_Str And @PARAM_WorkDate_End --(KL02) (KL05)
	--And TRIM(IQC.Refno) >= Case When ISNULL(@S_Refno_str,'') = '' Then TRIM(IQC.Refno) Else  @S_Refno_str End
	--And TRIM(IQC.Refno) <= Case When ISNULL(@S_Refno_end,'') = '' Then Case When ISNULL(@S_Refno_str,'') = '' Then TRIM(IQC.Refno) Else  @S_Refno_str End Else  @S_Refno_end End
	AND WO.ExternStatus <> 'CANC'  -- TP01
	group by 

		Format(IQC.UserDefine06,'MM') + N'月', --開單月份
		Convert(char(10),IQC.UserDefine06,111) , --開單日期
		IQC.Refno, --工單號碼
		Case When WO.ExternWorkOrderkey is null Then 1 Else WO.ExternStatus End, --狀態
		IQC.UserDefine05, --備註
		IQC.UserDefine03, --品牌
		Trim(IQC.UserDefine09), --Division
		convert(char(19),IQCD.UserDefine06,20), --預計完成日期
		IQC.UserDefine10 , --加工分類
		convert(char(19),IQC.UserDefine07,20), --WMS入帳日期
		IQCD.UserDefine10, --LOR ASN#
		IQC.UserDefine01, --LOR INV#
		IQCD.SKU, --SKU
		SKU.Descr, --Descr
		IQCD.FromLoc, --Loc(儲位)
		IQCD.Qty, --加工數量
		Convert(char(10),Lotattribute.Lottable04,111), --產品效期
		Pack.CaseCnt, --Casecnt(出貨入數)
		Lotattribute.Lottable02, --生產批號
		Lotattribute.Lottable03, --產地
		Case When WO.WkOrdUdef2 IS NULL Then IQC.UserDefine02 Else WO.WkOrdUdef2 End, --加工動作代碼  
		Case When ISNULL(WOS.Instructions,'') = '' Then N'未維護加工動作' Else WOS.Instructions End , --加工動作
		Case When WO.WkOrdUdef8 IS NULL Then IQC.UserDefine08 Else WO.WkOrdUdef8 End, --加工廠商  
		IQC.UserDefine04, --類型
		--WOJ.WorkStation, --工作臺號
		--WOJ.NoOfAssignedWorker, --加工人數
		--convert(char(19),WOJ.Start_Production,20)   , --工單開始日期時間
		--convert(char(19),WOJ.End_Production,20)  , --工單結束日期時間
		--WOJ.QtyCompleted , --工單完成數量
		Sku.innerPack, --中包裝入數
		IQCD.FromID, --可移動單位
		IQCD.ToLoc, --Loc(儲位)
		wo.EditDate, --狀態更改時間 /*QC狀態判斷(JH01)*/ 
		IQCD.FromLot --(KL03)

	/**************
	工單作業時間測試
	**************/
	IF OBJECT_ID('tempdb..#WorkStation_log') Is Not NULL 
		Drop table #WorkStation_log	

	select b.workorderkey,b.logdate
	, convert(nvarchar(10),ROW_NUMBER() OVER(PARTITION  by b.workorderkey  ORDER BY b.logdate,b.status)) NO 
	into #WorkStation_log
	from #temp a with (NOLOCK)
	inner join dbo.WorkStation_log b with (NOLOCK)
		on a.J0100_03_ExternWorkOrderkey = b.workorderkey
		and a.[J0100_04_ExternStatus] >= 5
	group by b.workorderkey,b.logdate,b.status
	order by b.workorderkey,b.logdate

	IF OBJECT_ID('tempdb..#worktime') Is Not NULL 
		Drop table #worktime	

	select workorderkey
	, DATEDIFF(minute,MAX(CASE NO WHEN '1' THEN logdate ELSE 0 END),MAX(CASE NO WHEN '2' THEN logdate ELSE 0 END))
	+ DATEDIFF(minute,MAX(CASE NO WHEN '3' THEN logdate ELSE 0 END),MAX(CASE NO WHEN '4' THEN logdate ELSE 0 END))
	+ DATEDIFF(minute,MAX(CASE NO WHEN '5' THEN logdate ELSE 0 END),MAX(CASE NO WHEN '6' THEN logdate ELSE 0 END))
	+ DATEDIFF(minute,MAX(CASE NO WHEN '7' THEN logdate ELSE 0 END),MAX(CASE NO WHEN '8' THEN logdate ELSE 0 END))
	+ DATEDIFF(minute,MAX(CASE NO WHEN '9' THEN logdate ELSE 0 END),MAX(CASE NO WHEN '10' THEN logdate ELSE 0 END))
	+ DATEDIFF(minute,MAX(CASE NO WHEN '11' THEN logdate ELSE 0 END),MAX(CASE NO WHEN '12' THEN logdate ELSE 0 END))  worktime
	into #worktime
	from #WorkStation_log with (NOLOCK)
	GROUP BY workorderkey



	/*********************************************
	Update Interruption Info
	**********************************************/

	--LogDate 
	Select WorkOrderkey,
		status,
		Max(LogDate) AS LogDate
	Into #Interruption
	From #TEMP AS temp with (NOLOCK)
	INNER JOIN dbo.WORKSTATION_LOG as WSL with (NOLOCK)
		On temp.J0100_03_ExternWorkOrderkey = WSL.Workorderkey
	Where status <> '9'
	Group by WorkOrderkey,status
		
	--ReasonCode 
	Select 
		INTER.WorkOrderkey,
		INTER.Status,
		WSL.ReasonCode,
		--INTER.LogDate   --(KL03)
		max(INTER.LogDate) LogDate, --(KL03)
		sum(isnull(WJ.QtyCompleted,0)) QtyCompleted --(KL03)
	Into #Interruption_Final
	From #Interruption as INTER with (NOLOCK)
	LEFT join dbo.WORKSTATION_LOG as WSL with (NOLOCK)
		On INTER.WorkOrderkey = WSL.WorkOrderKey
		And INTER.status = WSL.status
		And INTER.LogDate = WSL.LogDate
		And INTER.status = '5'
	--Start KL03
	LEFT join dbo.WORKORDERJOB as WJ with (NOLOCK)
		On INTER.WorkOrderkey = WJ.WorkOrderKey
		And WJ.JOBstatus = '5'
	Group by INTER.WorkOrderkey,
		INTER.Status,
		WSL.ReasonCode
	Having sum(isnull(WJ.QtyCompleted,0)) <> 0
	--End KL03

	/*********************************************
	Qty  不良品:W 短缺:D
	**********************************************/

	Select 
		Case  Case When LEN(IQCD.FromID) > 1 Then left(IQCD.FromID,1) End 
		  When 'W' Then Substring(IQCD.FromID,2,Len(IQCD.FromID))
		  When 'D' Then Substring(IQCD.FromID,2,Len(IQCD.FromID))
		  Else IQCD.FromID End　As Refno,
		Case When LEN(IQCD.FromID) > 1 Then left(IQCD.FromID,1) End As Type , 
		Cast (IQCD.ToQty as int) as ToQty
	Into #QualityOfProducts
	From #TEMP AS Temp with (NOLOCK)
	Inner Join dbo.InventoryQC AS IQC with (NOLOCK)
		On Temp.J0100_03_ExternWorkOrderkey = IQC.Refno
	Inner Join dbo.InventoryQCDetail AS IQCD with (NOLOCK)
		On IQC.QC_Key = IQCD.QC_Key 
	Where Temp.J0100_03_ExternWorkOrderkey = 
		Case  Case When LEN(IQCD.FromID) > 1 Then left(IQCD.FromID,1) End 
		When 'W' Then Substring(IQCD.FromID,2,Len(IQCD.FromID))
		When 'D' Then Substring(IQCD.FromID,2,Len(IQCD.FromID))
		Else IQCD.FromID End
	And IQC.FinalizeFlag = 'Y'

	/*********************************************
	Update Putaway Qty
	**********************************************/
	Select 
		temp.J0100_03_ExternWorkOrderkey as TOID,
		temp.J0100_13_SKU as SKU,
		SUM(ITRN.Qty) as Qty,
		MAX(ITRN.AddDate) as AddDate
	Into #ITRN
	From #TEMP as temp with (NOLOCK)
	INNER join dbo.ITRN as ITRN with (NOLOCK)
		On (substring(ITRN.fromID,2,len(temp.J0100_03_ExternWorkOrderkey)) = temp.J0100_03_ExternWorkOrderkey --(KL03)
		or left(ITRN.fromID,len(temp.J0100_03_ExternWorkOrderkey)) = temp.J0100_03_ExternWorkOrderkey) --(KL03)
		And ITRN.SKU = temp.[J0100_13_SKU]
		And ITRN.FromLoc = temp.[J0100_43_ToLoc]
		And ITRN.fromloc <> ITRN.toloc --(KL03)
		And ITRN.lot = temp.J0100_45_fromlot --(KL03)
	Where ITRN.TranType = 'MV' 
	And ITRN.Storerkey = 'LOR'
	And ITRN.SourceType = 'rdtfnc_Move_ID'
	Group by temp.J0100_03_ExternWorkOrderkey,temp.J0100_13_SKU 

	/*QC狀態判斷開始(JH01)*/
	select distinct tp.J0100_03_ExternWorkOrderkey,MIN(itrn.editdate) QCDate  --(KL04)
	into #QCstatus
	from #TEMP tp with (NOLOCK)
	--Start KL03
	/* 
	inner join dbo.lotxlocxid lli with (NOLOCK)
		on  tp.J0100_13_SKU = lli.sku
		and tp.J0100_43_ToLoc = lli.loc
		and (tp.J0100_03_ExternWorkOrderkey = left(lli.ID , len(tp.J0100_03_ExternWorkOrderkey))
		or tp.J0100_03_ExternWorkOrderkey = substring(lli.ID,2,len(tp.J0100_03_ExternWorkOrderkey)))
		and lli.qty <> 0
		and left(lli.ID,1) <> '0'
    */
	Inner join dbo.ITRN itrn with (nolocK) 
		On  tp.J0100_13_SKU = itrn.sku
		And tp.J0100_43_ToLoc = itrn.fromloc
		And itrn.storerkey = 'LOR'
		And itrn.trantype = 'MV'
		And left(itrn.TOID,1) <> '0'
		And itrn.sourcetype = 'rdtfnc_Move_SKU_Lottable' 
		And itrn.status = 'OK'
		And (tp.J0100_03_ExternWorkOrderkey = left(itrn.TOID , len(tp.J0100_03_ExternWorkOrderkey))
			Or tp.J0100_03_ExternWorkOrderkey = substring(itrn.TOID,2,len(tp.J0100_03_ExternWorkOrderkey)))
	--End KL03
	group by tp.J0100_03_ExternWorkOrderkey
	/*QC狀態判斷結束(JH01)*/

	/*********************************************
	Final
	**********************************************/
	--Join
	Select 
		[J0100_01_OrderMonth] = temp.[J0100_01_OrderMonth] , --開單月份
		[J0100_02_OrderDate] = temp.[J0100_02_OrderDate] , --開單日期
		[J0100_03_ExternWorkOrderkey] = temp.[J0100_03_ExternWorkOrderkey] , --工單號碼
		--(KL05) start
		[J0100_04_ExternStatus] = Case when Cast(temp.[J0100_04_ExternStatus] as nvarchar) in ('9','CANC') then temp.[J0100_04_ExternStatus] 						　　
								　else case when (ITRN.AddDate is not null) 
								  and (ISNULL(ITRN.QTY,0) + ISNULL(QOPW.ToQty,0) + ISNULL(QOPD.ToQty,0) - temp.[J0100_29_Excess] ) = temp.[J0100_16_Qty]  
								  /*良品+不良品+短缺-溢收*/
								  then '9' else 
								  case when (ITRN.AddDate is not null) then '8' else
								  case when Qc.J0100_03_ExternWorkOrderkey is not null then '7' 
								  else temp.[J0100_04_ExternStatus] end end end end, --狀態 /*QC狀態判斷(JH01)*/
		--(KL05) End
		[J0100_05_Remark] = temp.[J0100_05_Remark], --備註
		[J0100_06_Brand] = temp.[J0100_06_Brand] , --品牌
		[J0100_07_Division] = temp.[J0100_07_Division] , --Division
		[J0100_08_WkOrdUdef6] = temp.[J0100_08_WkOrdUdef6] , --預計完成日期
		[J0100_09_Sort] = temp.[J0100_09_Sort]  , --加工分類
		[J0100_10_WkOrdUdef7] = temp.[J0100_10_WkOrdUdef7], --WMS入帳日期
		[J0100_11_ASN_No] = temp.[J0100_11_ASN_No] , --LOR ASN#
		[J0100_12_INV_No] = temp.[J0100_12_INV_No] , --LOR INV#
		[J0100_13_SKU] = temp.[J0100_13_SKU] , --SKU
		[J0100_14_Descr] = temp.[J0100_14_Descr] , --Descr
		[J0100_15_FormLoc] = temp.[J0100_15_FormLoc] , --Loc(儲位)
		[J0100_16_Qty] = temp.[J0100_16_Qty], --加工數量
		[J0100_17_Lottable04] = temp.[J0100_17_Lottable04] , --產品效期
		[J0100_18_CaseCnt] = temp.[J0100_18_CaseCnt] , --Casecnt(出貨入數)
		[J0100_19_Lottable02] = temp.[J0100_19_Lottable02] , --生產批號
		[J0100_20_Lottable03] = temp.[J0100_20_Lottable03] , --產地
		[J0100_21_WkOrdUdef2] = temp.[J0100_21_WkOrdUdef2] , --加工動作代碼  
		[J0100_22_Instructions] = temp.[J0100_22_Instructions]  , --加工動作
		[J0100_23_WkOrdUdef8] = temp.[J0100_23_WkOrdUdef8] , --加工廠商  
		[J0100_24_WkOrdUdef4] = temp.[J0100_24_WkOrdUdef4] , --類型
		[J0100_25_EndDownTime] = convert(char(19),ITRN.AddDate,20) , --最後完工日期
		[J0100_26_Non_Defective] = ISNULL(ITRN.QTY,0) , --良品數量
		[J0100_27_Defective] = ISNULL(QOPW.ToQty,0) , --不良品
		[J0100_28_shortage] = ISNULL(QOPD.ToQty,0) , --短缺
		[J0100_29_Excess] = temp.[J0100_29_Excess] , --溢收
		[J0100_30_Abnormal_rate] = case when temp.[J0100_16_Qty] = '0' then 0 else (ISNULL(QOPW.ToQty,'') + ISNULL(QOPD.ToQty,'') ) / temp.[J0100_16_Qty] end, --異常率%
		[J0100_31_Difference] = temp.[J0100_16_Qty]-ISNULL(ITRN.QTY,'')-ISNULL(QOPW.ToQty,'')-ISNULL(QOPD.ToQty,''), --差異
		[J0100_32_WorkStation] = temp.[J0100_32_WorkStation] , --工作臺號
		[J0100_33_NoOfAssignedWorker] = temp.[J0100_33_NoOfAssignedWorker] , --加工人數
		[J0100_34_Start_Date] = temp.[J0100_34_Start_Date]    , --工單開始日期時間
		[J0100_35_End_Date] = temp.[J0100_35_End_Date]   , --工單結束日期時間
		[J0100_36_Completed_Qty] = temp.[J0100_36_Completed_Qty]  , --工單完成數量
		[J0100_37_Interruption_Date] = convert(char(19),interF.LogDate,20) , --工單中斷日期時間
		[J0100_38_Restart_Date] = convert(char(19),RestartF.LogDate,20) , --工單再開始日期時間
		[J0100_39_Interruption_Reason] = TMR.Descr , --工單中斷原因
		[J0100_40_Interruption_Qty] = temp.[J0100_40_Interruption_Qty]  , --工單中斷數量
		[J0100_41_innerPack] = temp.[J0100_41_innerPack] , --中包裝入數
		[J0100_42_FromID] = temp.[J0100_42_FromID],  --可移動單位
		[J0100_43_StatusTime] = convert(char(19),case when (ITRN.AddDate is not null) 
								  and (ISNULL(ITRN.QTY,0) + ISNULL(QOPW.ToQty,0) + ISNULL(QOPD.ToQty,0) - temp.[J0100_29_Excess] ) = temp.[J0100_16_Qty]  
								  /*良品+不良品+短缺-溢收*/
								  then ITRN.AddDate else 
								  case when (ITRN.AddDate is not null) then ITRN.AddDate else
								  case when Qc.J0100_03_ExternWorkOrderkey is not null then QC.QCDate 
								  else temp.[J0100_44_WOEditdate] end end end , 20), --狀態 /*QC狀態判斷(JH01)*/ 
		[J0100_44_WorkOrderTime(M)] = isnull(WT.worktime,0)

	Into #TEMP_FINAL
	From #TEMP as temp with (NOLOCK)
	LEFT join #Interruption_Final as interF with (NOLOCK)
		On temp.J0100_03_ExternWorkOrderkey = interF.WorkOrderkey
		And interF.Status = '5'
	LEFT join #Interruption_Final as RestartF with (NOLOCK)
		On interF.WorkOrderkey= RestartF.WorkOrderkey
		And RestartF.Status = '1'
	LEFT join dbo.TaskManagerReason as TMR with (NOLOCK)
		On TaskManagerReasonKey = interF.ReasonCode
	LEFT join #QualityOfProducts as QOPW with (NOLOCK)
		On temp.J0100_03_ExternWorkOrderkey = QOPW.Refno
		And QOPW.Type = 'W'　--不良品
	LEFT join #QualityOfProducts as QOPD with (NOLOCK)
		On temp.J0100_03_ExternWorkOrderkey = QOPD.Refno
		And QOPD.Type = 'D'　　--短缺
	LEFT join #ITRN as ITRN with (NOLOCK)
		On ITRN.TOID = temp.J0100_03_ExternWorkOrderkey
		And ITRN.SKU = temp.[J0100_13_SKU]
	/*QC狀態判斷JH01*/
	left join #QCstatus as QC with (NOLOCK)
		on temp.J0100_03_ExternWorkOrderkey = QC.J0100_03_ExternWorkOrderkey
	/*QC狀態判斷JH01*/
	/*工單作業時間JH02*/
	left join #worktime as WT with (NOLOCK)
		on Temp.J0100_03_ExternWorkOrderkey = wt.workorderkey
	/*工單作業時間JH02*/


	/*********************************************
	Result
	**********************************************/

	SELECT 
		J0100_03_ExternWorkOrderkey as N'工單號',
		J0100_23_WkOrdUdef8 as N'加工廠商',
		Case When J0100_04_ExternStatus < '7' Then 'Doing' Else 'Final' End as N'改包狀態', --(KL03)
		SUM(ISNULL([J0100_36_Completed_Qty],0)) as N'工單完成數量',
		SUM(ISNULL([J0100_16_Qty],0)) as N'加工數量',
		J0100_04_ExternStatus as N'狀態',
		--Right(Convert(char(10) , J0100_02_OrderDate,111),5) as N'開單日',	--(KL01)
		Convert(char(10) , J0100_02_OrderDate,111) as N'開單日',	--(KL01)
		CLK.UDF03 as N'品牌',
		TF.J0100_07_Division as 'ItemClass',
		TF.J0100_06_Brand as 'Brand',
		[J0100_08_WkOrdUdef6] as '預計完成日'  --(KL02)
	FROM #TEMP_FINAL TF with (NOLOCK)
	INNER JOIN dbo.Codelkup CLK with (NOLOCK)
		ON  CLK.Storerkey = 'LOR'
		AND CLK.LISTNAME = 'ITEMCLASS'
		AND TF.J0100_07_Division = CLK.Code
	Group by J0100_03_ExternWorkOrderkey,J0100_23_WkOrdUdef8 ,J0100_04_ExternStatus ,
		--Right(Convert(char(10) , J0100_02_OrderDate,111),5), --(KL01)
		Convert(char(10) , J0100_02_OrderDate,111), --(KL01)
		CLK.UDF03,TF.J0100_07_Division,
		TF.J0100_06_Brand,
		[J0100_08_WkOrdUdef6] --(KL02)

	IF OBJECT_ID('tempdb..#TEMP') Is Not NULL 
		Drop table #TEMP
	IF OBJECT_ID('tempdb..#Interruption') Is Not NULL 
		Drop table #Interruption
	IF OBJECT_ID('tempdb..#Interruption_Final') Is Not NULL 
		Drop table #Interruption_Final
	IF OBJECT_ID('tempdb..#TEMP_FINAL') Is Not NULL 
		Drop table #TEMP_FINAL
	IF OBJECT_ID('tempdb..#QualityOfProducts') Is Not NULL 
		Drop table #QualityOfProducts
	IF OBJECT_ID('tempdb..#ITRN') Is Not NULL 
		Drop table #ITRN	
	IF OBJECT_ID('tempdb..#WORKORDERSTEPS') Is Not NULL 
		Drop table #WORKORDERSTEPS	
	IF OBJECT_ID('tempdb..#QCstatus') Is Not NULL 
		Drop table #QCstatus	
	IF OBJECT_ID('tempdb..#WorkStation_log') Is Not NULL 
		Drop table #WorkStation_log	
	IF OBJECT_ID('tempdb..#worktime') Is Not NULL 
		Drop table #worktime		
	
	
	SET @nRowCnt = @@ROWCOUNT;
	
	SET @cParamOut = '{ "Stmt": "'+@Stmt+'" }'; -- for dynamic SQL ONly
	UPDATE dbo.ExecutiONLog SET TimeEND = GETDATE(), RowCnt = @nRowCnt, ParamOut = @cParamOut
	WHERE LogId = (SELECT TOP 1 LogId FROM @tVarLogId);

END -- Procedure 

GO