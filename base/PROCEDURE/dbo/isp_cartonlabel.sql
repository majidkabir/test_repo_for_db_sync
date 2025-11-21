SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_CartonLabel                                    */
/* Creation Date: 13-April-2010                                         */
/* Copyright: IDS                                                       */
/* Written by: Chew KP                                                  */
/*                                                                      */
/* Purpose:  SOS#166488 - Carton Label Printing for Carters .           */
/*                                                                      */
/* Called By:  RDT - Print Carton Label                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 25-11-2010   ChewKP    1.1   SOS#197634 Change Weight Calculation    */
/*                              formula (ChewKP01)                      */
/* 21-12-2010   James     1.2   Remove PFCMODEL hardcode                */
/* 24-Mar-2014  TLTING    1.3   SQL2012 Bug                             */
/************************************************************************/

CREATE PROC [dbo].[isp_CartonLabel] (
            @c_LabelNo      NVARCHAR(20)     = ''
          , @c_OrderKey     NVARCHAR(10)     = ''
          , @c_TemplateID   NVARCHAR(60)  = ''
          , @c_PrinterID    NVARCHAR(215) = ''
          , @c_FileName     NVARCHAR(215) = ''
          --, @c_CartonNoParm NVARCHAR(5)   = ''
          , @c_Storerkey    NVARCHAR(18)  = '' 
			 , @c_FilePath     NVARCHAR(120) = '')
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF

   DECLARE @b_debug int
   SET @b_debug = 0
/*********************************************/
/* Variables Declaration (Start)             */
/*********************************************/

   DECLARE @n_StartTCnt  int
   SELECT  @n_StartTCnt = @@TRANCOUNT

   DECLARE @n_continue int
         , @c_errmsg NVARCHAR(255)
         , @b_success int
         , @n_err int
         , @c_ExecStatements nvarchar(4000)
         , @c_ExecArguments nvarchar(4000)

   -- Extract from MBOL/Orders/PackInfo/Sku/PackDetail table

   DECLARE @c_ExternOrderKey NVARCHAR(30)
         , @c_BuyerPO NVARCHAR(20)
         , @c_Notes2 NVARCHAR(255)

   DECLARE @c_Style NVARCHAR(20)
         , @c_Color NVARCHAR(10)
         , @c_Measurement NVARCHAR(5)
         , @c_Size NVARCHAR(5)
         , @c_RSku NVARCHAR(20) --AAY0020
         , @c_Pack_Qty NVARCHAR(5)
         , @c_Sku NVARCHAR(20)        
         , @c_SkuDescr NVARCHAR(60)
         , @c_RetailSku NVARCHAR(20)
         , @c_SKUBUSR8 NVARCHAR(30)
         , @n_ComponentQty int

   DECLARE @c_CartonNo NVARCHAR(10)
         , @n_SkuCnt int
         , @n_TotQty int
         , @n_TotSkuQty int
         , @c_SingleSku NVARCHAR(20)
         , @n_CtnByMbol int
         , @c_PkInCnt NVARCHAR(18)  --LAu001
         , @c_PkSzScl NVARCHAR(18)  --AAY008
         , @c_PkQtyScl NVARCHAR(18) --AAY008
         , @c_PkDesc NVARCHAR(18)  --AAY008
         , @c_SKUDept NVARCHAR(18)  --AAY010
         , @c_SKUProd NVARCHAR(18)  --AAY010
         , @c_MstrSKU NVARCHAR(20) --AAY011
         , @c_PrintedBy NVARCHAR(20) --AAY015
         

   -- Extract from General
   DECLARE @c_Date NVARCHAR(8)
         , @c_Time NVARCHAR(8)
         , @c_DateTime NVARCHAR(14)
         , @n_SeqNo int
         , @n_SeqLineNo int
         , @n_licnt int
         , @c_licnt NVARCHAR(2)
         , @n_PageNumber int
         , @n_CartonNoParm int
         , @c_ColumnName	 NVARCHAR(100)
         , @c_ColumnValue	 NVARCHAR(255)
			, @c_PDColumnName	 NVARCHAR(100)
         , @c_PDColumnValue NVARCHAR(255)
			, @n_CountPD			INT
         , @c_LabelLineNo	 NVARCHAR(5)


         , @c_LabelLine       NVARCHAR(5)
         , @n_QTY             INT
         , @c_RefNo           NVARCHAR(20)
         , @c_UPC             NVARCHAR(30)
         , @c_DESCR           NVARCHAR(60)
         , @c_CLASS           NVARCHAR(10)
         , @c_SKUGROUP        NVARCHAR(10)
         , @c_BUSR5           NVARCHAR(30)
         , @c_ItemClass       NVARCHAR(10)
         
         
         , @n_RowCount        INT
         

   -- SOS127598
   DECLARE @n_IsRDT INT
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

   -- Variables Initialization
   SET @c_ExecStatements = ''
   SET @c_ExecArguments = ''
   SET @n_continue = 0
   SET @c_errmsg = ''
   SET @b_success = 0
   SET @n_err = 0
   SET @c_ExternOrderKey = ''
   SET @c_BuyerPO = ''
   SET @c_StorerKey = ''
   SET @c_Notes2 = ''
   SET @c_CartonNo = ''
   SET @c_Date = ''
   SET @c_Time = ''
   SET @n_SeqNo = 0
   SET @n_SeqLineNo = 0
   SET @c_licnt = ''
   SET @n_SkuCnt = 0
   SET @n_CtnByMbol = 0
   SET @c_SKUBUSR8 = ''
   SET @n_ComponentQty = 0

   SET @c_Date = RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(MONTH, GETDATE()))), 2) + '/'
               + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(DAY, GETDATE()))), 2) + '/'
               + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(YEAR, GETDATE()))), 2) + '/'

   SET @c_Time = RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(HOUR, GETDATE()))), 2) + ':'
               + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(MINUTE, GETDATE()))), 2) + ':'
               + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(SECOND, GETDATE()))), 2) + ':'

   SET @c_DateTime = RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(YEAR, GETDATE()))), 4)
                   + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(MONTH, GETDATE()))), 2)
                   + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(DAY, GETDATE()))), 2)
                   + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(HOUR, GETDATE()))), 2)
                   + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(MINUTE, GETDATE()))), 2)
                   + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(SECOND, GETDATE()))), 2)

   -- Retrieve StorerKey and BuyerPO from ORDERS
   SELECT DISTINCT @c_StorerKey = StorerKey 
     FROM ORDERS WITH (NOLOCK)
    WHERE ORDERS.OrderKey = @c_OrderKey

--   IF ISNULL(RTRIM(@c_CartonNoParm),'') <> '' AND ISNUMERIC(@c_CartonNoParm) = 1
--   BEGIN
--      SET @n_CartonNoParm = CAST(@c_CartonNoParm AS INT)
--   END

