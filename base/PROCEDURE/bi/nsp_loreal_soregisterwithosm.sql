SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***********************************************************************
TITLE: PH_LogiReport - Customized Reports - OrderProcessing [SP] https://jiralfl.atlassian.net/browse/WMS-21816 

DATE				VER		CREATEDBY		PURPOSE
15-FEB-2023			1.0		PCN				CONVERT SCRIPT TO SP
07-MAR-2023			1.1		JayCanete		Create in ph_dm prod & uat.
************************************************************************/

CREATE   PROC [BI].[nsp_LOREAL_SORegisterwithOSM] --NAME OF SP */	
			 @PARAM_GENERIC_EditDateFrom  DATETIME
			, @PARAM_GENERIC_EditDateTo DATETIME

AS
BEGIN
 SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

		
	IF DATEDIFF(HOUR,@PARAM_GENERIC_EditDateFrom,@PARAM_GENERIC_EditDateTo) > 24
		SET @PARAM_GENERIC_EditDateTo = DATEADD(HOUR,90,@PARAM_GENERIC_EditDateFrom)


   DECLARE @Debug	BIT = 0
		 , @LogId   INT
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'')
       , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= '{ '
                                    + '"PARAM_GENERIC_EditDateFrom":"'+CONVERT(NVARCHAR(19),@PARAM_GENERIC_EditDateFrom,121)+'", '
                                    + '"PARAM_GENERIC_EditDateTo":"'+CONVERT(NVARCHAR(19),@PARAM_GENERIC_EditDateTo,121)+'" '
                                    + ' }'

   EXEC BI.dspExecInit @ClientId = 'P001'
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;
	DECLARE @Stmt NVARCHAR(MAX) = '' -- for dynamic SQL only
	
