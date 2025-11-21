SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***********************************************************************************************/  
--PH_JReport - SORegister - Stored Procedure (PHWMS) https://jiralfl.atlassian.net/browse/WMS-20217
/* Updates:                                                                                    */  
/* Date            Author		Ver.    Purposes                                                */  
/* 12-JUL-2022     JAM			1.0     For Operations daily report                            */
/* 07/13/2022      Crisnah      1.1     Migrate also to PHWMS. this is usual daily report from operations*/ 
/* 03/08/2023      JayCanete    1.2     Add condition https://jiralfl.atlassian.net/browse/WMS-21816 */ 
/* 11-MAY-2023	   JarekLIM		1.5		Add Column and Add BI.V_DM_STORER	https://jiralfl.atlassian.net/browse/WMS-21816	*/
/* 15-June-2023	   JarekLIM		1.6		Add Column Customergroupcode	https://jiralfl.atlassian.net/browse/WMS-22848	*/
/* 20-JULY-2023	   CRISNAH		1.7		PH_LogiReport - Alter Stored Procedure - SORegister - 14Jun2023	https://jiralfl.atlassian.net/browse/WMS-22848	*/
/***********************************************************************************************/  
-- Test EXEC BI.nsp_STD_SORegister 'UNILEVER', 'UMDC', 'EDITDATE','2022-03-17', '2022-03-18','''9'''
 --      EXEC BI.nsp_STD_SORegister NULL, NULL, NULL, NULL
 --      EXEC BI.nsp_STD_SORegister '', '', '', ''
CREATE                   PROC [BI].[nsp_STD_SORegister]
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
		SET @Param_Orders_Status = '''0'''

	IF (SELECT COUNT(COLUMN_NAME) FROM INFORMATION_SCHEMA.COLUMNS 
		WHERE TABLE_NAME = 'V_ORDERS' and data_type='datetime' 
		AND COLUMN_NAME=@Param_Orders_DateDataType) = 0
	BEGIN SET @Param_Orders_DateDataType = 'ADDDATE' END	

		SET @Param_Orders_Status = REPLACE(REPLACE(@Param_Orders_Status,'[',''),']','')

   DECLARE  @Debug	BIT = 0
		 , @LogId   INT
         , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
         , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'') --NAME OF SP
         , @cParamOut NVARCHAR(4000)= ''
			, @cParamIn  NVARCHAR(4000)= '{ "Param_Generic_StorerKey":"'  +@Param_Generic_StorerKey+'"'
                                    + ',"Param_Generic_Facility":"'    +@Param_Generic_Facility+'"'
									+ ' "Param_Orders_DateDataType ":"'    +@Param_Orders_DateDataType +'", '
                                    + ' "Param_Generic_StartDate":"'+CONVERT(NVARCHAR(19),@Param_Generic_StartDate,121)+'",'
									+ ' "Param_Generic_EndDate":"'+CONVERT(NVARCHAR(19),@Param_Generic_EndDate,121)+'", '
									+ ' "Param_Orders_Status":"'    +@Param_Orders_Status+'" '
                                    + ' }'

   EXEC BI.dspExecInit @ClientId = @PARAM_GENERIC_StorerKey
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;

DECLARE @Stmt NVARCHAR(MAX) = '' -- for dynamic SQL only
	
/****** START YOUR SELECT STATEMENT HERE USE @Stmt FOR DYNAMIC SQL ******/

      SET @Stmt ='
SELECT 
 AL2.StorerKey        AS  ''01StorerKey''