/*********************************************/
/* Variables Declaration (End)               */
/*********************************************/



/*********************************************/
/* Temp Tables Creation (Start)              */
/*********************************************/
-- (YokeBeen01) - Start
--    IF ISNULL(OBJECT_ID('tempdb..#TempGSICartonLabel_XML'),'') <> ''
--       DROP TABLE #TempGSICartonLabel_XML
--
--    IF ISNULL(OBJECT_ID('tempdb..#TempGSICartonLabel_Rec'),'') <> ''
--       DROP TABLE #TempGSICartonLabel_Rec
-- (YokeBeen01) - End

   IF @b_debug = 2
   BEGIN
      SELECT 'Creat Temp tables - #TempGSICartonLabel_XML...'
   END

   IF ISNULL(OBJECT_ID('tempdb..#TempGSICartonLabel_XML'),'') = ''
   BEGIN
      -- Start Ricky for SOS161629
/*      CREATE TABLE #TempGSICartonLabel_XML
               ( SeqNo int IDENTITY(1,1),  -- Temp table's PrimaryKey
                 LineText NVARCHAR(1500)    -- XML column
               )
      CREATE INDEX Seq_ind ON #TempGSICartonLabel_XML (SeqNo)  */

      CREATE TABLE #TempGSICartonLabel_XML
               ( SeqNo int IDENTITY(1,1) Primary key,  -- Temp table's PrimaryKey
                 LineText NVARCHAR(1500)                -- XML column
               )      
      -- End Ricky for SOS161629               
   END

   IF @b_debug = 2
   BEGIN
      SELECT 'Creat Temp tables - #TempGSICartonLabel_Rec...'
   END


   -- Start tlting02 16/6/09
   IF ISNULL(OBJECT_ID('tempdb..#Pack_Det'),'') = ''
   BEGIN
      Create table #Pack_Det
      (  
         PackDetail_LabelLine                           NVARCHAR(5) default '' ,        
         PackDetail_SKU                                 NVARCHAR(20) default '',        
         PackDetail_Qty                                 NVARCHAR(10) default '',        
         PackDetail_RefNo                               NVARCHAR(20) default '',        
         PackDetail_UPC                                 NVARCHAR(30) default '',        
         SKU_DESCR                                      NVARCHAR(60) default '',        
         SKU_CLASS                                      NVARCHAR(10) default '',        
         SKU_SKUGROUP                                   NVARCHAR(10) default '',        
         SKU_BUSR5                                      NVARCHAR(30) default '',        
         SKU_itemclass                                  NVARCHAR(10) default '',        
         SKU_Style                                      NVARCHAR(20) default '',        
         SKU_Color                                      NVARCHAR(10) default '',        
         SKU_Size                                       NVARCHAR(5)  default '',         
         SKU_Measurement                                NVARCHAR(5)  default ''
			
      )
   END

-- Create index sort_ind2 ON #Pack_Det (StorerKey, OrderKey,CartonNo , LabelNo)  -- Ricky for SOS161629

