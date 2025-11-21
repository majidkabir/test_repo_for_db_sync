SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***********************************************************************************************/  
--PH_JReport - IssuanceRegister - Stored Procedure (PHWMS) https://jiralfl.atlassian.net/browse/WMS-20217
/* Updates:                                                                                    */  
/* Date            Author      Ver.    Purposes                                                */  
/* 07/12/2022      JAM         1.0     Migrate also to PHWMS. this is usual daily report from operations*/ 
/* 07/13/2022      Crisnah     1.1     Migrate also to PHWMS. this is usual daily report from operations*/ 
/* 13/04/2023	   Crisnah	   1.2	Add On OD.ExternLineNo column condition https://jiralfl.atlassian.net/browse/WMS-22167 */
/* 04/10/2023      JAM		   1.3  Added Loc.LocatioRoom - FONTERRA Enhancement Request       */
/***********************************************************************************************/ 
-- Test EXEC [BI].[nsp_STD_IssuanceRegister] 'YLEO', 'MERIT','2022-07-12', '2022-07-13'
CREATE       PROC [BI].[nsp_STD_IssuanceRegister] 
     @Param_Generic_Storerkey nvarchar(50)
	, @Param_Generic_Facility nvarchar(50) 
	, @Param_Generic_EditDateFrom datetime 
	, @Param_Generic_EditDateTo datetime 
AS
BEGIN
 SET NOCOUNT ON       ;   SET ANSI_DEFAULTS OFF  ;   SET QUOTED_IDENTIFIER OFF;   SET CONCAT_NULL_YIELDS_NULL OFF;
   SET ANSI_NULLS ON    ;   SET ANSI_WARNINGS ON   ;

   IF ISNULL(@PARAM_GENERIC_StorerKey, '') = ''
		   SET @PARAM_GENERIC_StorerKey = ''
   IF ISNULL(@PARAM_GENERIC_Facility, '') = ''
		   SET @PARAM_GENERIC_Facility = ''
	IF ISNULL(@PARAM_GENERIC_EditDateFrom, '') = ''
		   SET @PARAM_GENERIC_EditDateFrom = CONVERT(VARCHAR(25), GETDATE()-32, 121)
	IF ISNULL(@PARAM_GENERIC_EditDateTo, '') = ''
	       SET @PARAM_GENERIC_EditDateTo= GETDATE()
		
	SET @PARAM_GENERIC_StorerKey = TRIM(@PARAM_GENERIC_StorerKey)
	SET @PARAM_GENERIC_Facility = TRIM(@PARAM_GENERIC_Facility)

   DECLARE @nRowCnt INT = 0
	      , @Debug	  BIT = 0
	      , @LogId     INT
		   , @LinkSrv NVARCHAR(128) = ''
         , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
         , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'')
         , @cParamOut NVARCHAR(4000)= ''
         , @cParamIn  NVARCHAR(4000)= '{ "PARAM_GENERIC_StorerKey":"'    +@PARAM_GENERIC_StorerKey+'"'
                                     + '"PARAM_GENERIC_Facility":"'    +@PARAM_GENERIC_Facility+'"'
									 + ', "PARAM_GENERIC_EditDateFrom":"'+CONVERT(NVARCHAR(19),@PARAM_GENERIC_EditDateFrom,121)+'"'
									 + ', "PARAM_GENERIC_EditDateTo":"'+CONVERT(NVARCHAR(19),@PARAM_GENERIC_EditDateTo,121)+'"'
                                     + ' }'


   IF EXISTS (SELECT 1 FROM dbo.ExecutionLog WITH (NOLOCK)
              WHERE ClientID = @PARAM_GENERIC_StorerKey
              AND SP = @Proc
              AND TimeEnd IS NULL
              AND TimeStart > DATEADD(hh, -1, GETDATE())
              HAVING COUNT(1) > 2)
   THROW 50000, 'Multiple Execution detected, Please try later', 1

										
   	EXEC BI.dspExecInit @ClientId = @PARAM_GENERIC_StorerKey
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;

   DECLARE @Stmt NVARCHAR(MAX) = ''

      SET @Stmt ='
