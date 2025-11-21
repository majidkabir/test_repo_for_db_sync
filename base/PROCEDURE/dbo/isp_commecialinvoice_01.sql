SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_CommecialInvoice_01          			  	      */
/* Creation Date: 27-Apr-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Vital - Muji Customs Commecial Invoice                      */
/* (SOS#134610)                                                         */
/*                                                                      */
/* Called By: report dw = r_dw_commercialinvoice_01                     */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 09-JUN-2009  NJOW      1.1   Filter zero qty record (SOS#134610)     */
/* 22-OCT-2009  NJOW01    1.2   142634-add MBOL.Userdefine01.           */
/*                              Change IDSCNSZ to MGS link to storer    */
/* 10-Sep-2009  NJOW02    1.3   152660 - Include 1 mbol multi container */
/*                                       print from container screen    */
/* 09-Mar-2011  SPChin    1.4   SOS#208265 - Add NULL checking for      */
/*                                           ORDERS.PODUser             */
/************************************************************************/

CREATE PROC [dbo].[isp_CommecialInvoice_01] (
  @cMBOL_ContrKey NVARCHAR(21)  --NJOW02
) 
AS 
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF
   
   DECLARE @n_rowid int,
        @n_rowcnt int,
        @c_worldshoporder NVARCHAR(18),
        @c_sku NVARCHAR(20),
        @c_prev_worldshoporder NVARCHAR(18),
        @c_prev_sku NVARCHAR(20)
        
   --NJOW02 - Start      
   CREATE TABLE #TEMP_INV
         (MBOLKey NVARCHAR(20) NULL,
      		VesselVoyage NVARCHAR(63) NULL,
      		DepartureDate datetime NULL,
      	   ArrivalDate datetime NULL,
      		PlaceOfLoading NVARCHAR(30) NULL,
      	   PlaceOfDischarge NVARCHAR(30) NULL,
      		Equipment NVARCHAR(10) NULL,
      		Containerno NVARCHAR(30) NULL,
      		Sealno NVARCHAR(30) NULL, 
      		BookingReference NVARCHAR(30) NULL,
      		IDS_Company NVARCHAR(45) NULL,
      		IDS_Address1 NVARCHAR(45) NULL,
      		IDS_Address2 NVARCHAR(45) NULL,
      	   IDS_Address3 NVARCHAR(45) NULL,
      		IDS_Address4 NVARCHAR(45) NULL,
      		IDS_Phone1 NVARCHAR(18) NULL,
      		IDS_Fax1 NVARCHAR(18) NULL,
      		BILLTO_Company NVARCHAR(45) NULL,
      		BILLTO_Address1 NVARCHAR(45) NULL,
      		BILLTO_Address2 NVARCHAR(45) NULL,
      		BILLTO_Address3 NVARCHAR(45) NULL,
      		BILLTO_Address4 NVARCHAR(45) NULL,
      		BILLTO_City NVARCHAR(45) NULL,
      		BILLTO_Zip NVARCHAR(18) NULL,
      		BILLTO_Country NVARCHAR(30) NULL,
      		StorerKey NVARCHAR(15) NULL,
      		SKU NVARCHAR(20) NULL,
      		Descr NVARCHAR(90) NULL,
      		QtyShipped int NULL,
      		UnitPrice decimal(10,2) NULL,
      		WorldShopOrder NVARCHAR(18) NULL,
      		MaterialDesc NVARCHAR(125) NULL,
      		Currency NVARCHAR(18) NULL,
      		CountryOrg NVARCHAR(250) NULL,
      	   MBUserdefine01 NVARCHAR(20) NULL)
      			 
   DECLARE @c_refkey NVARCHAR(20),
           @n_pos INT,
           @c_rpttype NVARCHAR(10)
      
   SELECT @n_pos = CHARINDEX('$', @cMBOL_ContrKey, 0)
   
   IF @n_pos > 0 
   BEGIN   	  
      SELECT @c_refkey = LEFT(@cMBOL_ContrKey, @n_pos - 1)
      SELECT @c_rpttype = 'CONTAINER'
   END
   ELSE
   BEGIN
      SELECT @c_refkey = @cMBOL_ContrKey
      SELECT @c_rpttype = 'MBOL'   	  
   END
   -- NJOW02 End

   IF @c_rpttype = 'MBOL'
   BEGIN
   	  INSERT INTO #TEMP_INV
        SELECT MBOL.MBOLKey,
      			 ISNULL(RTRIM(MBOL.OtherReference),'') + ' / ' + ISNULL(RTRIM(MBOL.VoyageNumber),'') AS VesselVoyage,
      			 MBOL.DepartureDate,
      			 MBOL.ArrivalDate,
      			 MBOL.PlaceOfLoading,
      			 MBOL.PlaceOfDischarge,
      			 MBOL.Equipment,
      			 MBOL.Containerno,
      			 MBOL.Sealno,
      			 MBOL.BookingReference,
      			 IDSCNSZ.Company AS IDS_Company,
      			 IDSCNSZ.Address1 AS IDS_Address1,
      			 IDSCNSZ.Address2 AS IDS_Address2,
      			 IDSCNSZ.Address3 AS IDS_Address3,
      			 IDSCNSZ.Address4 AS IDS_Address4,
      			 IDSCNSZ.Phone1 AS IDS_Phone1,
      			 IDSCNSZ.Fax1 AS IDS_Fax1,
      			 BILLTO.Company AS BILLTO_Company,
      			 BILLTO.Address1 AS BILLTO_Address1,
      			 BILLTO.Address2 AS BILLTO_Address2,
      			 BILLTO.Address3 AS BILLTO_Address3,
      			 BILLTO.Address4 AS BILLTO_Address4,
      			 BILLTO.City AS BILLTO_City,
      			 BILLTO.Zip AS BILLTO_Zip,
      			 BILLTO.Country AS BILLTO_Country,
      			 ORDERDETAIL.StorerKey,
      			 ORDERDETAIL.SKU,
      			 RTRIM(SKU.Descr)+' '+RTRIM(ISNULL(SKU.Busr1,'')) AS Descr,
      			 SUM(ORDERDETAIL.qtypicked+ORDERDETAIL.shippedqty)AS QtyShipped,
      			 CONVERT(decimal(10,2),ORDERDETAIL.UnitPrice) AS UnitPrice,
      			 --ORDERS.PODUser AS WorldShopOrder, -- SOS#208265
      			 ISNULL(RTRIM(ORDERS.PODUser),'') AS WorldShopOrder, -- SOS#208265
      			 CONVERT(nvarchar(125),SKU.Notes1) AS MaterialDesc,
      			 ORDERDETAIL.Userdefine03 AS Currency,
      			 CODELKUP.Description AS CountryOrg,
      			 MBOL.Userdefine01 --NJOW01
      FROM MBOL WITH (NOLOCK)
      			INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
      			INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
      			INNER JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
      			INNER JOIN SKU WITH (NOLOCK) ON (ORDERDETAIL.StorerKey = SKU.StorerKey AND ORDERDETAIL.Sku = SKU.Sku)
      			INNER JOIN STORER IDSCNSZ WITH (NOLOCK) ON (IDSCNSZ.StorerKey = 'MGS')
      			INNER JOIN STORER BILLTO WITH (NOLOCK) ON (MBOL.CONSIGNEEACCOUNTCODE = BILLTO.Storerkey)
      			LEFT JOIN CODELKUP WITH (NOLOCK) ON (SKU.Busr6 = CODELKUP.Code AND CODELKUP.Listname = 'MJCOUNTRY')
      WHERE MBOL.MBOLKey = @c_refkey --NJOW02
      GROUP BY MBOL.MBOLKey,
      			MBOL.OtherReference,
               MBOL.VoyageNumber,
               MBOL.DepartureDate,
      			MBOL.ArrivalDate,
      			MBOL.PlaceOfLoading,
      			MBOL.PlaceOfDischarge,
      			MBOL.Equipment,
      			MBOL.Containerno,
      			MBOL.Sealno,
      			MBOL.BookingReference,
      			IDSCNSZ.Company, 
      			IDSCNSZ.Address1, 
      			IDSCNSZ.Address2,
      			IDSCNSZ.Address3,
      			IDSCNSZ.Address4,
      			IDSCNSZ.Phone1,
      			IDSCNSZ.Fax1,
      			BILLTO.Company,
      			BILLTO.Address1,
      			BILLTO.Address2,
      			BILLTO.Address3,
      			BILLTO.Address4,
      			BILLTO.City,
      			BILLTO.Zip,
      			BILLTO.Country,
      			ORDERDETAIL.StorerKey,
      			ORDERDETAIL.SKU,
      			SKU.Descr,
      			SKU.Busr1,
      			ORDERDETAIL.UnitPrice,
      			--ORDERS.PODUser, -- SOS#208265
      			ISNULL(RTRIM(ORDERS.PODUser),''), -- SOS#208265
      			CONVERT(nvarchar(125),SKU.Notes1),
      			ORDERDETAIL.Userdefine03,
      			CODELKUP.Description,
      			MBOL.Userdefine01 --NJOW01
      	HAVING SUM(ORDERDETAIL.qtypicked+ORDERDETAIL.shippedqty) > 0
   END
   ELSE
   BEGIN
   	  --NJOW02
   	  INSERT INTO #TEMP_INV
        SELECT CONTAINER.OtherReference,
      			 ISNULL(RTRIM(CONTAINER.Vessel),'') + ' / ' + ISNULL(RTRIM(CONTAINER.Voyage),'') AS VesselVoyage,
      			 MBOL.DepartureDate,
      			 MBOL.ArrivalDate,
      			 MBOL.PlaceOfLoading,
      			 MBOL.PlaceOfDischarge,
      			 CONTAINER.ContainerType AS Equipment,
      			 CONTAINER.BookingReference AS ContainerNo,
      			 CONTAINER.Seal01 AS SealNo,
      			 MBOL.BookingReference,
      			 IDSCNSZ.Company AS IDS_Company,
      			 IDSCNSZ.Address1 AS IDS_Address1,
      			 IDSCNSZ.Address2 AS IDS_Address2,
      			 IDSCNSZ.Address3 AS IDS_Address3,
      			 IDSCNSZ.Address4 AS IDS_Address4,
      			 IDSCNSZ.Phone1 AS IDS_Phone1,
      			 IDSCNSZ.Fax1 AS IDS_Fax1,
      			 BILLTO.Company AS BILLTO_Company,
      			 BILLTO.Address1 AS BILLTO_Address1,
      			 BILLTO.Address2 AS BILLTO_Address2,
      			 BILLTO.Address3 AS BILLTO_Address3,
      			 BILLTO.Address4 AS BILLTO_Address4,
      			 BILLTO.City AS BILLTO_City,
      			 BILLTO.Zip AS BILLTO_Zip,
      			 BILLTO.Country AS BILLTO_Country,
      			 ORDERDETAIL.StorerKey,
      			 ORDERDETAIL.SKU,
      			 RTRIM(SKU.Descr)+' '+RTRIM(ISNULL(SKU.Busr1,'')) AS Descr,
      			 SUM(PACKDETAIL.Qty)AS QtyShipped,
      			 CONVERT(decimal(10,2),ORDERDETAIL.UnitPrice) AS UnitPrice,
      			 --ORDERS.PODUser AS WorldShopOrder, -- SOS#208265
      			 ISNULL(RTRIM(ORDERS.PODUser),'') AS WorldShopOrder, -- SOS#208265
      			 CONVERT(nvarchar(125),SKU.Notes1) AS MaterialDesc,
      			 ORDERDETAIL.Userdefine03 AS Currency,
      			 CODELKUP.Description AS CountryOrg,
      			 MBOL.Userdefine01 --NJOW01
      FROM MBOL WITH (NOLOCK)
      			 INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
      			 INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
      			 INNER JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
      			 INNER JOIN SKU WITH (NOLOCK) ON (ORDERDETAIL.StorerKey = SKU.StorerKey AND ORDERDETAIL.Sku = SKU.Sku)
      			 INNER JOIN STORER IDSCNSZ WITH (NOLOCK) ON (IDSCNSZ.StorerKey = 'MGS')
      			 INNER JOIN STORER BILLTO WITH (NOLOCK) ON (MBOL.CONSIGNEEACCOUNTCODE = BILLTO.Storerkey)
      			 LEFT JOIN CODELKUP WITH (NOLOCK) ON (SKU.Busr6 = CODELKUP.Code AND CODELKUP.Listname = 'MJCOUNTRY')
                INNER JOIN PACKHEADER WITH (NOLOCK) ON (ORDERS.Orderkey = PACKHEADER.Orderkey 
                                               AND ORDERS.Loadkey = PACKHEADER.Loadkey)
                INNER JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno
                                                        AND ORDERDETAIL.Storerkey = PACKDETAIL.Storerkey
                                                        AND ORDERDETAIL.Sku = PACKDETAIL.Sku)
                INNER JOIN CONTAINER WITH (NOLOCK) ON (MBOL.Mbolkey = CONTAINER.OtherReference)
                INNER JOIN CONTAINERDETAIL WITH (NOLOCK) ON (CONTAINER.Containerkey = CONTAINERDETAIL.Containerkey
                                                            AND PACKDETAIL.LabelNo = CONTAINERDETAIL.Palletkey)
      WHERE CONTAINER.ContainerKey = @c_refKey 
      GROUP BY CONTAINER.OtherReference,
               CONTAINER.Vessel,
               CONTAINER.Voyage,
               MBOL.DepartureDate,
      			MBOL.ArrivalDate,
      			MBOL.PlaceOfLoading,
      			MBOL.PlaceOfDischarge,
     			   CONTAINER.ContainerType,
      			CONTAINER.BookingReference,
      			CONTAINER.Seal01,
      			MBOL.BookingReference,
      			IDSCNSZ.Company, 
      			IDSCNSZ.Address1, 
      			IDSCNSZ.Address2,
      			IDSCNSZ.Address3,
      			IDSCNSZ.Address4,
      			IDSCNSZ.Phone1,
      			IDSCNSZ.Fax1,
      			BILLTO.Company,
      			BILLTO.Address1,
      			BILLTO.Address2,
      			BILLTO.Address3,
      			BILLTO.Address4,
      			BILLTO.City,
      			BILLTO.Zip,
      			BILLTO.Country,
      			ORDERDETAIL.StorerKey,
      			ORDERDETAIL.SKU,
      			SKU.Descr,
      			SKU.Busr1,
      			ORDERDETAIL.UnitPrice,
      			--ORDERS.PODUser, -- SOS#208265
      			ISNULL(RTRIM(ORDERS.PODUser),''), -- SOS#208265
      			CONVERT(nvarchar(125),SKU.Notes1),
      			ORDERDETAIL.Userdefine03,
      			CODELKUP.Description,
      			MBOL.Userdefine01 --NJOW01
      	HAVING SUM(PACKDETAIL.Qty) > 0
   END
   
