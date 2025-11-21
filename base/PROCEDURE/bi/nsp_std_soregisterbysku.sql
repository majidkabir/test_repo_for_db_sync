SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***********************************************************************************************/  
--PH_JReport - SORegisterBySKU - Stored Procedure (PHWMS) https://jiralfl.atlassian.net/browse/WMS-20217
/* Updates:                                                                                    */  
/* Date            Author      Ver.    Purposes                                                */  
/* 12-JUL-2022       JAM       1.0      OPERATION'S DAILY REPORT                                 */
/* 07/13/2022       Crisnah     1.1     Migrate also to PHWMS. this is usual daily report from operations*/ 
/* 20-07-2023       Crisnah	   1.2		PH_LogiReport - Alter Stored Procedure - SORegister - 14Jun2023	https://jiralfl.atlassian.net/browse/WMS-22848 */
/***********************************************************************************************/  
--Test EXEC BI.nsp_STD_SORegisterBySKU 'YLEO', 'MERIT','EditDate', '2022-06-15', '2022-06-29','''9'''

CREATE       PROC [BI].[nsp_STD_SORegisterBySKU]
     @Param_Generic_StorerKey NVARCHAR(50) 
    ,@Param_Generic_Facility NVARCHAR(50) 
	, @Param_Orders_DateDataType NVARCHAR(50)=''
	, @Param_Generic_StartDate DATETIME=''
	, @Param_Generic_EndDate DATETIME=''
	, @Param_Orders_Status NVARCHAR(100)=''
AS
BEGIN
   SET NOCOUNT ON       ;   SET ANSI_DEFAULTS OFF  ;   SET QUOTED_IDENTIFIER OFF;   SET CONCAT_NULL_YIELDS_NULL OFF;
   SET ANSI_NULLS ON    ;   SET ANSI_WARNINGS ON   ;
		
	IF ISNULL(@PARAM_GENERIC_StorerKey, '') = ''
		SET @PARAM_GENERIC_StorerKey = ''
	IF ISNULL(@Param_Generic_Facility, '') = ''
		SET @Param_Generic_Facility = ''
	IF ISNULL(@Param_Orders_Status, '') = ''
		SET @Param_Orders_Status = '0'
		
	IF (SELECT COUNT(COLUMN_NAME) FROM INFORMATION_SCHEMA.COLUMNS 
		WHERE TABLE_NAME = 'V_ORDERS' and data_type='datetime' 
		AND COLUMN_NAME=@Param_Orders_DateDataType) = 0
	BEGIN SET @Param_Orders_DateDataType = 'ADDDATE' END	

	IF ISNULL(@Param_Orders_DateDataType, '') = ''
		SET @Param_Orders_DateDataType = 'Adddate'
		
		SET @Param_Orders_Status = REPLACE(REPLACE(@Param_Orders_Status,'[',''),']','')

   DECLARE @nRowCnt INT = 0
		, @nDebug BIT  = 0  
		, @RowNum    INT  
        , @Proc      NVARCHAR(128) = 'nsp_STD_SORegisterBySKU'
        , @cParamOut NVARCHAR(4000)= ''
        , @cParamIn  NVARCHAR(4000)= '{ "Param_Generic_StorerKey":"'  +@Param_Generic_StorerKey+'"'
                                    + ',"Param_Generic_Facility":"'    +@Param_Generic_Facility+'"'
									+ ' "Param_Orders_DateDataType ":"'    +@Param_Orders_DateDataType +'", '
                                    + ' "Param_Generic_StartDate":"'+CONVERT(NVARCHAR(19),@Param_Generic_StartDate,121)+'",'
									+ ' "Param_Generic_EndDate":"'+CONVERT(NVARCHAR(19),@Param_Generic_EndDate,121)+'", '
									+ ' "Param_Orders_Status":"'    +@Param_Orders_Status+'" '
                                    + ' }'   

	DECLARE @tVarLogId TABLE (LogId INT);
   INSERT dbo.ExecutionLog (ClientId, SP, ParamIn) OUTPUT INSERTED.LogId INTO @tVarLogId VALUES (CASE WHEN @Param_Generic_StorerKey = NULL THEN '' ELSE @Param_Generic_StorerKey END, @Proc, @cParamIn);

