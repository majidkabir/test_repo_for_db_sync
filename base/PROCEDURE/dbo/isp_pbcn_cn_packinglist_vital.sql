SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_PBCN_CN_PackingList					               */
/* Creation Date: 16-Jan-2007                                           */
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                                 */
/*                                                                      */
/* Purpose: Pacific Brands - China Customs Packing List (SOS64949)      */
/*                                                                      */
/* Called By: report dw = r_dw_cn_pakinglist_pbcn                       */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 29-Sep-2008  KC        1.1   SOS117442 Remap field for VITAL         */
/* 25-Nov-2008	 KC		  1.2	  Incorporate SQL2005 Std - WITH (NOLOCK)	*/
/* 26-Nov-2008	 KC		  1.3	  Vital Go-Live issue - fix syntax error	*/
/* 28-Jan-2019  TLTING_ext 1.4  enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[isp_PBCN_CN_PackingList_Vital] (
  @cMBOLKey NVARCHAR( 10)
) 
AS 
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Declare temp tables
   DECLARE @tTempSKUWgt TABLE (
      RowID            INT       NOT NULL IDENTITY (1, 1),
      StorerKey        NVARCHAR( 15) NULL,
      SKU              NVARCHAR( 20) NULL,
      QtyShipped       INT       NULL,
      NetWgt           FLOAT     NULL,
      GrossWgt         FLOAT     NULL,
      SubTotal_NetWgt  FLOAT     NULL,
      SubTotal_GrossWgt FLOAT    NULL
      )
   
   DECLARE @tTempPS TABLE (
      PickSlipNo   NVARCHAR(10) NULL,
      NoOfCartons  INT      NULL
      )

   DECLARE @tTempComponentSKU TABLE (
      StorerKey        NVARCHAR( 15) NULL,
      ComponentSKU     NVARCHAR( 20) NULL,
      ComponentSKUDesc NVARCHAR( 60) NULL
      )
      
   DECLARE @tTempRESULT TABLE (
      MBOLKey          NVARCHAR( 10) NULL,
      VoyageNumber     NVARCHAR( 60) NULL,	--SOS117442
      DepartureDate    DATETIME  NULL,
      EditDate         DATETIME  NULL,	--SOS117442
      OriginCountry    NVARCHAR( 30) NULL,
      PlaceOfLoading   NVARCHAR( 30) NULL,
      PlaceOfDischarge NVARCHAR( 30) NULL,
      PlaceOfDelivery  NVARCHAR( 30) NULL,
      OtherReference   NVARCHAR( 30) NULL,
      IDS_B_Company    NVARCHAR( 45) NULL,
      IDS_Company      NVARCHAR( 45) NULL,
      IDS_Address1     NVARCHAR( 45) NULL,
      IDS_Address2     NVARCHAR( 45) NULL,
      IDS_Address3     NVARCHAR( 45) NULL,
      IDS_Address4     NVARCHAR( 45) NULL,
      IDS_Phone1       NVARCHAR( 18) NULL,
      IDS_Fax1         NVARCHAR( 18) NULL,
      BillToKey        NVARCHAR( 15) NULL,
      BILLTO_Company   NVARCHAR( 45) NULL,
      BILLTO_Address1  NVARCHAR( 45) NULL, 
      BILLTO_Address2  NVARCHAR( 45) NULL,
      BILLTO_Address3  NVARCHAR( 45) NULL,
      BILLTO_Address4  NVARCHAR( 45) NULL, 
      BILLTO_City      NVARCHAR( 45) NULL,
      BILLTO_Zip       NVARCHAR( 18) NULL,
      StorerKey        NVARCHAR( 15) NULL,
      ComponentSKU     NVARCHAR( 20) NULL,
      ComponentSKUDesc NVARCHAR( 60) NULL,
      TotalCarton      INT       NULL,
      TotalNetWgt      FLOAT     NULL,
      TotalGrossWgt    FLOAT     NULL,
      TotalCube        FLOAT     NULL,
      /* SOS117442  */
      CPO1             NVARCHAR( 200) NULL,
      CPO2             NVARCHAR( 200) NULL,
      CPO3             NVARCHAR( 200) NULL,
      CPO4             NVARCHAR( 200) NULL,
      CPO5             NVARCHAR( 200) NULL
      )
   
   -- Declare variables
   DECLARE
      @b_Debug           INT

   DECLARE
      @cVoyageNumber     NVARCHAR( 60),	--SOS117442
      @dtDepartureDate   DATETIME,
      @dtEditDate        DATETIME,	--SOS117442
      @cOriginCountry    NVARCHAR( 30),
      @cPlaceOfLoading   NVARCHAR( 30),
      @cPlaceOfDischarge NVARCHAR( 30),
      @cPlaceOfDelivery  NVARCHAR( 30),
      @cOtherReference   NVARCHAR( 30),
      @cIDS_Company      NVARCHAR( 45),
      @cIDS_B_Company    NVARCHAR( 45),
      @cIDS_Address1     NVARCHAR( 45),
      @cIDS_Address2     NVARCHAR( 45),
      @cIDS_Address3     NVARCHAR( 45),
      @cIDS_Address4     NVARCHAR( 45),
      @cIDS_Phone1       NVARCHAR( 18),
      @cIDS_Fax1         NVARCHAR( 18),
      @cBillToKey        NVARCHAR( 15),
      @cBILLTO_Company   NVARCHAR( 45),
      @cBILLTO_Address1  NVARCHAR( 45),
      @cBILLTO_Address2  NVARCHAR( 45),
      @cBILLTO_Address3  NVARCHAR( 45),
      @cBILLTO_Address4  NVARCHAR( 45),
      @cBILLTO_City      NVARCHAR( 45),
      @cBILLTO_Zip       NVARCHAR( 18)

   DECLARE 
      @cExternOrderKey NVARCHAR( 50),  --tlting_ext
      @cPartialCPO     NVARCHAR( 1000),
      @cCPO            NVARCHAR( 1000),
      -- SOS117442
      @cCPO1             NVARCHAR( 200),
      @cCPO2             NVARCHAR( 200),
      @cCPO3             NVARCHAR( 200),
      @cCPO4             NVARCHAR( 200),
      @cCPO5             NVARCHAR( 200),
      @cTempCPO          NVARCHAR( 200),
      @nLen              INT,
      @nNum              INT

   DECLARE 
      @cStorerKey      NVARCHAR( 15),
      @cSKU            NVARCHAR( 20),
      @nTotalCarton    INT,
      @fTotalNetWgt    FLOAT,
      @fTotalGrossWgt  FLOAT,
      @fTotalCube      FLOAT 

   SET @nTotalCarton = 0
   SET @fTotalNetWgt = 0
   SET @fTotalGrossWgt = 0
   SET @fTotalCube = 0

   SET @b_Debug = 0

   /*****************/
   /* Get MBOL data */
   /*****************/
   SET ROWCOUNT 1
   SELECT 
      @cVoyageNumber     = dbo.fnc_RTRIM(dbo.fnc_LTRIM(MBOL.OtherReference)) + ' / ' + dbo.fnc_RTRIM(dbo.fnc_LTRIM(MBOL.VoyageNumber)), --SOS117442
      @dtDepartureDate   = MBOL.DepartureDate,
      @dtEditDate        = MBOL.EditDate, --SOS117442
      @cOriginCountry    = MBOL.OriginCountry,
      @cPlaceOfLoading   = MBOL.PlaceOfLoading,
      @cPlaceOfDischarge = MBOL.PlaceOfDischarge,
      @cPlaceOfDelivery  = MBOL.PlaceOfDelivery,
      @cOtherReference   = MBOL.OtherReference,
      @cIDS_Company      = IDSCNSZ.Company,
      @cIDS_B_Company    = IDSCNSZ.B_Company,
      @cIDS_Address1     = IDSCNSZ.Address1,
      @cIDS_Address2     = IDSCNSZ.Address2,
      @cIDS_Address3     = IDSCNSZ.Address3,
      @cIDS_Address4     = IDSCNSZ.Address4,
      @cIDS_Phone1       = IDSCNSZ.Phone1,
      @cIDS_Fax1         = IDSCNSZ.Fax1,
      --@cBillToKey        = ORDERS.BillToKey,  --SOS117442
      @cBillToKey        = MBOL.CONSIGNEEACCOUNTCODE, 
   	@cBillTo_Company   = BILLTO.Company,
   	@cBillTo_Address1  = BILLTO.Address1,
   	@cBillTo_Address2  = BILLTO.Address2,
   	@cBillTo_Address3  = BILLTO.Address3,
   	@cBillTo_Address4  = BILLTO.Address4,
      @cBillTo_City      = BILLTO.City,
      @cBillTO_Zip       = BILLTO.Zip
   FROM MBOL WITH (NOLOCK)
   INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
   INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
   INNER JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
   INNER JOIN STORER WITH (NOLOCK) ON (STORER.StorerKey = ORDERS.StorerKey)
   INNER JOIN STORER IDSCNSZ WITH (NOLOCK) ON (IDSCNSZ.StorerKey = 'IDSCNSZ')
   --INNER JOIN STORER BILLTO WITH (NOLOCK) ON (BILLTO.StorerKey = ORDERS.BillToKey) --SOS117422
   INNER JOIN STORER BILLTO WITH (NOLOCK) ON (BILLTO.StorerKey = MBOL.ConsigneeAccountCode)
   WHERE MBOL.MBOLKey = @cMBOLKey 
   GROUP BY
      MBOL.MBOLKey,   
      --MBOL.VoyageNumber,
      dbo.fnc_RTRIM(dbo.fnc_LTRIM(MBOL.OtherReference)) + ' / ' + dbo.fnc_RTRIM(dbo.fnc_LTRIM(MBOL.VoyageNumber)), -- SOS117442
      MBOL.DepartureDate,
      MBOL.EditDate,    --SOS117442
      MBOL.OriginCountry,
      MBOL.PlaceOfLoading,
      MBOL.PlaceOfDischarge,
      MBOL.PlaceOfdelivery,
      MBOL.OtherReference,
      IDSCNSZ.Company,
      IDSCNSZ.B_Company,
      IDSCNSZ.Address1,
      IDSCNSZ.Address2,
      IDSCNSZ.Address3,
      IDSCNSZ.Address4,
      IDSCNSZ.Phone1,
      IDSCNSZ.Fax1,
      --ORDERS.BillToKey,  --SOS117442
      MBOL.ConsigneeAccountCode,
      BILLTO.Company, 
      BILLTO.Address1,
      BILLTO.Address2,
      BILLTO.Address3,
      BILLTO.Address4,
      BILLTO.City,
      BILLTO.Zip 

   SET ROWCOUNT 0
   
   /*************************************************************************************/
   /* Get CPO#                                                                          */
   /* Eg. ExternOrderKey = A1111_STOR1111, CPO# = A1111                                 */
   /*     Find underscore '_' then get string from first char to char before underscore */
   /* SOS117442 Change to retrieve CPO# from ORDERS.BUYERPO                             */
   /*************************************************************************************/   
   SET @cCPO = ''
   SET @cPartialCPO = ''

   DECLARE @curCPO CURSOR
   SET @curCPO = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT 
         --ORDERS.ExternOrderKey -- SOS117442
           ORDERS.BUYERPO  --SOS117442
      FROM MBOL WITH (NOLOCK)
      INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
      INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
      WHERE MBOL.MBOLKey = @cMBOLKey
      GROUP BY ORDERS.BUYERPO	--SOS117442
	
	OPEN @curCPO
	FETCH NEXT FROM @curCPO INTO @cExternOrderKey

	WHILE @@FETCH_STATUS <> -1
	BEGIN
		 /* SOS117442 No longer required to search by externorderkey with '_'
      -- Proceed if found '_'
      IF CharIndex('_', @cExternOrderKey, 0) > 0
      BEGIN
         SET @cPartialCPO = SUBSTRING(@cExternOrderKey, 1, CharIndex('_', @cExternOrderKey, 0) - 1)
   
         IF LEN(dbo.fnc_RTrim(dbo.fnc_LTrim(@cPartialCPO))) > 0
         BEGIN
            IF @cCPO = ''
               SET @cCPO = dbo.fnc_RTrim(dbo.fnc_LTrim(@cPartialCPO))
             /* Do not want to show repeating #CPO. If CharIndex = 0, it means @cPartialCPO is not repeated in @cCPO and can be added into it */
            ELSE IF CharIndex(@cPartialCPO, @cCPO, 0) = 0
               SET @cCPO = @cCPO + ', ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cPartialCPO))
         END
      END
		*/
      SET @cPartialCPO = @cExternOrderKey
      IF LEN(dbo.fnc_RTrim(dbo.fnc_LTrim(@cPartialCPO))) > 0
      BEGIN
         IF @cCPO = '' 
            SET @cCPO = dbo.fnc_RTrim(dbo.fnc_LTrim(@cPartialCPO))

         -- Do not want to show repeating CPO#
         ELSE IF CharIndex(@cPartialCPO, @cCPO) = 0
            SET @cCPO = @cCPO + ', ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cPartialCPO))
      END
      FETCH NEXT FROM @curCPO INTO @cExternOrderKey
   END
   
   IF @b_Debug = 1
      SELECT @cCPO ' @cCPO'

   -- SOS73323   
   -- Since return value (string) in datawindow cannot greater than 255 chars,
   -- split NVARCHAR(1000) to 5 columns with NVARCHAR(200) each
   SET @nLen = LEN(@cCPO)
   SET @nNum = 0
   SET @cTempCPO = ''

   IF @nLen > 200
   BEGIN
      WHILE @nLen > 200
      BEGIN
         SET @nNum = @nNum + 1
         SET @cTempCPO = SUBSTRING (@cCPO, 1, 200)
         SET @cCPO = SUBSTRING( @cCPO, 201, @nLen - 200)

         ASSIGN_DATA:
            IF @nNum = 1      SET @cCPO1 = @cTempCPO
            ELSE IF @nNum = 2 SET @cCPO2 = @cTempCPO
            ELSE IF @nNum = 3 SET @cCPO3 = @cTempCPO
            ELSE IF @nNum = 4 SET @cCPO4 = @cTempCPO
            ELSE IF @nNum = 5 SET @cCPO5 = @cTempCPO

         SET @nLen = LEN(@cCPO)
         IF @nLen > 0 AND @nLen <= 200
         BEGIN
            SET @nNum = @nNum + 1
            SET @cTempCPO = @cCPO
            SET @nLen = 0
            SET @cCPO = ''
            GOTO ASSIGN_DATA
         END

         IF @nLen = 0   BREAK
      END
   END
   ELSE
   BEGIN
      SET @cCPO1 = @cCPO
   END   
   
   IF @b_Debug = 1
   BEGIN
      SELECT @cCPO1 ' @cCPO1'
      SELECT @cCPO2 ' @cCPO2'
      SELECT @cCPO3 ' @cCPO3'
      SELECT @cCPO4 ' @cCPO4'
      SELECT @cCPO5 ' @cCPO5'
   END
   /******************************************************************************/
   /* Get NetWgt and GrossWgt based on distinct SKU (for all orders in one MBOL) */
   /******************************************************************************/
   INSERT INTO @tTempSKUWgt
      (StorerKey, SKU, QtyShipped, NetWgt, GrossWgt, SubTotal_NetWgt, SubTotal_GrossWgt)
   SELECT
      ORDERS.StorerKey,
      SKU.SKU,
      SUM(ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty),
      SKU.StdGrossWgt,
      SKU.GrossWgt,
      SUM(ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty) * SKU.StdGrossWgt,
      SUM(ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty) * SKU.GrossWgt
   FROM MBOL WITH (NOLOCK)
   INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
   INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
   INNER JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
   INNER JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = ORDERDETAIL.StorerKey AND
   									 SKU.SKU = ORDERDETAIL.SKU)
   WHERE MBOL.MBOLKey = @cMBOLKey
   GROUP BY ORDERS.StorerKey, SKU.SKU, SKU.StdGrossWgt, SKU.GrossWgt
   ORDER BY SKU.SKU
   
   IF @b_Debug = 1
      SELECT * FROM @tTempSKUWgt

   /*************************************************/
   /* Get all pickslipno for all orders in one MBOL */
   /* 1 order to 1 pickslipno (discrete pickslip)   */
   /*************************************************/ 
   INSERT INTO @tTempPS
   SELECT PACKHEADER.PickSlipNo, COUNT(DISTINCT PACKDETAIL.CartonNo)
   FROM MBOLDETAIL WITH (NOLOCK)
   INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
   INNER JOIN PACKHEADER WITH (NOLOCK) ON ( PACKHEADER.Orderkey = ORDERS.Orderkey AND
      										   PACKHEADER.Loadkey = ORDERS.Loadkey )
   INNER JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)      										   
   WHERE MBOLDETAIL.MBOLKey = @cMBOLKey
   GROUP BY PACKHEADER.PickSlipNo
   
   IF @b_Debug = 1
      SELECT * FROM @tTempPS

   -- Get TotalCarton
   SELECT @nTotalCarton = SUM(NoOfCartons)
   FROM @tTempPS

   -- Get TotalNetWgt and TotalGrossWgt
   SELECT 
      @fTotalNetWgt   = SUM(SubTotal_NetWgt),
      @fTotalGrossWgt = SUM(SubTotal_GrossWgt)
   FROM @tTempSKUWgt
         
   -- Get TotalCube
   SELECT @fTotalCube = SUM(PACKINFO.Cube)
   FROM PACKINFO WITH (NOLOCK) 
   WHERE PACKINFO.PickSlipNo IN (SELECT PickSlipNo FROM @tTempPS)

   IF @b_Debug = 1
      SELECT @nTotalCarton '@nTotalCarton', @fTotalNetWgt '@fTotalNetWgt',
         @fTotalGrossWgt '@fTotalGrossWgt', @fTotalCube '@fTotalCube'

   /************************************************************/
   /* Insert data into @tTempComponentSKU - based on each SKU  */
   /************************************************************/
   DECLARE @curSKU CURSOR
   SET @curSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT StorerKey, SKU
      FROM @tTempSKUWgt
      ORDER BY RowID
	
	OPEN @curSKU
	FETCH NEXT FROM @curSKU INTO @cStorerKey, @cSKU

	WHILE @@FETCH_STATUS <> -1
	BEGIN
      INSERT INTO @tTempComponentSKU
         (StorerKey, ComponentSKU, ComponentSKUDesc)
      SELECT 
         SKU.StorerKey,
         BILLOFMATERIAL.ComponentSKU,
         BOMSKU.DESCR
      FROM BILLOFMATERIAL WITH (NOLOCK)
      INNER JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = BILLOFMATERIAL.StorerKey AND
                                  SKU.SKU = BILLOFMATERIAL.SKU)
      INNER JOIN SKU BOMSKU WITH (NOLOCK) ON (BOMSKU.StorerKey = BILLOFMATERIAL.StorerKey AND
                                        BOMSKU.SKU = BILLOFMATERIAL.ComponentSKU)                                  
      WHERE BILLOFMATERIAL.StorerKey = @cStorerKey
      AND   BILLOFMATERIAL.SKU = @cSKU
            
		FETCH NEXT FROM @curSKU INTO @cStorerKey, @cSKU
	END

   IF @b_Debug = 1
      SELECT * FROM @tTempComponentSKU  
           
   /*********************************/
   /* Insert data into @tTempRESULT */
   /*********************************/
   INSERT INTO @tTempRESULT 
      (StorerKey, ComponentSKU, ComponentSKUDesc,
      TotalCarton, TotalNetWgt, TotalGrossWgt, TotalCube)
   SELECT
      StorerKey,
      ComponentSKU, ComponentSKUDesc,
      @nTotalCarton, @fTotalNetWgt, @fTotalGrossWgt, @fTotalCube
   FROM @tTempComponentSKU
   GROUP BY StorerKey, ComponentSKU, ComponentSKUDesc
   ORDER BY StorerKey, ComponentSKU

   IF @b_Debug = 1
      SELECT * FROM @tTempRESULT

   /**************************************/
   /* Update MBOL data into @tTempRESULT */
   /**************************************/
   UPDATE @tTempRESULT SET
      MBOLKey          = @cMBOLKey,
      VoyageNumber     = @cVoyageNumber,
      DepartureDate    = @dtDepartureDate,
      EditDate         = @dtEditDate,  --SOS117442
      OriginCountry    = @cOriginCountry,
      PlaceOfLoading   = @cPlaceOfLoading,
      PlaceOfDischarge = @cPlaceOfDischarge,
      PlaceOfDelivery  = @cPlaceOfDelivery,
      OtherReference   = @cOtherReference,
      IDS_Company      = @cIDS_Company,  
      IDS_B_Company    = @cIDS_B_Company,
      IDS_Address1     = @cIDS_Address1, 
      IDS_Address2     = @cIDS_Address2, 
      IDS_Address3     = @cIDS_Address3,
      IDS_Address4     = @cIDS_Address4,
      IDS_Phone1       = @cIDS_Phone1,   
      IDS_Fax1         = @cIDS_Fax1,
      BillToKey        = @cBillToKey,
      BILLTO_Company   = @cBILLTO_Company,
      BILLTO_Address1  = @cBILLTO_Address1,
      BILLTO_Address2  = @cBILLTO_Address2, 
      BILLTO_Address3  = @cBILLTO_Address3,
      BILLTO_Address4  = @cBILLTO_Address4,
      BILLTO_City      = @cBILLTO_City,
      BILLTO_Zip       = @cBILLTO_Zip,
      /* SOS 117442 */
      CPO1             = @cCPO1,
      CPO2             = @cCPO2,
      CPO3             = @cCPO2,
      CPO4             = @cCPO4,
      CPO5             = @cCPO5
   
   -- Retrieve result
   SELECT 
      MBOLKey,
      VoyageNumber,
      DepartureDate,
      EditDate,   --SOS117442
      OriginCountry,
      PlaceOfLoading,
      PlaceOfDischarge,
      PlaceOfDelivery,
      OtherReference,
      IDS_Company,
      IDS_B_Company,
      IDS_Address1,
      IDS_Address2,
      IDS_Address3,
      IDS_Address4,
      IDS_Phone1,
      IDS_Fax1,
      BillToKey,
      BILLTO_Company,
      BILLTO_Address1,
      BILLTO_Address2,
      BILLTO_Address3,
      BILLTO_Address4,
      BILLTO_City,
      BILLTO_Zip,
      StorerKey,
      ComponentSKU,
      ComponentSKUDesc,
      TotalCarton,
      TotalNetWgt,
      TotalGrossWgt,
      TotalCube,
      /* SOS117442 */
      CPO1,
      CPO2,
      CPO3,
      CPO4,
      CPO5  
   FROM @tTempRESULT

END

GO