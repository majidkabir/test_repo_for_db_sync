SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Packing_List_04              			  	      */
/* Creation Date: 05-May-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Vital - Muji Store Level Packing list (Inner & Full case)   */
/* (SOS#134713)                                                         */
/*                                                                      */
/* Called By: report dw = r_dw_packing_list_04                          */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 10-Sep-2009  SPChin    1.1   SOS#147512 - To cater Full case and     */
/*                                           Inner Pack when Qty <>     */
/*                                           Casecnt                    */
/*                              SOS#147312 - Use Round for Stdnetwgt    */
/*                                           and Stdgrosswgt to 3       */
/*                                           decimal point              */
/* 24-Mar-2014  TLTING    1.1   SQL2012 Bug                             */
/************************************************************************/

CREATE PROC [dbo].[isp_Packing_List_04] (
  @cMBOLKey NVARCHAR( 10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF

   DECLARE @n_rowid int,
           @c_cartontype NVARCHAR(10),
           @c_prevcartontype NVARCHAR(10),
           @n_cnt int

   SELECT DISTINCT ORDERDETAIL.Orderkey, ORDERDETAIL.Storerkey, ORDERDETAIL.Sku, ORDERDETAIL.Userdefine01
   INTO #TEMP_OD
   FROM MBOLDETAIL WITH (NOLOCK)
   INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
   INNER JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
   WHERE MBOLDETAIL.MBOLKey = @cMBOLKey

   SELECT IDENTITY(int,1,1) AS rowid, PACKINFO.Pickslipno, PACKINFO.CartonNo, PACKINFO.CartonType, PACKINFO.[Cube]
   INTO #TEMP_PACKINFO
   FROM MBOLDETAIL WITH (NOLOCK)
   INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
   INNER JOIN PACKHEADER WITH (NOLOCK) ON ( ORDERS.Orderkey = PACKHEADER.Orderkey AND
 						                    		  ORDERS.Loadkey = PACKHEADER.Loadkey)
   INNER JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
   INNER JOIN PACKINFO WITH (NOLOCK) ON (PACKDETAIL.Pickslipno = PACKINFO.Pickslipno AND
                                         PACKDETAIL.Cartonno = PACKINFO.Cartonno)
   WHERE MBOLDETAIL.MBOLKey = @cMBOLKey
   GROUP BY PACKINFO.Pickslipno, PACKINFO.CartonNo, PACKINFO.CartonType, PACKINFO.[Cube]
   ORDER BY PACKINFO.Pickslipno, PACKINFO.CartonNo

   SELECT @n_rowid = 0

   WHILE 1=1
   BEGIN
   	  SET ROWCOUNT 1

   	  SELECT @n_rowid = rowid, @c_cartontype = ISNULL(cartontype,'')
   	  FROM #TEMP_PACKINFO
   	  WHERE rowid > @n_rowid
   	  ORDER BY rowid

   	  SELECT @n_cnt = @@ROWCOUNT

   	  SET ROWCOUNT 0

   	  IF @n_cnt = 0
   	     BREAK

   	  IF @c_cartontype = ''
   	  BEGIN
   	  	 SELECT @c_cartontype = @c_prevcartontype
   	  	 UPDATE #TEMP_PACKINFO
   	  	 SET cartontype = @c_cartontype
   	  	 WHERE rowid = @n_rowid
   	  END

   	  SELECT @c_prevcartontype = @c_cartontype
   END

   SELECT CONSIGNEE.Storerkey AS CON_Consigneekey,
   		 CONSIGNEE.Company AS CON_Company,
   		 CONSIGNEE.Address1 AS CON_Address1,
   		 CONSIGNEE.Address2 AS CON_Address2,
   		 CONSIGNEE.Address3 AS CON_Address3,
   		 CONSIGNEE.Address4 AS CON_Address4,
   		 CONSIGNEE.City AS CON_City,
   		 CONSIGNEE.Zip AS CON_Zip,
   		 CONSIGNEE.Country AS CON_Country,
          DELIVERTO.Storerkey AS DLTO_Key,
   		 DELIVERTO.Company AS DLTO_Company,
   		 DELIVERTO.Address1 AS DLTO_Address1,
   		 DELIVERTO.Address2 AS DLTO_Address2,
   		 DELIVERTO.Address3 AS DLTO_Address3,
   		 DELIVERTO.Address4 AS DLTO_Address4,
   		 DELIVERTO.City AS DLTO_City,
   		 DELIVERTO.Zip AS DLTO_Zip,
   		 DELIVERTO.Country AS DLTO_Country,
   		 ORDERS.Userdefine03,
   		 OD.StorerKey,
   		 OD.SKU,
   		 ISNULL(OD.Userdefine01,'') AS userdefine01,
   		 RTRIM(SKU.Descr)+' '+RTRIM(ISNULL(SKU.Busr1,'')) AS Descr,
   		 SKU.Length,
   		 SKU.Width,
   		 SKU.Height,
   		 CARTONIZATION.CartonLength,
   		 CARTONIZATION.CartonWidth,
   		 CARTONIZATION.CartonHeight,
   		 PINFO.[Cube] AS cartoncube,
   		 --SKU.StdGrossWgt,                          --SOS#147312
   		 --SKU.StdNetWgt,                            --SOS#147312
   		 ROUND(SKU.StdGrossWgt,3) AS StdGrossWgt ,   --SOS#147312
   		 ROUND(SKU.StdNetWgt,3) AS StdNetWgt ,       --SOS#147312
   		 PACK.InnerPack,
   		 PACKDETAIL.CartonNo,
   		 PACKDETAIL.qty,
   		 PACK.CaseCnt                                --SOS#147512
   INTO #TEMP_PACK
   FROM MBOL WITH (NOLOCK)
   			INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
   			INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
   			INNER JOIN #TEMP_OD OD WITH (NOLOCK) ON (OD.OrderKey = ORDERS.OrderKey)
   			INNER JOIN SKU WITH (NOLOCK) ON (OD.StorerKey = SKU.StorerKey AND OD.Sku = SKU.Sku)
   			INNER JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   			INNER JOIN STORER CONSIGNEE WITH (NOLOCK) ON (ORDERS.Consigneekey = CONSIGNEE.Storerkey)
   			INNER JOIN STORER DELIVERTO WITH (NOLOCK) ON (ORDERS.Markforkey = DELIVERTO.Storerkey)
		      INNER JOIN PACKHEADER WITH (NOLOCK) ON ( ORDERS.Orderkey = PACKHEADER.Orderkey AND
      						                    			  ORDERS.Loadkey = PACKHEADER.Loadkey)
  			   INNER JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo AND
  			                                           OD.Storerkey = PACKDETAIL.Storerkey AND
  			                                           OD.Sku = PACKDETAIL.Sku)
            INNER JOIN #TEMP_PACKINFO PINFO WITH (NOLOCK) ON (PACKDETAIL.Pickslipno = PINFO.Pickslipno AND
                                                              PACKDETAIL.Cartonno = PINFO.Cartonno)
            INNER JOIN STORER ST WITH (NOLOCK) ON (ORDERS.Storerkey = ST.Storerkey)
            INNER JOIN CARTONIZATION WITH (NOLOCK) ON (PINFO.Cartontype = CARTONIZATION.Cartontype AND
                                                       CARTONIZATION.CartonizationGroup = ST.CartonGroup)
   WHERE MBOL.MBOLKey = @cMBOLKey

   /* --SOS#147512 Start
   SELECT userdefine01, cartonno, COUNT(DISTINCT sku) AS Cnt
   INTO #TEMP_WORLDSHOP
   FROM #TEMP_PACK
   GROUP BY userdefine01, cartonno
   HAVING COUNT(DISTINCT sku) > 1
   */
   SELECT userdefine01, cartonno, CaseCnt, COUNT(DISTINCT sku) AS Cnt
   INTO #TEMP_WORLDSHOP
   FROM #TEMP_PACK
   GROUP BY userdefine01, cartonno, CaseCnt
   HAVING COUNT(DISTINCT sku) > 1 or SUM(Qty)<> CaseCnt
   --SOS#147512 End

   SELECT CON_Consigneekey,
   		 CON_Company,
   		 CON_Address1,
   		 CON_Address2,
   		 CON_Address3,
   		 CON_Address4,
   		 CON_City,
   		 CON_Zip,
   		 CON_Country,
          DLTO_Key,
   		 DLTO_Company,
   		 DLTO_Address1,
   		 DLTO_Address2,
   		 DLTO_Address3,
   		 DLTO_Address4,
   		 DLTO_City,
   		 DLTO_Zip,
   		 DLTO_Country,
   		 Userdefine03,
   		 StorerKey,
   		 SKU,
   		 Userdefine01,
   		 Descr,
   		 Length,
   		 Width,
   		 Height,
   		 CartonLength,
   		 CartonWidth,
   		 CartonHeight,
   		 CartonCube,
   		 --SUM(Qty * StdGrossWgt) AS totalgrosswgt,           --SOS#147312
   		 --SUM(Qty * StdNetWgt) AS totalnetwgt,               --SOS#147312
   		 SUM(Qty * ROUND(StdGrossWgt,3)) AS totalgrosswgt,    --SOS#147312   
          SUM(Qty * ROUND(StdNetWgt,3)) AS totalnetwgt,        --SOS#147312
   		 CEILING(SUM(Qty) / CASE WHEN InnerPack > 0 THEN InnerPack ELSE 1 END) AS InnerPerCtn,
   		 CartonNo,
   		 SUM(Qty) AS TotalUnit
    FROM #TEMP_PACK
    WHERE userdefine01 IN (SELECT userdefine01 FROM #TEMP_WORLDSHOP)
    GROUP BY CON_Consigneekey,
   			 CON_Company,
   			 CON_Address1,
   			 CON_Address2,
   			 CON_Address3,
   			 CON_Address4,
   			 CON_City,
   			 CON_Zip,
   			 CON_Country,
             DLTO_Key,
   			 DLTO_Company,
   			 DLTO_Address1,
   			 DLTO_Address2,
   			 DLTO_Address3,
   			 DLTO_Address4,
   			 DLTO_City,
   			 DLTO_Zip,
   			 DLTO_Country,
   			 Userdefine03,
   			 StorerKey,
   			 SKU,
   			 Userdefine01,
   			 Descr,
   			 Length,
   			 Width,
   			 Height,
   			 CartonLength,
   			 CartonWidth,
   			 CartonHeight,
   			 CartonCube,
   		  	 InnerPack,
   			 CartonNo
    ORDER BY userdefine01, cartonno, sku

END

GO