IF OBJECT_ID('dbo.ExecDebug','u') IS NOT NULL  
   BEGIN  
      SELECT @nDebug = Debug  
      FROM dbo.ExecDebug WITH (NOLOCK)  
      WHERE UserName = SUSER_SNAME()  
   END  

   DECLARE @Stmt     NVARCHAR(MAX) = ''
         , @Id       INT  = FLOOR(RAND()*99999)
         , @Success  INT  = 1
         , @Err      INT
         , @ErrMsg   NVARCHAR(250)

      SET @Stmt ='
SELECT 
 O.StorerKey        AS  ''01StorerKey''
 ,O.Facility 		 AS  ''02Facility''
 ,O.AddDate 			 AS  ''03AddDate''
 ,O.EditDate 		 AS  ''04EditDate''
 ,O.Type 				 AS  ''05Type'' 
 ,O.ExternOrderKey  AS  ''06ExternOrderKey''
 ,O.OrderKey			 AS  ''07OrderKey''
 ,O.OrderDate 		 AS  ''08OrderDate'' 
 ,OD.LoadKey 			 AS  ''09LoadKey''
 ,OD.MBOLKey 			 AS  ''10MBOLKey'' 
 ,O.DeliveryDate 	 AS  ''11DeliveryDate'' 
 ,RTrim(O.Status)	 AS  ''12Status'' 
 ,O.SOStatus 		 AS  ''13SOStatus'' 
 ,O.Route 			 AS  ''14Route''
 ,O.BillToKey 		 AS  ''15BillToKey'' 
 ,O.B_Company 		 AS  ''16B_Company''
 ,ST.B_Address1 		 AS  ''17B_Address1'' 
 ,O.B_Address2 		 AS  ''18B_Address2'' 
 ,O.B_Address3 		 AS  ''19B_Address3'' 
 ,O.B_City 			 AS  ''20B_City'' 
 ,O.ConsigneeKey 	 AS  ''21ShipTo'' 
 ,O.C_Contact1		 AS  ''22ShipTo_Contact1'' 
 ,O.C_Phone1			 AS  ''23ShipTo_Phone1''
 ,O.C_Company 		 AS  ''24ShipTo_Company'' 
 ,O.C_Address1		 AS  ''25ShipTo_Address1''
 ,O.C_Address2 		 AS  ''26ShipTo_Address2''
 ,O.C_Address3 		 AS  ''27ShipTo_Address3''
 ,O.C_City 			 AS  ''28ShipTo_City''
 ,O.C_STATE			 AS  ''29ShipTo_STATE''
 ,O.C_ZIP				 AS  ''30ShipTo_ZIP''
 ,O.C_ISOCntryCode	 AS  ''31ShipTo_ISOCntryCode''
 ,ST.Company 			 AS  ''32Company''
 ,ST.Address1 	    AS  ''33Address1'' 
 ,ST.Address2 		 AS  ''34Address2'' 
 ,ST.Address3 		 AS  ''35Address3'' 
 ,ST.City 				 AS  ''36City'', 

 SUM ( case when  P.InnerPack  = 0 then 0 ELSE
   (OD.QtyPicked + OD.ShippedQty) / P.Innerpack end ) AS ''37PickedQtyInnerPack'',
 SUM ( case when  P.InnerPack  = 0 then 0 ELSE 
   (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) / P.InnerPack end ) AS ''38OrderQtyInnerpack'',
 SUM ( case when P.InnerPack = 0 then 0 ELSE 
   OD.OpenQty / P.InnerPack end ) AS ''39OpenQtyInnerPack'', 
 SUM ( OD.OpenQty ) AS ''40OpenQtyPC'',
 SUM ( case when P.CaseCnt = 0 then 0 ELSE
   OD.OpenQty / P.CaseCnt end ) AS ''41OpenQtyCS'', 
 sum (  OD.OriginalQty  ) AS ''42OrderQtyPC'', 
 SUM ( case when  P.CaseCnt  = 0 then 0 ELSE 
   (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) / P.CaseCnt end ) AS ''43OrderQtyCS'', 
 SUM ( OD.QtyPicked  + OD.ShippedQty) AS ''44PickedQtyPC'', 
 SUM ( case when  P.CaseCnt  = 0 then 0 ELSE 
   (OD.QtyPicked + OD.ShippedQty) / P.CaseCnt end) AS ''45PickedQtyCS'',
 SUM ( S.STDGROSSWGT * OD.OriginalQty ) AS ''46OrdeGrossWeight'', 
 SUM( S.STDGROSSWGT *  ( OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty ) ) AS ''47ServedGrossWeight'',
 SUM ( S.STDCUBE * OD.OriginalQty ) AS ''48OrderGrossVolume'', 
 SUM( S.STDCUBE *  ( OD.QtyAllocated + OD.QtyPicked  + OD.ShippedQty)  ) AS ''49ServedGrossVolume'',  
 convert ( char ( 60 ) ,O.Notes )  AS ''50Notes'', 
 convert ( char ( 60 ) ,O.Notes2 ) AS ''51Notes2'',
 
 '

  SET @stmt = @stmt + '
 O.OrderGroup      AS ''52OrderGroup'',   
 O.Priority 			AS ''53Priority'', 
 O.UserDefine01    AS ''54UserDefine01'',
 O.UserDefine02    AS ''55UserDefine02'',
 O.UserDefine03    AS ''56UserDefine03'',
 O.UserDefine04    AS ''57UserDefine04'',
 O.UserDefine05		AS ''58UserDefine05'', 
 O.UserDefine06 	AS ''59UserDefine06'', 
 O.UserDefine07 	AS ''60UserDefine07'', 
 O.UserDefine08 	AS ''61UserDefine08'', 
 O.UserDefine09		AS ''62UserDefine09'', 
 O.UserDefine10		AS ''63UserDefine10'', 
 RTRIM(O.Status)	AS ''64Status'',
	CASE 
	when RTRIM(O.Status) = ''1'' then ''PARTIALLY ALLOCATED''
	when RTRIM(O.Status) = ''2'' then '' FULLY ALLOCATED''
	when RTRIM(O.Status) = ''3'' then ''PICK IN PROGRESS''
	when RTRIM(O.Status) = ''5'' then ''PICKED''
	when RTRIM(O.Status) = ''9'' then ''SHIPPED''
	when RTRIM(O.Status) = ''CANC'' then ''CANCELLED''
	else ''OPEN'' end  AS ''65STATUSDesc'',
 O.SOStatus		  AS ''66SOStatus'',
	case 
	when O.SOStatus = ''1'' then ''PARTIALLY ALLOCATED''
	when O.SOStatus = ''2'' then '' FULLY ALLOCATED''
	when O.SOSTatus = ''3'' then ''PICK IN PROGRESS''
	when O.SOSTatus = ''5'' then ''PICKED''
	when O.SOSTatus = ''9'' then ''SHIPPED''
	when O.SOSTatus = ''CANC'' then ''CANCELLED''
	else ''OPEN'' end  as ''67SOSTATUSDesc'',

 O.BuyerPO               AS  ''68BuyerPO''
 ,O.EditWho 				   AS  ''69EditWho''
 ,O.InvoiceNo 			   AS  ''70InvoiceNo'' 
 ,O.ExternPOKey 			AS  ''71ExternPOKey'' 
 ,O.TrackingNo				AS  ''72TrackingNo'' 
 ,ST.CustomerGroupCode 	AS  ''73CustomerGroupCode'' 
 ,O.Door 					   AS  ''74Door''
 ,O.Stop 					   AS  ''75Stop'' 
 ,O.ContainerType 		   AS  ''76ContainerType'' 
 ,S.SUSR3 				   AS  ''77SUSR3''
 ,C.Description 			AS  ''78Description'' 
 ,OD.Lottable01				AS  ''79Lottable01''
 ,O.SHIPPERKEY				AS  ''80ShipperKey'' 
 ,O.DELIVERYNOTE			AS  ''81DeliveryNote''
 ,O.SALESMAN				   AS  ''82Salesman''
 ,O.ecom_single_flag		AS  ''83Ecom_single_flag''
 ,O.InvoiceAmount			AS  ''84InvoiceAmount''
 ,OI.OrderInfo03			   AS  ''85OrderInfo03''
 ,O.Addwho 			      AS  ''86Addwho''
 ,M.ExternMbolKey			AS  ''87PalletKey''		
 ,M.UserDefine05			AS  ''88ContainerKey''		
 ,W.Descr				      AS  ''89WaveDescription''	
 ,PD.LabelNo				   AS  ''90CartonID''
 ,W.WaveKey              AS  ''91WaveKey''
 ,OD.Sku                  AS  ''92SKU''
 ,S.DESCR                AS  ''93SKUDescription''
 ,OD.Userdefine02         AS  ''94LineType'' 
 ,SUM(OD.SHIPPEDQTY)      AS  ''95ShippedQty''
 ,SUM(OD.ADJUSTEDQTY)     AS  ''96AdjustedQty''
 ,SUM(OD.QTYPREALLOCATED) AS  ''97QtyPreAllocated''
 ,SUM(OD.QTYALLOCATED)    AS  ''98QtyAllocated''
 ,SUM(OD.QTYPICKED)       AS  ''99QtyPicked''
 ,PF.CartonType          AS  ''100CartonType''
 ,OD.OrderLineNumber      AS  ''101OrderLineNumber''
 ,OD.ExternLineNo	       AS  ''102ExternLineNumber''
 ,O.IntermodalVehicle    AS  ''103IntermodalVehicle''
 ,O.M_Company			   AS  ''104M_Company''	
 ,STC.Customergroupcode   AS  ''105CustomerGroupCode''
 ,STC.Secondary		   AS  ''106ConsigneeSecondary'' 
 ,STC.Susr4			   AS  ''107ConsigneeSUSR4''	 
 ,MAX(S.Class)		   AS  ''108SKUClass''
 ,STC.MarketSegment	   AS  ''109ConsigneeMarketSegment''