SELECT 
O.StorerKey                           as ''01Storerkey''       , 
O.Facility                            as ''02Facility''        , 
convert(char( 10) ,O.AddDate,101)     as ''03OrdersAdddate''   ,  
O.OrderKey								as ''04OrderKey''        , 
O.ExternOrderKey						as ''05ExternOrderKey''  , 
O.OrderDate								as ''06OrderDate''       , 
O.ConsigneeKey							as ''07ShipTo''          ,
O.C_Company								as ''08ShipToName''      , 
O.OrderGroup							as ''09OrderGroup''      , 
PID.Sku									as ''10Sku''             , 
SKU.DESCR								as ''11Description''     , 
OD.OriginalQty							as ''12OriginalQty''     , 
SUM ( PID.Qty)							as ''13Qty''             , 
OD.UOM									as ''14OrderUOM''        , 
PID.ID									as ''15PalletID''        , 
M.Vessel									as ''16Vessel''          , 
PID.PickSlipNo							as ''17PickSlipNo''      , 
PID.Loc									as ''18Loc''             , 
LOC.HOSTWHCODE							as ''19HOSTWHCODE''      , 
PAC.PackKey								as ''20PackKey''         , 
PAC.Pallet								as ''21Pallet''          , 
PAC.CaseCnt								as ''22CaseCnt''         , 
case when (SUM ( PID.Qty)) > 0  then (case when (PAC.CaseCnt) > 0 then (SUM ( PID.Qty)) / (PAC.CaseCnt) else 0 end)  else 0 end  as ''23Qty - CS'', 
LOA.Lottable01							as ''24Lottable01''      , 
LOA.Lottable02							as ''25Lottable02''      , 
LOA.Lottable03							as ''26Lottable03''      , 
LOA.Lottable04							as ''27Lottable04''      , 
LOA.Lottable05							as ''28Lottable05''      ,
LOA.Lottable06							as ''29Lottable06''      , 
LOA.Lottable07							as ''30Lottable07''      , 
LOA.Lottable08							as ''31Lottable08''      , 
LOA.Lottable09							as ''32Lottable09''      , 
LOA.Lottable10							as ''33Lottable10''      , 
LOA.Lottable11							as ''34Lottable11''      , 
LOA.Lottable12							as ''35Lottable12''      , 
LOA.Lottable13							as ''36Lottable13''      , 
LOA.Lottable14							as ''37Lottable14''      , 
LOA.Lottable15							as ''38Lottable15''      , 
M.EditDate							   as ''39ShipDate''        , 
M.MbolKey								as ''40MbolKey''         , 
O.LoadKey								as ''41LoadKey''         , 
cast(O.Notes as char(60))			as ''42Notes''           , 
cast(O.Notes2 as char(60))			as ''43Notes2''          , 
O.Type								   as ''44Type''            , 
O.InvoiceNo							   as ''45InvoiceNo''       , 
O.BillToKey							   as ''46BillToKey''       , 
O.B_Company							   as ''47B_Company''       , 
O.B_Address1							as ''48B_Address1''      , 
O.B_Address2							as ''49B_Address2''      , 
SKU.STDCUBE								as ''50STDCUBE''         , 
SKU.STDGROSSWGT						as ''51STDGROSSWGT''     , 
O.BuyerPO								as ''52BuyerPO''         ,  
O.Route									  as ''53Route''         , 
SKU.SUSR3								as ''54SUSR3''           , 
SKU.itemclass							as ''55Itemclass''       , 
PID.AddWho								as ''56AllocateWho''     , 
PID.AddDate								as ''57AllocateDate''    , 
PID.EditDate							as ''58EditDate''        ,
O.UserDefine10							as ''59UserDefine10''    , 
O.DeliveryDate							as ''60DeliveryDate''    , 
STO.CustomerGroupName				as ''61CustomerGroupName'',
STO.CustomerGroupCode				as ''62CustomerGroupCode'', 
M.UserDefine01							as ''63MBOL_UserDefine01'', 
M.UserDefine02							as ''64MBOL_UserDefine02'', 
M.UserDefine03							as ''65MBOL_UserDefine03'', 
M.UserDefine04							as ''66MBOL_UserDefine04'', 
O.C_Address1							as ''67C_Address1''       , 
O.C_Address2							as ''68C_Address2''       , 
O.C_Address3							as ''69C_Address3''       , 
O.C_Address4							as ''70C_Address4''       , 
PAC.InnerPack							as ''71InnerPack''        , 
O.ExternPOKey							as ''72ExternPOKey''      , 
SKU.ALTSKU								as ''73ALTSKU''           , 
SKU.BUSR7								as ''74BUSR7''            , 
M.AddWho									as ''75AddWho''           , 
SKU.Price								as ''76Unit Cost''        , 
(SKU.Price) * (SUM ( PID.Qty))	as ''77Total Cost''       , 
PID.DropID								as ''78DropID''          , 
OI.EcomOrderId							as ''79EcomOrderId''  ,
PID.CASEID							    as ''80CaseID''  ,
O.Deliverynote							as ''81DeliveryNote'',
OD.ExternLineNo							as ''82ExternLineNo'',
OD.ExternLineNo							as ''82ExternLineNo'' ,
STO.Secondary							as ''83ConsigneeSecondary'' ,
STO.Susr4							    as ''84ConsigneeSUSR4''	, 
SKU.Class							    as ''85SKUClass'',
OD.Orderlinenumber							as ''86Orderlinenumber''
,loc.LocationRoom, PAC.PalletTi, PAC.PalletHi, STO.Susr1, STO.Susr2, STO.Susr3, STO.Susr5			
'
SET @stmt = @stmt + '

