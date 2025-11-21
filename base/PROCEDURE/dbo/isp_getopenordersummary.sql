SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/ 
/* Object Name: isp_GetOpenOrderSummary                                    */
/* Modification History:                                                   */  
/*                                                                         */  
/* Called By:  Exceed                                                      */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Date         Author    Ver.  Purposes                                   */
/* 05-Aug-2002            1.0   Initial revision                           */ 
/***************************************************************************/    
CREATE PROC [dbo].[isp_GetOpenOrderSummary] (
	@cFacility       NVARCHAR(5),
	@cStorerkeyParm  NVARCHAR(250) = '', 
	@cMBOLStatusParm NVARCHAR(250) = '', 
	@cExOrderKeyParm NVARCHAR(250) = '',
	@cBuyerPOParm    NVARCHAR(250) = '',
	@cLoadKeyParm    NVARCHAR(250) = '',
	@cMBOLKeyParm    NVARCHAR(250) = '',
	@cWaveKeyParm    NVARCHAR(250) = '',
   @cShipDate       NVARCHAR(20)  = '',
	@cShipDateCond   NVARCHAR(10)  = '',
	@cPickUpDate     NVARCHAR(20)  = '',
	@cPickUpDateCond NVARCHAR(10)  = '',
	@cDepartmentParm NVARCHAR(250) = ''
)	
AS
BEGIN
SET NOCOUNT ON
SET ANSI_WARNINGS OFF

	
DECLARE 
       @cStorerKeyCriteria   NVARCHAR(500)
      ,@cMBOLKeyCriteria     NVARCHAR(500)     
      ,@cExtOrderKeyCriteria NVARCHAR(500)
      ,@cBuyerPOCriteria     NVARCHAR(500)
      ,@cLoadKeyCriteria     NVARCHAR(500)
      ,@cWaveKeyCriteria     NVARCHAR(500)
      ,@cShipDateStart       NVARCHAR(500)
      ,@cPickUpDateCriteria  NVARCHAR(500)
      ,@cDeptCriteria        NVARCHAR(500)
      ,@cCriteria            NVARCHAR(500)
      ,@cParameters          NVARCHAR(250)
      ,@nBookMark            INT 

DECLARE @cColValue   NVARCHAR(60)
       ,@cSQLSelect  NVARCHAR(MAX)


IF ISNULL(RTRIM(@cStorerkeyParm), '') <> ''
BEGIN
   SET @cCriteria = ''
   SET @cParameters = @cStorerkeyParm
   SET @nBookMark = 1

   GOTO BuildCriteria

   BookMark1:
   SET @nBookMark = 0
   SET @cStorerKeyCriteria =  'AND OH.STORERKEY IN ' + @cCriteria   
END


IF ISNULL(RTRIM(@cExOrderKeyParm), '') <> ''
BEGIN
   SET @cCriteria = ''
   SET @cParameters = @cExOrderKeyParm
   SET @nBookMark = 2

   GOTO BuildCriteria

   BookMark2:
   SET @nBookMark = 0
   SET @cExtOrderKeyCriteria =  'AND OH.ExternOrderKey IN ' + @cCriteria   

END

IF ISNULL(RTRIM(@cMBOLKeyParm), '') <> ''
BEGIN
   SET @cCriteria = ''
   SET @cParameters = @cMBOLKeyParm
   SET @nBookMark = 3

   GOTO BuildCriteria

   BookMark3:
   SET @nBookMark = 0
   SET @cMBOLKeyCriteria =  'AND OH.MBOLKey IN ' + @cCriteria   

END

IF ISNULL(RTRIM(@cBuyerPOParm), '') <> ''
BEGIN
   SET @cCriteria = ''
   SET @cParameters = @cBuyerPOParm
   SET @nBookMark = 4

   GOTO BuildCriteria

   BookMark4:
   SET @nBookMark = 0
   SET @cBuyerPOCriteria =  'AND OH.BuyerPO IN ' + @cCriteria   

END