SELECT IDENTITY(int,1,1) AS rowid, #TEMP_INV.*, BILLOFMATERIAL.ComponentSku, ' ' as linetype
INTO #TEMP_RESULT
FROM #TEMP_INV
LEFT JOIN BILLOFMATERIAL (NOLOCK) ON (#TEMP_INV.Storerkey = BILLOFMATERIAL.Storerkey AND #TEMP_INV.Sku = BILLOFMATERIAL.Sku)
ORDER BY #TEMP_INV.WorldShopOrder, #TEMP_INV.Sku, BILLOFMATERIAL.ComponentSku

SELECT  @c_prev_worldshoporder = '',
        @c_prev_sku = '',
        @n_rowid = 0

WHILE 1=1
BEGIN
	SET ROWCOUNT 1
  SELECT @n_rowid = rowid, @c_worldshoporder = worldshoporder, @c_sku = sku
  FROM #TEMP_RESULT
  WHERE rowid > @n_rowid
  ORDER BY rowid
 
  SELECT @n_rowcnt = @@ROWCOUNT
  
	SET ROWCOUNT 0

  IF @n_rowcnt = 0
     BREAK 
  
  IF @c_worldshoporder = @c_prev_worldshoporder AND @c_sku = @c_prev_sku
  BEGIN
     UPDATE #TEMP_RESULT SET linetype = 'C' WHERE rowid = @n_rowid 	  
	END
  
  SELECT @c_prev_worldshoporder = @c_worldshoporder, @c_prev_sku = @c_sku  
END

SELECT * FROM #TEMP_RESULT ORDER BY rowid

END

GO