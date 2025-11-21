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
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[isp_PBCN_CN_CommecialInvoice] (
  @cMBOLKey NVARCHAR( 10)
) 
AS 
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
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
      VoyageNumber     NVARCHAR( 30) NULL,
      DepartureDate    DATETIME  NULL,
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
      CPO              NVARCHAR( 1000) NULL
      )
   
   -- Declare variables
   DECLARE
      @b_Debug           INT

   DECLARE
      @cVoyageNumber     NVARCHAR( 30),
      @dtDepartureDate   DATETIME,
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
      @cCPO            NVARCHAR( 1000)

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
      @cVoyageNumber     = MBOL.VoyageNumber,
      @dtDepartureDate   = MBOL.DepartureDate,
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
      @cBillToKey        = ORDERS.BillToKey,
   	@cBillTo_Company   = BILLTO.Company,
   	@cBillTo_Address1  = BILLTO.Address1,
   	@cBillTo_Address2  = BILLTO.Address2,
   	@cBillTo_Address3  = BILLTO.Address3,
   	@cBillTo_Address4  = BILLTO.Address4,
      @cBillTo_City      = BILLTO.City,
      @cBillTo_Zip       = BILLTO.Zip
   FROM MBOL (NOLOCK)
   INNER JOIN MBOLDETAIL (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
   INNER JOIN ORDERS (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
   INNER JOIN ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
   INNER JOIN STORER (NOLOCK) ON (STORER.StorerKey = ORDERS.StorerKey)
   INNER JOIN STORER IDSCNSZ (NOLOCK) ON (IDSCNSZ.StorerKey = 'IDSCNSZ')
   INNER JOIN STORER BILLTO (NOLOCK) ON (BILLTO.StorerKey = ORDERS.BillToKey)
   WHERE MBOL.MBOLKey = @cMBOLKey 
   GROUP BY
      MBOL.MBOLKey,   
      MBOL.VoyageNumber,
      MBOL.DepartureDate,
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
      ORDERS.BillToKey,
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
   /*************************************************************************************/   
   SET @cCPO = ''
   SET @cPartialCPO = ''

   DECLARE @curCPO CURSOR
   SET @curCPO = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT 
         ORDERS.ExternOrderKey
      FROM MBOL (NOLOCK)
      INNER JOIN MBOLDETAIL (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
      INNER JOIN ORDERS (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
      WHERE MBOL.MBOLKey = @cMBOLKey
      GROUP BY ORDERS.ExternOrderKey
	
	OPEN @curCPO

	FETCH NEXT FROM @curCPO INTO @cExternOrderKey

	WHILE @@FETCH_STATUS <> -1
	BEGIN
	   -- Proceed if found '_'
	   IF CharIndex('_', @cExternOrderKey, 0) > 0
	   BEGIN
         SET @cPartialCPO = SUBSTRING(@cExternOrderKey, 1, CharIndex('_', @cExternOrderKey, 0) - 1)
   
         IF LEN(dbo.fnc_RTrim(dbo.fnc_LTrim(@cPartialCPO))) > 0
         BEGIN
            IF @cCPO = ''
               SET @cCPO = dbo.fnc_RTrim(dbo.fnc_LTrim(@cPartialCPO))

            -- Do not want to show repeating CPO#
            ELSE IF CharIndex(@cPartialCPO, @cCPO) = 0
               SET @cCPO = @cCPO + ', ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@cPartialCPO))
         END
      END
               
      FETCH NEXT FROM @curCPO INTO @cExternOrderKey
   END
   
   IF @b_Debug = 1
      SELECT @cCPO ' @cCPO'

   /****************************************************************/
   /* Get distinct SKU and QtyShipped (for all orders in one MBOL) */
   /****************************************************************/
   INSERT INTO @tTempSKU 
      (StorerKey, SKU, QtyShipped)
   SELECT
      ORDERS.StorerKey,
      SKU.SKU,
      SUM(ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty)
   FROM MBOL (NOLOCK)
   INNER JOIN MBOLDETAIL (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
   INNER JOIN ORDERS (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
   INNER JOIN ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
   INNER JOIN SKU (NOLOCK) ON (SKU.StorerKey = ORDERDETAIL.StorerKey AND
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
      FROM BILLOFMATERIAL (NOLOCK)
      INNER JOIN SKU (NOLOCK) ON (SKU.StorerKey = BILLOFMATERIAL.StorerKey AND
                                  SKU.SKU = BILLOFMATERIAL.SKU)
      INNER JOIN SKU BOMSKU (NOLOCK) ON (BOMSKU.StorerKey = BILLOFMATERIAL.StorerKey AND
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
      CPO              = @cCPO
   
   -- Retrieve result
   SELECT 
      MBOLKey,
      VoyageNumber,
      DepartureDate,
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
      CPO
   FROM @tTempRESULT

END


GO