IF ISNULL(RTRIM(@cLoadKeyParm), '') <> ''
BEGIN
   SET @cCriteria = ''
   SET @cParameters = @cLoadKeyParm
   SET @nBookMark = 5

   GOTO BuildCriteria

   BookMark5:
   SET @nBookMark = 0
   SET @cLoadKeyCriteria =  'AND OH.LoadKey IN ' + @cCriteria   

END

IF ISNULL(RTRIM(@cWaveKeyParm), '') <> ''
BEGIN
   SET @cCriteria = ''
   SET @cParameters = @cWaveKeyParm
   SET @nBookMark = 6

   GOTO BuildCriteria

   BookMark6:
   SET @nBookMark = 0
   SET @cWaveKeyCriteria =  'AND OH.UserDefine09 IN ' + @cCriteria   

END

BuildCriteria:
DECLARE CUR1 CURSOR LOCAL FOR  
SELECT ColValue
FROM [dbo].[fnc_DelimSplit](',',@cParameters)
ORDER BY SeqNo

OPEN CUR1

FETCH NEXT FROM CUR1 INTO @cColValue 
WHILE @@FETCH_STATUS <> -1
BEGIN
   IF LEFT(@cColValue,1) <> '''' 
      SET @cColValue = 'N''' + @cColValue
 
   IF RIGHT(@cColValue,1) <> '''' 
      SET @cColValue = @cColValue + ''''  

   IF LEN(@cCriteria) > 0 
      SET @cCriteria = RTRIM(@cCriteria) + ',' + @cColValue
   ELSE
      SET  @cCriteria = '(' + @cColValue

   FETCH NEXT FROM CUR1 INTO @cColValue 
END 
CLOSE CUR1
DEALLOCATE CUR1
SET @cCriteria = @cCriteria + ')'

IF @nBookMark = 1 GOTO BookMark1
IF @nBookMark = 2 GOTO BookMark2
IF @nBookMark = 3 GOTO BookMark3
IF @nBookMark = 4 GOTO BookMark4
IF @nBookMark = 5 GOTO BookMark5
IF @nBookMark = 6 GOTO BookMark6


IF OBJECT_ID('tempdb..#RESULT') IS NOT NULL
   DROP TABLE #RESULT 

