SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_PBCN_AUS_PackingList					            */
/* Creation Date: 17-Jan-2007                                           */
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                                 */
/*                                                                      */
/* Purpose: Pacific Brands - Australia Customs Packing List (SOS66012)  */
/*                                                                      */
/* Called By: report dw = r_dw_aus_packinglist_pbcn                     */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 16-Apr-2007  MaryVong      SOS73323 Split CPO into 5 columns with    */
/*                            NVARCHAR(200) each                            */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[isp_PBCN_AUS_PackingList] (
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
      RowID                INT       NOT NULL IDENTITY (1, 1),
      StorerKey            NVARCHAR( 15) NULL,
      SKU                  NVARCHAR( 20) NULL,
      QtyShipped           INT       NULL,
      GrossWgt             FLOAT     NULL,
      SubTotal_GrossWgt    FLOAT     NULL
      )
   
   DECLARE @tTempPS TABLE (
      PickSlipNo   NVARCHAR(10) NULL,
      NoOfCartons  INT      NULL
      )
      
   DECLARE @tTempRESULT TABLE (
      MBOLKey          NVARCHAR( 10) NULL,
      VoyageNumber     NVARCHAR( 30) NULL,
      PlaceOfLoading   NVARCHAR( 30) NULL,
      PlaceOfDischarge NVARCHAR( 30) NULL,
      VesselQualifier  NVARCHAR( 10) NULL,
      ExternMBOLKey    NVARCHAR( 30) NULL,
      Vessel           NVARCHAR( 30) NULL,      
      DepartureDate    DATETIME  NULL, 
      ArrivalDate      DATETIME  NULL,
      BookingReference NVARCHAR( 30) NULL,
      BuyerPO          NVARCHAR( 20) NULL,
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
      SKU              NVARCHAR( 20) NULL,
      SKUDesc          NVARCHAR( 60) NULL,
      UOM              NVARCHAR( 10) NULL,
      QtyShipped       INT       NULL,
      TotalCarton      INT       NULL,
      TotalGrossWgt    FLOAT     NULL,
      TotalCube        FLOAT     NULL,
      TotalQtyShipped  INT       NULL,
      -- SOS73323
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
      @cVoyageNumber     NVARCHAR( 30),
      @cPlaceOfLoading   NVARCHAR( 30),
      @cPlaceOfDischarge NVARCHAR( 30),
      @cVesselQualifier  NVARCHAR( 10),
      @cExternMBOLKey    NVARCHAR( 30),
      @cVessel           NVARCHAR( 30),
      @dtDepartureDate   DATETIME,
      @dtArrivalDate     DATETIME,
      @cBookingReference NVARCHAR( 30),
      @cBuyerPO          NVARCHAR( 20),
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
      @cExternOrderKey   NVARCHAR( 50),  --tlting_ext
      @cPartialCPO       NVARCHAR( 1000),
      @cCPO              NVARCHAR( 1000),
      -- SOS73323
      @cCPO1             NVARCHAR( 200),
      @cCPO2             NVARCHAR( 200),
      @cCPO3             NVARCHAR( 200),
      @cCPO4             NVARCHAR( 200),
      @cCPO5             NVARCHAR( 200),
      @cTempCPO          NVARCHAR( 200),
      @nLen              INT,
      @nNum              INT

   DECLARE 
      @cStorerKey        NVARCHAR( 15),
      @cSKU              NVARCHAR( 20),
      @nQtyShipped       INT,
      @nTotalQtyShipped  INT,
      @nTotalCarton      INT,
      @fTotalGrossWgt    FLOAT,
      @fTotalCube        FLOAT 

   SET @nTotalQtyShipped = 0
   SET @nTotalCarton     = 0
   SET @fTotalGrossWgt   = 0
   SET @fTotalCube       = 0

   SET @b_Debug = 0

   /*****************/
   /* Get MBOL data */
   /*****************/
   SET ROWCOUNT 1
   SELECT 
      @cVoyageNumber     = MBOL.VoyageNumber,
      @cPlaceOfLoading   = MBOL.PlaceOfLoading,
      @cPlaceOfDischarge = MBOL.PlaceOfDischarge,
      @cVesselQualifier  = MBOL.VesselQualifier,
      @cExternMBOLKey    = MBOL.ExternMBOLKey,
      @cVessel           = MBOL.Vessel,
      @dtDepartureDate   = MBOL.DepartureDate,
      @dtArrivalDate     = MBOL.ArrivalDate,
      @cBookingReference = MBOL.BookingReference,
      @cBuyerPO          = ORDERS.BuyerPO,
      @cIDS_Company      = IDSCNSZ.Company,
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
      MBOL.PlaceOfLoading,
      MBOL.PlaceOfDischarge,
      MBOL.VesselQualifier,
      MBOL.ExternMbolKey,
      MBOL.Vessel,
      MBOL.DepartureDate,
      MBOL.ArrivalDate,
      MBOL.BookingReference,
      ORDERS.BuyerPO,
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

   /*******************************************************************/
   /* Get GrossWgt based on distinct SKU (for all orders in one MBOL) */
   /*******************************************************************/
   INSERT INTO @tTempSKUWgt
      (StorerKey, SKU, QtyShipped, GrossWgt, SubTotal_GrossWgt)
   SELECT
      ORDERS.StorerKey,
      SKU.SKU,
      SUM(ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty),
      SKU.GrossWgt,
      SUM(ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty) * SKU.GrossWgt
   FROM MBOL (NOLOCK)
   INNER JOIN MBOLDETAIL (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
   INNER JOIN ORDERS (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
   INNER JOIN ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
   INNER JOIN SKU (NOLOCK) ON (SKU.StorerKey = ORDERDETAIL.StorerKey AND
   									 SKU.SKU = ORDERDETAIL.SKU)						 
   WHERE MBOL.MBOLKey = @cMBOLKey
   GROUP BY ORDERS.StorerKey, SKU.SKU, SKU.GrossWgt
   ORDER BY SKU.SKU
   
   IF @b_Debug = 1
      SELECT * FROM @tTempSKUWgt

   /*************************************************/
   /* Get all pickslipno for all orders in one MBOL */
   /* 1 order to 1 pickslipno (discrete pickslip)   */
   /*************************************************/ 
   INSERT INTO @tTempPS
   SELECT PACKHEADER.PickSlipNo, COUNT(DISTINCT PACKDETAIL.CartonNo)
   FROM MBOLDETAIL (NOLOCK)
   INNER JOIN ORDERS (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
   INNER JOIN PACKHEADER (NOLOCK) ON ( PACKHEADER.Orderkey = ORDERS.Orderkey AND
      										   PACKHEADER.Loadkey = ORDERS.Loadkey )
   INNER JOIN PACKDETAIL (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)      										   
   WHERE MBOLDETAIL.MBOLKey = @cMBOLKey
   GROUP BY PACKHEADER.PickSlipNo
   
   IF @b_Debug = 1
      SELECT * FROM @tTempPS

   -- Get TotalCarton
   SELECT @nTotalCarton = SUM(NoOfCartons)
   FROM @tTempPS

   -- Get TotalQtyShip and TotalGrossWgt
   SELECT
      @nTotalQtyShipped = SUM(QtyShipped),
      @fTotalGrossWgt = SUM(SubTotal_GrossWgt)
   FROM @tTempSKUWgt
         
   -- Get TotalCube
   SELECT @fTotalCube = SUM(PACKINFO.Cube)
   FROM PACKINFO (NOLOCK) 
   WHERE PACKINFO.PickSlipNo IN (SELECT PickSlipNo FROM @tTempPS)

   IF @b_Debug = 1
      SELECT @nTotalCarton '@nTotalCarton', @fTotalGrossWgt '@fTotalGrossWgt', @fTotalCube '@fTotalCube'

   /******************************************************/
   /* Insert data into @tTempRESULT - based on each SKU  */
   /******************************************************/
   DECLARE @curSKU CURSOR
   SET @curSKU = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT StorerKey, SKU, QtyShipped
      FROM @tTempSKUWgt
      ORDER BY RowID
	
	OPEN @curSKU
	FETCH NEXT FROM @curSKU INTO @cStorerKey, @cSKU, @nQtyShipped

	WHILE @@FETCH_STATUS <> -1
	BEGIN
      INSERT INTO @tTempRESULT
         (StorerKey, SKU, SKUDesc, UOM, QtyShipped,
         TotalCarton, TotalGrossWgt, TotalCube, TotalQtyShipped)
      SELECT 
         SKU.StorerKey,
         SKU.SKU,
         SKU.DESCR,
         PACK.PackUOM3,
         @nQtyShipped,
         @nTotalCarton,
         @fTotalGrossWgt,
         @fTotalCube,
         @nTotalQtyShipped
      FROM SKU (NOLOCK)
      INNER JOIN PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      WHERE SKU.StorerKey = @cStorerKey
      AND   SKU.SKU = @cSKU
      ORDER BY SKU.SKU
          
		FETCH NEXT FROM @curSKU INTO @cStorerKey, @cSKU, @nQtyShipped
	END

   IF @b_Debug = 1
      SELECT * FROM @tTempRESULT 

   /**************************************/
   /* Update MBOL data into @tTempRESULT */
   /**************************************/
   UPDATE @tTempRESULT SET
      MBOLKey          = @cMBOLKey,
      VoyageNumber     = @cVoyageNumber,
      PlaceOfLoading   = @cPlaceOfLoading,
      PlaceOfDischarge = @cPlaceOfDischarge,
      VesselQualifier  = @cVesselQualifier,      
      ExternMBOLKey    = @cExternMBOLKey,
      Vessel           = @cVessel,
      DepartureDate    = @dtDepartureDate,
      ArrivalDate      = @dtArrivalDate,
      BookingReference = @cBookingReference,
      BuyerPO          = @cBuyerPO,
      IDS_Company      = @cIDS_Company,  
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
      CPO1             = @cCPO1,
      CPO2             = @cCPO2,
      CPO3             = @cCPO3,
      CPO4             = @cCPO4,
      CPO5             = @cCPO5
   
   -- Retrieve result
   SELECT 
      MBOLKey,
      VoyageNumber,    
      PlaceOfLoading,
      PlaceOfDischarge,
      VesselQualifier,
      ExternMBOLKey,
      Vessel,
      DepartureDate,
      ArrivalDate,
      BookingReference,
      BuyerPO,
      IDS_Company,
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
      SKU,
      SKUDesc,
      UOM,
      QtyShipped,
      TotalCarton,
      TotalGrossWgt,
      TotalCube,
      TotalQtyShipped,
      CPO1,
      CPO2,
      CPO3,
      CPO4,
      CPO5   
   FROM @tTempRESULT

END



GO