--   INSERT INTO #Pack_Det ( OrderKey,   StorerKey,   TTLCnts,   CartonNo,
--                  LabelNo,   TotQty,   TotCarton,   CartonType, Weight , Cube)
--      SELECT PACKHEADER.OrderKey, PACKHEADER.StorerKey, PACKHEADER.TTLCnts, PACKDETAIL.CartonNo,
--        PACKDETAIL.LabelNo,  SUM(PACKDETAIL.Qty) AS TotQty, PACKHEADER.TTLCnts AS TotCarton, ISNULL(RTRIM(PACKINFO.CartonType), '') -- (Vicky01)
--		  , ISNULL(PACKINFO.Weight,0) , ISNULL(PACKINFO.Cube, 0)
--      FROM PACKHEADER PACKHEADER -- (index =Idx_PACKHEADER_orderkey, NOLOCK) -- Ricky for SOS161629
--           JOIN PACKDETAIL PACKDETAIL WITH (NOLOCK) ON ( PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo
--                                                      AND PACKHEADER.StorerKey = PACKDETAIL.StorerKey )
--           LEFT OUTER JOIN PACKINFO PACKINFO WITH (NOLOCK) ON ( PACKDETAIL.PickSlipNo = PACKINFO.PickSlipNo
--                                                      AND PACKDETAIL.CartonNo = PACKINFO.CartonNo )
--      WHERE PACKDETAIL.LabelNo = @c_LabelNo
--		AND	PACKHEADER.Storerkey = @c_Storerkey
--		AND   PACKHEADER.Orderkey = @c_Orderkey
--      AND   ( PACKDETAIL.CartonNo = ISNULL(RTRIM(''),0) OR ISNULL(RTRIM(''),0) = 0  )
--      GROUP BY PACKHEADER.OrderKey, PACKHEADER.StorerKey, PACKHEADER.TTLCnts, PACKDETAIL.CartonNo,
--               PACKDETAIL.LabelNo, PACKINFO.CartonType
--					, PACKINFO.Weight , PACKINFO.Cube	



   IF ISNULL(OBJECT_ID('tempdb..#TempGSICartonLabel_Rec'),'') = ''
   BEGIN

      CREATE TABLE #TempGSICartonLabel_Rec
               (  SeqNo                                          int IDENTITY(1,1),   
                  SeqLineNo as SeqNo,
                  Facility_Descr                                 NVARCHAR(50) default '',        
						Facility_contact1                              NVARCHAR(30) default '',        
                  Facility_Contact2                              NVARCHAR(30) default '',        
                  Facility_Address1                              NVARCHAR(45) default '',        
                  Facility_Address2                              NVARCHAR(45) default '',        
                  Facility_Address3                              NVARCHAR(45) default '',        
                  Facility_Address4                              NVARCHAR(45) default '',        
                  Facility_City                                  NVARCHAR(45) default '',        
                  Facility_State                                 NVARCHAR(45) default '',        
                  Facility_Zip                                   NVARCHAR(18) default '',        
                  Facility_Country                               NVARCHAR(30) default '',        
                  Facility_ISOCntryCode                          NVARCHAR(10) default '',        
                  Facility_Phone1                                NVARCHAR(18) default '',        
                  Facility_Phone2                                NVARCHAR(18) default '',       
                  Facility_Fax1                                  NVARCHAR(18) default '',        
                  Facility_Fax2                                  NVARCHAR(18) default '',        
						Orders_StorerKey                               NVARCHAR(15) default '',        
                  Orders_ExternOrderKey                          NVARCHAR(30) default '',        
                  Orders_OrderDate                               NVARCHAR(14) default '',        
                  Orders_DeliveryDate                            NVARCHAR(14) default '',        
                  Orders_ConsigneeKey                            NVARCHAR(15) default '',        
                  Orders_C_contact1                              NVARCHAR(30) default '',        
                  Orders_C_Contact2                              NVARCHAR(30) default '',        
                  Orders_C_Company                               NVARCHAR(45) default '',        
                  Orders_C_Address1                              NVARCHAR(45) default '',        
                  Orders_C_Address2                             NVARCHAR(45) default '',        
                  Orders_C_Address3                              NVARCHAR(45) default '',        
                  Orders_C_Address4                              NVARCHAR(45) default '',        
                  Orders_C_City                                  NVARCHAR(45) default '',        
                  Orders_C_State                                 NVARCHAR(45) default '',        
                  Orders_C_Zip                                   NVARCHAR(18) default '',        
                  Orders_C_Country                               NVARCHAR(30) default '',        
                  Orders_C_ISOCntryCode                          NVARCHAR(10) default '',        
                  Orders_C_Phone1                                NVARCHAR(18) default '',        
                  Orders_C_Phone2                                NVARCHAR(18) default '',        
                  Orders_C_Fax1                                  NVARCHAR(18) default '',        
                  Orders_C_Fax2                                  NVARCHAR(18) default '',        
                  Orders_BuyerPO                                 NVARCHAR(20) default '',        
                  Orders_BillToKey                               NVARCHAR(15) default '',        
                  Orders_B_contact1                              NVARCHAR(30) default '',        
                  Orders_B_Contact2                             NVARCHAR(30) default '',        
                  Orders_B_Company                               NVARCHAR(45) default '',        
                  Orders_B_Address1                              NVARCHAR(45) default '',        
                  Orders_B_Address2                              NVARCHAR(45) default '',        
                  Orders_B_Address3                              NVARCHAR(45) default '',        
                  Orders_B_Address4                              NVARCHAR(45) default '',        
                  Orders_B_City                                  NVARCHAR(45) default '',        
                  Orders_B_State                                 NVARCHAR(45) default '',        
                  Orders_B_Zip                                   NVARCHAR(18) default '',        
                  Orders_B_Country                               NVARCHAR(30) default '',        
                  Orders_B_ISOCntryCode                          NVARCHAR(10) default '',        
                  Orders_B_Phone1                                NVARCHAR(18) default '',        
                  Orders_B_Phone2                                NVARCHAR(18) default '',        
                  Orders_B_Fax1                                  NVARCHAR(18) default '',        
                  Orders_B_Fax2                                  NVARCHAR(18) default '',        
                  Orders_DischargePlace                          NVARCHAR(30) default '',        
                  Orders_DeliveryPlace                           NVARCHAR(30) default '',        
                  Orders_IntermodalVehicle                       NVARCHAR(30) default '',        
                  Orders_CountryOfOrigin                         NVARCHAR(30) default '',        
                  Orders_CountryDestination                      NVARCHAR(30) default '',        
                  Orders_Route                                   NVARCHAR(10) default '',        
                  Orders_Stop                                    NVARCHAR(10) default '',        
                  Orders_Notes                                   NVARCHAR(256) default '',       
                  Orders_EffectiveDate                           NVARCHAR(14) default '',        
                  Orders_MBOLKey                                 NVARCHAR(10) default '',        
                  Orders_InvoiceNo                               NVARCHAR(20) default '',        
                  Orders_LoadKey                                 NVARCHAR(10) default '',        
                  Orders_LabelPrice                              NVARCHAR(5) default '' ,        
                  Orders_UserDefine01                            NVARCHAR(20) default '',        
                  Orders_UserDefine02                           NVARCHAR(20) default '',        
                  Orders_UserDefine03                            NVARCHAR(20) default '',        
                  Orders_UserDefine04                            NVARCHAR(20) default '',        
                  Orders_UserDefine05                            NVARCHAR(20) default '',        
                  Orders_UserDefine06                            NVARCHAR(14) default '',        
                  Orders_UserDefine07                            NVARCHAR(14) default '',        
                  Orders_UserDefine08                            NVARCHAR(10) default '',        
                  Orders_UserDefine09                            NVARCHAR(10) default '',        
                  Orders_UserDefine10                            NVARCHAR(10) default '',        
                  Orders_DeliveryNote                            NVARCHAR(10) default '',        
                  Orders_M_Contact1                              NVARCHAR(30) default '',        
                  Orders_M_Contact2                              NVARCHAR(30) default '',        
                  Orders_M_Company                               NVARCHAR(45) default '',        
                  Orders_M_Address1                              NVARCHAR(45) default '',        
                  Orders_M_Address2                              NVARCHAR(45) default '',        
                  Orders_M_Address3                              NVARCHAR(45) default '',        
                  Orders_M_Address4                              NVARCHAR(45) default '',        
                  Orders_M_City                                  NVARCHAR(45) default '',        
                  Orders_M_State                                 NVARCHAR(45) default '',        
                  Orders_M_Zip                                   NVARCHAR(18) default '',        
                  Orders_M_Country                               NVARCHAR(30) default '',        
                  Orders_M_ISOCntryCode                          NVARCHAR(10) default '',        
                  Orders_M_Phone1                                NVARCHAR(18) default '',        
                  Orders_M_Phone2                                NVARCHAR(18) default '',        
                  Orders_M_Fax1                                  NVARCHAR(18) default '',        
                  Orders_M_Fax2                                  NVARCHAR(18) default '',        
                  Orders_M_vat                                   NVARCHAR(18) default '',        
                  OrderInfo_OrderInfo01                          NVARCHAR(30) default '',        
                  OrderInfo_OrderInfo02                          NVARCHAR(30) default '',        
                  OrderInfo_OrderInfo03                          NVARCHAR(30) default '',        
                  OrderInfo_OrderInfo04                          NVARCHAR(30) default '',        
                  OrderInfo_OrderInfo05                          NVARCHAR(30) default '',        
                  OrderInfo_OrderInfo06                          NVARCHAR(30) default '',        
                  OrderInfo_OrderInfo07                          NVARCHAR(30) default '',        
                  OrderInfo_OrderInfo08                          NVARCHAR(30) default '',        
                  OrderInfo_OrderInfo09                          NVARCHAR(30) default '',        
                  OrderInfo_OrderInfo10                          NVARCHAR(30) default '',        
                  CartonTrack_TrackingNo                         NVARCHAR(20) default '',        
                  Cartonization_CartonLength                     NVARCHAR(10) default '',        
                  Cartonization_CartonWidth                      NVARCHAR(10) default '',        
                  Cartonization_CartonHeight                     NVARCHAR(10) default '',        
                  PackInfo_Weight                                NVARCHAR(10) default '',        
                  PackInfo_Cube                                  NVARCHAR(10) default '',        
                  PackInfo_CartonType                            NVARCHAR(10) default '',        
                  PackDetail_PickSlipNo                          NVARCHAR(10) default '',        
                  PackDetail_CartonNo                            NVARCHAR(10) default '',        
                  PackDetail_LabelNo                             NVARCHAR(20) default '',   
                  CustomHeader_Field_1									  NVARCHAR(30) default '',
                  CustomHeader_Field_2									  NVARCHAR(10) default '',                      
                  CustomHeader_Field_3									  NVARCHAR(10) default '', 
                  CustomHeader_Field_4									  NVARCHAR(40) default '', 
                  CustomHeader_Field_5									  NVARCHAR(40) default '', 
                  CustomHeader_Field_6									  NVARCHAR(40) default '', 
                  CustomHeader_Field_7									  NVARCHAR(40) default '', 
                  CustomHeader_Field_8									  NVARCHAR(40) default '', 
                  CustomHeader_Field_9									  NVARCHAR(40) default '', 
                  CustomHeader_Field_10								  NVARCHAR(40) default '', 
						Primary key (SeqNo)
               )