/****** START YOUR SELECT STATEMENT HERE USE @Stmt FOR DYNAMIC SQL ******/
set @Stmt = '
SELECT 
  AL2.UserDefine07 AS ''01ProcessingDate'',
  AL2.IntermodalVehicle as ''02Forwarded'', 
  AL2.UserDefine06 as ''03LoadingDate'',  	
  AL2.StorerKey as ''04Storerkey'', 
  AL2.Facility as ''05Facility'', 
  AL2.AddDate as ''06OrderTransmissionDate'', 
  AL2.EditDate as ''07EditDate'', 
  AL2.Type as ''08OrderType'', 
  AL2.ExternOrderKey as ''09SONumber'', 
  AL2.OrderKey as ''10Orderkey'', 
  AL1.LoadKey as ''11Loadkey'', 
  AL1.MBOLKey as ''12MBOLKey'',
  AL2.UserDefine09 AS ''13Wavekey'',
  AL2.OrderDate as ''14OrderDate'', 
  AL2.DeliveryDate as ''15DeliveryDate'', 
  case AL2.Status 
	when ''0'' then ''NOT ALLOCATED''
	when ''1'' then ''For Picking''
	when ''2'' then ''For Picking''
	when ''3'' then ''For Checking''
	when ''5'' then ''Completely Processed''
	when ''9'' then ''Dispatched''
	when ''CANC'' then ''CANCELLED''
  end as ''16Status'',
  case AL2.SOStatus
	when ''0'' then ''NOT ALLOCATED''
	when ''1'' then ''PARTIALLY ALLOCATED''
	when ''2'' then ''FULLY ALLOCATED''
	when ''3'' then ''PICK IN PROGRESS''
	when ''5'' then ''PICKED''
	when ''9'' then ''SHIPPED''
	when ''CANC'' then ''CANCELLED''
  end as ''17SOStatus'',
  AL2.Route as ''18Route'' ,
  AL2.ConsigneeKey as ''19ShipTo'', 
  AL2.C_Company as ''20ShipToName'', 
  AL2.C_Address1 as ''21C_Address1'', 
  AL2.C_Address2 as ''22C_Address1'', 
  AL2.C_Address3 as ''23C_Address1'', 
  AL2.C_City as ''24C_City'', 
  AL3.Company as ''25StorerCompany'', 
  AL3.Address1 as ''26StorerAddress1'', 
  AL3.Address2 as ''27StorerAddress2'', 
  AL3.Address3 as ''28StorerAddress3'', 
  AL3.City as ''29StorerCity'', 
  AL2.BillToKey as ''30BillTo'', 
  AL2.B_Company as ''31BillToName'', 
  AL3.B_Address1 as ''32B_Address1'', 
  AL2.B_Address1 as ''33B_Address2'', 
  AL2.B_Address3 as ''34B_Address3'', 
  AL2.B_City as ''35B_City'', 
  AL2.BuyerPO as ''36BuyerPO'', 
  AL2.InvoiceNo as ''37InvoiceNo'', 
  SUM (AL1.OpenQty) as ''38OpenQtyPC'', 
  SUM (case when AL6.CaseCnt = 0 then 0 else AL1.OpenQty / AL6.CaseCnt end) as ''39OpenQtyCS'', 
  sum (AL1.OriginalQty) as ''40OrderQtyPC'', 
  SUM (case when AL6.CaseCnt = 0 then 0 else (AL1.QtyAllocated + AL1.QtyPicked + AL1.ShippedQty) / AL6.CaseCnt end) as ''41OrderQtyCS'', 
  SUM (AL1.QtyAllocated + AL1.QtyPicked + AL1.ShippedQty) as ''42ServedQtyPC'', 
  SUM (case when AL6.CaseCnt = 0 then 0 else (AL1.QtyAllocated + AL1.QtyPicked + AL1.ShippedQty) / AL6.CaseCnt end) as ''43ServedQtyCS'', 
  SUM (AL4.STDGROSSWGT * AL1.OriginalQty) as ''44OrderGrossWeight'', 
  SUM(AL4.STDGROSSWGT * (AL1.QtyAllocated + AL1.QtyPicked + AL1.ShippedQty)) as ''45ServedGrossWeight'', 
  SUM (AL4.STDCUBE * AL1.OriginalQty) as ''46OrderGrossVolume'', 
  SUM(AL4.STDCUBE * (AL1.QtyAllocated + AL1.QtyPicked + AL1.ShippedQty)) as ''47ServedGrossVolume'', 
  convert (char (60), AL2.Notes) as ''48Notes'', 
  convert (char (60), AL2.Notes2) as ''49Notes2'', 
  AL2.OrderGroup as ''50OrderGroup'', 
  AL2.Priority as ''51Priority'', 
  AL2.UserDefine01 as ''52OrderUserdefine01'', 
  AL2.UserDefine02 as ''53OrderUserdefine02'', 
  AL2.UserDefine03 as ''54OrderUserdefine03'', 
  AL2.UserDefine04 as ''55OrderUserdefine04'', 
  AL2.EditWho as ''56ModifiedBy'', 
  AL2.ExternPOKey as ''57ExternPOKey'', 
  AL3.CustomerGroupCode as ''58CustomerGroupCode'', 
  AL2.Door as ''59Door'', 
  AL2.Stop as ''60Stop'', 
  AL4.SUSR3 as ''61Principal'', 
  AL5.Description as ''62PrincipalName'',
  AL2.ContainerType as ''63ContainerType'',
  Count( distinct isnull(AL1.LoadKey,'''')+isnull(AL2.ExternOrderKey,'''') ) as ''64CountLoadkey'',
  getdate() as ''65Today'',
  SUM (AL1.QtyAllocated + AL1.QtyPicked + AL1.ShippedQty) -SUM (AL1.QtyAllocated + AL1.QtyPicked + AL1.ShippedQty)as ''66UnservedQtyPC'',
  case when (AL2.UserDefine06 is null or AL2.UserDefine06 = ''1900-01-01 00:00:00'') then ''FOR PLANNING'' else DATENAME(WEEKDAY, AL2.UserDefine06) end as ''67LD-WeekDay'',
  case when (AL2.UserDefine06 is null or AL2.UserDefine06 = ''1900-01-01 00:00:00'') then ''0'' else 1 end as ''68SOwithLD'',
  format(AL2.UserDefine06, ''dd-MMM'') as ''ComputedLoadingDate''
FROM 
  BI.V_ORDERS AL2 (nolock)
  JOIN BI.V_ORDERDETAIL AL1 (nolock) on AL1.OrderKey = AL2.OrderKey AND AL1.Storerkey = AL2.Storerkey 
  JOIN BI.V_STORER AL3 (nolock) on AL2.StorerKey = AL3.StorerKey 
  JOIN BI.V_SKU AL4 (nolock) on AL1.Sku = AL4.Sku AND AL4.StorerKey = AL1.StorerKey
  JOIN BI.V_PACK AL6 (nolock) on AL4.PACKKey = AL6.PackKey 
  LEFT JOIN BI.V_CODELKUP AL5 ON (AL4.SUSR3 = AL5.Code) 
  '
  SET @Stmt = @Stmt + '
WHERE 
      AL2.StorerKey = ''P001'' 
      AND AL2.Facility = ''P001'' 
      AND AL2.Status IN (''0'', ''1'', ''2'', ''3'', ''5'') 
      AND (
        AL5.LISTNAME = ''PRINCIPAL'' 
        OR AL5.LISTNAME IS NULL
      ) 
	  AND AL2.EditDate BETWEEN '''+CONVERT(NVARCHAR(19),@Param_Generic_EditDateFrom,121)+'''  
      AND '''+CONVERT(NVARCHAR(19),@Param_Generic_EditDateTo,121)+''' 

GROUP BY 
  AL2.StorerKey, 
  AL2.Facility, 
  AL2.AddDate, 
  AL2.EditDate, 
  AL2.Type, 
  AL2.ExternOrderKey, 
  AL2.OrderKey, 
  AL2.OrderDate, 
  AL1.LoadKey, 
  AL1.MBOLKey, 
  AL2.DeliveryDate, 
  AL2.Status, 
  AL2.SOStatus, 
  AL2.Route, 
  AL2.BillToKey, 
  AL2.B_Company, 
  AL3.B_Address1, 
  AL2.B_Address1, 
  AL2.B_Address3, 
  AL2.B_City, 
  AL2.ConsigneeKey, 
  AL2.C_Company, 
  AL2.C_Address1, 
  AL2.C_Address2, 
  AL2.C_Address3, 
  AL2.C_City, 
  AL3.Company, 
  AL3.Address1, 
  AL3.Address2, 
  AL3.Address3, 
  AL3.City, 
  AL2.UserDefine06, 
  convert (
    char (60), 
    AL2.Notes
  ), 
  convert (
    char (60), 
    AL2.Notes2
  ), 
  AL2.OrderGroup, 
  AL2.Priority, 
  AL2.UserDefine01, 
  AL2.UserDefine02, 
  AL2.UserDefine03, 
  AL2.UserDefine04, 
  AL2.BuyerPO, 
  AL2.EditWho, 
  AL2.InvoiceNo, 
  AL2.ExternPOKey, 
  AL3.CustomerGroupCode, 
  AL2.Door, 
  AL2.Stop, 
  AL2.ContainerType, 
  AL4.SUSR3, 
  AL5.Description, 
  AL2.UserDefine09, 
  AL2.IntermodalVehicle, 
  AL2.UserDefine07
      '

/*************************** FOOTER *******************************/
   EXEC BI.dspExecStmt @Stmt = @Stmt
   , @LogId = @LogId
   , @Debug = @Debug;

END


GO