CREATE TABLE #RESULT (
   StorerKey   NVARCHAR(15),
   C_Company   NVARCHAR(45), 
   RecvDate    NVARCHAR(20),
   WMSOrdKey   NVARCHAR(10),
   PO          NVARCHAR(30),
   PO_Batch    NVARCHAR(10),
   PT          NVARCHAR(20),
   STATUS      NVARCHAR(10),
   LoadKey     NVARCHAR(10),
   SCAC        NVARCHAR(30),
   VicsBill    NVARCHAR(20),
   MBOLKey     NVARCHAR(10),
   StartDate   DATETIME NULL,
   CancelDate  DATETIME NULL,
   RoutingDate NVARCHAR(20),
   PickupDate  NVARCHAR(20),
   Originalqty  INT,
   Qtyallocated INT,
   Qtypicked    INT,
   PackQty      INT,
   Ord_Notes1   NVARCHAR(1000),
   Orders_Deliverynote NVARCHAR(20),
   Ord_Notes2          NVARCHAR(1000),
   PackConfirm         INT, 
   Company             NVARCHAR(45),
   RunDate           NVARCHAR(20),
   RouteAuth         NVARCHAR(20), 
   LabelCreated      INT,
   ShipCompany       NVARCHAR(45),
   BU                NVARCHAR(5),
   [LANE#]           NVARCHAR(20),
   MbolNotes         NVARCHAR(20),
   BISOCntryCode     NVARCHAR(45),
   Dept              NVARCHAR(2),
   Facility          NVARCHAR(5),
   ShippedQty        INT,
   PickCnt           INT,
   PickLoose         INT,  
   JCPPOM            NVARCHAR(20),
   [DEPT#]           NVARCHAR(30)) 
         

SET @cSQLSelect = 
"SELECT OH.StorerKey
      ,ShipTo = OH.C_Company
      ,RecvDate = CONVERT(NVARCHAR(10) ,OH.AddDate ,120)
      ,WMSOrdKey = OH.OrderKey
      ,PO = OH.ExternOrderKey
      ,PO_Batch = OH.POKey
      ,PT = OH.BuyerPO
      ,OH.Status
      ,OH.LoadKey
      ,SCAC = MBOL.CarrierKey
      ,VicsBill = MBOL.ExternMbolKey
      ,OH.MBOLKey
      ,StartDate = OH.OrderDate
      ,CancelDate = OH.DeliveryDate
      ,RoutingDate = CASE 
                          WHEN LEN(
                                   RTRIM(ISNULL(CONVERT(NVARCHAR(10) ,LP.UserDefine06 ,120) ,''))
                               )='0' THEN (
                                   CASE 
                                        WHEN LEN(
                                                 RTRIM(ISNULL(CONVERT(NVARCHAR(10) ,MBOL.UserDefine06 ,120) ,''))
                                             )='0' THEN 'No Input Value'
                                        WHEN LEFT(
                                                 RTRIM(ISNULL(CONVERT(NVARCHAR(10) ,MBOL.UserDefine06 ,120) ,''))
                                                ,10
                                             )='1900-01-01' THEN 
                                             'No Input Value'
                                        ELSE CONVERT(NVARCHAR(10) ,MBOL.UserDefine06 ,120)
                                   END
                               )
                          WHEN LEFT(
                                   RTRIM(ISNULL(CONVERT(NVARCHAR(10) ,LP.UserDefine06 ,120) ,''))
                                  ,10
                               )='1900-01-01' THEN (
                                   CASE 
                                        WHEN LEN(
                                                 RTRIM(ISNULL(CONVERT(NVARCHAR(10) ,MBOL.UserDefine06 ,120) ,''))
                                             )='0' THEN 'No Input Value'
                                        WHEN LEFT(
                                                 RTRIM(ISNULL(CONVERT(NVARCHAR(10) ,MBOL.UserDefine06 ,120) ,''))
                                                ,10
                                             )='1900-01-01' THEN 
                                             'No Input Value'
                                        ELSE CONVERT(NVARCHAR(10) ,MBOL.UserDefine06 ,120)
                                   END
                               )
                          ELSE CONVERT(NVARCHAR(10) ,LP.UserDefine06 ,120)
                     END
      ,PickupDate = CASE 
                         WHEN LEN(
                                  RTRIM(ISNULL(CONVERT(NVARCHAR(19) ,MBOL.UserDefine07 ,120) ,''))
                              )='0' THEN 'No Input Value'
                         WHEN LEFT(
                                  RTRIM(ISNULL(CONVERT(NVARCHAR(19) ,MBOL.UserDefine07 ,120) ,''))
                                 ,10
                              )='1900-01-01' THEN 'No Input Value'
                         ELSE CONVERT(NVARCHAR(19) ,MBOL.UserDefine07 ,120)
                    END
      ,Originalqty = SUM(OD.OriginalQty)
      ,Qtyallocated = SUM(OD.QtyAllocated)
      ,Qtypicked = SUM(OD.QtyPicked)
      ,PackQty = 0
      ,Ord_Notes1 = CONVERT(NVARCHAR(1000) ,OH.Notes2)
      ,Orders_Deliverynote = OH.DeliveryNote
      ,Ord_Notes2 = CONVERT(NVARCHAR(1000) ,OH.Notes)
      ,PackConfirm = 0 
      ,Company = STORER.B_Company
      ,RunDate = MAX(CONVERT(NVARCHAR(19) ,GETDATE() ,120))
      ,RouteAuth = MBOL.BookingReference 
      ,LabelCreated = 0
      ,ShipCompany = STORER.B_ISOCntryCode
      ,BU = OH.Facility
      ,LANE# = MBOL.UserDefine10
      ,MbolNotes = ISNULL(MBOL.DRIVERName,'')
      ,BIsocntrycode = STORER.B_ISOCntryCode
      ,Dept = RIGHT(RTRIM(LTRIM(OH.UserDefine03)) ,2)
      ,OH.Facility
      ,ShippedQty = SUM(OD.QtyAllocated+OD.QtyPicked+OD.ShippedQty)
      ,PickCnt = 0
      ,PickLoose = 0  
      ,JCPPOM = OH.OrderGroup
      ,DEPT# = OH.UserDefine03 
FROM   dbo.STORER STORER WITH (NOLOCK) 
INNER JOIN  dbo.ORDERS OH WITH (NOLOCK) ON OH.StorerKey = STORER.StorerKey  
INNER JOIN  dbo.ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = OH.OrderKey  
LEFT  OUTER JOIN dbo.MBOL MBOL ON  (MBOL.MbolKey=OH.MBOLKey)
LEFT  OUTER JOIN dbo.LoadPlan LP ON  (OH.LoadKey=LP.LoadKey)
WHERE  (OH.Status<'9') 
AND   OH.Facility  = N'" + @cFacility + "'" + master.dbo.fnc_GetCharASCII(13) +
ISNULL(@cStorerKeyCriteria,'')   + " " +    
ISNULL(@cMBOLKeyCriteria,'')     + " " +     
ISNULL(@cExtOrderKeyCriteria,'') + " " + 
ISNULL(@cBuyerPOCriteria,'') + " " +     
ISNULL(@cLoadKeyCriteria,'') + " " +      
ISNULL(@cWaveKeyCriteria,'') + " " +      
master.dbo.fnc_GetCharASCII(13) + " GROUP BY
       OH.StorerKey
      ,OH.C_Company
      ,CONVERT(NVARCHAR(10) ,OH.AddDate ,120)
      ,OH.OrderKey
      ,OH.ExternOrderKey
      ,OH.POKey
      ,OH.BuyerPO
      ,OH.Status
      ,OH.LoadKey
      ,MBOL.CarrierKey
      ,MBOL.ExternMbolKey
      ,OH.MBOLKey
      ,OH.OrderDate
      ,OH.DeliveryDate
      ,CASE 
            WHEN LEN(
                     RTRIM(ISNULL(CONVERT(NVARCHAR(10) ,LP.UserDefine06 ,120) ,''))
                 )='0' THEN (
                     CASE 
                          WHEN LEN(
                                   RTRIM(ISNULL(CONVERT(NVARCHAR(10) ,MBOL.UserDefine06 ,120) ,''))
                               )='0' THEN 'No Input Value'
                          WHEN LEFT(
                                   RTRIM(ISNULL(CONVERT(NVARCHAR(10) ,MBOL.UserDefine06 ,120) ,''))
                                  ,10
                               )='1900-01-01' THEN 'No Input Value'
                          ELSE CONVERT(NVARCHAR(10) ,MBOL.UserDefine06 ,120)
                     END
                 )
            WHEN LEFT(
                     RTRIM(ISNULL(CONVERT(NVARCHAR(10) ,LP.UserDefine06 ,120) ,''))
                    ,10
                 )='1900-01-01' THEN (
                     CASE 
                          WHEN LEN(
                                   RTRIM(ISNULL(CONVERT(NVARCHAR(10) ,MBOL.UserDefine06 ,120) ,''))
                               )='0' THEN 'No Input Value'
                          WHEN LEFT(
                                   RTRIM(ISNULL(CONVERT(NVARCHAR(10) ,MBOL.UserDefine06 ,120) ,''))
                                  ,10
                               )='1900-01-01' THEN 'No Input Value'
                          ELSE CONVERT(NVARCHAR(10) ,MBOL.UserDefine06 ,120)
                     END
                 )
            ELSE CONVERT(NVARCHAR(10) ,LP.UserDefine06 ,120)
       END
      ,CASE 
            WHEN LEN(
                     RTRIM(ISNULL(CONVERT(NVARCHAR(19) ,MBOL.UserDefine07 ,120) ,''))
                 )='0' THEN 'No Input Value'
            WHEN LEFT(
                     RTRIM(ISNULL(CONVERT(NVARCHAR(19) ,MBOL.UserDefine07 ,120) ,''))
                    ,10
                 )='1900-01-01' THEN 'No Input Value'
            ELSE CONVERT(NVARCHAR(19) ,MBOL.UserDefine07 ,120)
       END
      ,CONVERT(NVARCHAR(1000) ,OH.Notes2)
      ,OH.DeliveryNote
      ,CONVERT(NVARCHAR(1000) ,OH.Notes)
      ,STORER.B_Company
      ,MBOL.BookingReference
      ,STORER.B_ISOCntryCode
      ,OH.Facility
      ,MBOL.UserDefine10
      ,MBOL.DRIVERName
      ,STORER.B_ISOCntryCode
      ,RIGHT(RTRIM(LTRIM(OH.UserDefine03)) ,2)
      ,OH.Facility
      ,OH.OrderGroup
      ,OH.UserDefine03 
 "  

   INSERT INTO #RESULT
   EXEC sp_ExecuteSQL @cSQLSelect
  
    
   DECLARE @cOrderKey      NVARCHAR(10), 
           @nPackQty       INT, 
           @nLabelCreated  INT,
           @nPickCnt       INT,
           @nPickLoose     INT,
           @cPackConfirm   NVARCHAR(10), 
           @cSQL           NVARCHAR(MAX)
             
       
   DECLARE CUR_ORDER_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT WMSOrdKey FROM #RESULT 

   OPEN  CUR_ORDER_LOOP
   	
   FETCH FROM CUR_ORDER_LOOP INTO @cOrderKey
   WHILE @@FETCH_STATUS <> -1 
   BEGIN
      SET @nPackQty = 0
      SET @nLabelCreated = 0
      SET @cPackConfirm = 'N'
      SET @nPickCnt = 0
      SET @nPickLoose = 0

   	SELECT @nPackQty      = SUM(Qty), 
   	       @nLabelCreated = COUNT(DISTINCT PD.LabelNo),
   	       @cPackConfirm  = MAX(PH.[Status])
   	FROM PackHeader PH WITH (NOLOCK)   
   	JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.PickSlipNo = PH.PickSlipNo 
   	WHERE PH.OrderKey = @cOrderKey 


     SET @cSQL = N'USE MASTER
     SELECT @nPickCnt =
            ISNULL(SUM((PD.Qty- PD.Qty % CONVERT(INT ,(BU.Qty * BU.CS_Qty)))/(BU.Qty * BU.CS_Qty)),0),
            @nPickLoose = 
            ISNULL(SUM(PD.Qty % CONVERT(INT ,(ISNULL(BU.qty * BU.CS_Qty ,999999999)))),0)             
     FROM   ' + DB_NAME() + '.dbo.PICKDETAIL PD (NOLOCK) 
     INNER JOIN ' + DB_NAME() + '.dbo.LotAttribute l (NOLOCK) ON  PD.lot = L.lot 
     CROSS APPLY ' + DB_NAME() + '.dbo.fnc_BOM_UOM(L.StorerKey, L.Lottable03) AS BU 
     WHERE  pd.orderkey = @cOrderKey'

     EXEC sp_executesql @cSQL, N'@cOrderKey NVARCHAR(10), @nPickCnt INT OUTPUT, @nPickLoose INT OUTPUT', 
          @cOrderKey, @nPickCnt OUTPUT, @nPickLoose OUTPUT 
     
      
      UPDATE #RESULT 
         SET PackQty      = ISNULL(@nPackQty,0),
             PackConfirm  = ISNULL(@cPackConfirm,''),
             LabelCreated = ISNULL(@nLabelCreated,0),
             PickCnt      = ISNULL(@nPickCnt,0),
             PickLoose    = ISNULL(@nPickLoose,0) 
      WHERE WMSOrdKey = @cOrderKey
   	
	   FETCH FROM CUR_ORDER_LOOP INTO @cOrderKey
   END 
   CLOSE CUR_ORDER_LOOP
   DEALLOCATE CUR_ORDER_LOOP	
	
   SELECT * FROM #RESULT 

END -- Procedure

GO