--      CREATE clustered INDEX Seq_ind ON #TempGSICartonLabel_Rec (SeqNo)     -- Added by tlting01, comment by Ricky for SOS161629
--      CREATE INDEX Seq_ind2 ON #TempGSICartonLabel_Rec (SeqNo,  OrderKey)   -- Ricky for SOS161629
   END

/*********************************************/
/* Temp Tables Creation (End)                */
/*********************************************/
 DECLARE @n_RunNumber int
 SELECT @n_RunNumber = 0
/*********************************************/
/* Data extraction (Start)                   */
/*********************************************/

   IF @b_debug = 1
   BEGIN
      SELECT 'Extract records into Temp table - #TempGSICartonLabel_Rec...'
   END
   -- Extract records into Temp table.

   INSERT INTO #TempGSICartonLabel_Rec
         (   Facility_Descr            
				,Facility_contact1         
				,Facility_Contact2         
				,Facility_Address1         
				,Facility_Address2         
				,Facility_Address3         
				,Facility_Address4         
				,Facility_City             
				,Facility_State            
				,Facility_Zip              
				,Facility_Country          
				,Facility_ISOCntryCode     
				,Facility_Phone1           
				,Facility_Phone2           
				,Facility_Fax1             
				,Facility_Fax2
				,Orders_StorerKey          
				,Orders_ExternOrderKey     
				,Orders_OrderDate          
				,Orders_DeliveryDate       
				,Orders_ConsigneeKey       
				,Orders_C_contact1         
				,Orders_C_Contact2         
				,Orders_C_Company          
				,Orders_C_Address1         
				,Orders_C_Address2         
				,Orders_C_Address3         
				,Orders_C_Address4         
				,Orders_C_City             
				,Orders_C_State            
				,Orders_C_Zip              
				,Orders_C_Country          
				,Orders_C_ISOCntryCode     
				,Orders_C_Phone1           
				,Orders_C_Phone2           
				,Orders_C_Fax1             
				,Orders_C_Fax2             
				,Orders_BuyerPO            
				,Orders_BillToKey          
				,Orders_B_contact1         
				,Orders_B_Contact2         
				,Orders_B_Company          
				,Orders_B_Address1         
				,Orders_B_Address2         
				,Orders_B_Address3         
				,Orders_B_Address4         
				,Orders_B_City             
				,Orders_B_State            
				,Orders_B_Zip              
				,Orders_B_Country          
				,Orders_B_ISOCntryCode     
				,Orders_B_Phone1           
				,Orders_B_Phone2           
				,Orders_B_Fax1             
				,Orders_B_Fax2             
				,Orders_DischargePlace     
				,Orders_DeliveryPlace      
				,Orders_IntermodalVehicle  
				,Orders_CountryOfOrigin    
				,Orders_CountryDestination 
				,Orders_Route              
				,Orders_Stop               
				,Orders_Notes              
				,Orders_EffectiveDate      
				,Orders_MBOLKey            
				,Orders_InvoiceNo          
				,Orders_LoadKey            
				,Orders_LabelPrice         
				,Orders_UserDefine01       
				,Orders_UserDefine02       
				,Orders_UserDefine03       
				,Orders_UserDefine04       
				,Orders_UserDefine05       
				,Orders_UserDefine06       
				,Orders_UserDefine07       
				,Orders_UserDefine08       
				,Orders_UserDefine09       
				,Orders_UserDefine10       
				,Orders_DeliveryNote       
				,Orders_M_Contact1         
				,Orders_M_Contact2         
				,Orders_M_Company          
				,Orders_M_Address1         
				,Orders_M_Address2         
				,Orders_M_Address3         
				,Orders_M_Address4         
				,Orders_M_City             
				,Orders_M_State            
				,Orders_M_Zip              
				,Orders_M_Country          
				,Orders_M_ISOCntryCode     
				,Orders_M_Phone1           
				,Orders_M_Phone2           
				,Orders_M_Fax1             
				,Orders_M_Fax2             
				,Orders_M_vat              
				,OrderInfo_OrderInfo01     
				,OrderInfo_OrderInfo02     
				,OrderInfo_OrderInfo03     
				,OrderInfo_OrderInfo04     
				,OrderInfo_OrderInfo05     
				,OrderInfo_OrderInfo06     
				,OrderInfo_OrderInfo07     
				,OrderInfo_OrderInfo08     
				,OrderInfo_OrderInfo09     
				,OrderInfo_OrderInfo10     
				,CartonTrack_TrackingNo    
				,Cartonization_CartonLength
				,Cartonization_CartonWidth 
				,Cartonization_CartonHeight
				,PackInfo_Weight           
				,PackInfo_Cube             
				,PackInfo_CartonType       
				,PackDetail_PickSlipNo     
				,PackDetail_CartonNo       
				,PackDetail_LabelNo  
				,CustomHeader_Field_1
				,CustomHeader_Field_2         
				,CustomHeader_Field_3
				,CustomHeader_Field_4
				,CustomHeader_Field_5
				,CustomHeader_Field_6
				,CustomHeader_Field_7
				,CustomHeader_Field_8
				,CustomHeader_Field_9
				,CustomHeader_Field_10 )				
         SELECT ISNULL(RTRIM(Facility.Descr),'')
			,ISNULL(RTRIM(Facility.contact1),'')
			,ISNULL(RTRIM(Facility.Contact2),'')
			,ISNULL(RTRIM(Facility.Address1),'')
			,ISNULL(RTRIM(Facility.Address2),'')
			,ISNULL(RTRIM(Facility.Address3),'')
			,ISNULL(RTRIM(Facility.Address4),'')
			,ISNULL(RTRIM(Facility.City),'')
			,ISNULL(RTRIM(Facility.State),'')
			,ISNULL(RTRIM(Facility.Zip),'')
			,ISNULL(RTRIM(Facility.Country),'')
			,ISNULL(RTRIM(Facility.ISOCntryCode),'')
			,ISNULL(RTRIM(Facility.Phone1),'')
			,ISNULL(RTRIM(Facility.Phone2),'')
			,ISNULL(RTRIM(Facility.Fax1),'')
			,ISNULL(RTRIM(Facility.Fax2),'')
			,ISNULL(RTRIM(Orders.StorerKey),'')
			,ISNULL(RTRIM(Orders.ExternOrderKey),'')