,AL2.Facility 			 AS  ''02Facility''
,AL2.AddDate 			 AS  ''03AddDate''
,AL2.EditDate 			 AS  ''04EditDate''
,AL2.Type 				 AS  ''05Type''
,AL2.ExternOrderKey 	 AS  ''06ExternOrderKey''
,AL2.OrderKey			 AS  ''07OrderKey''
,AL2.OrderDate 		 AS  ''08OrderDate''
,AL1.LoadKey 			 AS  ''09LoadKey''
,AL1.MBOLKey 			 AS  ''10MBOLKey''
,AL2.DeliveryDate 	 AS  ''11DeliveryDate''
,RTrim(AL2.Status)	 AS  ''12Status''
,AL2.SOStatus 			 AS  ''13SOStatus''
,AL2.Route 			    AS  ''14Route''
,AL2.BillToKey 		 AS  ''15BillToKey''
,AL2.B_Company 		 AS  ''16B_Company''
,AL3.B_Address1 		 AS  ''17B_Address1''
,AL2.B_Address2 		 AS  ''18B_Address2''
,AL2.B_Address3 		 AS  ''19B_Address3''
,AL2.B_City 			 AS  ''20B_City''
,AL2.ConsigneeKey     AS  ''21ShipTo''
,AL2.C_Contact1		 AS  ''22ShipTo_Contact1''
,AL2.C_Phone1			 AS  ''23ShipTo_Phone1''
,AL2.C_Company 		 AS  ''24ShipTo_Company'' 
,AL2.C_Address1		 AS  ''25ShipTo_Address1''
,AL2.C_Address2 		 AS  ''26ShipTo_Address2''
,AL2.C_Address3 		 AS  ''27ShipTo_Address3''
,AL2.C_City 			 AS  ''28ShipTo_City''
,AL2.C_STATE			 AS  ''29ShipTo_STATE'' 
,AL2.C_ZIP				 AS  ''30ShipTo_ZIP'' 
,AL2.C_ISOCntryCode	 AS  ''31ShipTo_ISOCntryCode'' 
,AL3.Company 			 AS  ''32Company''
,AL3.Address1 			 AS  ''33Address1''
,AL3.Address2 			 AS  ''34Address2''
,AL3.Address3 			 AS  ''35Address3''
,AL3.City 				 AS  ''36City'',
                      
 SUM (CASE WHEN  AL6.InnerPack  = 0 then 0 ELSE 
   (AL1.QtyPicked + AL1.ShippedQty) / AL6.Innerpack end ) AS ''37PickedQtyInnerPack'',
 SUM (CASE WHEN  AL6.InnerPack  = 0 then 0 ELSE 
   ( AL1.QtyAllocated + AL1.QtyPicked + AL1.ShippedQty) / AL6.InnerPack end ) AS ''38OrderQtyInnerpack'',
 SUM (CASE WHEN AL6.InnerPack = 0 then 0 ELSE 
    AL1.OpenQty / AL6.InnerPack end ) AS ''39OpenQtyInnerPack'', 
 SUM ( AL1.OpenQty ) AS ''40OpenQtyPC'',
 SUM (CASE WHEN AL6.CaseCnt = 0 then 0 ELSE 
    AL1.OpenQty / AL6.CaseCnt end ) AS ''41OpenQtyCS'', 
 SUM (  AL1.OriginalQty  ) AS ''42OrderQtyPC'', 
 SUM (CASE WHEN  AL6.CaseCnt  = 0 then 0 ELSE
   ( AL1.QtyAllocated + AL1.QtyPicked + AL1.ShippedQty) / AL6.CaseCnt end ) AS ''43OrderQtyCS'', 
 SUM ( AL1.QtyPicked  + AL1.ShippedQty) AS ''44PickedQtyPC'', 
 SUM (CASE WHEN  AL6.CaseCnt  = 0 then 0 ELSE 
   (AL1.QtyPicked + AL1.ShippedQty) / AL6.CaseCnt end) AS ''45PickedQtyCS'',
 SUM ( AL4.STDGROSSWGT * AL1.OriginalQty ) AS ''46OrdeGrossWeight'', 
 SUM( AL4.STDGROSSWGT *  ( AL1.QtyAllocated + AL1.QtyPicked + AL1.ShippedQty ) ) AS ''47ServedGrossWeight'',
 SUM ( AL4.STDCUBE * AL1.OriginalQty ) AS ''48OrderGrossVolume'', 
 SUM( AL4.STDCUBE *  ( AL1.QtyAllocated + AL1.QtyPicked  + AL1.ShippedQty)  ) AS ''49ServedGrossVolume'',  
 CONVERT ( char ( 60 ) ,AL2.Notes )  AS ''50Notes'', 
 CONVERT ( char ( 60 ) ,AL2.Notes2 ) AS ''51Notes2'', 
 '
 
 SET @stmt = @stmt + '
 AL2.OrderGroup      AS ''52OrderGroup'' 
