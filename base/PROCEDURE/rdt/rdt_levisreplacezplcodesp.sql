SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_LevisReplaceZPLCodeSP                           */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 2025-01-23  1.0  Dennis       FCR-1824 Created                       */
/************************************************************************/

CREATE   PROCEDURE rdt.rdt_LevisReplaceZPLCodeSP
   @nMobile      INT,             
   @nFunc        INT,             
   @cLangCode    NVARCHAR( 3),    
   @cStorerKey   NVARCHAR( 15),   
   @cValue01     NVARCHAR( 20),   
   @cValue02     NVARCHAR( 20),   
   @cValue03     NVARCHAR( 20),   
   @cValue04     NVARCHAR( 20),   
   @cValue05     NVARCHAR( 20),   
   @cValue06     NVARCHAR( 20),   
   @cValue07     NVARCHAR( 20),   
   @cValue08     NVARCHAR( 20),   
   @cValue09     NVARCHAR( 20),   
   @cValue10     NVARCHAR( 20),   
   @cTemplate    NVARCHAR( MAX),  
   @cPrintData   NVARCHAR( MAX) OUTPUT,  
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount   INT
   DECLARE @cPickSlipNo NVARCHAR(10)
   DECLARE @cOrderKey   NVARCHAR(10)
   DECLARE @cLabelNo    NVARCHAR(20)
   DECLARE @cExtTemplateSP    NVARCHAR(20),
   @cSQL           NVARCHAR( MAX),
   @cSQLParam      NVARCHAR( MAX),
   @cUserName      NVARCHAR( 20),
   @cReportType    NVARCHAR( 10),
   @cUDF02         NVARCHAR( 10),
   @cFacility      NVARCHAR( 5),
   @nSKUCnt        INT
   
   SELECT @cFacility = FACILITY FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
   SELECT @cLabelNo = @cValue01, @cReportType = @cValue02

   SELECT @cOrderKey = CASE WHEN COUNT(OrderKey) = 1 THEN OrderKey ELSE 'MPOC' END
   FROM dbo.PickDetail WITH(NOLOCK)
   WHERE StorerKey = @cStorerKey 
      AND CaseID <> ''
      AND CaseID = @cLabelNo
   GROUP BY OrderKey

   SET @cPrintData = @cTemplate;

   DECLARE @CartonTrack_TrackingNo NVARCHAR(MAX) = '',
      @Facility_Address1 NVARCHAR(MAX) = '',
      @Facility_Address2 NVARCHAR(MAX) = '',
      @Facility_City NVARCHAR(MAX) = '',
      @Facility_Description NVARCHAR(MAX) = '',
      @Facility_Facility NVARCHAR(MAX) = '',
      @Facility_State NVARCHAR(MAX) = '',
      @Facility_Zip NVARCHAR(MAX) = '',
      @MBOL_Carrierkey NVARCHAR(MAX) = '',
      @MBOL_Door NVARCHAR(MAX) = '',
      @MBOL_ExternMBOLKey NVARCHAR(MAX) = '',
      @MBOL_MBOLKEY NVARCHAR(MAX) = '',
      @OrderDetail_Userdefine07 NVARCHAR(MAX) = '',
      @OrderDetail_SKU NVARCHAR(MAX) = '',
      @OrderDetail_Userdefine03 NVARCHAR(MAX) = '',
      @OrderInfo_Notes NVARCHAR(MAX) = '',
      @OrderInfo_OrderInfo02 NVARCHAR(MAX) = '',
      @OrderInfo_OrderInfo05 NVARCHAR(MAX) = '',
      @Orders_B_Address1 NVARCHAR(MAX) = '',
      @Orders_B_Address2 NVARCHAR(MAX) = '',
      @Orders_B_City NVARCHAR(MAX) = '',
      @Orders_B_Company NVARCHAR(MAX) = '',
      @Orders_B_ISOCntryCode NVARCHAR(MAX) = '',
      @Orders_B_State NVARCHAR(MAX) = '',
      @Orders_B_Zip NVARCHAR(MAX) = '',
      @Orders_Billtokey NVARCHAR(MAX) = '',
      @Orders_BuyerPO NVARCHAR(MAX) = 'VARIOUS',
      @Orders_C_Address1 NVARCHAR(MAX) = '',
      @Orders_C_Address2 NVARCHAR(MAX) = '',
      @Orders_C_City NVARCHAR(MAX) = '',
      @Orders_C_Company NVARCHAR(MAX) = '',
      @Orders_C_Contact1 NVARCHAR(MAX) = '',
      @Orders_C_ISOCntryCode NVARCHAR(MAX) = '',
      @Orders_C_State NVARCHAR(MAX) = '',
      @Orders_C_Zip NVARCHAR(MAX) = '',
      @Orders_Consigneekey NVARCHAR(MAX) = '',
      @Orders_ExternOrderkey NVARCHAR(MAX) = '',
      @Orders_M_Address1 NVARCHAR(MAX) = '',
      @Orders_M_Address2 NVARCHAR(MAX) = '',
      @Orders_M_City NVARCHAR(MAX) = '',
      @Orders_M_Company NVARCHAR(MAX) = '',
      @Orders_M_Contact1 NVARCHAR(MAX) = '',
      @Orders_M_State NVARCHAR(MAX) = '',
      @Orders_M_Zip NVARCHAR(MAX) = '',
      @Orders_Markforkey NVARCHAR(MAX) = '',
      @Orders_UserDefine04 NVARCHAR(MAX) = '',
      @Orders_UserDefine08 NVARCHAR(MAX) = '',
      @Orders_UserDefine09 NVARCHAR(MAX) = '',
      @PackDetail_Carton_Total_Qty NVARCHAR(MAX) = '',
      @Packdetail_Carton_Count NVARCHAR(MAX) = '',
      @Packdetail_Labelno NVARCHAR(MAX) = '',
      @PackDetail_Total_Qty_by_SKU NVARCHAR(MAX) = '',
      @PackInfo_CartonType NVARCHAR(MAX) = '',
      @Storer_Company_Type7 NVARCHAR(MAX) = '',
      @Storer_Storerkey_Type7 NVARCHAR(MAX) = '',
      @MBOL_CarrierAgent NVARCHAR(MAX) = '',
      @PackDetail_CartonNo NVARCHAR(MAX) = '',
      @Storer_Company_Type_1 NVARCHAR(MAX) = '',
      @Storer_Storerkey_Type_1 NVARCHAR(MAX) = '',
      @SKU_RetailSKU NVARCHAR(MAX) = '',
      @SKU_Size_Measurement NVARCHAR(MAX) = '',
      @SKU_Style NVARCHAR(MAX) = '',
      @wkOrdUDef2 NVARCHAR(MAX) = '',
      @wkOrdUDef4 NVARCHAR(MAX) = '',
      @Hangers NVARCHAR(MAX) = '';

   SELECT
      @CartonTrack_TrackingNo = ''
   
   SELECT TOP 1
      @Facility_Address1 = Address1,
      @Facility_Address2 = Address2,
      @Facility_City = City,
      @Facility_Description = Descr,
      @Facility_Facility = Facility,
      @Facility_State = State,
      @Facility_Zip = Zip
   FROM dbo.Facility WITH(NOLOCK)
   WHERE FACILITY = @cFacility
   
   IF @cOrderKey <> 'MPOC'
   BEGIN
      SELECT TOP 1
         @MBOL_Carrierkey = M.Carrierkey,
         @MBOL_Door = O.DOOR,
         @MBOL_ExternMBOLKey = M.ExternMBOLKEY,
         @MBOL_MBOLKEY = M.MBOLKEY
      FROM dbo.MBOL M WITH(NOLOCK)
      INNER JOIN dbo.MBOLDetail MD WITH(NOLOCK) ON (M.MBOLKey = MD.MBOLKey) 
      INNER JOIN ORDERS     O  WITH (NOLOCK) ON (MD.OrderKey = O.OrderKey) 
      WHERE O.OrderKey = @cOrderKey

      SELECT
         @Orders_B_Address1 = B_Address1,
         @Orders_B_Address2 = B_Address2,
         @Orders_B_City = B_City,
         @Orders_B_Company = B_Company,
         @Orders_B_ISOCntryCode = B_ISOCntryCode,
         @Orders_B_State = B_State,
         @Orders_B_Zip = B_Zip,
         @Orders_Billtokey = BilltoKey,
         @Orders_BuyerPO = BuyerPO,
         @Orders_C_Address1 = C_Address1,
         @Orders_C_Address2 = C_Address2,
         @Orders_C_City = C_City,
         @Orders_C_Company = C_Company,
         @Orders_C_Contact1 = C_Contact1,
         @Orders_C_ISOCntryCode = C_ISOCntryCode,
         @Orders_C_State = C_State,
         @Orders_C_Zip = C_Zip,
         @Orders_Consigneekey = Consigneekey,
         @Orders_ExternOrderkey = ExternOrderkey,
         @Orders_M_Address1 = M_Address1,
         @Orders_M_Address2 = M_Address2,
         @Orders_M_City = M_City,
         @Orders_M_Company = M_Company,
         @Orders_M_Contact1 = M_Contact1,
         @Orders_M_State = M_State,
         @Orders_M_Zip = M_Zip,
         @Orders_Markforkey = Markforkey,
         @Orders_UserDefine04 = Userdefine04,
         @Orders_UserDefine08 = Userdefine08,
         @Orders_UserDefine09 = Userdefine09
      FROM dbo.Orders WITH(NOLOCK)
      WHERE OrderKey = @cOrderKey

      SELECT TOP 1
         @OrderDetail_Userdefine07 = Userdefine07,
         @OrderDetail_SKU = SKU,
         @OrderDetail_Userdefine03 = Userdefine03
      FROM dbo.OrderDetail WITH(NOLOCK)
      WHERE OrderKey = @cOrderKey
   END

   SELECT
      @PackDetail_Carton_Total_Qty = SUM(Qty),
      @Packdetail_Carton_Count = COUNT(CartonNo),
      @Packdetail_Labelno = Labelno,
      @PackDetail_Total_Qty_by_SKU = SUM(Qty)
   FROM dbo.PackDetail WITH(NOLOCK) 
   WHERE StorerKey = @cStorerKey 
      AND labelno = @cLabelNo
   GROUP BY LabelNo

   -- SELECT
   --    @PackDetail_Total_Qty_by_SKU = SUM(Qty)
   -- FROM dbo.PackDetail WITH(NOLOCK) 
   -- WHERE StorerKey = @cStorerKey 
   --    AND labelno = @cLabelNo
   -- GROUP BY LabelNo,SKU

   SELECT TOP 1
      @PackInfo_CartonType = CartonType
   FROM dbo.PackInfo PI WITH(NOLOCK) 
   WHERE PI.RefNo IS NOT NULL
      AND PI.RefNo = @cLabelNo

   SELECT TOP 1
      @Storer_Company_Type7 = Company,
      @Storer_Storerkey_Type7 = Storerkey
   FROM dbo.Storer WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey

   SELECT
      @nSKUCnt = COUNT(SKU)
   FROM dbo.PackDetail WITH(NOLOCK) 
   WHERE StorerKey = @cStorerKey 
      AND labelno = @cLabelNo

   SELECT
      @SKU_RetailSKU = CONCAT('',CASE WHEN @nSKUCnt = 1 THEN RetailSKU ELSE 'MIXED' END,''),
      @SKU_Size_Measurement =  CONCAT('',CASE WHEN @nSKUCnt = 1 THEN ISNULL(Size,'') + ISNULL(Measurement,'') ELSE 'MIXED' END,''),
      @SKU_Style = CONCAT('',CASE WHEN @nSKUCnt = 1 THEN ISNULL(STYLE,'') ELSE 'MIXED' END,'')
   FROM dbo.SKU SKU WITH (NOLOCK)
   INNER JOIN dbo.PackDetail PD WITH(NOLOCK) ON PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey
   WHERE PD.StorerKey = @cStorerKey 
      AND PD.labelno = @cLabelNo

   SELECT top 1 @wkOrdUDef2 = wod.WkOrdUdef2,
      @wkOrdUDef4 = wod.WkOrdUdef4,
      @Hangers = IIF(CLK.udf01 = 'H','Hanger','')
   FROM dbo.WorkOrderDetail wod (NOLOCK)
      INNER JOIN dbo.PickDetail pkd WITH(NOLOCK) ON wod.StorerKey = pkd.StorerKey AND ISNULL(wod.ExternWorkOrderKey, '') = pkd.OrderKey AND pkd.OrderLinenumber = wod.ExternLineNo
      LEFT JOIN dbo.CODELKUP CLK WITH(NOLOCK)
         ON CLK.StorerKey = wod.StorerKey AND CLK.LISTNAME = 'wkordtype' AND WOD.Type = CLK.Code
      WHERE ISNULL(pkd.CaseID, '') = @cLabelNo
      AND WOD.StorerKey = @cStorerKey


   SET @cPrintData = REPLACE(@cPrintData, '[[Label.CartonTrack_TrackingNo]]', ISNULL(@CartonTrack_TrackingNo, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Date_Time_Now]]', CONVERT(VARCHAR, GETDATE(), 120));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Facility_Address1]]', ISNULL(@Facility_Address1, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Facility_Address2]]', ISNULL(@Facility_Address2, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Facility_City]]', ISNULL(@Facility_City, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Facility_Description]]', ISNULL(@Facility_Description, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Facility_Facility]]', ISNULL(@Facility_Facility, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Facility_State]]', ISNULL(@Facility_State, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Facility_Zip]]', ISNULL(@Facility_Zip, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.MBOL_Carrierkey]]', ISNULL(@MBOL_Carrierkey, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.MBOL_Door]]', ISNULL(@MBOL_Door, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.MBOL_ExternMBOLKey]]', ISNULL(@MBOL_ExternMBOLKey, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.MBOL_MBOLKEY]]', ISNULL(@MBOL_MBOLKEY, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.OrderDetail.Userdefine07]]', ISNULL(@OrderDetail_Userdefine07, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.OrderDetail_SKU]]', ISNULL(@OrderDetail_SKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.OrderDetail_Userdefine03]]', ISNULL(@OrderDetail_Userdefine03, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.OrderInfo_Notes]]', ISNULL(@OrderInfo_Notes, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.OrderInfo_OrderInfo02]]', ISNULL(@OrderInfo_OrderInfo02, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.OrderInfo_OrderInfo05]]', ISNULL(@OrderInfo_OrderInfo05, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_B_Address1]]', ISNULL(@Orders_B_Address1, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_B_Address2]]', ISNULL(@Orders_B_Address2, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_B_City]]', ISNULL(@Orders_B_City, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_B_Company]]', ISNULL(@Orders_B_Company, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_B_ISOCntryCode]]', ISNULL(@Orders_B_ISOCntryCode, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_B_State]]', ISNULL(@Orders_B_State, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_B_Zip]]', ISNULL(@Orders_B_Zip, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_Billtokey]]', ISNULL(@Orders_Billtokey, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_BuyerPO]]', ISNULL(@Orders_BuyerPO, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_C_Address1]]', ISNULL(@Orders_C_Address1, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_C_Address2]]', ISNULL(@Orders_C_Address2, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_C_City]]', ISNULL(@Orders_C_City, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_C_Company]]', ISNULL(@Orders_C_Company, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_C_Contact1]]', ISNULL(@Orders_C_Contact1, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_C_ISOCntryCode]]', ISNULL(@Orders_C_ISOCntryCode, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_C_State]]', ISNULL(@Orders_C_State, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_C_Zip]]', '' + ISNULL(@Orders_C_Zip, '') + '');
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_Consigneekey]]', ISNULL(@Orders_Consigneekey, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_ExternOrderkey]]', ISNULL(@Orders_ExternOrderkey, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_M_Address1]]', ISNULL(@Orders_M_Address1, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_M_Address2]]', ISNULL(@Orders_M_Address2, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_M_City]]', ISNULL(@Orders_M_City, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_M_Company_C_Company]]', CASE WHEN ISNULL(@Orders_M_Company, '') = '' THEN ISNULL(@Orders_C_Company, '') ELSE ISNULL(@Orders_M_Company, '') END);
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_M_Contact1_C_Contact1]]', CASE WHEN ISNULL(@Orders_M_Contact1, '') = '' THEN ISNULL(@Orders_C_Contact1, '') ELSE ISNULL(@Orders_M_Contact1, '') END);
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_M_State_C_State]]', CASE WHEN ISNULL(@Orders_M_State, '') = '' THEN ISNULL(@Orders_C_State, '') ELSE ISNULL(@Orders_M_State, '') END);
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_M_Zip]]', ISNULL(@Orders_M_Zip, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_Markforkey_Consigneekey]]', CASE WHEN ISNULL(@Orders_Markforkey, '') = '' THEN ISNULL(@Orders_Consigneekey, '') ELSE ISNULL(@Orders_Markforkey, '') END);
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_UserDefine04]]', ISNULL(@Orders_UserDefine04, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_UserDefine08]]', ISNULL(@Orders_UserDefine08, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Orders_UserDefine09]]', ISNULL(@Orders_UserDefine09, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail.Carton_Total_Qty]]', ISNULL(@PackDetail_Carton_Total_Qty, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Packdetail_Carton_Count]]', ISNULL(@Packdetail_Carton_Count, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Packdetail_Labelno]]', ISNULL(@Packdetail_Labelno, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU]]', ISNULL(@PackDetail_Total_Qty_by_SKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackInfo_CartonType]]', ISNULL(@PackInfo_CartonType, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Storer_Company_Type7]]', ISNULL(@Storer_Company_Type7, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.Storer_Storerkey_Type7]]', ISNULL(@Storer_Storerkey_Type7, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[Label.MBOL_CarrierAgent]]', ISNULL(@MBOL_CarrierAgent, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[Label.PackDetail_CartonNo]]', ISNULL(@PackDetail_CartonNo, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[Label.Storer_Company_Type_1]]', ISNULL(@Storer_Company_Type_1, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[Label.Storer_Storerkey_Type_1]]', ISNULL(@Storer_Storerkey_Type_1, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU1]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement1]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style1]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU1]]', ISNULL(@PackDetail_Total_Qty_by_SKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU2]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement2]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style2]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU2]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU3]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement3]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style3]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU3]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU4]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement4]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style4]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU4]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU5]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement5]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style5]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU5]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU6]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement6]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style6]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU6]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU7]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement7]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style7]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU7]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU8]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement8]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style8]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU8]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU9]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement9]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style9]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU9]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU10]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement10]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style10]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU10]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU11]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement11]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style11]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU11]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU12]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement12]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style12]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU12]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU13]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement13]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style13]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU13]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU14]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement14]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style14]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU14]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU15]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement15]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style15]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU15]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU16]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement16]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style16]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU16]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU17]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement17]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style17]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU17]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU18]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement18]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style18]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU18]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU19]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement19]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style19]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU19]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU20]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement20]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style20]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU20]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU21]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement21]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style21]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU21]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU22]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement22]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style22]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU22]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_RetailSKU23]]', ISNULL(@SKU_RetailSKU, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Size_Measurement23]]', ISNULL(@SKU_Size_Measurement, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.SKU_Style23]]', ISNULL(@SKU_Style, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.PackDetail_Total_Qty_by_SKU23]]', ISNULL(@SKU_Style, ''));

   /** LVSUS Spec **/
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.LVSUSA_Hangers_Included]]', ISNULL(@Hangers, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.WorkOrderDetail_WkOrdUDef2]]', ISNULL(@wkOrdUDef2, ''));
   SET @cPrintData = REPLACE(@cPrintData, '[[Label.WorkOrderDetail_WkOrdUDef4]]', ISNULL(@wkOrdUDef4, ''));


   Quit:
   RETURN
END


GO