--			,ISNULL(RTRIM(Orders.OrderDate),'')
--			,ISNULL(RTRIM(Orders.DeliveryDate),'')
			,RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(YEAR, ORDERS.OrderDate))), 4) + 
           + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(MONTH, ORDERS.OrderDate))), 2) + 
           + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(DAY, ORDERS.OrderDate))), 2) + 
			  + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(HOUR, ORDERS.OrderDate))), 2) +
			  + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(MINUTE, ORDERS.OrderDate))), 2) +
			  + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(SECOND, ORDERS.OrderDate))), 2)
			,RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(YEAR, ORDERS.DeliveryDate))), 4) + 
           + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(MONTH, ORDERS.DeliveryDate))), 2) + 
           + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(DAY, ORDERS.DeliveryDate))), 2) + 
			  + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(HOUR, ORDERS.DeliveryDate))), 2) +
			  + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(MINUTE, ORDERS.DeliveryDate))), 2) +
			  + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(SECOND, ORDERS.DeliveryDate))), 2)
			,ISNULL(RTRIM(Orders.ConsigneeKey),'')
			,ISNULL(RTRIM(Orders.C_contact1),'')
			,ISNULL(RTRIM(Orders.C_Contact2),'')
			,ISNULL(RTRIM(Orders.C_Company),'')
			,ISNULL(RTRIM(Orders.C_Address1),'')
			,ISNULL(RTRIM(Orders.C_Address2),'')
			,ISNULL(RTRIM(Orders.C_Address3),'')
			,ISNULL(RTRIM(Orders.C_Address4),'')
			,ISNULL(RTRIM(Orders.C_City),'')
			,ISNULL(RTRIM(Orders.C_State),'')
			,ISNULL(RTRIM(Orders.C_Zip),'')
			,ISNULL(RTRIM(Orders.C_Country),'')
			,ISNULL(RTRIM(Orders.C_ISOCntryCode),'')
			,ISNULL(RTRIM(Orders.C_Phone1),'')
			,ISNULL(RTRIM(Orders.C_Phone2),'')
			,ISNULL(RTRIM(Orders.C_Fax1),'')
			,ISNULL(RTRIM(Orders.C_Fax2),'')
			,ISNULL(RTRIM(Orders.BuyerPO),'')
			,ISNULL(RTRIM(Orders.BillToKey),'')
			,ISNULL(RTRIM(Orders.B_contact1),'')
			,ISNULL(RTRIM(Orders.B_Contact2),'')
			,ISNULL(RTRIM(Orders.B_Company),'')
			,ISNULL(RTRIM(Orders.B_Address1),'')
			,ISNULL(RTRIM(Orders.B_Address2),'')
			,ISNULL(RTRIM(Orders.B_Address3),'')
			,ISNULL(RTRIM(Orders.B_Address4),'')
			,ISNULL(RTRIM(Orders.B_City),'')
			,ISNULL(RTRIM(Orders.B_State),'')
			,ISNULL(RTRIM(Orders.B_Zip),'')
			,ISNULL(RTRIM(Orders.B_Country),'')
			,ISNULL(RTRIM(Orders.B_ISOCntryCode),'')
			,ISNULL(RTRIM(Orders.B_Phone1),'')
			,ISNULL(RTRIM(Orders.B_Phone2),'')
			,ISNULL(RTRIM(Orders.B_Fax1),'')
			,ISNULL(RTRIM(Orders.B_Fax2),'')
			,ISNULL(RTRIM(Orders.DischargePlace),'')
			,ISNULL(RTRIM(Orders.DeliveryPlace),'')
			,ISNULL(RTRIM(Orders.IntermodalVehicle),'')
			,ISNULL(RTRIM(Orders.CountryOfOrigin),'')
			,ISNULL(RTRIM(Orders.CountryDestination),'')
			,ISNULL(RTRIM(Orders.Route),'')
			,ISNULL(RTRIM(Orders.Stop),'')
			,RIGHT(ISNULL(RTRIM(CONVERT(NVARCHAR(255), Orders.Notes)),''), 255)
			--,ISNULL(RTRIM(Orders.EffectiveDate),'')
			,RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(YEAR, ORDERS.EffectiveDate))), 4) + 
           + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(MONTH, ORDERS.EffectiveDate))), 2) + 
           + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(DAY, ORDERS.EffectiveDate))), 2) + 
			  + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(HOUR, ORDERS.EffectiveDate))), 2) +
			  + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(MINUTE, ORDERS.EffectiveDate))), 2) +
			  + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(SECOND, ORDERS.EffectiveDate))), 2)
			,ISNULL(RTRIM(Orders.MBOLKey),'')
			,ISNULL(RTRIM(Orders.InvoiceNo),'')
			,ISNULL(RTRIM(Orders.LoadKey),'')
			,ISNULL(RTRIM(Orders.LabelPrice),'')
			,ISNULL(RTRIM(Orders.UserDefine01),'')
			,ISNULL(RTRIM(Orders.UserDefine02),'')
			,ISNULL(RTRIM(Orders.UserDefine03),'')
			,ISNULL(RTRIM(Orders.UserDefine04),'')
			,ISNULL(RTRIM(Orders.UserDefine05),'')
			--,ISNULL(RTRIM(Orders.UserDefine06),'')
			--,ISNULL(RTRIM(Orders.UserDefine07),'')
			,RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(YEAR, ORDERS.UserDefine06))), 4) + 
           + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(MONTH, ORDERS.UserDefine06))), 2) + 
           + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(DAY, ORDERS.UserDefine06))), 2) + 
			  + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(HOUR, ORDERS.UserDefine06))), 2) +
			  + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(MINUTE, ORDERS.UserDefine06))), 2) +
			  + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(SECOND, ORDERS.UserDefine06))), 2)
			,RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(YEAR, ORDERS.UserDefine07))), 4) + 
           + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(MONTH, ORDERS.UserDefine07))), 2) + 
           + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(DAY, ORDERS.UserDefine07))), 2) + 
			  + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(HOUR, ORDERS.UserDefine07))), 2) +
			  + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(MINUTE, ORDERS.UserDefine07))), 2) +
			  + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(SECOND, ORDERS.UserDefine07))), 2)
			,ISNULL(RTRIM(Orders.UserDefine08),'')
			,ISNULL(RTRIM(Orders.UserDefine09),'')
			,ISNULL(RTRIM(Orders.UserDefine10),'')
			,ISNULL(RTRIM(Orders.DeliveryNote),'')
			,ISNULL(RTRIM(Orders.M_Contact1),'')
			,ISNULL(RTRIM(Orders.M_Contact2),'')
			,ISNULL(RTRIM(Orders.M_Company),'')
			,ISNULL(RTRIM(Orders.M_Address1),'')
			,ISNULL(RTRIM(Orders.M_Address2),'')
			,ISNULL(RTRIM(Orders.M_Address3),'')
			,ISNULL(RTRIM(Orders.M_Address4),'')
			,ISNULL(RTRIM(Orders.M_City),'')
			,ISNULL(RTRIM(Orders.M_State),'')
			,ISNULL(RTRIM(Orders.M_Zip),'')
			,ISNULL(RTRIM(Orders.M_Country),'')
			,ISNULL(RTRIM(Orders.M_ISOCntryCode),'')
			,ISNULL(RTRIM(Orders.M_Phone1),'')
			,ISNULL(RTRIM(Orders.M_Phone2),'')
			,ISNULL(RTRIM(Orders.M_Fax1),'')
			,ISNULL(RTRIM(Orders.M_Fax2),'')
			,ISNULL(RTRIM(Orders.M_vat),'')
			,ISNULL(RTRIM(OrderInfo.OrderInfo01),'')
			,ISNULL(RTRIM(OrderInfo.OrderInfo02),'')
			,ISNULL(RTRIM(OrderInfo.OrderInfo03),'')
			,ISNULL(RTRIM(OrderInfo.OrderInfo04),'')
			,ISNULL(RTRIM(OrderInfo.OrderInfo05),'')
			,ISNULL(RTRIM(OrderInfo.OrderInfo06),'')
			,ISNULL(RTRIM(OrderInfo.OrderInfo07),'')
			,ISNULL(RTRIM(OrderInfo.OrderInfo08),'')
			,ISNULL(RTRIM(OrderInfo.OrderInfo09),'')
			,ISNULL(RTRIM(OrderInfo.OrderInfo10),'')
			,ISNULL(RTRIM(CartonTrack.TrackingNo),'')
			,ISNULL(RTRIM(Cartonization.CartonLength),'')
			,ISNULL(RTRIM(Cartonization.CartonWidth),'')
			,ISNULL(RTRIM(Cartonization.CartonHeight),'')
			,ISNULL(RTRIM(PackInfo.Weight),'')
			,ISNULL(RTRIM(PackInfo.[Cube]),'')
			,ISNULL(RTRIM(PackInfo.CartonType),'')
			,ISNULL(RTRIM(PackDetail.PickSlipNo),'')
			,ISNULL(RTRIM(PackDetail.CartonNo),'')
			,ISNULL(RTRIM(PackDetail.LabelNo),'')
			,ISNULL(RTRIM(CodeLkup.Code),'')
			,(SUM(SKU.STDGrossWGT * PACKDETAIL.Qty) + Cartonization.CartonWeight ) -- (ChewKP01)
			,CASE 
			 WHEN CHARINDEX('-', ISNULL(RTRIM(Orders.MarkForKey),'')) > 0 THEN RIGHT(ISNULL(RTRIM(Orders.MarkForKey),'') , (LEN(ISNULL(RTRIM(Orders.MarkForKey),'')) - CHARINDEX('-', ISNULL(RTRIM(Orders.MarkForKey),''))))
			 ELSE ''
			 END
			,ISNULL(RTRIM(CARTONTRACK.CarrierRef1),'')
			,''
			,''
			,''
			,''
			,''
			,''
			FROM PACKDETAIL  (NOLOCK)
         INNER JOIN STORER (NOLOCK) ON STORER.Storerkey = PACKDETAIL.Storerkey
         INNER JOIN PACKHEADER (NOLOCK) ON PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo
         INNER JOIN ORDERS (NOLOCK) ON ORDERS.Orderkey = PACKHEADER.Orderkey
         INNER JOIN ORDERINFO (NOLOCK) ON ORDERINFO.Orderkey = ORDERS.Orderkey
         INNER JOIN FACILITY (NOLOCK) ON Facility.Facility = ORDERS.Facility
         INNER JOIN CARTONTRACK (NOLOCK) ON CARTONTRACK.LabelNo = PACKDETAIL.LabelNo
         INNER JOIN PACKINFO (NOLOCK) ON (PACKINFO.PickSlipNo = PackDetail.PickSlipNo
														AND PACKINFO.CartonNo = PackDetail.CartonNo)
         INNER JOIN SKU (NOLOCK) ON (SKU.SKU = PACKDETAIL.SKU 
         									 AND SKU.Storerkey = PACKDETAIL.Storerkey)
         INNER JOIN CARTONIZATION (NOLOCK) ON (CARTONIZATION.CartonType = PACKINFO.CartonType 
         												  AND CARTONIZATION.CartonizationGroup = STORER.CartonGroup)
			INNER JOIN CODELKUP (NOLOCK) ON (CODELKUP.Short = ORDERS.Facility
														AND  CODELKUP.LISTNAME = 'CARTERFAC' ) 
         WHERE PACKDETAIL.LabelNo = @c_LabelNo
         AND STORER.Storerkey = @c_Storerkey
         GROUP BY 
			 Facility.Descr
			,CodeLkup.Code
         ,Facility.contact1
         ,Facility.Contact2
         ,Facility.Address1
         ,Facility.Address2
         ,Facility.Address3
         ,Facility.Address4
         ,Facility.City
         ,Facility.State
         ,Facility.Zip
         ,Facility.Country
         ,Facility.ISOCntryCode
         ,Facility.Phone1
         ,Facility.Phone2
         ,Facility.Fax1
         ,Facility.Fax2
			,Orders.MarkForKey
         ,Orders.StorerKey
         ,Orders.ExternOrderKey
         ,Orders.OrderDate
         ,Orders.DeliveryDate
         ,Orders.ConsigneeKey
         ,Orders.C_contact1
         ,Orders.C_Contact2
         ,Orders.C_Company
         ,Orders.C_Address1
         ,Orders.C_Address2
         ,Orders.C_Address3
         ,Orders.C_Address4
         ,Orders.C_City
         ,Orders.C_State
         ,Orders.C_Zip
         ,Orders.C_Country
         ,Orders.C_ISOCntryCode
         ,Orders.C_Phone1
         ,Orders.C_Phone2
         ,Orders.C_Fax1
         ,Orders.C_Fax2
         ,Orders.BuyerPO
         ,Orders.BillToKey
         ,Orders.B_contact1
         ,Orders.B_Contact2
         ,Orders.B_Company
         ,Orders.B_Address1
         ,Orders.B_Address2
         ,Orders.B_Address3
         ,Orders.B_Address4
         ,Orders.B_City
         ,Orders.B_State
         ,Orders.B_Zip
         ,Orders.B_Country
         ,Orders.B_ISOCntryCode
         ,Orders.B_Phone1
         ,Orders.B_Phone2
         ,Orders.B_Fax1
         ,Orders.B_Fax2
         ,Orders.DischargePlace
         ,Orders.DeliveryPlace
         ,Orders.IntermodalVehicle
         ,Orders.CountryOfOrigin
         ,Orders.CountryDestination
         ,Orders.Route
         ,Orders.Stop
         ,RIGHT(ISNULL(RTRIM(CONVERT(NVARCHAR(255), Orders.Notes)),''), 255)
         ,Orders.EffectiveDate
         ,Orders.MBOLKey
         ,Orders.InvoiceNo
         ,Orders.LoadKey
         ,Orders.LabelPrice
         ,Orders.UserDefine01
         ,Orders.UserDefine02
         ,Orders.UserDefine03
         ,Orders.UserDefine04
         ,Orders.UserDefine05
         ,Orders.UserDefine06
         ,Orders.UserDefine07
         ,Orders.UserDefine08
         ,Orders.UserDefine09
         ,Orders.UserDefine10
         ,Orders.DeliveryNote
         ,Orders.M_Contact1
         ,Orders.M_Contact2
         ,Orders.M_Company
         ,Orders.M_Address1
         ,Orders.M_Address2
         ,Orders.M_Address3
         ,Orders.M_Address4
         ,Orders.M_City
         ,Orders.M_State
         ,Orders.M_Zip
         ,Orders.M_Country
         ,Orders.M_ISOCntryCode
         ,Orders.M_Phone1
         ,Orders.M_Phone2
         ,Orders.M_Fax1
         ,Orders.M_Fax2
         ,Orders.M_vat
         ,OrderInfo.OrderInfo01
         ,OrderInfo.OrderInfo02
         ,OrderInfo.OrderInfo03
         ,OrderInfo.OrderInfo04
         ,OrderInfo.OrderInfo05
         ,OrderInfo.OrderInfo06
         ,OrderInfo.OrderInfo07
         ,OrderInfo.OrderInfo08
         ,OrderInfo.OrderInfo09
         ,OrderInfo.OrderInfo10
         ,CartonTrack.TrackingNo
         ,Cartonization.CartonLength
         ,Cartonization.CartonWidth
         ,Cartonization.CartonHeight
         ,PackInfo.Weight
         ,PackInfo.[Cube]
         ,PackInfo.CartonType
         ,PackDetail.PickSlipNo
         ,PackDetail.CartonNo
         ,PackDetail.LabelNo
			,CARTONTRACK.CarrierRef1
         ,Cartonization.CartonWeight
         


   IF @b_debug = 2
   BEGIN
      SELECT '#TempCSICartonLabel_Rec.. '
      SELECT * FROM #TempGSICartonLabel_Rec
   END
   