,STC.Susr5,STC.Susr1,STC.Susr2,STC.Susr3, O.xdockPOKey
 ,OD.Userdefine01,OD.Userdefine02,OD.Userdefine03,OD.Userdefine04,OD.Userdefine05
,OD.Userdefine06,OD.Userdefine07,OD.Userdefine08,OD.Userdefine09,OD.Userdefine10
,OD.Lottable02,OD.Lottable03,OD.Lottable04,OD.Lottable05
,OD.Lottable06,OD.Lottable07,OD.Lottable08,OD.Lottable09,OD.Lottable10
,OD.Lottable11,OD.Lottable12,OD.Lottable13,OD.Lottable14,OD.Lottable15

 '

  SET @stmt = @stmt + '
FROM BI.V_ORDERS O 
 JOIN BI.V_STORER ST ON (ST.StorerKey=O.StorerKey)
 JOIN BI.V_ORDERDETAIL OD ON (O.OrderKey=OD.OrderKey AND OD.StorerKey=O.StorerKey)
 JOIN BI.V_SKU S ON (OD.StorerKey=S.StorerKey AND OD.Sku=S.Sku) 
 LEFT OUTER JOIN BI.V_CODELKUP C ON (S.SUSR3=C.Code AND (C.LISTNAME=''PRINCIPAL'' OR C.LISTNAME IS NULL) ) 
 JOIN BI.V_PACK P ON (S.PACKKey=P.PackKey) 
 LEFT OUTER JOIN BI.V_OrderInfo OI ON (OI.Orderkey=OD.OrderKey)
 LEFT OUTER JOIN BI.V_MBOL M ON (O.MBOLKey=M.MbolKey)				
 LEFT OUTER JOIN BI.V_WAVE W ON (O.UserDefine09=W.WaveKey)			
 LEFT OUTER JOIN BI.V_PackHeader PH ON (O.OrderKey=PH.OrderKey)		
 LEFT OUTER JOIN BI.V_PackDetail PD ON (PH.PickSlipNo=PD.PickSlipNo and OD.Sku=PD.sku)	
 LEFT OUTER JOIN BI.V_PackInfo PF ON PF.PickSlipNo = PH.PickSlipNo and PD.cartonno=PF.cartonno
 LEFT OUTER JOIN BI.V_STORER STC (NOLOCK) ON (O.Consigneekey = STC.Storerkey) 



 WHERE 
 ((O.StorerKey=  '''+ @Param_Generic_StorerKey +'''
 AND O.Facility=  '''+ @Param_Generic_Facility +'''
 AND (C.LISTNAME=''PRINCIPAL'' OR C.LISTNAME IS NULL) 
 AND O.'+@Param_Orders_DateDataType+' >= '''+CONVERT(char(19),@Param_Generic_StartDate,121) +'''   
 AND O.'+@Param_Orders_DateDataType+' <=  '''+ CONVERT(char(19),@Param_Generic_EndDate,121) +'''))   
