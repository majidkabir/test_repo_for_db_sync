SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_PBCN_CN_CommecialInvoice02  			        */
/* Creation Date: 28-Apr-2017                                           */
/* Copyright:                                                           */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-1709 - CN LOGITECH Commercial invoice Report            */
/*                                                                      */
/* Called By: report dw = r_dw_cn_commercialinvoice_02                  */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 05-05-2017   CSCHONG   1.0    Change mapping (CS01)                  */
/* 09-05-2017   CSCHONG   1.1    Add new field (CS02)                   */
/* 06-09-2017   CSCHONG   1.2    WMS-2624-Revise Field mapping (CS03)   */
/************************************************************************/

CREATE PROC [dbo].[isp_PBCN_CN_CommecialInvoice02](
  @cMBOL_ContrKey NVARCHAR(21)  
) 
AS 
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF

   DECLARE @tTempRESULT02 TABLE (
      MBOLKey          NVARCHAR( 20) NULL, 
      ExternOrdKey     NVARCHAR( 20) NULL, 
      DepartureDate    DATETIME  NULL,
      AddDate          DATETIME  NULL, 
     -- OriginCountry    NVARCHAR( 30) NULL,
    --  PlaceOfLoading   NVARCHAR( 30) NULL,
      PlaceOfDischarge NVARCHAR( 30) NULL,
     --PlaceOfDelivery  NVARCHAR( 30) NULL,
     -- OtherReference   NVARCHAR( 30) NULL,
     -- BillToKey        NVARCHAR( 15) NULL,
      BILLTO_Company   NVARCHAR( 45) NULL,
      BILLTO_Address1  NVARCHAR( 45) NULL, 
      BILLTO_Address2  NVARCHAR( 45) NULL,
      BILLTO_Address3  NVARCHAR( 45) NULL,
      BILLTO_Address4  NVARCHAR( 45) NULL,
      BILLTO_City      NVARCHAR( 45) NULL,
      BILLTO_Zip       NVARCHAR( 18) NULL, 
      BILLTO_State     NVARCHAR( 45) NULL,
      BILLTO_Country   NVARCHAR( 45) NULL,
      BILLTO_Contact1  NVARCHAR( 18) NULL,
      BILLTO_Phone1    NVARCHAR( 18) NULL,
      StorerKey        NVARCHAR( 15) NULL,
      HSCode           NVARCHAR( 20) NULL,
      SKUDesc          NVARCHAR( 60) NULL,
      COO              NVARCHAR(20)  NULL,
      ShippQty         INT       NULL,
      UnitPrice        DECIMAL(10, 3) NULL,
      OHUdef03         NVARCHAR(30) NULL,               --CS02
      OrdKey           NVARCHAR(20) NULL,
      BTASKUDESCR      NVARCHAR(120) NULL               --CS03
      )
   
   -- Declare variables
   DECLARE
      @b_Debug           INT

   SET @b_Debug = 0

	  INSERT INTO @tTempRESULT02 (
	  	            MBOLKey,
	               ExternOrdKey, 
	               DepartureDate,
	               AddDate,
	               PlaceOfDischarge, BILLTO_Company, BILLTO_Address1,
	               BILLTO_Address2, BILLTO_Address3, BILLTO_Address4, BILLTO_City,
	               BILLTO_Zip, BILLTO_State, BILLTO_Country, BILLTO_Contact1,
	               BILLTO_Phone1, StorerKey, HSCode, SKUDesc, COO, ShippQty,
	               UnitPrice,OHUdef03,ordkey,BTASKUDESCR                               --CS02 --CS03
	  )
   
      SELECT 
         cMbolkey          = MBOL.Mbolkey,
         CExtenOrdKey      = '',--ORDERS.ExternOrderKey,
         dtDepartureDate   = MBOL.DepartureDate,
         dtAddDate         =  MIN(MBOL.AddDate),                                       --CS03
         cPlaceOfDischarge = ISNULL(MIN(ORDERS.c_address4),''),--MBOL.PlaceOfDischarge,
      	 cBillTo_Company   = ISNULL(MIN(ORDERS.C_Company),''),--ISNULL(MBOL.userdefine01,''),--ORDERS.C_Company,        --CS03 start
      	 cBillTo_Address1  = ISNULL(MIN(ORDERS.C_Address1),''),--ISNULL(MBOL.userdefine02,''),--ORDERS.C_Address1,
      	 cBillTo_Address2  = ISNULL(MIN(ORDERS.C_Address2),''),--ISNULL(MBOL.userdefine03,''),--ORDERS.C_Address2,
      	 cBillTo_Address3  = ISNULL(MIN(ORDERS.C_Address3),''),--ORDERS.C_Address3,
      	 cBillTo_Address4  = ISNULL(MIN(ORDERS.C_Address4),''),--ORDERS.C_Address4,
         cBillTo_City      = ISNULL(MIN(ORDERS.C_City),''),--ORDERS.C_City,
         cBillTo_Zip       = ISNULL(MIN(ORDERS.C_Zip),''),--ORDERS.C_Zip,
         cBillTo_State     = ISNULL(MIN(ORDERS.C_State),''),--ORDERS.C_State,
         cBillTo_country   = ISNULL(MIN(ORDERS.C_Country),''),--ORDERS.C_Country,
         cBILLTO_Contact1  = ISNULL(MAX(ORDERS.C_Contact1),''),--ISNULL(MBOL.userdefine04,''),--ORDERS.C_Contact1,
		 cBILLTO_Phone1    = ISNULL(MIN(ORDERS.C_Phone1),''),--ISNULL(MBOL.userdefine05,''),--ORDERS.C_Phone1, 
         cStorerkey        = ORDERS.StorerKey,
         CHsCode           = ISNULL(BTA.HSCode,''),
         cSkuDecr          = ISNULL(BTA.Userdefine01,''),--ISNULL(BTA.SkuDescr,''),
         cCOO              =ISNULL(BTA.COO,''),
         ShippedQty        = SUM(ORDERDETAIL.ShippedQty+ORDERDETAIL.QtyPicked),                      --CS03 End
         UniPrice          =AVG(ORDERDETAIL.unitprice),
         OHUdef03          = MIN(ORDERS.Userdefine03),
         ordkey            = '',--orders.orderkey
         BTASKUDESCR         = BTA.IssueAuthority                                                            --CS03
      FROM MBOL WITH (NOLOCK)
      LEFT JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
      LEFT JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
      LEFT JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
      LEFT JOIN STORER IDSCNSZ WITH (NOLOCK) ON (IDSCNSZ.StorerKey = ORDERS.Facility)
      LEFT JOIN STORER BILLTO WITH (NOLOCK) ON (BILLTO.StorerKey = ORDERS.StorerKey) 
      LEFT JOIN BTB_FTA BTA WITH (NOLOCK) ON BTA.Storerkey = ORDERDETAIL.Storerkey AND BTA.sku =ORDERDETAIL.sku   
      WHERE MBOL.MBOLKey = @cMBOL_ContrKey 
      GROUP BY
         MBOL.MBOLKey,   
         MBOL.DepartureDate,
        -- MBOL.PlaceOfDischarge,
        -- ORDERS.ExternOrderkey,
        -- ISNULL(ORDERS.C_Company,''),--ISNULL(MBOL.userdefine01,''),--ORDERS.c_Company, 
        -- ISNULL(ORDERS.C_Address1,''),--ISNULL(MBOL.userdefine02,''),--ORDERS.c_Address1,
        -- ISNULL(ORDERS.C_Address2,''),--ISNULL(MBOL.userdefine03,''),--ORDERS.c_Address2,
       --  ISNULL(ORDERS.c_Address3,''),
       --  ISNULL(ORDERS.c_Address4,''),
       --  ISNULL(ORDERS.C_State,''),
      --  ISNULL(ORDERS.c_City,''),
      --   ISNULL(ORDERS.c_Zip,''), 
      --   ISNULL(ORDERS.C_Country,''),
         --ISNULL(ORDERS.C_Contact1,''),--ISNULL(MBOL.userdefine04,''),--ORDERS.C_Contact1,
		--	ISNULL(ORDERS.c_Phone1,''),--ISNULL(MBOL.userdefine05,''),--ORDERS.c_Phone1,
         ORDERS.StorerKey, 
         ISNULL(BTA.HSCode,''),
         --ISNULL(BTA.SkuDescr,''),
         ISNULL(BTA.Userdefine01,''),
         ISNULL(BTA.COO,'') --,orders.orderkey
         ,BTA.IssueAuthority                                               --CS03

   SET ROWCOUNT 0
   -- Retrieve result
   SELECT 
        MBOLKey,
		ExternOrdKey, 
		DepartureDate,
		AddDate,
		PlaceOfDischarge, 
		BILLTO_Company, 
		BILLTO_Address1,
		BILLTO_Address2, 
		BILLTO_Address3, 
		BILLTO_Address4, 
		BILLTO_City,
		BILLTO_Zip, 
		BILLTO_State, 
		BILLTO_Country, 
		BILLTO_Contact1,
		BILLTO_Phone1, 
		StorerKey, 
		HSCode, 
		SKUDesc, 
		COO, 
		ShippQty,
		UnitPrice,
		OHUdef03 ,OrdKey ,BTASKUDESCR                                      --Cs03
   FROM @tTempRESULT02
   ORDER BY  HSCode, 
	         SKUDesc, 
	         COO

END


GO