FROM            
	BI.V_ORDERS O
	JOIN BI.V_ORDERDETAIL OD ON O.OrderKey=OD.OrderKey --AND O.StorerKey=OD.StorerKey
	Join BI.V_MBOL M ON M.MbolKey=O.MBOLKey
	JOIN BI.V_PICKDETAIL PID ON OD.OrderKey=PID.OrderKey 
	--AND OD.StorerKey = PID.Storerkey 
	--AND PID.Sku=OD.Sku 
	AND PID.OrderLineNumber=OD.OrderLineNumber 
	JOIN BI.V_SKU SKU ON (PID.Storerkey= SKU.StorerKey AND PID.Sku=SKU.Sku) 
	JOIN BI.V_LOC LOC	ON LOC.Loc=PID.Loc
	LEFT JOIN BI.V_STORER STO ON (STO.StorerKey=O.ConsigneeKey) 
	LEFT JOIN BI.V_OrderInfo OI ON (O.OrderKey=OI.OrderKey) 
	JOIN BI.V_LOTATTRIBUTE LOA ON (PID.Storerkey=LOA.StorerKey AND PID.Sku=LOA.Sku AND PID.Lot=LOA.Lot) 
	JOIN BI.V_PACK PAC ON (SKU.PACKKey=PAC.PackKey) 


WHERE
O.Facility= '''+@Param_Generic_Facility+'''  
AND O.Storerkey = '''+@Param_Generic_Storerkey+'''  
AND M.Status = ''9''      
AND (O.editdate BETWEEN ''' +CONVERT(NVARCHAR(19),@Param_Generic_EditDateFrom,121)+'''  
AND '''+CONVERT(NVARCHAR(19),@Param_Generic_EditDateTo,121)+''')     
AND (PID.editDate BETWEEN ''' +CONVERT(NVARCHAR(19),@Param_Generic_EditDateFrom,121)+'''  
AND '''+CONVERT(NVARCHAR(19),@Param_Generic_EditDateTo,121)+''')   
AND PID.Status=''9''
--Limits of 3month range in generation of reports
AND datediff (dd,''' +CONVERT(NVARCHAR(19),@Param_Generic_EditDateFrom,121)+''','''+CONVERT(NVARCHAR(19),@Param_Generic_EditDateTo,121)+''') < 94

'

SET @stmt = @stmt + '
GROUP BY 
O.StorerKey
, O.Facility
, convert(char( 10) ,O.AddDate,101) 
, O.OrderKey
, O.ExternOrderKey
, O.OrderDate
, O.ConsigneeKey
, O.C_Company
, O.OrderGroup
, PID.Sku
, SKU.DESCR
, OD.OriginalQty
, OD.UOM
, PID.ID
, M.Vessel
, PID.PickSlipNo
, PID.Loc
, LOC.HOSTWHCODE
, PAC.PackKey
, PAC.Pallet
, PAC.CaseCnt
, LOA.Lottable01
, LOA.Lottable02
, LOA.Lottable03
, LOA.Lottable04
, LOA.Lottable05
, LOA.Lottable06
, LOA.Lottable07
, LOA.Lottable08
, LOA.Lottable09
, LOA.Lottable10
,LOA.Lottable11
, LOA.Lottable12
, LOA.Lottable13
, LOA.Lottable14
, LOA.Lottable15
,M.EditDate
, M.MbolKey
, O.LoadKey
, cast(O.Notes as char(60)) 
, cast(O.Notes2 as char(60)) 
, O.Type
, O.InvoiceNo
, O.BillToKey
, O.B_Company
, O.B_Address1
, O.B_Address2
, SKU.STDCUBE
, SKU.STDGROSSWGT
,O.BuyerPO
, O.Route
, SKU.SUSR3
, SKU.itemclass
, PID.AddWho
, PID.AddDate
, PID.EditDate
, O.UserDefine10
, O.DeliveryDate
, STO.CustomerGroupName
, STO.CustomerGroupCode
, M.UserDefine01
, M.UserDefine02
, M.UserDefine03
, M.UserDefine04
, O.C_Address1
, O.C_Address2
, O.C_Address3
, O.C_Address4
, PAC.InnerPack
, O.ExternPOKey
, SKU.ALTSKU
, SKU.BUSR7
, M.AddWho
, SKU.Price
, PID.DropID
, OI.EcomOrderId 
,PID.CASEID		
,O.DeliveryNote
,OD.ExternLineNo
,STO.Secondary
,STO.Susr4
,SKU.Class,OD.Orderlinenumber,LOC.LocationRoom, PAC.PalletTi, PAC.PalletHi, STO.Susr1, STO.Susr2, STO.Susr3, STO.Susr5
ORDER BY  1,  2,  4,  10
OPTION (RECOMPILE);
'
--print @Stmt
 EXEC BI.dspExecStmt @Stmt = @Stmt
   , @LinkSrv = @LinkSrv
   , @LogId = @LogId
   , @Debug = @Debug;

END -- Procedure 

GO