AND O.STATUS IN ('+@Param_Orders_Status+') 


 GROUP BY O.StorerKey
 ,O.Facility
 ,O.AddDate
 ,O.EditDate
 ,O.Type
 ,O.ExternOrderKey
 ,O.OrderKey
 ,O.OrderDate
 ,OD.LoadKey
 ,OD.MBOLKey
 ,O.DeliveryDate
 ,O.Status
 ,O.SOStatus
 ,O.Route
 ,O.BillToKey
 ,O.B_Company
 ,ST.B_Address1
 ,O.B_Address2
 ,O.B_Address3
 ,O.B_City
 ,O.ConsigneeKey
 ,O.C_Company
 ,O.C_Address1
 ,O.C_Address2
 ,O.C_Address3
 ,O.C_City
 ,ST.Company
 ,ST.Address1
 ,ST.Address2
 ,ST.Address3
 ,ST.City
 ,O.UserDefine06
 ,convert ( char ( 60 ) ,O.Notes ) 
 ,convert ( char ( 60 ) ,O.Notes2 ) 
 ,O.OrderGroup
 ,O.Priority
 ,O.UserDefine01
 ,O.UserDefine02
 ,O.UserDefine03
 ,O.UserDefine04
 ,O.BuyerPO
 ,O.EditWho
 ,O.UserDefine06
 ,O.InvoiceNo
 ,O.ExternPOKey
 ,ST.CustomerGroupCode
 ,O.Door
 ,O.Stop
 ,O.ContainerType
 ,S.SUSR3
 ,C.Description
 ,O.UserDefine09
 ,O.Addwho
 ,O.SHIPPERKEY
 ,OD.LOTTABLE01
 ,O.C_Contact1
 ,O.C_Phone1
 ,O.C_STATE
 ,O.C_ZIP
 ,O.C_ISOCntryCode
 ,O.TrackingNo
 ,O.DELIVERYNOTE
 ,O.SALESMAN
 ,O.ecom_single_flag
 ,O.invoiceamount
 ,O.UserDefine05
 ,O.UserDefine10
 ,O.UserDefine07
 ,O.UserDefine08
 ,OI.OrderInfo03 
 ,M.ExternMbolKey 
 ,W.Descr 
 ,M.UserDefine05
 ,W.Descr 
 ,PD.LabelNo	
 ,W.WaveKey
 ,OD.Sku 
 ,S.DESCR
 ,OD.Userdefine02    
 ,PF.CartonType
 ,OD.OrderLineNumber
 ,OD.ExternLineNo
 ,O.IntermodalVehicle
 ,O.M_Company	
 ,STC.Customergroupcode   
 ,STC.Secondary		  
 ,STC.Susr4		
 ,STC.MarketSegment,STC.Susr5,STC.Susr1,STC.Susr2,STC.Susr3, O.xdockPOKey
 ,OD.Userdefine01,OD.Userdefine02,OD.Userdefine03,OD.Userdefine04,OD.Userdefine05
,OD.Userdefine06,OD.Userdefine07,OD.Userdefine08,OD.Userdefine09,OD.Userdefine10
,OD.Lottable02,OD.Lottable03,OD.Lottable04,OD.Lottable05
,OD.Lottable06,OD.Lottable07,OD.Lottable08,OD.Lottable09,OD.Lottable10
,OD.Lottable11,OD.Lottable12,OD.Lottable13,OD.Lottable14,OD.Lottable15


  OPTION (RECOMPILE);
 '

 IF @nDebug = 1   
   BEGIN  
   PRINT @Stmt  
      PRINT SUBSTRING(@Stmt, 4001, 8000)  
      PRINT SUBSTRING(@Stmt, 8001,12000)    
      PRINT SUBSTRING(@Stmt, 12001,16000)    
   END 
--print @Stmt
  EXEC sp_ExecuteSql @Stmt;
   SET @nRowCnt = @@ROWCOUNT
   SET @cParamOut = '{ "Stmt": "'+@Stmt+'" }';
   
   UPDATE dbo.ExecutionLog SET TimeEnd = GETDATE(), RowCnt = @nRowCnt, ParamOut = @cParamOut WHERE LogId = (SELECT TOP 1 LogId FROM @tVarLogId);

END -- Procedure 

GO