/*********************************************/
/* Data extraction (Start)                   */
/*********************************************/
/*********************************************/
/* Cursor Loop - XML Data Insertion (Start)  */
/*********************************************/
   DECLARE @n_FieldID int
         , @c_ColName NVARCHAR(225)
         , @c_ColValues NVARCHAR(1000)
         , @n_ColID int
         , @n_ColCnt int
         , @n_LIColID int

   SET @n_FieldID = 0
   SET @c_ColValues = ''
   SET @c_ColName = ''
   SET @n_ColID = 0
   SET @c_BuyerPO = ''
   SET @n_LIColID = 0

   
      -- Insert <?xml Version>
      INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
      VALUES ('<?xml version="1.0" encoding="UTF-8" standalone="no"?>', @@SPID)

      -- Insert <labels>
      INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
      VALUES ('<labels _FORMAT = "' + @c_FilePath + ISNULL(RTRIM(@c_TemplateID),'') + '" _QUANTITY="1" _PRINTERNAME="' +
              ISNULL(RTRIM(@c_PrinterID),'') + '" _JOBNAME="Shipping">', @@SPID)
   
   

/*********************************************/
/* Cursor Loop - File level                  */
/*********************************************/
   
      IF @b_debug = 1
      BEGIN
         SELECT 'GSI_Label_Cur.. '
         SELECT SeqLineNo, SeqNo
           FROM #TempGSICartonLabel_Rec
          ORDER BY SeqLineNo, SeqNo
      END
	
	 -- Insert <label> - record level start
   INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
   VALUES ('<label>', @@SPID)

   DECLARE GSI_Label_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Name FROM tempdb.sys.columns (NOLOCK) 
   WHERE object_id = object_id('tempdb..#TempGSICartonLabel_Rec')
   
   OPEN GSI_Label_Cur
   
   FETCH NEXT FROM GSI_Label_Cur INTO @c_ColumnName
   
   
   WHILE (@@FETCH_STATUS <> -1)
   BEGIN

