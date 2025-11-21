SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/******************************************************************************/              
/* Store Procedure: isp_Packing_List_36                                       */              
/* Creation Date: 10-Jan-2017                                                 */              
/* Copyright: IDS                                                             */              
/* Written by: CSCHONG                                                        */              
/*                                                                            */              
/* Purpose: WMS-915 - CN Carter's wholesale Packing list                      */  
/*                                                                            */              
/*                                                                            */              
/* Called By:  r_dw_packing_list_36                                           */              
/*                                                                            */              
/* PVCS Version: 1.0                                                          */              
/*                                                                            */              
/* Version: 1.0                                                               */              
/*                                                                            */              
/* Data Modifications:                                                        */              
/*                                                                            */              
/* Updates:                                                                   */              
/* Date         Author    Ver.  Purposes                                      */  
/* 05-05-2017   CSCHONG   1.0    Change mapping (CS01)                        */  
/* 09-05-2017   CSCHONG   1.1    Add new field (CS02)                         */
/* 06-09-2017   CSCHONG   1.2    WMs-2623 - revise field mapping (CS03)       */
/******************************************************************************/     
  
CREATE PROC [dbo].[isp_Packing_List_36]             
       (@c_MBOLKey NVARCHAR(20))              
AS            
BEGIN            
   SET NOCOUNT ON            
   SET ANSI_WARNINGS OFF            
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @n_TTLPDQty        INT   
         , @c_labelno         NVARCHAR(45)  
         , @n_TTLSKU          INT
         , @n_Wgt             FLOAT
         , @c_ExtOrdkey       NVARCHAR(30)
         , @c_Issue           NVARCHAR(1)
         , @n_ttlcnt          INT
         
         
         
  SET @n_ttlcnt = 0       
  
  
 CREATE TABLE #PACKLIST32(
         MBOLKey          NVARCHAR( 20) NULL, 
			ExternOrdKey     NVARCHAR( 20) NULL, 
			DepartureDate    DATETIME  NULL,
			AddDate          DATETIME  NULL, 
			PlaceOfDischarge NVARCHAR( 30) NULL,
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
			ShippQty         INT       ,
			StdNetWgt        DECIMAL(10, 2) NULL,
			CntLabelNo       INT ,
			StdGrossWgt      DECIMAL(10, 2) NULL,
			Measurement      FLOAT,--DECIMAL(10, 4) NULL,
			OHUdef03         NVARCHAR(30) NULL ,              --CS02
			OrdKey           NVARCHAR(20) NULL,
			CNTPLT           INT,                           --CS03
			CUDF02           FLOAT,                          --CS03
			CUDF03           FLOAT,                           --CS03
			BTASKUDESCR      NVARCHAR(120) NULL               --CS03
			
               )
 
 
 
   SET @n_ttlcnt = 0
   SELECT @n_ttlcnt = COUNT(DISTINCT PDET.LabelNo) 
    FROM MBOL WITH (NOLOCK)
      LEFT JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
      LEFT JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
      LEFT JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
      LEFT JOIN PackHeader AS PH WITH (NOLOCK) ON PH.OrderKey = ORDERS.OrderKey
	   LEFT JOIN PackDetail AS PDET WITH (NOLOCK) ON PDET.PickSlipNo=PH.PickSlipNo
    WHERE MBOL.MBOLKey = @c_MBOLKey
         
   INSERT INTO #PACKLIST32 (      
								   MBOLKey,
	                        ExternOrdKey, 
									DepartureDate,
									AddDate,
									PlaceOfDischarge, BILLTO_Company, BILLTO_Address1,
									BILLTO_Address2, BILLTO_Address3, BILLTO_Address4, BILLTO_City,
									BILLTO_Zip, BILLTO_State, BILLTO_Country, BILLTO_Contact1,
									BILLTO_Phone1, StorerKey, HSCode, SKUDesc, ShippQty,StdNetWgt,
									CntLabelNo,  StdGrossWgt,  Measurement,OHUdef03,ordkey ,CNTPLT,
								   CUDF02,CUDF03,BTASKUDESCR                    --CS03 
								     )             
   SELECT  
          cMbolkey          = MBOL.Mbolkey,
          CExtenOrdKey      = MIN(ORDERS.ExternOrderKey),
         dtDepartureDate      = MBOL.DepartureDate,
         dtAddDate            =  MIN(ORDERS.AddDate), 
         cPlaceOfDischarge    = ISNULL(MIN(ORDERS.c_address4),''),--MBOL.PlaceOfDischarge,
      	cBillTo_Company   = MIN(ORDERS.C_Company),--ISNULL(MBOL.userdefine01,''),--ORDERS.C_Company,    --CS03
      	cBillTo_Address1  = ISNULL(MIN(ORDERS.C_Address1),''),--ISNULL(MBOL.userdefine02,''),--ORDERS.C_Address1,  --CS03 Start
      	cBillTo_Address2  = ISNULL(MIN(ORDERS.C_Address2),''),--ISNULL(MBOL.userdefine03,''),--ORDERS.C_Address2,  --CS03
      	cBillTo_Address3  = ISNULL(MIN(ORDERS.C_Address3),''),--ORDERS.C_Address3,                                 --CS03
      	cBillTo_Address4  = ISNULL(MIN(ORDERS.C_Address4),''),--ORDERS.C_Address4,                                 --CS03
         cBillTo_City      = ISNULL(MIN(ORDERS.C_City),''),--ORDERS.C_City,                                         --CS03
         cBillTo_Zip       = ISNULL(MIN(ORDERS.C_Zip),''),--ORDERS.C_Zip,                                           --CS03  
         cBillTo_State     = ISNULL(MIN(ORDERS.C_State),''),--ORDERS.C_State,         
         cBillTo_country   = ISNULL(MIN(ORDERS.C_Country),''),--ORDERS.C_Country,     -
         cBILLTO_Contact1  = ISNULL(MIN(ORDERS.C_Contact1),''),--ISNULL(MBOL.userdefine04,''),--ORDERS.C_Contact1,
			cBILLTO_Phone1    = ISNULL(MIN(ORDERS.C_Phone1),''),--ISNULL(MBOL.userdefine05,''),--ORDERS.C_Phone1,      --CS03 End
         cStorerkey        = ORDERS.StorerKey,
         CHsCode           = ISNULL(BTA.HSCode,''),
         cSkuDecr          = ISNULL(BTA.Userdefine01,''),--ISNULL(BTA.SkuDescr,''),                           --CS03
         ShippedQty        = sum(PDET.Qty),--SUM(ORDERDETAIl.ShippedQty),                                     --CS03
         StdNetWgt         = CASE WHEN ISNUMERIC(BTA.userdefine02) = 1 
                             THEN CAST(BTA.userdefine02 AS DECIMAL(10,2)) ELSE 0.00 END,--sum(S.STDNetWGT),  --CS03
         CntLabelNo        = @n_ttlcnt,--count(DISTINCT PDET.labelno), 
         StdGrossWgt       = SUM((P.netWGT*(PDET.Qty/cast(p.casecnt AS INT))) + (p.GrossWgt * ((PDET.qty%cast(p.casecnt AS INT))))) ,  --SUM(S.STDGROSSWGT) ,
         --Measurement       = ((SUM(P.cubeuom1)/1000000) * SUM(PDET.Qty)) ,--SUM(S.STDCUBE) ,            --CS03
         Measurement       = SUM((P.cubeuom1 * (PDET.Qty/cast(p.casecnt AS INT))/1000000) + (P.cubeuom3 * ((PDET.qty%cast(p.casecnt AS INT)))/1000000)),
         OHUdef03          = MIN(ORDERS.Userdefine03),                              --CS02
         ordkey            = MIN(orders.orderkey),
         CNTPLT            = CASE WHEN ISNUMERIC(MBOL.UserDefine01) = 1 
                             THEN CAST(MBOL.UserDefine01 AS INT) ELSE 0 END ,         --CS03
         CUDF02            = CASE WHEN ISNUMERIC(MBOL.UserDefine01) = 1  
                             THEN CONVERT(FLOAT,C.UDF02) ELSE 0 END,   
         CUDF03            = CASE WHEN ISNUMERIC(MBOL.UserDefine01) = 1  
                             THEN CONVERT(FLOAT,C.UDF03) ELSE 0 END ,
        BTASKUDESCR         = BTA.IssueAuthority                                   --CS03                                  
      FROM MBOL WITH (NOLOCK)
      LEFT JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
      LEFT JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
      LEFT JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
      LEFT JOIN PackHeader AS PH WITH (NOLOCK) ON PH.OrderKey = ORDERS.OrderKey
	   LEFT JOIN PackDetail AS PDET WITH (NOLOCK) ON PDET.PickSlipNo=PH.PickSlipNo AND PDET.sku=ORDERDETAIL.sku
	   LEFT JOIN SKU S WITH (NOLOCK) ON S.StorerKey = ORDERDETAIL.StorerKey AND S.SKU = ORDERDETAIL.SKU
      LEFT JOIN BTB_FTA BTA WITH (NOLOCK) ON BTA.Storerkey = ORDERDETAIL.Storerkey AND BTA.sku =ORDERDETAIL.sku
      JOIN PACK P WITH (NOLOCK) ON P.PackKey=s.PACKKey                                 --CS03
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'LOGILOC' AND C.code = ORDERS.facility AND C.storerkey = ORDERS.Storerkey
      WHERE MBOL.MBOLKey = @c_MBOLKey
      GROUP BY
         MBOL.MBOLKey,   
         MBOL.DepartureDate,
        -- MBOL.PlaceOfDischarge,
        -- ORDERS.ExternOrderkey,
   --      ORDERS.c_Company, 
   --      ORDERS.c_Address1,
   --      ORDERS.c_Address2,
   --      ORDERS.c_Address3,
   --      ORDERS.c_Address4,
   --      ORDERS.C_State,
   --      ORDERS.c_City,
   --      ORDERS.c_Zip, 
   --      ORDERS.C_Country,
   --      ORDERS.C_Contact1,
			--ORDERS.c_Phone1,
         ORDERS.StorerKey, 
         ISNULL(BTA.HSCode,''),
         --ISNULL(BTA.SkuDescr,''), 
         ISNULL(BTA.Userdefine01,''),
        -- orders.orderkey,
         MBOL.UserDefine01     --CS03
         ,BTA.userdefine02
         --,PDET.Qty
         ,c.udf02
         ,c.udf03
         ,BTA.IssueAuthority                                               --CS03   
 
                  SELECT MBOLKey,
	                      ExternOrdKey, 
							 	 DepartureDate,
								 AddDate,
								 PlaceOfDischarge, BILLTO_Company, BILLTO_Address1,
								 BILLTO_Address2, BILLTO_Address3, BILLTO_Address4, BILLTO_City,
								 BILLTO_Zip, BILLTO_State, BILLTO_Country, BILLTO_Contact1,
								 BILLTO_Phone1, StorerKey, HSCode, SKUDesc, ShippQty,(StdNetWgt * ShippQty)as StdNetWgt,
								 CntLabelNo,  StdGrossWgt,  
								 case when Measurement < 0.01 THEN 0.01 ELSE Measurement END as Measurement ,
								 OHUdef03,ordkey,CNTPLT,CUDF02,CUDF03 ,BTASKUDESCR       --CS02     --CS03
						FROM #PACKLIST32  
					   ORDER BY ordkey
               
END

QUIT:



GO