,AL2.Priority 			AS ''53Priority''
,AL2.UserDefine01 	AS ''54UserDefine01''
,AL2.UserDefine02 	AS ''55UserDefine02''
,AL2.UserDefine03 	AS ''56UserDefine03''
,AL2.UserDefine04 	AS ''57UserDefine04''
,AL2.UserDefine05		AS ''58UserDefine05'' 
,AL2.UserDefine06 	AS ''59UserDefine06'' 
,AL2.UserDefine07 	AS ''60UserDefine07'' 
,AL2.UserDefine08 	AS ''61UserDefine08'' 
,AL2.UserDefine09		AS ''62UserDefine09''
,AL2.UserDefine10		AS ''63UserDefine10'' 
,RTRIM(AL2.Status)	AS ''64Status'',
	CASE 
	WHEN RTRIM(AL2.Status) = ''1'' THEN ''PARTIALLY ALLOCATED''
	WHEN RTRIM(AL2.Status) = ''2'' THEN '' FULLY ALLOCATED''
	WHEN RTRIM(AL2.Status) = ''3'' THEN ''PICK IN PROGRESS''
	WHEN RTRIM(AL2.Status) = ''5'' THEN ''PICKED''
	WHEN RTRIM(AL2.Status) = ''9'' THEN ''SHIPPED''
	WHEN RTRIM(AL2.Status) = ''CANC'' THEN ''CANCELLED''
	ELSE ''OPEN'' end  AS ''65STATUSDesc'',
 AL2.SOStatus		    AS ''66SOStatus'',
	CASE 
	WHEN AL2.SOStatus = ''1'' THEN ''PARTIALLY ALLOCATED''
	WHEN AL2.SOStatus = ''2'' THEN '' FULLY ALLOCATED''
	WHEN AL2.SOSTatus = ''3'' THEN ''PICK IN PROGRESS''
	when AL2.SOSTatus = ''5'' then ''PICKED''
	WHEN AL2.SOSTatus = ''9'' THEN ''SHIPPED''
	WHEN AL2.SOSTatus = ''CANC'' THEN ''CANCELLED''
	ELSE ''OPEN'' end  as ''67SOSTATUSDesc'',

 AL2.BuyerPO               AS  ''68BuyerPO''
,AL2.EditWho 				   AS  ''69EditWho''
,AL2.InvoiceNo 			   AS  ''70InvoiceNo'' 
,AL2.ExternPOKey 			   AS  ''71ExternPOKey''
,AL2.TrackingNo				AS  ''72TrackingNo'' 
,AL3.CustomerGroupCode 	   AS  ''73CustomerGroupCode'' 
,AL2.Door 					   AS  ''74Door'' 
,AL2.Stop 					   AS  ''75Stop'' 
,AL2.ContainerType 		   AS  ''76ContainerType''
,AL4.SUSR3 				      AS  ''77SUSR3''
,AL5.Description 			   AS  ''78Description'' 
,AL1.Lottable01				AS  ''79Lottable01'' 
,AL2.SHIPPERKEY				AS  ''80ShipperKey'' 
,AL2.DELIVERYNOTE			   AS  ''81DeliveryNote''
,AL2.SALESMAN				   AS  ''82Salesman''
,AL2.ecom_single_flag		AS  ''83Ecom_single_flag''
,AL2.InvoiceAmount			AS  ''84InvoiceAmount''	
,AL7.OrderInfo03			   AS  ''85OrderInfo03'' 
,AL2.Addwho 			      AS  ''86Addwho''
,AL8.ExternMbolKey			AS  ''87PalletKey''			
,AL8.UserDefine05				AS  ''88ContainerKey''		
,AL9.Descr						AS  ''89WaveDescription''	
,AL2.M_Company				   AS  ''90CartonID''			

