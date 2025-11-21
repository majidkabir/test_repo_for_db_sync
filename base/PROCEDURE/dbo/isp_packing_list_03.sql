SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_Packing_List_03               			  	      */
/* Creation Date: 04-May-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Vital - Muji Store Level Packing list (Full case)           */
/* (SOS#134711)                                                         */
/*                                                                      */
/* Called By: report dw = r_dw_packing_list_03                          */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 09-JUN-2009  NJOW      1.1   Split cartonlist to 3 return parameters */
/*                              250 each. Fix Carton sorting issue      */
/*                              SOS#134711                              */
/* 10-Sep-2009  SPChin    1.2   SOS#147512 - To cater Full case when    */
/*                                           Qty = Casecnt              */
/*                              SOS#147312 - Use Round for Stdnetwgt,   */
/*                                           Stdgrosswgt and StdCube to */
/*                                           3 decimal point            */
/************************************************************************/

CREATE PROC [dbo].[isp_Packing_List_03] (
  @cMBOLKey NVARCHAR( 10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF

   DECLARE @c_key NVARCHAR(50),
           @c_sku NVARCHAR(15),
           @c_userdefine01 NVARCHAR(18),
           @c_prevsku NVARCHAR(15),
           @c_prevuserdefine01 NVARCHAR(18),
           @c_cartonno NVARCHAR(5),
           @n_cnt int,
           @c_cartonlist NVARCHAR(750)

   SELECT DISTINCT ORDERDETAIL.Orderkey, ORDERDETAIL.Storerkey, ORDERDETAIL.Sku, ORDERDETAIL.Userdefine01
   INTO #TEMP_OD
   FROM MBOLDETAIL WITH (NOLOCK)
   INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
   INNER JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
   WHERE MBOLDETAIL.MBOLKey = @cMBOLKey

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
   		 PACK.LengthUOM1,
   		 PACK.WidthUOM1,
   		 PACK.HeightUOM1,
   		 --SKU.StdGrossWgt,                           --SOS#147312
   		 --SKU.StdNetWgt,                             --SOS#147312
   		 --SKU.StdCube,                               --SOS#147312
   		 ROUND(SKU.StdGrossWgt,3) AS StdGrossWgt ,    --SOS#147312
   		 ROUND(SKU.StdNetWgt,3) AS StdNetWgt,         --SOS#147312
   		 ROUND(SKU.StdCube,3) AS StdCube,             --SOS#147312  
   		 PACK.CaseCnt AS UnitPerCtn,
   		 (PACK.CaseCnt / CASE WHEN PACK.InnerPack > 0 THEN PACK.InnerPack ELSE 1 END) AS InnerPerCtn,
   		 CONVERT(NVARCHAR(5),PACKDETAIL.CartonNo) AS cartonno,
   		 PACKDETAIL.qty,
   		 CONVERT(NVARCHAR(750),'') AS cartonlist,
   		 RIGHT('00000'+RTRIM(CONVERT(NVARCHAR(5),PACKDETAIL.CartonNo)),5) AS CtnNoSort
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
   WHERE MBOL.MBOLKey = @cMBOLKey

   --SOS#147512 Start
   /*
   SELECT userdefine01, cartonno, COUNT(DISTINCT sku) AS cnt
   INTO #TEMP_WORLDSHOP
   FROM #TEMP_PACK
   GROUP BY userdefine01, cartonno
   HAVING COUNT(DISTINCT sku) > 1
   */
   SELECT userdefine01, cartonno, UnitPerCtn, COUNT(DISTINCT sku) AS Cnt
   INTO #TEMP_WORLDSHOP
   FROM #TEMP_PACK
   GROUP BY userdefine01, cartonno, UnitPerCtn
   HAVING COUNT(DISTINCT sku) > 1 or SUM(Qty)<> UnitPerCtn
   --SOS#147512 End

   SELECT @c_key = '', @c_userdefine01 = '', @c_sku = '', @c_cartonno = '', @c_cartonlist = ''

   WHILE 1=1
   BEGIN
   	  SET ROWCOUNT 1
   	  SELECT @c_userdefine01=userdefine01, @c_sku=sku, @c_cartonno=cartonno, @c_key=userdefine01+sku+ctnnosort
   	  FROM #TEMP_PACK
   	  WHERE userdefine01+sku+ctnnosort > @c_key
   	  AND userdefine01 NOT IN (SELECT userdefine01 FROM #TEMP_WORLDSHOP)
   	  ORDER BY userdefine01, sku, ctnnosort

   	  SELECT @n_cnt = @@ROWCOUNT
   	  SET ROWCOUNT 0

   	  IF @n_cnt = 0
   	     BREAK

   	  IF (@c_userdefine01 = @c_prevuserdefine01 AND @c_sku = @c_prevsku) OR @c_prevsku = ''
   	  BEGIN
   	     SELECT @c_cartonlist = @c_cartonlist + RTRIM(@c_cartonno)+','
   	  END
   	  ELSE
   	  BEGIN
         IF RIGHT(@c_cartonlist,1) = ','
   	        SELECT @c_cartonlist = LEFT(@c_cartonlist,LEN(@c_cartonlist)- 1)

   	  	 UPDATE #TEMP_PACK
   	  	 SET cartonlist = @c_cartonlist
   	  	 WHERE userdefine01 = @c_prevuserdefine01
   	  	 AND sku = @c_prevsku

   	     SELECT @c_cartonlist = RTRIM(@c_cartonno)+','
   	  END

   	  SELECT @c_prevsku = @c_sku, @c_prevuserdefine01 = @c_userdefine01

   END

    IF RIGHT(@c_cartonlist,1) = ','
    	 SELECT @c_cartonlist = LEFT(@c_cartonlist,LEN(@c_cartonlist)- 1)
 	 UPDATE #TEMP_PACK
 	 SET cartonlist = @c_cartonlist
 	 WHERE userdefine01 = @c_prevuserdefine01
 	 AND sku = @c_prevsku

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
   		 LengthUOM1,
   		 WidthUOM1,
   		 HeightUOM1,
   		 UnitPerCtn,
   		 InnerPerCtn,
   		 SUM(Qty) AS TotalUnit,
   		 CEILING(SUM(Qty) / UnitPerCtn) AS NoofCtn,
   		 --(UnitPerCtn * StdGrossWgt) AS Grosswgtperctn,          --SOS#147312
   		 --(UnitPerCtn * StdNetWgt) AS NetWgtperctn,              --SOS#147312
   		 --(UnitPerCtn * StdCube) AS CBMperctn,                   --SOS#147312
   		 (UnitPerCtn * ROUND(StdGrossWgt,3)) AS Grosswgtperctn,   --SOS#147312
   		 (UnitPerCtn * ROUND(StdNetWgt,3)) AS NetWgtperctn,       --SOS#147312
   		 (UnitPerCtn * ROUND(StdCube,3)) AS CBMperctn,            --SOS#147312
   		 LEFT(Cartonlist,250) AS Cartonlist,
   		 SUBSTRING(Cartonlist,251,250) AS Cartonlist_2,
   		 SUBSTRING(Cartonlist,501,250) AS Cartonlist_3
    FROM #TEMP_PACK
    WHERE userdefine01 NOT IN (SELECT userdefine01 FROM #TEMP_WORLDSHOP)
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
   			 LengthUOM1,
   			 WidthUOM1,
   			 HeightUOM1,
   			 UnitPerCtn,
   			 InnerPerCtn,
   			 stdgrosswgt,
   			 stdNetWgt,
   			 stdcube,
   			 Cartonlist
    ORDER BY userdefine01, cartonlist, sku

END

GO