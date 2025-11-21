SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_PBCN_AUS_CommecialInvoice					         */
/* Creation Date: 30-Sept-2008                                          */
/* Copyright: IDS                                                       */
/* Written by: KC                                                       */
/*                                                                      */
/* Purpose: Pacific Brands - Australia Customs Commecial Invoice        */
/* (SOS117446)                                                          */
/*                                                                      */
/* Called By: report dw = r_dw_aus_commercialinvoice_pbcn               */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 25-Nov-2008	 KC		  1.1	  Incorporate SQL2005 std WITH (NOLOCK)	*/
/* 28-Jan-2019  TLTING_ext 1.2  enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[isp_PBCN_AUS_CommecialInvoice] (
  @cMBOLKey NVARCHAR( 10)
) 
AS 
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   -- Declare temp tables
   DECLARE @tTempSKU TABLE (
      RowID            INT       NOT NULL IDENTITY (1, 1),
      StorerKey        NVARCHAR( 15) NULL,
      SKU              NVARCHAR( 20) NULL,
      DESCR            NVARCHAR( 60) NULL,
      UnitPrice        DECIMAL(10,2) NULL,
      QtyShipped       INT       NULL
      )


   DECLARE @tTempRESULT TABLE (
      MBOLKey          NVARCHAR( 10) NULL,
      VoyageNumber     NVARCHAR( 60) NULL,
      DepartureDate    DATETIME  NULL,
      ArrivalDate      DATETIME  NULL,
      PlaceOfLoading   NVARCHAR( 30) NULL,
      PlaceOfDischarge NVARCHAR( 30) NULL,
      Equipment        NVARCHAR( 10) NULL,
      ContainerNo      NVARCHAR( 11) NULL,
      Sealno           NVARCHAR( 8)  NULL,
      Bookingreference NVARCHAR( 30) NULL,
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
      Descr            NVARCHAR( 60) NULL,
      qtyShipped       INT       NULL,
      UnitPrice        DECIMAL(10, 2) NULL,
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
      @cVoyageNumber     NVARCHAR( 60),
      @dtDepartureDate   DATETIME,
      @dtArrivalDate     DATETIME,
      @cPlaceOfLoading   NVARCHAR( 30),
      @cPlaceOfDischarge NVARCHAR( 30),
      @cEquipment        NVARCHAR( 10),
      @cContainerNo      NVARCHAR( 11),
      @cSealno           NVARCHAR( 8) ,
      @Bookingreference  NVARCHAR( 30),
      @cIDS_Company      NVARCHAR( 45),
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
      @cDescr          NVARCHAR( 60),
      @nQtyShipped     INT,
      @nUnitPrice      DECIMAL(10,2)

   SET @b_Debug = 0

   /*****************/
   /* Get MBOL data */
   /*****************/
   SET ROWCOUNT 1
   SELECT 
      @cVoyageNumber     = RTRIM(LTRIM(MBOL.OtherReference)) + ' / ' + RTRIM(LTRIM(MBOL.VoyageNumber)),  
      @dtDepartureDate   = MBOL.DepartureDate,
      @dtArrivalDate     = MBOL.ArrivalDate, 
      @cPlaceOfLoading   = MBOL.PlaceOfLoading,
      @cPlaceOfDischarge = MBOL.PlaceOfDischarge,
      @cEquipment        = MBOL.Equipment,
      @cContainerNo      = MBOL.Containerno,
      @cSealno           = MBOL.Sealno,
      @Bookingreference  = MBOL.BookingReference,
      @cIDS_Company      = IDSCNSZ.Company,
      @cIDS_Address1     = IDSCNSZ.Address1,
      @cIDS_Address2     = IDSCNSZ.Address2,
      @cIDS_Address3     = IDSCNSZ.Address3,
      @cIDS_Address4     = IDSCNSZ.Address4,
      @cIDS_Phone1       = IDSCNSZ.Phone1,
      @cIDS_Fax1         = IDSCNSZ.Fax1,
      -- SOS117432
      /*
      @cBillToKey        = MIN(ORDERS.MarkForKey),
   	@cBillTo_Company   = (SELECT Company FROM STORER (NOLOCK) WHERE Storerkey = min(ORDERS.MarkForKey)) ,
   	@cBillTo_Address1  = (SELECT Address1 FROM STORER (NOLOCK) WHERE Storerkey = min(ORDERS.MarkForKey)) ,
   	@cBillTo_Address2  = (SELECT Address2 FROM STORER (NOLOCK) WHERE Storerkey = min(ORDERS.MarkForKey)) ,
   	@cBillTo_Address3  = (SELECT Address3 FROM STORER (NOLOCK) WHERE Storerkey = min(ORDERS.MarkForKey)) ,
   	@cBillTo_Address4  = (SELECT Address4 FROM STORER (NOLOCK) WHERE Storerkey = min(ORDERS.MarkForKey)) ,
      @cBillTo_City      = (SELECT City FROM STORER (NOLOCK) WHERE Storerkey = min(ORDERS.MarkForKey)) ,
      @cBillTo_Zip       = (SELECT Zip FROM STORER (NOLOCK) WHERE Storerkey = min(ORDERS.MarkForKey)) 
      */
      @cBillToKey        = BILLTO.Storerkey,
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
   INNER JOIN STORER BILLTO WITH (NOLOCK) ON (BILLTO.Storerkey = MBOL.CONSIGNEEACCOUNTCODE )   -- SOS117432
   WHERE MBOL.MBOLKey = @cMBOLKey 
   GROUP BY
      MBOL.MBOLKey,   
      RTRIM(LTRIM(MBOL.OtherReference)) + ' / ' + RTRIM(LTRIM(MBOL.VoyageNumber)), -- SOS117432
      MBOL.DepartureDate,
      MBOL.ArrivalDate,
      MBOL.PlaceOfLoading,
      MBOL.PlaceOfDischarge,
      MBOl.Equipment,
      MBOL.Containerno,
      MBOL.SealNo,
      MBOL.Bookingreference,
      IDSCNSZ.Company,
      IDSCNSZ.B_Company,
      IDSCNSZ.Address1,
      IDSCNSZ.Address2,
      IDSCNSZ.Address3,
      IDSCNSZ.Address4,
      IDSCNSZ.Phone1,
      IDSCNSZ.Fax1,
      BILLTO.Storerkey,
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
   /*************************************************************************************/   
   SET @cCPO = ''
   SET @cPartialCPO = ''

   DECLARE @curCPO CURSOR
   SET @curCPO = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT 
           ORDERS.BUYERPO 
      FROM MBOL WITH (NOLOCK)
      INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
      INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
      WHERE MBOL.MBOLKey = @cMBOLKey
      GROUP BY ORDERS.BUYERPO
	
	OPEN @curCPO

	FETCH NEXT FROM @curCPO INTO @cExternOrderKey

	WHILE @@FETCH_STATUS <> -1
	BEGIN
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
      (StorerKey, SKU, DESCR, UnitPrice, QtyShipped)
   SELECT
      ORDERS.StorerKey,
      SKU.SKU,
      SKU.DESCR,
      ORDERDETAIL.UnitPrice,
      SUM(ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty)
   FROM MBOL WITH (NOLOCK)
   INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
   INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
   INNER JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
   INNER JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = ORDERDETAIL.StorerKey AND
   									 SKU.SKU = ORDERDETAIL.SKU)
   WHERE MBOL.MBOLKey = @cMBOLKey
   GROUP BY ORDERS.StorerKey, SKU.SKU, SKU.DESCR, ORDERDETAIL.UNITPRICE
   ORDER BY SKU.SKU
   
   IF @b_Debug = 1
      SELECT * FROM @tTempSKU


   /*********************************/
   /* Insert data into @tTempRESULT */
   /*********************************/
   INSERT INTO @tTempRESULT 
      (StorerKey, SKU, Descr, Qtyshipped, UnitPrice)
   SELECT
      StorerKey,
      SKU, 
      DESCR,
      SUM(Qtyshipped),
      UnitPrice
   FROM @tTempSKU
   GROUP BY StorerKey, SKU, DESCR, UnitPrice
   ORDER BY StorerKey, SKU

   /**************************************/
   /* Update MBOL data into @tTempRESULT */
   /**************************************/
   UPDATE @tTempRESULT SET
      MBOLKey          = @cMBOLKey,
      VoyageNumber     = @cVoyageNumber,
      DepartureDate    = @dtDepartureDate,
      ArrivalDate      = @dtArrivalDate,
      PlaceOfLoading   = @cPlaceOfLoading,
      PlaceOfDischarge = @cPlaceOfDischarge,
      Equipment        = @cEquipment,
      Containerno      = @cContainerNo,
      Sealno           = @cSealno,
      BookingReference = @Bookingreference,
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
      CPO3             = @cCPO2,
      CPO4             = @cCPO4,
      CPO5             = @cCPO5
   
   -- Retrieve result

   SELECT  
      MBOLKey,
      VoyageNumber,
      DepartureDate,
      ArrivalDate,
      PlaceOfLoading,
      PlaceOfDischarge,
      Equipment,
      ContainerNo,
      SealNo,
      Bookingreference,
      IDS_Company,
      IDS_Address1,
      IDS_Address2,
      IDS_Address3,
      IDS_Address4,
      IDS_Phone1,
      IDS_Fax1,
      BILLTO_Company,
      BILLTO_Address1,
      BILLTO_Address2,
      BILLTO_Address3,
      BILLTO_Address4,
      BILLTO_City,
      BILLTO_Zip,
      StorerKey,
      SKU,
      Descr,
      QtyShipped,
      UnitPrice,
      CPO1,
      CPO2,
      CPO3,
      CPO4,
      CPO5 
   FROM @tTempRESULT

END


GO