,SUM(AL1.ShippedQty)			AS  ''91ShippedQty_PC''	
,SUM(AL1.ShippedQty/NULLIF(AL6.CaseCnt,0))			AS  ''92ShippedQty_CS''			
,SUM(AL1.AdjustedQty)			AS  ''93AdjustedQty_PC''				
,SUM(AL1.AdjustedQty/NULLIF(AL6.CaseCnt,0))			AS  ''94AdjustedQty_CS''			
,SUM(AL1.QtyPreAllocated)		AS  ''95QtyPreAllocated_PC''			
,SUM(AL1.QtyPreAllocated/NULLIF(AL6.CaseCnt,0))		AS  ''96QtyPreAllocated_CS''			
,SUM(AL1.QtyAllocated)			AS  ''97QtyAllocated_PC''					
,SUM(AL1.QtyAllocated/NULLIF(AL6.CaseCnt,0))			AS  ''98QtyAllocated_CS''					
,SUM(AL1.QtyPicked)				AS  ''99QtyPicked_PC''		
,SUM(AL1.QtyPicked/NULLIF(AL6.CaseCnt,0))				AS  ''100QtyPicked_CS''	
,MAX(AL12.Pickheaderkey)   as ''101PickSlipNo'' 
,AL10.Adddate	as ''102PackingAddDate''
,AL10.Editdate	as ''103PackingEditDate''
, case when AL10.Status = ''9'' then  AL10.Editdate else NULL end as ''104PackConfirmDate''
,AL2.IntermodalVehicle
,AL13.Secondary							as ''106ConsigneeSecondary'' 
,AL13.Susr4							    as ''107ConsigneeSUSR4''	 
,MAX(AL4.Class)							    as ''108SKUClass''
,AL13.MarketSegment	   AS  ''109ConsigneeMarketSegment''
,AL13.Customergroupcode as ''Customergroupcode''
, AL2.xdockPOKey,AL13.Susr5,AL13.Susr1,AL13.Susr2,AL13.Susr3
'

 SET @stmt = @stmt + '
 FROM BI.V_ORDERS AL2 (NOLOCK)
 JOIN BI.V_STORER AL3 (NOLOCK) ON (AL3.StorerKey=AL2.StorerKey)
 JOIN BI.V_ORDERDETAIL AL1 (NOLOCK) ON (AL2.OrderKey=AL1.OrderKey)
 JOIN BI.V_SKU AL4 (NOLOCK) ON (AL1.StorerKey=AL4.StorerKey AND AL1.Sku=AL4.Sku) 
 JOIN BI.V_PACK AL6 (NOLOCK) ON (AL4.PACKKey=AL6.PackKey) 
 LEFT OUTER JOIN BI.V_CODELKUP AL5 (NOLOCK) ON (AL4.SUSR3=AL5.Code AND AL5.LISTNAME=''PRINCIPAL'') 
 LEFT OUTER JOIN BI.V_OrderInfo AL7 (NOLOCK) ON (AL7.Orderkey=AL1.OrderKey)
 LEFT JOIN BI.V_MBOL AL8 (NOLOCK) ON  (AL2.MBOLKey=AL8.MbolKey)						
 LEFT OUTER JOIN BI.V_WAVE AL9 (NOLOCK) ON  (AL2.UserDefine09=AL9.WaveKey)					
 LEFT OUTER JOIN BI.V_PackHeader AL10 (NOLOCK) ON (AL2.OrderKey=AL10.OrderKey AND AL2.Storerkey = AL10.Storerkey)			
 -- LEFT OUTER JOIN BI.V_PackDetail AL11 (NOLOCK) ON (AL10.PickSlipNo=AL11.PickSlipNo and AL1.Sku=AL11.sku)	
 LEFT OUTER JOIN BI.V_PICKHEADER AL12 (NOLOCK) ON (AL2.OrderKey = AL12.OrderKey) 
 LEFT JOIN BI.V_STORER AL13 (NOLOCK) ON (AL2.Consigneekey = AL13.Storerkey) 

 WHERE ((AL2.StorerKey=  '''+ @Param_Generic_StorerKey +'''
 AND AL2.Facility= '''+ @Param_Generic_Facility +'''
 AND AL2.'+@Param_Orders_DateDataType+' >= '''+CONVERT(char(19),@Param_Generic_StartDate,121) +'''   
 AND AL2.'+@Param_Orders_DateDataType+' <=  '''+ CONVERT(char(19),@Param_Generic_EndDate,121) +'''))   
