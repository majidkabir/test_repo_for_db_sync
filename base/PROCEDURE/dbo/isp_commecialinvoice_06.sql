SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
   
   /************************************************************************/
   /* Stored Procedure: isp_CommecialInvoice_06                            */
   /* Creation Date: 25-Jan-2019                                           */
   /* Copyright: IDS                                                       */
   /* Written by: WLCHOOI                                                  */
   /*                                                                      */
   /* Purpose: WMS-7758 [CN]LOGITECH Commercial Invoice                    */
   /*          Copy from isp_CommecialInvoice_03                           */
   /*                                                                      */
   /*                                                                      */
   /* Called By: report dw = r_dw_commercialinvoice_06                     */
   /*                                                                      */
   /* PVCS Version: 1.0                                                    */
   /*                                                                      */
   /* Version: 5.4                                                         */
   /*                                                                      */
   /* Data Modifications:                                                  */
   /*                                                                      */
   /* Updates:                                                             */
   /* Date         Author    Ver.  Purposes                                */
   /* 23-APR-2020  WLChooi   1.1   WMS-13022 - ShowModelNumber by ReportCFG*/
   /*                              (WL01)                                  */    
   /************************************************************************/
   
   CREATE PROC [dbo].[isp_CommecialInvoice_06] (
      @c_MBOLKey  NVARCHAR(21)  
     ,@c_type     NVARCHAR(10)   = 'H1'
     ,@c_Orderkey NVARCHAR(10)   = ''  
     ,@c_ShipType NVARCHAR(10)   = ''  
   ) 
   AS 
   BEGIN
      SET NOCOUNT ON
     -- SET ANSI_WARNINGS OFF
      SET QUOTED_IDENTIFIER OFF
      SET ANSI_NULLS OFF
      SET ANSI_DEFAULTS OFF
      
      DECLARE @n_rowid      INT,
           @n_rowcnt        INT,
           @c_Getmbolkey    NVARCHAR(20),
           @c_getExtOrdkey  NVARCHAR(20),
           @n_GetUnitPrice  FLOAT,
           @n_GetPQty       INT,
           @n_amt           DECIMAL(10,2),
           @n_getamt        DECIMAL(10,2),
           @n_TTLTaxamt     DECIMAL(10,2),
           @c_getCountry    NVARCHAR(10),
           @n_getttlamt     DECIMAL(10,2)                   
          ,@c_Con_Company   NVARCHAR(45)                     
          ,@c_Con_Address1  NVARCHAR(45)                      
          ,@c_Con_Address2  NVARCHAR(45)                      
          ,@c_Con_Address3  NVARCHAR(45)                      
          ,@c_Con_Address4  NVARCHAR(45)                      
          ,@c_OrdGrp        NVARCHAR(20)                           
          --,@c_orderkey      NVARCHAR(20)                   
          ,@c_PreOrderKey   NVARCHAR(20)
          ,@c_FromCountry   NVARCHAR(10)
          ,@n_TTLPLT        INT
          ,@n_lineno        INT
          ,@c_palletkey     NVARCHAR(30)
          ,@c_storerkey     NVARCHAR(20)
          ,@C_Lottable11    NVARCHAR(30)     
          ,@c_madein        NVARCHAR(250)
          ,@c_delimiter     NVARCHAR(1)     
          ,@c_GetOrderKey   NVARCHAR(10)      
          ,@c_getsku        NVARCHAR(20)    
          ,@n_CntRec        INT
          ,@c_company       NVARCHAR(45)
          ,@c_lott11        NVARCHAR(30)
          ,@c_UPDATECCOM    NVARCHAR(1)     
          ,@c_getconsignee  NVARCHAR(45)    

          ,@c_OrderKey_Inv  NVARCHAR(10)     
       
         
      CREATE TABLE #TEMP_CommINV06
            (  Rowid            INT IDENTITY(1,1),
               MBOLKey          NVARCHAR(20) NULL,
               pmtterm          NVARCHAR(10) NULL,
               Lottable11       NVARCHAR(30) NULL,
               ExtPOKey         NVARCHAR(20) NULL,
               OHUdf05          NVARCHAR(20) NULL, 
               ExternOrdKey     NVARCHAR(30) NULL,
               IDS_Company      NVARCHAR(45) NULL,
               IDS_Address1     NVARCHAR(45) NULL,
               IDS_Address2     NVARCHAR(45) NULL,
               IDS_Address3     NVARCHAR(45) NULL,
               IDS_Address4     NVARCHAR(45) NULL,
               IDS_Phone1       NVARCHAR(18) NULL,
               IDS_City         NVARCHAR(150) NULL,
               BILLTO_Company   NVARCHAR(45) NULL,
               BILLTO_Address1  NVARCHAR(45) NULL,
               BILLTO_Address2  NVARCHAR(45) NULL,
               BILLTO_Address3  NVARCHAR(45) NULL,
               BILLTO_Address4  NVARCHAR(45) NULL,
               BILLTO_City      NVARCHAR(150) NULL,
               ShipTO_Company   NVARCHAR(45) NULL,
               ShipTO_Address1  NVARCHAR(45) NULL,
               ShipTO_Address2  NVARCHAR(45) NULL,
               ShipTO_Address3  NVARCHAR(45) NULL,
               ShipTO_Address4  NVARCHAR(45) NULL,
               ShipTO_City      NVARCHAR(150) NULL,
               ShipTO_Phone1    NVARCHAR(18) NULL,
               ShipTO_Contact1  NVARCHAR(30) NULL,
               ShipTO_Country   NVARCHAR(30) NULL,
               From_Country     NVARCHAR(30) NULL,
               StorerKey        NVARCHAR(15) NULL,
               SKU              NVARCHAR(20) NULL,
               Descr            NVARCHAR(90) NULL,
               QtyShipped       int NULL,
               UnitPrice        decimal(10,2) NULL,
               Currency         NVARCHAR(18) NULL,
               ShipMode         NVARCHAR(18) NULL,
               SONo             NVARCHAR(30) NULL,
               consigneekey     NVARCHAR(20) NULL,
               ODUDF05          NVARCHAR(50) NULL,   --WL01        
               Taxtitle         NVARCHAR(20) NULL,
               Amt              FLOAT ,                   
               TaxAmt           FLOAT NULL,               
               TaxCurSymbol     NVARCHAR(20) NULL,
               TTLAmt           DECIMAL(10,2)  NULL,
               ShipTitle        NVARCHAR(30) NULL,        
               CON_Company      NVARCHAR(45) NULL,        
               CON_Address1     NVARCHAR(45) NULL,         
               CON_Address2     NVARCHAR(45) NULL,        
               CON_Address3     NVARCHAR(45) NULL,        
               CON_Address4     NVARCHAR(45) NULL,        
               ORDGRP           NVARCHAR(20) NULL,        
               PalletKey        NVARCHAR(20) NULL,        
               TTLPLT           INT NULL,
               Orderkey         NVARCHAR(20) NULL,
               Madein           NVARCHAR(250) NULL
            ,  OrderKey_Inv     NVARCHAR(10) NULL     
            ,  Freight          FLOAT     
            )
            

      CREATE TABLE #TEMP_madein06 (
      MBOLKey        NVARCHAR(20) NULL,
      OrderKey       NVARCHAR(20) NULL,
      SKU            NVARCHAR(20) NULL,
      lot11          NVARCHAR(50) NULL,
      company        NVARCHAR(45) NULL
   ,  OrderKey_Inv   NVARCHAR(10)                      
      )

      SET @c_UPDATECCOM = 'N'              

      CREATE TABLE #TEMP_Orderkey
               (  MBOLKey          NVARCHAR(20) NULL,
                  Orderkey         NVARCHAR(20) NOT NULL    PRIMARY KEY,
               )

      SET @c_Orderkey = ISNULL(RTRIM(@c_Orderkey), '')
      SET @c_ShipType = ISNULL(RTRIM(@c_ShipType), '')
      IF @c_Orderkey <> ''  -- Sub Report 
      BEGIN
         INSERT INTO #TEMP_Orderkey
            (  MBOLKey 
            ,  Orderkey
            )
         VALUES
            (  @c_MBOLKey
            ,  @c_Orderkey
            )
      END
      ELSE
      BEGIN
         INSERT INTO #TEMP_Orderkey
            (  MBOLKey 
            ,  Orderkey
            )
         SELECT DISTINCT
               MBD.MBOLKey
            ,  MBD.Orderkey
         FROM MBOLDETAIL MBD WITH (NOLOCK)
         WHERE MBD.MBolKey = @c_MBOLKey
      END   

      INSERT INTO #TEMP_CommINV06
      SELECT  MBOL.Mbolkey AS MBOLKEY,
             ORDERS.PmtTerm,
             Lott.lottable11,
             ORDERS.ExternPOKey,
             ORDERS.Userdefine05,
             ORDERS.ExternOrderKey,
             ISNULL(S.B_Company,'') AS IDS_Company,
             ISNULL(S.B_Address1,'') AS IDS_Address1,
             ISNULL(S.B_Address2,'') AS IDS_Address2,
             ISNULL(S.B_Address3,'') AS IDS_Address3,
             ISNULL(S.B_Address4,'') AS IDS_Address4,
              ISNULL(S.B_Phone1,'') AS IDS_Phone1,
             (ISNULL(S.b_city,'') + SPACE(2) + ISNULL(S.B_state,'') + SPACE(2) +  ISNULL(s.B_zip,'') +
              ISNULL(S.B_country,'') ) AS IDS_City,
             ISNULL(ORDERS.B_Company,'') AS BILLTO_Company,
             ISNULL(ORDERS.B_Address1,'') AS BILLTO_Address1,
             ISNULL(ORDERS.B_Address2,'') AS BILLTO_Address2,
             ISNULL(ORDERS.B_Address3,'') AS BILLTO_Address3,
             ISNULL(ORDERS.B_Address4,'') AS BILLTO_Address4,
             (ISNULL(ORDERS.B_City,'') + SPACE(2) + ISNULL(ORDERS.B_State,'') + SPACE(2) +
             ISNULL(ORDERS.B_Zip,'') + SPACE(2) +   ISNULL(ORDERS.B_Country,'')) AS BILLTO_City,
              CASE WHEN ORDERS.Ordergroup <> 'S01' THEN
                 CASE WHEN ORDERS.facility='WGQAP' AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%')   THEN
                      CASE WHEN ORDERS.c_country = 'HK' THEN ISNULL(SHK.company,'')
                           WHEN ORDERS.c_country = 'TW' THEN ISNULL(STW.company,'')
                           ELSE ISNULL(ORDERS.C_Company,'') END
                      ELSE ISNULL(ORDERS.C_Company,'') END 
                   ELSE 
                      CASE WHEN ORDERS.type='WR' THEN ORDERS.c_company ELSE '' END 
                   END AS ShipTO_Company,
             CASE  WHEN ORDERS.Ordergroup <> 'S01' THEN      
                      CASE WHEN ORDERS.facility='WGQAP' AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%')  THEN
                               CASE WHEN ORDERS.c_country = 'HK' THEN ISNULL(SHK.Address1,'')
                                    WHEN ORDERS.c_country = 'TW' THEN ISNULL(STW.Address1,'')
                                    ELSE ISNULL(ORDERS.C_Address1,'') 
                                    END
                           ELSE ISNULL(ORDERS.C_Address1,'') END 
                   ELSE
                     ISNULL(ORDERS.C_Address1,'') 
                   END AS ShipTO_Address1,                   
             CASE  WHEN ORDERS.Ordergroup <> 'S01' THEN      
                   CASE WHEN ORDERS.facility='WGQAP'  AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%') THEN
                         CASE WHEN ORDERS.c_country = 'HK' THEN ISNULL(SHK.Address2,'')
                              WHEN ORDERS.c_country = 'TW' THEN ISNULL(STW.Address2,'')
                              ELSE ISNULL(ORDERS.C_Address2,'') END
                        ELSE ISNULL(ORDERS.C_Address2,'') END 
                   ELSE
                        ISNULL(ORDERS.C_Address2,'') 
                   END AS ShipTO_Address2,                   
             CASE WHEN ORDERS.Ordergroup <> 'S01'  THEN      
                      CASE WHEN ORDERS.facility='WGQAP' AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%')  
                           THEN
                               CASE WHEN ORDERS.c_country = 'HK'  THEN ISNULL(SHK.Address3,'')
                                    WHEN ORDERS.c_country = 'TW'  THEN ISNULL(STW.Address3,'')
                                    ELSE ISNULL(ORDERS.C_Address3,'') END
                           ELSE ISNULL(ORDERS.C_Address3,'') END 
                  ELSE
                     ISNULL(ORDERS.C_Address3,'') 
                  END  AS ShipTO_Address3,                   
             CASE WHEN ORDERS.Ordergroup <> 'S01' THEN          
                       CASE WHEN ORDERS.facility='WGQAP' AND ORDERS.c_country IN ('HK','TW') 
                                 AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%' ) 
                            THEN '' 
                            ELSE ISNULL(ORDERS.C_Address4,'') END 
                  ELSE
                     ISNULL(ORDERS.C_Address4,'') 
                  END AS ShipTO_Address4,                    
             CASE WHEN ORDERS.facility='WGQAP' AND ORDERS.c_country IN ('HK','TW') 
                  AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%') 
                  THEN '' 
                  ELSE (ISNULL(ORDERS.C_City,'') + SPACE(2) + ISNULL(ORDERS.C_State,'') + SPACE(2) +
                        ISNULL(ORDERS.C_Zip,'') + SPACE(2) +   ISNULL(ORDERS.C_Country,'')) 
                  END AS ShipTO_City,
             ISNULL(ORDERS.C_phone1,'') AS ShipTo_phone1, 
             ISNULL(ORDERS.C_contact1,'') AS ShipTo_contact1, 
             ISNULL(ORDERS.C_country,'') AS ShipTo_country,
             ISNULL(S.country,'') AS From_country, 
             ORDERS.StorerKey,
             ORDERDETAIL.SKU,
             RTRIM(SKU.Descr) AS Descr,
             SUM(PICKDETAIL.Qty)AS QtyShipped,
             CONVERT(decimal(10,2),ORDERDETAIL.UnitPrice) AS UnitPrice,
             ORDERDETAIL.Userdefine03 AS Currency,
             ORDERS.Userdefine03 AS ShipMode,
             ORDERS.Userdefine01 AS SONo,
             ORDERS.Consigneekey AS Consigneekey,
             --WL01 START
             CASE WHEN ISNULL(CL1.Short,'N') = 'Y' 
                  THEN CASE WHEN LEN(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,'')))) > 16 
                            THEN SUBSTRING(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))),1,16) + ' ' + SUBSTRING(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))),17,LEN(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,'')))))    --WL04
                            ELSE ISNULL(SKUINFO.EXTENDEDFIELD05,'') END
             ELSE ORDERDETAIL.Userdefine05 END AS ODUDF05,
             --WL01 END
             'Tax:',
			 CASE WHEN ISNUMERIC(ISNULL(ORDERS.INVOICENO,'')) = 1 THEN 
			 ROUND( (1+(CAST(ORDERS.INVOICENO AS FLOAT)/100)) * (SUM(PICKDETAIL.Qty)*CONVERT(decimal(10,2),ORDERDETAIL.UnitPrice)),2)  
					ELSE ROUND(SUM(PICKDETAIL.Qty)*CONVERT(decimal(10,2),ORDERDETAIL.UnitPrice),2) END AS Amt,
             ROUND((SUM(PICKDETAIL.Qty)*CONVERT(decimal(10,2),ORDERDETAIL.UnitPrice)*0.07),2) AS taxamt
             ,MAX(ORDERDETAIL.Userdefine03) AS TaxCurSymbol,0,     
             CASE WHEN ORDERS.Ordergroup <> 'S01' THEN            
                      CASE WHEN ORDERS.facility='WGQAP' AND ORDERS.c_country IN ('HK','TW') 
                      AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%')
                      THEN 'Consignee:' 
                      ELSE 'Ship To:' END 
                  ELSE
                        'Ship To/Notify To:' 
                  END AS ShipTitle,                          
             CASE WHEN ORDERS.Ordergroup = 'S01' THEN 
                      CASE WHEN ORDERS.c_country = 'HK'  THEN ISNULL(MWRHK.company,'')
                           WHEN ORDERS.c_country = 'TW'  THEN ISNULL(MWRTW.company,'')
                           WHEN ORDERS.c_country = 'AU'  THEN ISNULL(MWRAU.company,'')
                           WHEN ORDERS.c_country = 'NZ'  THEN ISNULL(MWRNZ.company,'')
                           ELSE '' END
             ELSE '' END AS CON_Company,
             CASE WHEN ORDERS.Ordergroup = 'S01' THEN 
                      CASE WHEN ORDERS.c_country = 'HK'  THEN ISNULL(MWRHK.Address1,'')
                           WHEN ORDERS.c_country = 'TW'  THEN ISNULL(MWRTW.Address1,'')
                           WHEN ORDERS.c_country = 'AU'  THEN ISNULL(MWRAU.Address1,'')
                           WHEN ORDERS.c_country = 'NZ'  THEN ISNULL(MWRNZ.Address1,'')
                           ELSE '' END
             ELSE '' END AS CON_Address1,
             CASE WHEN ORDERS.Ordergroup = 'S01' THEN 
                      CASE WHEN ORDERS.c_country = 'HK'  THEN ISNULL(MWRHK.Address2,'')
                           WHEN ORDERS.c_country = 'TW'  THEN ISNULL(MWRTW.Address2,'')
                           WHEN ORDERS.c_country = 'AU'  THEN ISNULL(MWRAU.Address2,'')
                           WHEN ORDERS.c_country = 'NZ'  THEN ISNULL(MWRNZ.Address2,'')
                           ELSE '' END
             ELSE '' END AS CON_Address2,
             CASE WHEN ORDERS.Ordergroup = 'S01' THEN 
                      CASE WHEN ORDERS.c_country = 'HK'  THEN ISNULL(MWRHK.Address3,'')
                           WHEN ORDERS.c_country = 'TW'  THEN ISNULL(MWRTW.Address3,'')
                           WHEN ORDERS.c_country = 'AU'  THEN ISNULL(MWRAU.Address3,'')
                           WHEN ORDERS.c_country = 'NZ'  THEN ISNULL(MWRNZ.Address3,'')
                           ELSE '' END
             ELSE '' END AS CON_Address3,
             CASE WHEN ORDERS.Ordergroup = 'S01' THEN 
                      CASE WHEN ORDERS.c_country = 'HK'  THEN ISNULL(MWRHK.Address4,'')
                           WHEN ORDERS.c_country = 'TW'  THEN ISNULL(MWRTW.Address4,'')
                           WHEN ORDERS.c_country = 'AU'  THEN ISNULL(MWRAU.Address4,'')
                           WHEN ORDERS.c_country = 'NZ'  THEN ISNULL(MWRNZ.Address4,'')
                           ELSE '' END
             ELSE '' END AS CON_Address4
             , ORDERS.OrderGroup AS OrdGrp
             , '' AS palletkey,0,ORDERS.Orderkey,'' AS madein
             , OrderKey_Inv = CASE WHEN @c_ShipType = 'L' THEN ORDERS.Orderkey ELSE '' END
             , CASE WHEN ISNUMERIC(ISNULL(ORDERS.INVOICENO,'')) = 1 THEN 
             ROUND( (CAST(ORDERS.INVOICENO AS FLOAT)/100) * (SUM(PICKDETAIL.Qty)*CONVERT(decimal(10,2),ORDERDETAIL.UnitPrice)),2)  
             ELSE CONVERT(decimal(10,2),0) END AS Freight
             FROM MBOL WITH (NOLOCK)
             INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
             INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)
             INNER JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey)
             INNER JOIN SKU WITH (NOLOCK) ON (ORDERDETAIL.StorerKey = SKU.StorerKey AND ORDERDETAIL.Sku = SKU.Sku)
             INNER JOIN STORER S WITH (NOLOCK) ON (S.Storerkey = ORDERS.Storerkey)
             INNER JOIN PICKDETAIL WITH (NOLOCK) ON (PICKDETAIL.Orderkey = ORDERDETAIL.Orderkey
                                                     AND ORDERDETAIL.Storerkey = ORDERDETAIL.Storerkey
                                                     AND ORDERDETAIL.Sku = PICKDETAIL.Sku
                                                     AND ORDERDETAIL.OrderLineNumber=pickdetail.OrderLineNumber)
             INNER JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON (LOTT.Lot=PICKDETAIL.Lot AND LOTT.Storerkey=PICKDETAIL.Storerkey
                                                          AND LOTT.SKU=PICKDETAIL.SKU)
             LEFT JOIN STORER STW WITH (NOLOCK) ON (STW.Storerkey = 'LOGITWDDP')    
             LEFT JOIN STORER SHK WITH (NOLOCK) ON (SHK.Storerkey = 'LOGIHKDDP')
             LEFT JOIN STORER MWRHK WITH (NOLOCK) ON (MWRHK.Storerkey = 'LOGISMWRHK')    
             LEFT JOIN STORER MWRTW WITH (NOLOCK) ON (MWRTW.Storerkey = 'LOGISMWRTW') 
             LEFT JOIN STORER MWRAU WITH (NOLOCK) ON (MWRAU.Storerkey = 'LOGISMWRAU')    
             LEFT JOIN STORER MWRNZ WITH (NOLOCK) ON (MWRNZ.Storerkey = 'LOGISMWRNZ')   
             LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (CL1.Listname = 'REPORTCFG' AND CL1.Code = 'ShowModelNumber' AND CL1.Storerkey = ORDERS.Storerkey
                                                  AND CL1.code2 = ORDERS.Facility) --WL01        
             LEFT JOIN SKUINFO WITH (NOLOCK) ON (SKUINFO.StorerKey = SKU.StorerKey    
                                                  AND ORDERDETAIL.Sku = SKUINFO.Sku AND SKU.SKU = SKUINFO.SKU) --WL01                                     
             WHERE MBOL.Mbolkey = @c_mbolkey
             AND EXISTS (SELECT 1 FROM #TEMP_Orderkey TMP WHERE TMP.Orderkey = ORDERS.Orderkey)      
             GROUP BY  MBOL.Mbolkey ,
                       ORDERS.PmtTerm,
                       Lott.lottable11,
                       ORDERS.ExternPOKey,
                       ORDERS.Userdefine05,
                       ORDERS.ExternOrderKey,
                       ISNULL(S.B_Company,'') ,
                       ISNULL(S.B_Address1,'') ,
                       ISNULL(S.B_Address2,'') ,
                       ISNULL(S.B_Address3,'') ,
                       ISNULL(S.B_Address4,'') ,
                       ISNULL(S.B_Phone1,'') ,
                       (ISNULL(S.b_city,'')+ SPACE(2) + ISNULL(S.B_state,'') + SPACE(2) +  ISNULL(s.B_zip,'') +
                       ISNULL(S.B_country,'') ) ,
                       ISNULL(ORDERS.B_Company,'') ,
                       ISNULL(ORDERS.B_Address1,'') ,
                       ISNULL(ORDERS.B_Address2,'') ,
                       ISNULL(ORDERS.B_Address3,'') ,
                       ISNULL(ORDERS.B_Address4,'') ,
                       (ISNULL(ORDERS.B_City,'') + SPACE(2) + ISNULL(ORDERS.B_State,'') + SPACE(2) +
                       ISNULL(ORDERS.B_Zip,'') + SPACE(2) +   ISNULL(ORDERS.B_Country,'')) ,
                       ORDERS.C_Company ,
                       ISNULL(ORDERS.C_Address1,'') ,
                       ISNULL(ORDERS.C_Address2,'') ,
                       ISNULL(ORDERS.C_Address3,'') ,
                       ISNULL(ORDERS.C_Address4,'') ,
                       (ISNULL(ORDERS.C_City,'') + SPACE(2) + ISNULL(ORDERS.C_State,'') + SPACE(2) +
                       ISNULL(ORDERS.C_Zip,'') + SPACE(2) +   ISNULL(ORDERS.C_Country,'')) ,
                       ISNULL(ORDERS.C_phone1,'') , ISNULL(ORDERS.C_contact1,'') , 
                       ISNULL(ORDERS.C_country,''),  ISNULL(S.country,'') , 
                       ORDERS.StorerKey,
                       ORDERDETAIL.SKU,
                       RTRIM(SKU.Descr) ,
                       CONVERT(decimal(10,2),ORDERDETAIL.UnitPrice) ,
                       ORDERDETAIL.Userdefine03,ORDERS.Userdefine03,
                       ORDERS.Userdefine01 ,ORDERS.Consigneekey
                       --WL01 START
                      ,CASE WHEN ISNULL(CL1.Short,'N') = 'Y' 
                       THEN CASE WHEN LEN(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,'')))) > 16 
                                 THEN SUBSTRING(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))),1,16) + ' ' + SUBSTRING(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))),17,LEN(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,'')))))    --WL04
                                 ELSE ISNULL(SKUINFO.EXTENDEDFIELD05,'') END
                       ELSE ORDERDETAIL.Userdefine05 END
                       --WL01 END             
                      ,ORDERS.Facility,ORDERS.C_Country,ORDERS.UserDefine05,SHK.company,STW.company      
                      ,SHK.Address1,STW.Address1 ,SHK.Address2,STW.Address2 ,SHK.Address3,STW.Address3  --CS03
                      ,ORDERS.Ordergroup ,ORDERS.type,ISNULL(MWRHK.company,''),ISNULL(MWRTW.company,'')  
                      ,ISNULL(MWRAU.company,''),ISNULL(MWRNZ.company,''),ISNULL(MWRHK.Address1,'')
                      ,ISNULL(MWRTW.Address1,''),ISNULL(MWRAU.Address1,''),ISNULL(MWRNZ.Address1,'')
                      ,ISNULL(MWRHK.Address2,''),ISNULL(MWRTW.Address2,''),ISNULL(MWRAU.Address2,''),ISNULL(MWRNZ.Address2,'')
                      ,ISNULL(MWRHK.Address3,'')
                      ,ISNULL(MWRTW.Address3,''),ISNULL(MWRAU.Address3,''),ISNULL(MWRNZ.Address3,'')
                      ,ISNULL(MWRHK.Address4,'')
                      ,ISNULL(MWRTW.Address4,''),ISNULL(MWRAU.Address4,''),ISNULL(MWRNZ.Address4,'')
                      ,ORDERS.Orderkey
                      ,ORDERS.INVOICENO

      
      SET @c_FromCountry = ''    
      SET @n_lineNo = 1        
      SET @c_palletkey = ''
      SET @c_delimiter =',' 
   
      DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT mbolkey,ExternOrdKey,sum(TaxAmt),Orderkey,StorerKey--sum(UnitPrice*QtyShipped)    
            ,  OrderKey_Inv                                                           
      FROM   #TEMP_CommINV06    
      WHERE mbolkey=@c_MBOLKey 
      GROUP BY mbolkey,ExternOrdKey,Orderkey,StorerKey
            ,  OrderKey_Inv                                                 
     
      OPEN CUR_RESULT   
        
      FETCH NEXT FROM CUR_RESULT INTO @c_Getmbolkey,@c_getExtOrdkey,@n_getamt,@c_orderkey,@c_storerkey  -- WL01
                                    , @c_OrderKey_Inv                         
        
      WHILE @@FETCH_STATUS <> -1  
      BEGIN   
         
         IF @c_OrderKey_Inv = ''                                            
         BEGIN                                                              
            SELECT TOP 1                                                    
               @c_getCountry = b_country                                    
            ,  @c_FromCountry=C_Country                                     
            ,  @c_getconsignee = consigneekey                                       
            FROM ORDERS (NOLOCK)                                            
            WHERE MBOLKey=@c_getmbolkey AND OrderKey=@c_OrderKey_Inv               
         END                                                                
         ELSE                                                               
         BEGIN
            SELECT TOP 1 @c_getCountry = b_country,@c_FromCountry=C_Country    
            ,@c_getconsignee = consigneekey                                   
            FROM ORDERS (NOLOCK)
            WHERE MBOLKey=@c_getmbolkey AND ExternOrderKey=@c_getExtOrdkey   
         END                                                                

         SET @n_amt = 0 
         SET @n_getttlamt = 0           
         SET @c_PreOrderKey = ''
         SET @n_TTLPLT = 0
               
         SELECT @n_amt = SUM(amt)
               ,@n_getttlamt = SUM (TaxAmt) 
         FROM   #TEMP_CommINV06 
         WHERE mbolkey=@c_Getmbolkey
         AND   OrderKey_Inv = @c_OrderKey_Inv                                 
         GROUP BY MBOLKey
       
         IF @c_getCountry = 'SG' and @c_getconsignee <> '31624' 
         BEGIN
            --SET @n_amt = @n_getamt * 0.07
            
            --SET @n_TTLTaxamt = @n_getttlamt + @n_amt                  
            SET @n_TTLTaxamt = convert(decimal(10,2),(@n_getttlamt + @n_amt))               
      
            --SELECT @n_getamt AS '@n_getamt',@n_amt AS '@n_amt',@n_TTLTaxamt AS '@n_TTLTaxamt',@n_getttlamt AS '@n_getttlamt'
         END
         ELSE
         BEGIN
            SET @n_TTLTaxamt = @n_amt
         END   
      
         
         IF @c_FromCountry='TH'
         BEGIN
            IF @c_PreOrderKey <> @c_OrderKey
            BEGIN
            
               IF @n_lineNo = 1
               BEGIN
                   SELECT @n_TTLPLT= COUNT(DISTINCT CD.palletkey) 
                   FROM Containerdetail CD WITH (NOLOCK)
                   JOIN Container CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey=@c_MBOLKey
                   --JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CONTAINERT' AND C.UDF01='P' AND C.code=CON.ContainerType
                  -- GROUP BY C.UDF01
               END
            END
                
            SELECT @c_palletkey = ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') 
            FROM PACKHEADER PH WITH (NOLOCK)
            JOIN PackDetail AS PD WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo
            JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=ph.OrderKey     
            JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.caseid = PD.LabelNo  AND PLTD.Sku=pd.sku 
            JOIN Containerdetail CD WITH (NOLOCK) ON CD.PalletKey=PLTD.PalletKey
            JOIN Container CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey  AND CON.MBOLKey=ord.MBOLKey      
            LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CONTAINERT' AND C.UDF01='P' AND C.code=CON.ContainerType
            WHERE PH.orderkey = @c_OrderKey
            AND PLTD.STORERKEY = @c_storerkey
               
            DECLARE TH_ORDERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT mbolkey,orderkey,sku
            FROM #TEMP_CommINV06
            WHERE mbolkey=@c_MBOLKey
            AND   OrderKey_Inv = @c_OrderKey_Inv                            
            AND ShipTO_Country='TH'
            
            OPEN TH_ORDERS
           
            FETCH FROM TH_ORDERS INTO @c_Getmbolkey,@c_GetOrderKey,@c_getsku

            WHILE @@FETCH_STATUS = 0
            BEGIN
               INSERT INTO #TEMP_madein06
               (
                  MBOLKey,
                  OrderKey,
                  SKU,
                  lot11,
                  company
               ,  OrderKey_Inv                                           
               )
               SELECT DISTINCT  ORD.mbolkey, ORD.orderkey ,PD.sku,c.Description,ord.C_Company
                     ,  OrderKey_Inv = @c_OrderKey_Inv                     
               FROM PICKDETAIL PD (NOLOCK) 
               JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=pd.OrderKey     
               JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.userdefine02  = PD.orderkey AND PLTD.Sku=pd.sku AND PLTD.StorerKey=ORD.StorerKey   --CS04b
               JOIN Containerdetail CD WITH (NOLOCK) ON CD.PalletKey=PLTD.PalletKey
               JOIN Container CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey=ord.MBOLKey      
               JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON (LOTT.SKU=PD.SKU AND LOTT.Storerkey=PD.Storerkey AND LOTT.lot=PD.Lot)
               LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CTYCAT' AND C.code=LOTT.lottable11 
               WHERE ORD.mbolkey=@c_Getmbolkey AND ORD.orderkey = @c_GetOrderKey AND PD.sku = @c_getsku
          
               FETCH FROM TH_ORDERS INTO @c_Getmbolkey,@c_GetOrderKey,@c_getsku
            END
           
            CLOSE TH_ORDERS
            DEALLOCATE TH_ORDERS
       
            --SELECT * FROM #TEMP_madein06    
            SET @n_CntRec = 0
            SET @c_madein = ''

            IF EXISTS (SELECT 1 FROM #TEMP_madein06  WHERE MBOLKey = @c_MBOLKey
                       AND   OrderKey_Inv = @c_OrderKey_Inv             
                      )
            BEGIN
               SET @c_UPDATECCOM = 'Y'              
            END
       
            SELECT @n_CntRec = COUNT(DISTINCT lot11),@C_Lottable11 = MIN(lot11)
                ,@c_company=MIN(company)
            FROM  #TEMP_madein06 
            WHERE MBOLKey = @c_MBOLKey
            AND   OrderKey_Inv = @c_OrderKey_Inv                        
      
            SET @n_lineNo = 1
            SET @n_lineNo = @n_CntRec
       
            IF @n_CntRec = 1
            BEGIN
               SET @c_madein = @C_Lottable11
            END
            ELSE
            BEGIN 
               DECLARE MadeIn_loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT DISTINCT lot11
               FROM #TEMP_madein06
               WHERE mbolkey=@c_MBOLKey
               AND   OrderKey_Inv = @c_OrderKey_Inv                   

               OPEN MadeIn_loop

               FETCH FROM MadeIn_loop INTO @c_lott11

               WHILE @@FETCH_STATUS = 0
               BEGIN

                  IF @n_CntRec >=2
                  BEGIN
                     SET @c_madein = @c_lott11 + @c_delimiter
                  END
                  ELSE
                  BEGIN
                     SET @c_madein = @c_madein + @c_lott11
                  END  

                  SET @n_CntRec = @n_CntRec - 1

                  FETCH FROM MadeIn_loop INTO @c_lott11
               END
           
               CLOSE MadeIn_loop
               DEALLOCATE MadeIn_loop
            END
       
            -- SELECT @c_madein '@c_madein'
              
            UPDATE #TEMP_CommINV06
            SET  TTLPLT = @n_TTLPLT
            WHERE MBOLKey=@c_Getmbolkey
            AND Orderkey=@c_GetOrderKey
            AND SKU = @c_getsku
         END
      
         -- select @c_company '@c_company'
         UPDATE #TEMP_CommINV06
         SET TaxAmt = CASE WHEN @c_getCountry = 'SG' AND @c_getconsignee <>'31624' THEN TaxAmt ELSE 0.00  END  
             ,TTLAmt = @n_TTLTaxamt
             ,TaxCurSymbol = TaxCurSymbol
             ,Madein = @c_madein
             ,ShipTO_Company = CASE WHEN @c_UPDATECCOM = 'Y' THEN @c_company ELSE ShipTO_Company END  
         WHERE MBOLKey=@c_Getmbolkey
         AND   OrderKey_Inv = @c_OrderKey_Inv                       
         --AND ExternOrdKey = @c_getExtOrdkey    
      
         SET @c_PreOrderKey = @c_OrderKey    
         SET @n_lineNo = @n_lineNo + 1       
      
         FETCH NEXT FROM CUR_RESULT INTO @c_Getmbolkey,@c_getExtOrdkey,@n_getamt,@c_orderkey,@c_storerkey   
                                       , @c_OrderKey_Inv                  
      END
      CLOSE CUR_RESULT
      DEALLOCATE CUR_RESULT

      IF @c_ShipType <> 'L'
      BEGIN         
         SET @c_company = ''
         SELECT TOP 1 @c_company = company
         FROM #TEMP_madein06 AS tm
         WHERE tm.MBOLKey = @c_Getmbolkey
      
         UPDATE #TEMP_CommINV06
         SET  PalletKey =  CASE WHEN @c_FromCountry = 'TH' THEN @c_palletkey ELSE PalletKey END
             ,Madein =  CASE WHEN @c_FromCountry = 'TH' THEN @c_madein ELSE Madein END
             ,ShipTO_Company = CASE WHEN @c_FromCountry = 'TH' THEN @c_company ELSE ShipTO_Company END
         WHERE MBOLKey=@c_Getmbolkey   
      END

      DELETE FROM #TEMP_madein06
      
      IF @c_type = 'H1' GOTO TYPE_H1   
      IF @c_type = 'S01' GOTO TYPE_S01
      IF @c_type = 'S02' GOTO TYPE_S02
       
   
      TYPE_H1:
   
        SELECT Rowid            ,   
               MBOLKey          ,   
               pmtterm          ,   
               Lottable11       ,   
               ExtPOKey         ,   
               OHUdf05          ,   
               ExternOrdKey     ,   
               IDS_Company      ,   
               IDS_Address1     ,   
               IDS_Address2     ,   
               IDS_Address3     ,   
               IDS_Address4     ,   
               IDS_Phone1       ,   
               IDS_City         ,   
               BILLTO_Company   ,   
               BILLTO_Address1  ,   
               BILLTO_Address2  ,   
               BILLTO_Address3  ,   
               BILLTO_Address4  ,   
               BILLTO_City      ,   
               ShipTO_Company   ,   
               ShipTO_Address1  ,   
               ShipTO_Address2  ,   
               ShipTO_Address3  ,   
               ShipTO_Address4  ,   
               ShipTO_City      ,   
               ShipTO_Phone1    ,   
               ShipTO_Contact1  ,   
               ShipTO_Country   ,   
               From_Country     ,   
               StorerKey        ,   
               SKU              ,   
               Descr            ,   
               QtyShipped       ,   
               UnitPrice        ,   
               Currency         ,   
               ShipMode         ,   
               SONo             ,   
               consigneekey     ,   
               ODUDF05          ,   
               Taxtitle         ,   
               Amt              ,   
               TaxAmt           ,   
               TaxCurSymbol     ,   
               TTLAmt           ,   
               ShipTitle        ,
               CON_Company      , 
               CON_Address1     ,  
               CON_Address2     , 
               CON_Address3     ,
               CON_Address4     , 
               ORDGRP           ,
               PalletKey, TTLPLT,Madein
            ,  ShipType = @c_ShipType
            ,  OrderKey_Inv
            ,  InvoiceNo = CASE WHEN OrderKey_Inv = '' THEN MBOLKey ELSE 'A' + RTRIM(OrderKey_Inv) END   
			,  Freight
         FROM #TEMP_CommINV06
         ORDER BY mbolkey,ExternOrdKey
       
       GOTO QUIT
       TYPE_S01:
       
       SELECT  Rowid            ,   
               MBOLKey          ,   
               ExternOrdKey     ,   
               BILLTO_Company   ,   
               BILLTO_Address1  ,   
               BILLTO_Address2  ,   
               BILLTO_Address3  ,   
               BILLTO_Address4  ,   
               BILLTO_City      ,   
               ShipTO_Company   ,   
               ShipTO_Address1  ,   
               ShipTO_Address2  ,   
               ShipTO_Address3  ,   
               ShipTO_Address4  ,   
               ShipTO_City      ,   
               ShipTO_Phone1    ,   
               ShipTO_Contact1  ,   
               ShipTO_Country   ,   
               From_Country     ,   
               StorerKey        ,     
               ShipTitle        ,
               CON_Company      , 
               CON_Address1     ,  
               CON_Address2     , 
               CON_Address3     ,
               CON_Address4    , 
               ORDGRP    
         FROM #TEMP_CommINV06
         WHERE MBOLKey = @c_MBOLKey
      ORDER BY mbolkey,ExternOrdKey
      
       GOTO QUIT
  
       TYPE_S02:
      
      SELECT  Rowid            ,   
            MBOLKey          ,   
            ExternOrdKey     ,   
            BILLTO_Company   ,   
            BILLTO_Address1  ,   
            BILLTO_Address2  ,   
            BILLTO_Address3  ,   
            BILLTO_Address4  ,   
            BILLTO_City      ,   
            ShipTO_Company   ,   
            ShipTO_Address1  ,   
            ShipTO_Address2  ,   
            ShipTO_Address3  ,   
            ShipTO_Address4  ,   
            ShipTO_City      ,   
            ShipTO_Phone1    ,   
            ShipTO_Contact1  ,   
            ShipTO_Country   ,   
            From_Country     ,   
            StorerKey        ,     
            ShipTitle        ,
            CON_Company      , 
            CON_Address1     ,  
            CON_Address2     , 
            CON_Address3     ,
            CON_Address4     , 
            ORDGRP    
      FROM #TEMP_CommINV06
      WHERE MBOLKey = @c_MBOLKey
      ORDER BY mbolkey,ExternOrdKey
      
       GOTO QUIT
  QUIT:
  END

GO