/*********************************************/
/* Cursor Loop - Record/Line level           */
/*********************************************/
    
         
         -- Start Generating XML Part1 -- Common Information(Start)
         
			-- Do No Print Extract First 2 Column --
			IF ISNULL(RTRIM(@c_ColumnName),'') <> 'SeqNo' AND ISNULL(RTRIM(@c_ColumnName),'') <> 'SeqLineNo'
			BEGIN
			   
				SET @c_ExecStatements = ''
				SET @c_ExecArguments = ''

				SET @c_ExecStatements = N'SELECT @c_ColumnValue = [' + ISNULL(RTRIM(@c_ColumnName),'') + ']' + 
												 ' FROM #TEMPGSICARTONLABEL_Rec ' 
												 --' WHERE SeqNo = ' + ISNULL(RTRIM(@n_SeqNo),0) +
												 --' AND SeqLineNo = ' + ISNULL(RTRIM(@n_SeqLineNo),0)

				SET @c_ExecArguments = N'@c_ColumnValue NVARCHAR(255) OUTPUT '

				IF @b_debug = 2
					SELECT @c_ExecStatements, @c_ExecArguments

				EXEC sp_ExecuteSql @c_ExecStatements, @c_ExecArguments, @c_ColumnValue OUTPUT
	      
	         
				INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
						VALUES ('<variable name="' + ISNULL(RTRIM(@c_ColumnName),0) + '">' +
									ISNULL(RTRIM(@c_ColumnValue),'') + '</variable>', @@SPID)
	    
				-- Start Generating XML Part1 -- Common Information(End)
			   
         END

      FETCH NEXT FROM GSI_Label_Cur INTO @c_ColumnName

      
   END -- END WHILE (@@FETCH_STATUS <> -1)

   CLOSE GSI_Label_Cur
   DEALLOCATE GSI_Label_Cur
	
         -- Start Generating XML Part2 -- PackingDetail (Start)
         SET @n_RowCount = 1
			
			
			INSERT INTO #Pack_Det
			SELECT PD.LabelLine, PD.SKU, PD.QTY, PD.RefNo, PD.UPC
         ,SKU.DESCR, SKU.CLASS , SKU.SKUGROUP, SKU.BUSR5, SKU.ItemClass
         ,SKU.Style, SKU.Color, SKU.Size, SKU.Measurement --,  (SUM(SKU.STDGrossWGT * PD.Qty) + Cartonization.CartonWeight )
         FROM PACKDETAIL PD (NOLOCK)
			INNER JOIN STORER (NOLOCK) ON STORER.Storerkey = PD.Storerkey
         INNER JOIN SKU (NOLOCK) ON (SKU.SKU = PD.SKU
         						 AND SKU.Storerkey = PD.Storerkey)
			INNER JOIN PACKINFO (NOLOCK) ON (PACKINFO.PickSlipNo = PD.PickSlipNo
													   AND PACKINFO.CartonNo = PD.CartonNo)
         INNER JOIN CARTONIZATION (NOLOCK) ON (CARTONIZATION.CartonType = PACKINFO.CartonType 
         												  AND CARTONIZATION.CartonizationGroup = STORER.CartonGroup)
         WHERE PD.LabelNo = @c_LabelNo
         AND PD.Storerkey = @c_Storerkey
			GROUP BY 
			PD.LabelLine, PD.SKU, PD.QTY, PD.RefNo, PD.UPC
         ,SKU.DESCR, SKU.CLASS , SKU.SKUGROUP, SKU.BUSR5, SKU.ItemClass
         ,SKU.Style, SKU.Color, SKU.Size, SKU.Measurement --, Cartonization.CartonWeight

      
			DECLARE PD_Loop_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR

	      SELECT [PackDetail_LabelLine] From #Pack_Det
			Order By [PackDetail_LabelLine]

			OPEN PD_Loop_Cur
	        
			FETCH NEXT FROM PD_Loop_Cur INTO @c_LabelLineNo

			WHILE (@@FETCH_STATUS <> -1)
			BEGIN


				DECLARE PD_Items_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
				
				SELECT Name FROM tempdb.sys.columns (NOLOCK) 
				WHERE object_id = object_id('tempdb..#Pack_Det')
	         
				OPEN PD_Items_Cur
	         
				FETCH NEXT FROM PD_Items_Cur INTO @c_PDColumnName
	        
	         
				WHILE (@@FETCH_STATUS <> -1)
				BEGIN
					 
				SET @c_ExecStatements = ''
				SET @c_ExecArguments = ''

				SET @c_ExecStatements = N'SELECT @c_PDColumnValue = [' + ISNULL(RTRIM(@c_PDColumnName),'') + ']' +
												 ' FROM #Pack_Det ' +
												 ' WHERE [PackDetail_LabelLine] = ' + @c_LabelLineNo
	                                  
				SET @c_ExecArguments = N'@c_PDColumnValue NVARCHAR(255) OUTPUT '

				IF @b_debug = 2
					SELECT @c_ExecStatements, @c_ExecArguments

				EXEC sp_ExecuteSql @c_ExecStatements, @c_ExecArguments, @c_PDColumnValue OUTPUT

				

  					INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
						VALUES ('<variable name="' + ISNULL(RTRIM(@c_PDColumnName),0) + '_' + RTRIM(RTRIM(CONVERT(CHAR(4), @n_RowCount))) + '">' +
									ISNULL(RTRIM(@c_PDColumnValue),'') + '</variable>', @@SPID)
	            
					FETCH NEXT FROM PD_Items_Cur INTO @c_PDColumnName
	         
				END
				
	         
				CLOSE PD_Items_Cur
				DEALLOCATE PD_Items_Cur
				
				SET @n_RowCount = @n_RowCount + 1
				SET @n_CountPD = @n_CountPD - 1

				FETCH NEXT FROM PD_Loop_Cur INTO @c_LabelLineNo
		
			END --@n_CountPD <= 0
			
			CLOSE PD_Loop_Cur
			DEALLOCATE PD_Loop_Cur

			-- Start Generating XML Part2 -- PackingDetail (End)

			-- Generate Blank Label If Nothing Found (Start)
			IF NOT EXISTS (SELECT 1 FROM #Pack_Det)
			BEGIN
				SET @n_RowCount = 1

				DECLARE PD_Items_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
				
				SELECT Name FROM tempdb.sys.columns (NOLOCK) 
				WHERE object_id = object_id('tempdb..#Pack_Det')
	         
				OPEN PD_Items_Cur
	         
				FETCH NEXT FROM PD_Items_Cur INTO @c_PDColumnName
	        
	         
				WHILE (@@FETCH_STATUS <> -1)
				BEGIN
					 
				SET @c_ExecStatements = ''
				SET @c_ExecArguments = ''

				SET @c_ExecStatements = N'SELECT @c_PDColumnValue = [' + ISNULL(RTRIM(@c_PDColumnName),'') + ']' +
												 ' FROM #Pack_Det '
												 
	                                  
				SET @c_ExecArguments = N'@c_PDColumnValue NVARCHAR(255) OUTPUT '

				IF @b_debug = 2
					SELECT @c_ExecStatements, @c_ExecArguments

				EXEC sp_ExecuteSql @c_ExecStatements, @c_ExecArguments, @c_PDColumnValue OUTPUT

				

  					INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
						VALUES ('<variable name="' + ISNULL(RTRIM(@c_PDColumnName),0) + '_' + RTRIM(RTRIM(CONVERT(CHAR(4), @n_RowCount))) + '">' +
									ISNULL(RTRIM(@c_PDColumnValue),'') + '</variable>', @@SPID)
	            
					FETCH NEXT FROM PD_Items_Cur INTO @c_PDColumnName
	         
				END
				
	         
				CLOSE PD_Items_Cur
				DEALLOCATE PD_Items_Cur
			END
			-- Generate Blank Label If Nothing Found (End)
			
         
         -- Insert <label> - record level end
         INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
         VALUES ('</label>', @@SPID)
	
     
         
      -- Insert </labels>
      INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
      VALUES ('</labels>', @@SPID)
  

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN

	-- Clean Up Temp Tabel	
	DROP Table #TempGSICartonLabel_Rec
	DROP Table #Pack_Det    
--BEGIN
      -- Select list of records
      --SELECT SeqNo, LineText FROM #TempGSICartonLabel_XML
--END

END
/*********************************************/
/* Cursor Loop - XML Data Insertion (End)    */
/*********************************************/

SET QUOTED_IDENTIFIER OFF 

GO