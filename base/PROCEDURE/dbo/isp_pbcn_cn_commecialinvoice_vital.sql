SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_PBCN_CN_CommecialInvoice					         */
/* Creation Date: 29-Dec-2006                                           */
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                                 */
/*                                                                      */
/* Purpose: Pacific Brands - China Customs Commecial Invoice (SOS64828) */
/*                                                                      */
/* Called By: report dw = r_dw_cn_commercialinvoice_pbcn                */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 29-Sep-2008  KC        1.1   SOS117432 Remap field for VITAL         */
/* 25-Nov-2008	 KC		  1.2	  Incorporate SQL2005 Std WITH (NOLOCK)	*/
/* 28-Jan-2019  TLTING_ext 1.3  enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[isp_PBCN_CN_CommecialInvoice_Vital] (
  @cMBOLKey NVARCHAR( 10)
) 
AS 
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   -- Declare temp tables
   DECLARE @tTempSKU TABLE (
      RowID            INT       NOT NULL IDENTITY (1, 1),
      StorerKey        NVARCHAR( 15) NULL,
      SKU              NVARCHAR( 20) NULL,
      QtyShipped       INT       NULL
      )
   
   DECLARE @tTempCALC TABLE (
      StorerKey        NVARCHAR( 15)      NULL,
      SKU              NVARCHAR( 20)      NULL,      
      ComponentSKU     NVARCHAR( 20)      NULL,
      ComponentSKUDesc NVARCHAR( 60)      NULL,
      Qty              INT            NULL,
      Price            DECIMAL(10, 2) NULL,
      SubTotal_Qty     INT            NULL,
      SubTotal_Price   DECIMAL(10, 2) NULL
      )

   DECLARE @tTempRESULT TABLE (
      MBOLKey          NVARCHAR( 10) NULL,
      VoyageNumber     NVARCHAR( 60) NULL, --SOS117432
      DepartureDate    DATETIME  NULL,
      EditDate         DATETIME  NULL, --SOS117432
      OriginCountry    NVARCHAR( 30) NULL,
      PlaceOfLoading   NVARCHAR( 30) NULL,
      PlaceOfDischarge NVARCHAR( 30) NULL,
      PlaceOfDelivery  NVARCHAR( 30) NULL,
      OtherReference   NVARCHAR( 30) NULL,
      IDS_Company      NVARCHAR( 45) NULL,
      IDS_B_Company    NVARCHAR( 45) NULL,
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
      TotalQty         INT       NULL,
      TotalPrice       DECIMAL(10, 2) NULL,
      /* SOS117432  */
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
      @cVoyageNumber     NVARCHAR( 60), --SOS117432
      @dtDepartureDate   DATETIME,
      @dtEditDate        DATETIME,  --SOS117432
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
      @cExternOrderKey NVARCHAR( 50),   --tlting_ext
      @cPartialCPO     NVARCHAR( 1000),
      @cCPO            NVARCHAR( 1000),
      -- SOS117432
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
      @nQtyShipped     INT

   SET @b_Debug = 0

   /*****************/
   /* Get MBOL data */
   /*****************/
   SET ROWCOUNT 1
   SELECT 
      @cVoyageNumber     = dbo.fnc_RTRIM(dbo.fnc_LTRIM(MBOL.OtherReference)) + ' / ' + dbo.fnc_RTRIM(dbo.fnc_LTRIM(MBOL.VoyageNumber)),   --SOS117432
      @dtDepartureDate   = MBOL.DepartureDate,
      @dtEditDate        = MBOL.EditDate, --SOS117432
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
      --@cBillToKey        = ORDERS.BillToKey,
      @cBillToKey        = MBOL.ConsigneeAccountCode, --SOS117432
   	@cBillTo_Company   = BILLTO.Company,
   	@cBillTo_Address1  = BILLTO.Address1,
   	@cBillTo_Address2  = BILLTO.Address2,
   	@cBillTo_Address3  = BILLTO.Address3,
   	@cBillTo_Address4  = BILLTO.Address4,
      @cBillTo_City      = BILLTO.City,
      @cBillTo_Zip       = BILLTO.Zip
   FROM MBOL WITH (NOLOCK)
   INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
   INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
   INNER JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
   INNER JOIN STORER WITH (NOLOCK) ON (STORER.StorerKey = ORDERS.StorerKey)
   INNER JOIN STORER IDSCNSZ WITH (NOLOCK) ON (IDSCNSZ.StorerKey = 'IDSCNSZ')
   --INNER JOIN STORER BILLTO WITH (NOLOCK) ON (BILLTO.StorerKey = ORDERS.BillToKey)  --SOS117432
   INNER JOIN STORER BILLTO WITH (NOLOCK) ON (BILLTO.StorerKey = MBOL.ConsigneeAccountCode)    --SOS117432
   WHERE MBOL.MBOLKey = @cMBOLKey 
   GROUP BY
      MBOL.MBOLKey,   
      --MBOL.VoyageNumber,
      dbo.fnc_RTRIM(dbo.fnc_LTRIM(MBOL.OtherReference)) + ' / ' + dbo.fnc_RTRIM(dbo.fnc_LTRIM(MBOL.VoyageNumber)), -- SOS117432
      MBOL.DepartureDate,
      MBOL.EditDate,    --SOS117432
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
      --ORDERS.BillToKey,
      MBOL.ConsigneeAccountCode, --SOS117432
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
   /* SOS117432 Change to retrieve CPO# from ORDERS.BUYERPO                             */
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
	    /* SOS117432 No longer required to search by externorderkey with '_'
      -- Proceed if found '_'
      IF CharIndex('_', @cExternOrderKey, 0) > 0
      BEGIN
         SET @cPartialCPO = SUBSTRING(@cExternOrderKey, 1, CharIndex('_', @cExternOrderKey, 0) - 1)
   
         IF LEN(dbo.fnc_RTRIM(dbo.fnc_LTRIM(@cPartialCPO))) > 0
         BEGIN
            IF @cCPO = ''
               SET @cCPO = dbo.fnc_RTRIM(dbo.fnc_LTRIM(@cPartialCPO))
             /* Do not want to show repeating #CPO. If CharIndex = 0, it means @cPartialCPO is not repeated in @cCPO and can be added into it */
            ELSE IF CharIndex(@cPartialCPO, @cCPO, 0) = 0
               SET @cCPO = @cCPO + ', ' + dbo.fnc_RTRIM(dbo.fnc_LTRIM(@cPartialCPO))
         END
      END
      */
      SET @cPartialCPO = @cExternOrderKey
      IF LEN(dbo.fnc_RTRIM(dbo.fnc_LTRIM(@cPartialCPO))) > 0
      BEGIN
         IF @cCPO = '' 
            SET @cCPO = dbo.fnc_RTRIM(dbo.fnc_LTRIM(@cPartialCPO))

         -- Do not want to show repeating CPO#
         ELSE IF CharIndex(@cPartialCPO, @cCPO) = 0
            SET @cCPO = @cCPO + ', ' + dbo.fnc_RTRIM(dbo.fnc_LTRIM(@cPartialCPO))
      END
      FETCH NEXT FROM @curCPO INTO @cExternOrderKey
   END
   
   IF @b_Debug = 1
      SELECT @cCPO ' @cCPO'

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


   /****************************************************************/
   /* Get distinct SKU and QtyShipped (for all orders in one MBOL) */
   /****************************************************************/
   INSERT INTO @tTempSKU 
      (StorerKey, SKU, QtyShipped)
   SELECT
      ORDERS.StorerKey,
      SKU.SKU,
      SUM(ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty)
   FROM MBOL WITH (NOLOCK)
   INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
   INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
   INNER JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
   INNER JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = ORDERDETAIL.StorerKey AND
   									 SKU.SKU = ORDERDETAIL.SKU)
   WHERE MBOL.MBOLKey = @cMBOLKey
   GROUP BY ORDERS.StorerKey, SKU.SKU
   ORDER BY SKU.SKU
   
   IF @b_Debug = 1
      SELECT * FROM @tTempSKU

   /************************************************************************************/
   /* Calculate Qty & Price for individual sku & componentsku, based on qtyshipped     */
   /* Eg. StorerKey SKU   QtyShipped                                                   */
   /*     --------- ----  ----------                                                   */
   /*     PBCN      SKUA          10                                                   */
   /*     PBCN      SKUB          30                                                   */
   /*     PBCN      SKUC          50                                                   */
   /*                                                                                  */
   /*     SKU   ComponentSKU   Qty   Price   SubTotal_Qty               SubTotal_Price */
   /*     ---   ------------   ----- ------  ------------   -------------------------- */
   /*     SKUA  HSCode1        1     100.00  10 x 1 =  10   10 x 1 x 100.00 =  1000.00 */
   /*     SKUA  HSCode2        2      20.00  10 x 2 =  20   10 x 2 x 20.00  =   400.00 */
   /*     SKUB  HSCode1        1     150.00  30 x 1 =  30   30 x 1 x 150.00 =  3000.00 */
   /*     SKUB  HSCode2        1      45.00  30 x 1 =  30   30 x 1 x 45.00  =  1350.00 */
   /*     SKUC  HSCode8        6      75.00  50 x 6 = 300   50 x 6 x 75.00  = 22500.00 */
   /************************************************************************************/

   DECLARE @curSKU CURSOR
   SET @curSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT StorerKey, SKU, QtyShipped
      FROM @tTempSKU
      ORDER BY RowID
	
	OPEN @curSKU

	FETCH NEXT FROM @curSKU INTO @cStorerKey, @cSKU, @nQtyShipped

	WHILE @@FETCH_STATUS <> -1
	BEGIN
      INSERT INTO @tTempCALC
         (StorerKey, SKU, ComponentSKU, ComponentSKUDesc, Qty, Price, SubTotal_Qty, SubTotal_Price)
      SELECT 
         SKU.StorerKey,
         SKU.SKU, 
         BILLOFMATERIAL.ComponentSKU,
         BOMSKU.DESCR,
         BILLOFMATERIAL.Qty,
         CAST( CAST(BILLOFMATERIAL.Notes AS NVARCHAR( 20)) AS DECIMAL( 10, 2)),
         BILLOFMATERIAL.Qty * @nQtyShipped,
         BILLOFMATERIAL.Qty * @nQtyShipped * CAST( CAST(BILLOFMATERIAL.Notes AS NVARCHAR( 20)) AS DECIMAL( 10, 2))
      FROM BILLOFMATERIAL WITH (NOLOCK)
      INNER JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = BILLOFMATERIAL.StorerKey AND
                                  SKU.SKU = BILLOFMATERIAL.SKU)
      INNER JOIN SKU BOMSKU WITH (NOLOCK) ON (BOMSKU.StorerKey = BILLOFMATERIAL.StorerKey AND
                                        BOMSKU.SKU = BILLOFMATERIAL.ComponentSKU)
      WHERE BILLOFMATERIAL.StorerKey = @cStorerKey
      AND   BILLOFMATERIAL.SKU = @cSKU
      
		FETCH NEXT FROM @curSKU INTO @cStorerKey, @cSKU, @nQtyShipped
	END

   IF @b_Debug = 1
      SELECT * FROM @tTempCALC

   /*********************************/
   /* Insert data into @tTempRESULT */
   /*********************************/
   INSERT INTO @tTempRESULT 
      (StorerKey, ComponentSKU, ComponentSKUDesc,TotalQty, TotalPrice)
   SELECT
      StorerKey,
      ComponentSKU, ComponentSKUDesc,
      SUM( SubTotal_Qty),
      SUM( SubTotal_Price)
   FROM @tTempCALC
   GROUP BY StorerKey, ComponentSKU, ComponentSKUDesc
   ORDER BY StorerKey, ComponentSKU

   /**************************************/
   /* Update MBOL data into @tTempRESULT */
   /**************************************/
   UPDATE @tTempRESULT SET
      MBOLKey          = @cMBOLKey,
      VoyageNumber     = @cVoyageNumber,
      DepartureDate    = @dtDepartureDate,
      EditDate         = @dtEditDate,  --SOS117432
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
      /* SOS 117432 */
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
      EditDate,
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
      TotalQty,
      TotalPrice,
      /* SOS117442 */
      CPO1,
      CPO2,
      CPO3,
      CPO4,
      CPO5  
   FROM @tTempRESULT

END

GO