AND AL2.STATUS IN ('+@Param_Orders_Status+') 
 GROUP BY
 AL2.StorerKey
,AL2.Facility
,AL2.AddDate
,AL2.EditDate
,AL2.Type
,AL2.ExternOrderKey
,AL2.OrderKey
,AL2.OrderDate
,AL1.LoadKey
,AL1.MBOLKey 
,AL2.DeliveryDate
,AL2.Status
,AL2.SOStatus 
,AL2.Route
,AL2.BillToKey
,AL2.B_Company
,AL3.B_Address1
,AL2.B_Address2 
,AL2.B_Address3
,AL2.B_City 
,AL2.ConsigneeKey
,AL2.C_Company
,AL2.C_Address1
,AL2.C_Address2 
,AL2.C_Address3
,AL2.C_City
,AL3.Company 
,AL3.Address1
,AL3.Address2
,AL3.Address3
,AL3.City
,AL2.UserDefine06 
,CONVERT ( char ( 60 ) ,AL2.Notes ) 
,CONVERT ( char ( 60 ) ,AL2.Notes2 )  
,AL2.OrderGroup
,AL2.Priority
,AL2.UserDefine01
,AL2.UserDefine02 
,AL2.UserDefine03
,AL2.UserDefine04
,AL2.BuyerPO
,AL2.EditWho
,AL2.UserDefine06
,AL2.InvoiceNo
,AL2.ExternPOKey
,AL3.CustomerGroupCode
,AL2.Door
,AL2.Stop
,AL2.ContainerType 
,AL4.SUSR3
,AL5.Description
,AL2.UserDefine09
,AL2.Addwho 
,AL2.SHIPPERKEY 
,AL1.LOTTABLE01
,AL2.C_Contact1
,AL2.C_Phone1
,AL2.C_STATE
,AL2.C_ZIP
,AL2.C_ISOCntryCode
,AL2.TrackingNo
,AL2.DELIVERYNOTE 
,AL2.SALESMAN
,AL2.ecom_single_flag
,AL2.invoiceamount
,AL2.UserDefine05 
,AL2.UserDefine10 
,AL2.UserDefine07
,AL2.UserDefine08 
,AL7.OrderInfo03
, AL8.ExternMbolKey		
, AL9.Descr					
, AL8.UserDefine05		
, AL9.Descr	
, AL2.M_Company
--, AL11.LabelNo		
-- ,AL12.Pickheaderkey
,AL10.Adddate
,AL10.Editdate
,AL10.Status
,AL2.IntermodalVehicle
,AL13.Secondary		
,AL13.Susr4							 
-- ,AL4.Class
,AL13.MarketSegment	
,AL13.Customergroupcode, AL2.xdockPOKey,AL13.Susr5,AL13.Susr1,AL13.Susr2,AL13.Susr3

'

/*************************** FOOTER *******************************/
   EXEC BI.dspExecStmt @Stmt = @stmt
   , @LogId = @LogId
   , @Debug = @Debug;


END -- Procedure 


GO