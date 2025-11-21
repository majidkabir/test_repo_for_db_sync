SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/    
/* Stored Procedure: isp_Delivery_Note54_SG                               */    
/* Creation Date: 02-AUG-2021                                             */    
/* Copyright: IDS                                                         */    
/* Written by: Mingle                                                     */    
/*                                                                        */    
/* Purpose:WMS-17353 - CN&SG-Logitech-DeliveryNote LOGIVMI order CR       */    
/*         (copy from  isp_Delivery_Note23_SG)                            */    
/*                                                                        */    
/* Called By: report dw = r_dw_delivery_note54_SG                         */    
/*                                                                        */    
/* PVCS Version: 1.3                                                      */    
/*                                                                        */    
/* Version: 5.4                                                           */    
/*                                                                        */    
/* Data Modifications:                                                    */    
/*                                                                        */    
/* Updates:                                                               */    
/* Date         Author    Ver.  Purposes                                  */  
/* 22-Dec-2021  CHOGNCS   1.1   Devops Scripts Combine                    */
/* 22-Dec-2021  CHOGNCS   1.2   WMS-17743 - Change print logic based on   */  
/*                              Orders.SpecialHandling (CS01)             */   
/* 10-May-2022  WLChooi   1.3   WMS-19628 Extend Userdefine02 column to   */
/*                              40 (WL01)                                 */
/**************************************************************************/    
    
CREATE PROC [dbo].[isp_Delivery_Note54_SG] (    
    @c_MBOLKey NVARCHAR(21)    
   ,@c_ShipType NVARCHAR(10)   = ''       
   ,@c_SHPFlag  NVARCHAR(10)   = ''     --CS01
)    
AS    
BEGIN    
   SET NOCOUNT ON    
 --  SET ANSI_WARNINGS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET ANSI_DEFAULTS OFF    
    
   DECLARE @n_rowid         INT,    
           @n_rowcnt        INT,    
           @c_Getmbolkey    NVARCHAR(20),    
           @c_getExtOrdkey  NVARCHAR(20),    
           @c_sku           NVARCHAR(20),    
           @c_prev_sku      NVARCHAR(20),    
           @n_ctnSKU        INT,    
           @c_pickslipno    NVARCHAR(20),    
           @n_CartonNo      INT,    
           @c_multisku      NVARCHAR(1),    
           @n_CtnCount      INT    
    
DECLARE @c_OrderKey            NVARCHAR(10)    
       ,@c_pmtterm             NVARCHAR(10)    
       ,@c_ExtPOKey            NVARCHAR(20)    
       ,@c_OHUdf05             NVARCHAR(20)    
       ,@c_MBOLKeyBarcode      NVARCHAR(20)      
       ,@c_ExternOrdKey        NVARCHAR(30)    
       ,@c_IDS_Company         NVARCHAR(45)    
       ,@c_IDS_Address1        NVARCHAR(45)    
       ,@c_IDS_Address2        NVARCHAR(45)    
       ,@c_IDS_Address3        NVARCHAR(45)    
       ,@c_IDS_Address4        NVARCHAR(45)    
       ,@c_IDS_Phone1          NVARCHAR(18)    
       ,@c_IDS_City            NVARCHAR(150)    
       ,@c_BILLTO_Company      NVARCHAR(45)    
       ,@c_BILLTO_Address1     NVARCHAR(45)    
       ,@c_BILLTO_Address2     NVARCHAR(45)    
       ,@c_BILLTO_Address3     NVARCHAR(45)    
       ,@c_BILLTO_Address4     NVARCHAR(45)    
       ,@c_BILLTO_City         NVARCHAR(150)    
       ,@c_ShipTO_Company      NVARCHAR(45)    
       ,@c_ShipTO_Address1     NVARCHAR(45)    
       ,@c_ShipTO_Address2     NVARCHAR(45)    
       ,@c_ShipTO_Address3     NVARCHAR(45)    
       ,@c_ShipTO_Address4     NVARCHAR(45)    
       ,@c_ShipTO_City         NVARCHAR(150)    
       ,@c_ShipTO_Phone1       NVARCHAR(18)    
       ,@c_ShipTO_Contact1     NVARCHAR(30)    
       ,@c_ShipTO_Country      NVARCHAR(30)    
       ,@c_From_Country        NVARCHAR(30)    
       ,@c_StorerKey           NVARCHAR(15)    
       ,@c_Descr               NVARCHAR(90)    
       ,@n_QtyShipped          INT    
       ,@c_UnitPrice           DECIMAL(10 ,2)    
       ,@c_ShipMode            NVARCHAR(18)    
       ,@c_SONo                NVARCHAR(30)    
       ,@c_PCaseCnt            INT    
       ,@n_PQty                INT    
       ,@n_PGrossWgt           FLOAT    
       ,@c_PCubeUom1           FLOAT    
       ,@c_PalletKey           NVARCHAR(30)    
       ,@c_ODUDEF05            NVARCHAR(30)    
       ,@c_CTNCOUNT            INT    
       ,@n_PieceQty            INT    
       ,@n_TTLWGT              FLOAT    
       ,@n_CBM                 FLOAT    
       ,@n_PCubeUom3           FLOAT    
       ,@c_PNetWgt             FLOAT    
       ,@n_CtnQty              INT    
       ,@n_PrevCtnQty          INT    
       ,@c_CartonType          VARCHAR(10)    
       ,@n_NoOfCarton          INT    
       ,@n_NoFullCarton        INT    
       ,@n_CaseCnt             INT    
       ,@c_GetPalletKey        NVARCHAR(30)                        
       ,@n_TTLPLT              INT                                 
       ,@c_PreOrderKey         NVARCHAR(10)                        
       ,@c_ChkPalletKey        NVARCHAR(30)                        
       ,@c_facility            NVARCHAR(5)                         
       ,@c_OrdGrp              NVARCHAR(20)                        
       ,@n_EPWGT_Value         DECIMAL(6,2)                        
       ,@n_EPCBM_Value         DECIMAL(6,2)                       
       ,@c_UDF01               NVARCHAR(5)                         
       ,@n_lineNo              INT                                                                             
       ,@C_CLKUPUDF01          NVARCHAR(15)         
       ,@C_Lottable11          NVARCHAR(30)         
       ,@c_madein              NVARCHAR(250)    
       ,@c_delimiter           NVARCHAR(1)         
       ,@c_GetOrderKey         NVARCHAR(10)          
       ,@c_getsku              NVARCHAR(20)        
       ,@n_CntRec              INT    
       ,@c_company             NVARCHAR(45)    
       ,@c_lott11              NVARCHAR(30)        
       ,@c_UPDATECCOM          NVARCHAR(1)         
       ,@c_OrderKey_Inv        NVARCHAR(50)         
       ,@c_CLKUDF01            NVARCHAR(60) = ''     
       ,@c_CLKUDF02            NVARCHAR(60) = ''     
       ,@n_pltwgt              FLOAT                               
       ,@n_pltcbm              FLOAT                                  
       ,@n_Cntvrec             INT                                 
       --,@n_fpltwgt             INT                               
       ,@n_fpltwgt             FLOAT                               
       ,@n_fpltcbm             FLOAT                                
       ,@c_ohroute             NVARCHAR(20)                          
       ,@n_epltwgt             FLOAT                               
       ,@n_epltcbm             FLOAT                                  
       ,@c_getstorerkey        NVARCHAR(20)                        
       ,@c_LocalOrd            NVARCHAR(5)    


    --CS01 S
        ,@c_getCountry        NVARCHAR(10) 
        ,@c_SpecialHandling   NVARCHAR(250) = ''     
        ,@c_SplitFlag         NVARCHAR(10)  = 'N'    
        ,@c_CombineStr        NVARCHAR(4000) = ''    
        ,@c_AllSHPFlag        NVARCHAR(250) = ''     
        ,@c_CCountry          NVARCHAR(100) = ''     
        ,@n_Continue          INT = 1           
        ,@n_Err               INT = 0           
        ,@b_Success           INT = 1           
        ,@n_Starttcnt         INT = @@TRANCOUNT     
        ,@c_Errmsg            NVARCHAR(255)   
        ,@c_InvResetPageNo    NVARCHAR(100)       
        ,@c_ResetPageNoFlag   NVARCHAR(10)   
        ,@n_RecNo             INT     
        ,@c_MinSH             NVARCHAR(10) = ''  

    --CS01 E                     
    
 CREATE TABLE #TEMP_DelNote54SG    
         (  Rowid            INT IDENTITY(1,1),    
            MBOLKey          NVARCHAR(20) NULL,    
            pmtterm          NVARCHAR(10) NULL,    
            --Lottable11       NVARCHAR(30) NULL,    
            ExtPOKey         NVARCHAR(20) NULL,    
            OHUdf05          NVARCHAR(20) NULL,    
            MBOLKeyBarcode   NVARCHAR(20) NULL,    
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
            ShipTO_Company  NVARCHAR(45) NULL,    
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
            QtyShipped       INT NULL,    
            UnitPrice        DECIMAL(10,2) NULL,    
            --Currency         NVARCHAR(18) NULL,    
            ShipMode         NVARCHAR(18) NULL,    
            SONo             NVARCHAR(30) NULL,    
            PCaseCnt         INT,    
            Pqty             INT,    
            PGrossWgt        FLOAT,    
            PCubeUom1        FLOAT,    
            PalletKey        NVARCHAR(30) NULL,    
            ODUDEF05         NVARCHAR(30) NULL,    
            CTNCOUNT         INT ,    
            PieceQty         INT,    
            TTLWGT           FLOAT,    
            CBM              FLOAT,    
            PCubeUom3        FLOAT,    
            PNetWgt          FLOAT,    
            TTLPLT           INT,                       
            ORDGRP           NVARCHAR(20) NULL,       
            EPWGT            FLOAT,    
            EPCBM            FLOAT,    
            CLKUPUDF01       NVARCHAR(5)    NULL,       
            Orderkey         NVARCHAR(20)   NULL,    
            lott11           NVARCHAR(250)  NULL,        
            OrderKey_Inv     NVARCHAR(50)  NULL,         
            pltwgt           FLOAT,                                               
            pltcbm           FLOAT,                                                
            Fpltwgt          FLOAT,                                               
            Fpltcbm          FLOAT                                                   
           -- OHROUTE          NVARCHAR(20)                                       
           ,epltwgt          FLOAT NULL                                                    
           ,epltcbm          FLOAT NULL
           ,InvResetPageNo   NVARCHAR(100) NULL       --CS01  
           ,ResetPageNoFlag  NVARCHAR(10)  NULL       --CS01                                            
         )    
    
    
    CREATE TABLE #TEMP_CTHTYPEDelNote54 (    
         CartonType   NVARCHAR(20) NULL,    
         SKU          NVARCHAR(20) NULL,    
         QTY          INT,    
         TotalCtn     INT,    
         TotalQty     INT,    
         CartonNo     INT,    
         Palletkey    NVARCHAR(20) NULL,    
         CLKUPUDF01   NVARCHAR(15) NULL     
        -- ,Lottable11     NVARCHAR(15) NULL       
    )    
          
         CREATE TABLE #TEMP_madein54 (    
         MBOLKey        NVARCHAR(20) NULL,    
         OrderKey       NVARCHAR(20) NULL,    
         SKU            NVARCHAR(20) NULL,    
         lot11          NVARCHAR(50) NULL,    
         C_Company      NVARCHAR(45) NULL    
        )    
      
          
        
        CREATE TABLE #TMP_PLTDET2 (        
        PLTKEY        NVARCHAR(30) NULL,        
        MBOLKEY       NVARCHAR(20) NULL,        
        PLTDETUDF02   NVARCHAR(40) NULL,   --WL01        
        ExtOrdKey     NVARCHAR(50) NULL,        
        C_Company     NVARCHAR(45) NULL )        
        
               
        CREATE TABLE #TMP_PLTDET3 (        
        RN            INT,        
        PLTKEY        NVARCHAR(30) NULL,        
        MBOLKEY       NVARCHAR(20) NULL,        
        PLTDETUDF02   NVARCHAR(40) NULL,   --WL01        
        GrpExtOrdKey  NVARCHAR(500) NULL,        
        C_Company     NVARCHAR(45) NULL   )        
        
        CREATE TABLE #TMP_PLTDETLOGI (        
        PalletNO            INT,        
        PLTKEY              NVARCHAR(30) NULL,        
        MBOLKEY             NVARCHAR(20) NULL,        
        PalletType          NVARCHAR(30) NULL,        
        PLTDETUDF02         NVARCHAR(40) NULL,   --WL01         
        PLTLength           FLOAT NULL,        
        PLTWidth            FLOAT NULL,        
        PLTHeight           FLOAT NULL,        
        CBM                 FLOAT NULL,        
        PLTGrosswgt         FLOAT NULL,        
        LOC                 NVARCHAR(20) NULL,        
        ExtOrdKey           NVARCHAR(500) NULL,        
        C_Company           NVARCHAR(45) NULL )       

 
          
        SET @c_getstorerkey = ''    
    
        SELECT TOP 1 @c_getstorerkey = ORDERS.Storerkey    
        FROM MBOL WITH (NOLOCK)    
        JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)    
        JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)      
        WHERE MBOL.MbolKey = @c_MBOLKey    
        
       INSERT INTO #TMP_PLTDET2(PLTKEY,MBOLKEY,PLTDETUDF02,ExtOrdKey,C_Company)        
       Select PD.Palletkey, O.MBOLKey, PD.UserDefine02, O.ExternOrderkey, O.C_Company           
       From dbo.PALLETDETAIL PD (nolock)                
       LEFT JOIN dbo.ORDERS O (NOLOCK) ON O.OrderKey = PD.UserDefine02 and O.StorerKey = @c_getstorerkey          
       where PD.Storerkey = @c_getstorerkey --and PalletKey = 'AP074275'               
       AND O.MBOLKey = @c_MBOLKey         
       Group By PD.Palletkey, O.MBOLKey, PD.UserDefine02, O.ExternOrderkey, O.C_Company          
        
       INSERT INTO #TMP_PLTDET3(RN,PLTKEY,MBOLKEY,PLTDETUDF02,GrpExtOrdKey,C_Company)        
       Select ROW_NUMBER() OVER (PARTITION BY PLTKEY Order BY PLTDETUDF02 DESC) as RN, PLTKEY, MBOLKey, PLTDETUDF02,               
       STUFF((SELECT '; ' + RTRIM(PD3.ExtOrdKey )              
       FROM #TMP_PLTDET2 PD3              
       WHERE PD.PLTKEY = PD3.PLTKEY          
       AND MBOLKey = @c_MBOLKey                 
       FOR XML PATH('')),1,1,'') AS ExtOrdKey, PD.C_Company From #TMP_PLTDET2 PD (nolock)-- where pd.PalletKey = 'AP074275'               
       group by PLTKEY, MBOLKey, PLTDETUDF02, ExtOrdKey, C_Company            
        
        
        INSERT INTO #TMP_PLTDETLOGI(PalletNO,PLTKEY,MBOLKEY,PalletType,PLTDETUDF02,PLTLength,PLTWidth,PLTHeight,cbm,PLTGrosswgt,LOC,ExtOrdKey,C_Company)        
        Select ROW_NUMBER() OVER(PARTITION BY PD.MBOLKey ORDER BY PD.MBOLKey) AS PalletNO, PD.PLTKEY, PD.MBOLKey, P.PalletType, PD.PLTDETUDF02, P.Length, P.Width, P.Height       
        ,CBM= (P.Length*P.Width* P.Height)/1000000          
        , P.GrossWgt, LLI.LOC, PD.GrpExtOrdKey, PD.C_Company              
        From #TMP_PLTDET3 PD (nolock)                  
        JOIN dbo.PALLET P (nolock) ON P.PalletKey = PD.PLTKEY                  
        JOIN (select DISTINCT LOC, ID FROM dbo.LOTxLOCxID (nolock) where StorerKey = @c_getstorerkey) AS LLI ON LLI.Id = PD.PLTKEY                
        where P.StorerKey = @c_getstorerkey and pd.rn = 1-- and mbolkey = '0000606408'            
        AND   PD.MBOLKEY = @c_MBOLKey        
        group by PD.PLTKEY, PD.MBOLKey, P.PalletType, PD.PLTDETUDF02, P.Length, P.Width, P.Height, P.GrossWgt, LLI.LOC, PD.GrpExtOrdKey, PD.C_Company           
          
  --select '1' , * from #TMP_PLTDETLOGI            


    --CS01 S  

   CREATE TABLE #TEMP_Orderkey        
             (  MBOLKey          NVARCHAR(20) NULL,        
                Orderkey         NVARCHAR(20) NOT NULL    PRIMARY KEY,        
             )        

          
   INSERT INTO #TEMP_Orderkey        
          (  MBOLKey         
          ,  Orderkey        
          )        
       SELECT DISTINCT        
             MBD.MBOLKey        
          ,  MBD.Orderkey        
       FROM MBOLDETAIL MBD WITH (NOLOCK)        
       WHERE MBD.MBolKey = @c_MBOLKey            
          
   IF ISNULL(@c_SHPFlag,'') <> '' AND ISNULL(@c_ShipType,'') = ''  
   BEGIN  

      SELECT @c_CCountry = OH.C_Country   --1 MBOL will not mix C_Country  
      FROM ORDERS OH (NOLOCK)  
      WHERE OH.MBOLKey = @c_MBOLKey  
  
      SET @c_AllSHPFlag = CAST(STUFF((SELECT DISTINCT ',' + RTRIM(ISNULL(OH.SpecialHandling,''))   
                                      FROM ORDERS OH (NOLOCK)  
                                      WHERE OH.MBOLKey = @c_MBOLKey  
                                      AND OH.C_Country IN ('ID','TH','VN','MY')  
                                      ORDER BY ',' + RTRIM(ISNULL(OH.SpecialHandling,'')) FOR XML PATH('')),1,1,'' ) AS NVARCHAR(100))  

     SELECT @c_MinSH = MIN(RTRIM(ISNULL(OH.SpecialHandling,'')))
     FROM ORDERS OH (NOLOCK)  
     WHERE OH.MBOLKey = @c_MBOLKey  
     AND OH.C_Country IN ('ID','TH','VN','MY')  
     ORDER BY MIN(RTRIM(ISNULL(OH.SpecialHandling,'')))


 -- SELECT @c_AllSHPFlag '@c_AllSHPFlag', @c_MinSH '@c_MinSH'
  
      IF @c_CCountry IN ('ID','TH','VN')  
      BEGIN  
         --Maximum print 2 reports, as SHP E & N will be combined, only SHP D will be splitted  
         IF @c_SHPFlag = 'N'  AND @c_MinSH <> 'N' AND EXISTS (SELECT 1 FROM ORDERS OH (NOLOCK)  
                                                              WHERE OH.MBOLKey = @c_MBOLKey  
                                                              AND OH.C_Country IN ('ID','TH','VN','MY')  
                                                              AND OH.SpecialHandling = @c_SHPFlag)  
         BEGIN  
              
            SET @n_Continue = 3  
            SET @c_Errmsg = CONVERT(CHAR(250),@n_Err)  
            SET @n_Err = 69500  
            SET @c_Errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': No Report will be printed. Special Handling = ''N'' is already printed on previous RCM (isp_Delivery_Note54_SG)'   
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
            GOTO QUIT  
         END  
      END  
      ELSE IF @c_CCountry IN ('MY')  
      BEGIN  
         --Maximum print 3 reports, as SHP D, E, N will be splitted  
         SET @n_Continue = 1  
      END  

       IF NOT EXISTS (SELECT 1  
                     FROM dbo.fnc_DelimSplit(',', @c_AllSHPFlag) FDS  
                     WHERE FDS.ColValue IN (SELECT DISTINCT FDS1.ColValue   
                                            FROM dbo.fnc_DelimSplit(',', @c_SHPFlag) FDS1))  AND ISNULL(@c_AllSHPFlag,'') <> ''
      BEGIN  
         SET @n_Continue = 3  
         SET @c_Errmsg = CONVERT(CHAR(250),@n_Err)  
         SET @n_Err = 69501  
         SET @c_Errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': No Report will be printed. Special Handling = '''   
                       + UPPER(@c_SHPFlag) + ''' is not found (isp_Delivery_Note54_SG)'   
                       + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
         GOTO QUIT  
      END  

   END  
  
   CREATE TABLE #TMP_SHandling (  
      Orderkey             NVARCHAR(10)  
    , OriginalSHandling    NVARCHAR(100)  
    , CombineSHandling     NVARCHAR(100)  
    , SHandlingFlag        NVARCHAR(10)  
    , Country              NVARCHAR(100)  
   )  
  
   IF @c_ShipType <> 'L'  
   BEGIN  
      DECLARE CUR_SHandling CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT DISTINCT TOR.Orderkey  
      FROM #TEMP_Orderkey TOR  
      ORDER BY TOR.Orderkey  
        
      OPEN CUR_SHandling  
        
      FETCH NEXT FROM CUR_SHandling INTO @c_GetOrderKey  
        
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
         SELECT @c_GetCountry      = OH.C_Country  
              , @c_SpecialHandling = ISNULL(OH.SpecialHandling,'')  
         FROM ORDERS OH (NOLOCK)  
         WHERE OH.OrderKey = @c_GetOrderKey  
           
         --IF @c_GetCountry = ''  
         IF @c_GetCountry IN ('ID','TH','VN','MY') AND @c_SpecialHandling IN ('D','E','N')  
         BEGIN  
            INSERT INTO #TMP_SHandling(Orderkey, OriginalSHandling, CombineSHandling, SHandlingFlag, Country)  
            VALUES(@c_GetOrderKey  
                 , @c_SpecialHandling  
                 , @c_SpecialHandling  
                 , 'N'   
                 , @c_GetCountry  
               )  
              
         END  
         ELSE  
         BEGIN  
            INSERT INTO #TMP_SHandling(Orderkey, OriginalSHandling, CombineSHandling, SHandlingFlag, Country)  
            VALUES(@c_GetOrderKey  
                 , ''  
                 , ''  
                 , ''   
               , @c_GetCountry  
               )  
         END  
        
         FETCH NEXT FROM CUR_SHandling INTO @c_GetOrderKey  
      END  
      CLOSE CUR_SHandling  
      DEALLOCATE CUR_SHandling  
        

--SELECT * FROM #TMP_SHandling
      --For ORDERS.C_Country IN ('ID','TH','VN') - START  
      /*  
      DE  - Split & Reset Page No  
      DN  - Combine  
      EN  - Combine  
      NN  - Combine  
      DD  - Combine  
      EE  - Combine  
      DEN - Combine EN, Split D & Reset Page No  
      */  
      IF EXISTS (SELECT 1 FROM #TMP_SHandling TSH WHERE TSH.Country IN ('ID','TH','VN'))  
      BEGIN  
         SELECT @c_CombineStr = REPLACE(CAST(STUFF((SELECT DISTINCT ',' + RTRIM(ISNULL(TSH.OriginalSHandling,''))   
                                                    FROM #TMP_SHandling TSH  
                                                    WHERE TSH.SHandlingFlag = 'N'  
                                                    AND TSH.Country IN ('ID','TH','VN')  
                                                    ORDER BY ',' + RTRIM(ISNULL(TSH.OriginalSHandling,'')) FOR XML PATH('')),1,1,'' ) AS NVARCHAR(100)), ',', '')  
           
         --Combine all first  
         UPDATE #TMP_SHandling  
         SET CombineSHandling = @c_CombineStr  
         WHERE SHandlingFlag = 'N'  
         AND Country IN ('ID','TH','VN')  


--SELECT '1',* FROM #TMP_SHandling
           
         --DEN - Combine EN, Split D & Reset Page No  
         IF EXISTS (SELECT 1 FROM #TMP_SHandling TSH WHERE TSH.CombineSHandling IN ('DEN') AND TSH.Country IN ('ID','TH','VN'))  
         BEGIN  
            SET @c_CombineStr = REPLACE(CAST(STUFF((SELECT DISTINCT ',' + RTRIM(ISNULL(TSH.OriginalSHandling,''))   
                                                    FROM #TMP_SHandling TSH  
                                                    WHERE TSH.Country IN ('ID','TH','VN')  
                                                    AND TSH.OriginalSHandling IN ('E','N')  
                                                    ORDER BY ',' + RTRIM(ISNULL(TSH.OriginalSHandling,'')) FOR XML PATH('')),1,1,'' ) AS NVARCHAR(100)), ',', '')  
              
            UPDATE #TMP_SHandling  
            SET CombineSHandling = CASE WHEN OriginalSHandling = 'D' THEN 'D' ELSE @c_CombineStr END  
              , SHandlingFlag = 'Y'  
            WHERE SHandlingFlag = 'N'  
            AND Country IN ('ID','TH','VN')  
            AND OriginalSHandling IN ('D','E','N')  
           
            UPDATE #TMP_SHandling  
            SET CombineSHandling = REPLACE(CAST(STUFF((SELECT DISTINCT ',' + RTRIM(ISNULL(TSH.OriginalSHandling,''))   
                                                       FROM #TMP_SHandling TSH  
                                                       WHERE TSH.Country IN ('ID','TH','VN')  
                                                       AND TSH.CombineSHandling IN ('EN')  
                                                       ORDER BY ',' + RTRIM(ISNULL(TSH.OriginalSHandling,'')) FOR XML PATH('')),1,1,'' ) AS NVARCHAR(100)), ',', '')  
            WHERE Country IN ('ID','TH','VN')  
            AND CombineSHandling IN ('EN')  
         END  
           
         --DE  - Split & Reset Page No  
         IF EXISTS (SELECT 1 FROM #TMP_SHandling TSH WHERE TSH.CombineSHandling IN ('DE') AND TSH.Country IN ('ID','TH','VN'))  
         BEGIN  
            SET @c_CombineStr = REPLACE(CAST(STUFF((SELECT DISTINCT ',' + RTRIM(ISNULL(TSH.OriginalSHandling,''))   
                                                    FROM #TMP_SHandling TSH  
                                                    WHERE TSH.Country IN ('ID','TH','VN')  
                                                    AND TSH.OriginalSHandling IN ('E')  
                                                    ORDER BY ',' + RTRIM(ISNULL(TSH.OriginalSHandling,'')) FOR XML PATH('')),1,1,'' ) AS NVARCHAR(100)), ',', '')  
              
            UPDATE #TMP_SHandling  
            SET CombineSHandling = CASE WHEN OriginalSHandling = 'D' THEN 'D' ELSE @c_CombineStr END  
              , SHandlingFlag = 'Y'  
             WHERE SHandlingFlag = 'N'  
            AND Country IN ('ID','TH','VN')  
            AND OriginalSHandling IN ('D','E')  
         END
         IF EXISTS (SELECT 1 FROM #TMP_SHandling TSH WHERE TSH.Country IN('ID','TH','VN') AND CombineSHandling IN ('DN','D','E','N','EN')   )  
         BEGIN  

         --For ORDERS.C_Country IN ('ID','TH','VN') and OriginalSHandling IN ('D','E','N' and )   - START  
         /*  
         DE  - Combine
         NN  - Combine  
         DD  - Combine  
         EE  - Combine  
         */  
         SELECT @c_CombineStr = REPLACE(CAST(STUFF((SELECT DISTINCT ',' + RTRIM(ISNULL(TSH.OriginalSHandling,''))   
                                                    FROM #TMP_SHandling TSH  
                                                    WHERE TSH.SHandlingFlag = 'N'  
                                                    AND TSH.Country IN ('ID','TH','VN')  
                                                    ORDER BY ',' + RTRIM(ISNULL(TSH.OriginalSHandling,'')) FOR XML PATH('')),1,1,'' ) AS NVARCHAR(100)), ',', '')  
           
         --Combine all first  
         --UPDATE #TMP_SHandling  
         --SET CombineSHandling = @c_CombineStr  
         --WHERE SHandlingFlag = 'N'  
         --AND Country IN ('ID','TH','VN')  

   -- SELECT '123',@c_CombineStr '@c_CombineStr'
  
         UPDATE #TMP_SHandling  
         SET CombineSHandling = CASE WHEN CombineSHandling IN ('D','E','N') THEN OriginalSHandling ELSE @c_CombineStr END
           , SHandlingFlag = 'Y'  
         WHERE SHandlingFlag = 'N'  
         AND Country IN ('ID','TH','VN')  
         AND CombineSHandling IN ('DN','D','E','N','EN')  
         --For ORDERS.C_Country IN ('MY') - END  
      END     

--     SELECT '456',* FROM #TMP_SHandling
  
         --For ORDERS.C_Country IN ('ID','TH','VN') - END  
      END  
      ELSE IF EXISTS (SELECT 1 FROM #TMP_SHandling TSH WHERE TSH.Country IN ('MY'))  
      BEGIN  
         --For ORDERS.C_Country IN ('MY') - START  
         /*  
         DE  - Split & Reset Page No  
         DN  - Split & Reset Page No  
         EN  - Split & Reset Page No  
         NN  - Combine  
         DD  - Combine  
         EE  - Combine  
         DEN - Split & Reset Page No  
         */  
         SELECT @c_CombineStr = REPLACE(CAST(STUFF((SELECT DISTINCT ',' + RTRIM(ISNULL(TSH.OriginalSHandling,''))   
                                                    FROM #TMP_SHandling TSH  
                                                    WHERE TSH.SHandlingFlag = 'N'  
                                                    AND TSH.Country IN ('MY')  
                                                    ORDER BY ',' + RTRIM(ISNULL(TSH.OriginalSHandling,'')) FOR XML PATH('')),1,1,'' ) AS NVARCHAR(100)), ',', '')  
           
         --Combine all first  
         UPDATE #TMP_SHandling  
         SET CombineSHandling = @c_CombineStr  
         WHERE SHandlingFlag = 'N'  
         AND Country IN ('MY')  

  
         UPDATE #TMP_SHandling  
         SET CombineSHandling = OriginalSHandling  
           , SHandlingFlag = 'Y'  
         WHERE SHandlingFlag = 'N'  
         AND Country IN ('MY')  
         AND CombineSHandling IN ('DEN','DE','DN','EN','D','E','N')  
         --For ORDERS.C_Country IN ('MY') - END  
      END  
  
      SET @c_GetCountry  = ''  
      SET @c_GetOrderKey = ''  
           
   END  
   --CS01 E     

  --SELECT * FROM #TMP_SHandling
    
        SET @c_multisku = 'N'    
        SET @n_EPWGT_Value = 0.00                
        SET @n_EPCBM_value = 0.00    
        SET @n_lineNo = 1                        
        SET @c_delimiter =','                    
        SET @c_UPDATECCOM = 'N'                 
        SET @c_LocalOrd = 'N'                    
    
        DECLARE CS_ORDERS_INFO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
        SELECT DISTINCT ORDERS.OrderKey,    
                CASE WHEN FACILITY.Userdefine06='Y' THEN 'SH'+ISNULL(MBOL.Mbolkey,'') ELSE ISNULL(MBOL.Mbolkey,'') END AS MBOLKEY,     
                ORDERS.PmtTerm,    
                ORDERS.ExternPOKey,    
                ORDERS.Userdefine05,    
                CASE WHEN  FACILITY.Userdefine06='Y' THEN 'SH'+ISNULL(MBOL.Mbolkey,'')  ELSE NULL  END as BarcodeValue,     
                ORDERS.ExternOrderKey,      
                --CASE WHEN  ORDERS.facility='YPCN1' THEN ISNULL(S.company,'') ELSE ISNULL(S.B_Company,'') END,     
                --CASE WHEN  ORDERS.facility='YPCN1' THEN ISNULL(S.Address1,'') ELSE ISNULL(S.B_Address1,'') END AS IDS_Address1,      
                --CASE WHEN  ORDERS.facility='YPCN1' THEN ISNULL(S.Address2,'') ELSE ISNULL(S.B_Address2,'') END AS IDS_Address2,      
                --CASE WHEN  ORDERS.facility='YPCN1' THEN ISNULL(S.Address3,'') ELSE ISNULL(S.B_Address3,'') END AS IDS_Address3,      
                -- CASE WHEN  ORDERS.facility='YPCN1' THEN '' ELSE ISNULL(S.B_Address4,'') END AS IDS_Address4,      
                --CASE WHEN  ORDERS.facility='YPCN1' THEN ISNULL(S.Phone1,'')  ELSE ISNULL(S.B_Phone1,'')  END AS IDS_Phone1,      
            CASE WHEN (ISNULL(SOD.Door,''))<> '' THEN ISNULL(SD.B_Company,'')    
             ELSE ISNULL(S.B_Company,'') END AS IDS_Company,    
                CASE WHEN (ISNULL(SOD.Door,''))<> '' THEN ISNULL(SD.B_Address1,'')    
             ELSE ISNULL(S.B_Address1,'') END AS IDS_Address1,    
                CASE WHEN (ISNULL(SOD.Door,''))<> '' THEN ISNULL(SD.B_Address2,'')    
             ELSE ISNULL(S.B_Address2,'') END AS IDS_Address2,    
                CASE WHEN (ISNULL(SOD.Door,''))<> '' THEN ISNULL(SD.B_Address3,'')    
             ELSE ISNULL(S.B_Address3,'') END AS IDS_Address3,    
                CASE WHEN (ISNULL(SOD.Door,''))<> '' THEN ISNULL(SD.B_Address4,'')    
             ELSE ISNULL(S.B_Address4,'') END AS IDS_Address4,    
                CASE WHEN (ISNULL(SOD.Door,''))<> '' THEN ISNULL(SD.B_Phone1,'')    
             ELSE ISNULL(S.B_Phone1,'') END AS IDS_Phone1,      
                (ISNULL(S.b_city,'') + SPACE(2) + ISNULL(S.B_state,'') + SPACE(2) +  ISNULL(s.B_zip,'') +    
                 ISNULL(S.B_country,'') ) AS IDS_City,    
                ORDERS.B_Company AS BILLTO_Company,    
                ISNULL(ORDERS.B_Address1,'') AS BILLTO_Address1,    
                ISNULL(ORDERS.B_Address2,'') AS BILLTO_Address2,    
                ISNULL(ORDERS.B_Address3,'') AS BILLTO_Address3,    
                ISNULL(ORDERS.B_Address4,'') AS BILLTO_Address4,    
                LTRIM(ISNULL(ORDERS.B_City,'') + SPACE(2) + ISNULL(ORDERS.B_State,'') + SPACE(2) +    
                ISNULL(ORDERS.B_Zip,'') + SPACE(2) +   ISNULL(ORDERS.B_Country,'')) AS BILLTO_City,    
                ORDERS.C_Company AS ShipTO_Company,    
                ISNULL(ORDERS.C_Address1,'') AS ShipTO_Address1,    
                ISNULL(ORDERS.C_Address2,'') AS ShipTO_Address2,    
                ISNULL(ORDERS.C_Address3,'') AS ShipTO_Address3,    
                ISNULL(ORDERS.C_Address4,'') AS ShipTO_Address4,    
                LTRIM(ISNULL(ORDERS.C_City,'') + SPACE(2) + ISNULL(ORDERS.C_State,'') + SPACE(2) +    
                ISNULL(ORDERS.C_Zip,'') + SPACE(2) +   ISNULL(ORDERS.C_Country,'')) AS ShipTO_City,    
                ISNULL(ORDERS.C_phone1,'') AS ShipTo_phone1,ISNULL( ORDERS.C_contact1,'') AS ShipTo_contact1,    
                ISNULL(ORDERS.C_country,'') AS ShipTo_country,  ISNULL(S.country,'') AS From_country,    
                ORDERS.StorerKey,    
                ORDERS.Userdefine03 AS ShipMode,    
                ORDERS.Userdefine01 AS SONo    
                ,ISNULL(PTD.Palletkey,'N/A') AS palletkey    
                ,ORDERS.facility                                            
               ,ORDERS.OrderGroup AS OrdGrp                                  
               --,OrderKey_Inv = CASE WHEN @c_ShipType = 'L' THEN ORDERS.Orderkey ELSE '' END       
                 ,OrderKey_Inv = CASE WHEN @c_ShipType = 'L' THEN 'A' + ORDERS.Orderkey     
                                    WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'O' AND TSH.SHandlingFlag = '' THEN  MBOL.Mbolkey             --CS01   
                                    WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'D' AND TSH.SHandlingFlag = '' THEN  'D' + MBOL.Mbolkey       --CS01
                                    WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'E' AND TSH.SHandlingFlag = '' THEN  'E' + MBOL.Mbolkey       --CS01
                                    WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'N' AND TSH.SHandlingFlag = '' THEN  'N' + MBOL.Mbolkey        --CS01 
                                    WHEN @c_ShipType = '' AND ORDERS.SpecialHandling IN ('D','E','N') AND TSH.SHandlingFlag = 'Y' THEN TSH.CombineSHandling + MBOL.Mbolkey  END  --CS01                       
                 ,ORDERS.[route] 
                 ,InvResetPageNo  =  CASE WHEN @c_ShipType = '' AND TSH.SHandlingFlag = 'Y' THEN TSH.CombineSHandling + MBOL.Mbolkey END             --CS01    
                 ,ResetPageNoFlag =  CASE WHEN ORDERS.C_Country IN ('ID','TH','VN','MY') AND TSH.SHandlingFlag = 'Y' THEN 'Y' ELSE 'N' END            --CS01                                                                      
      FROM MBOL WITH (NOLOCK)    
      INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)    
      INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)    
      INNER JOIN FACILITY WITH (NOLOCK) ON (FACILITY.facility = Orders.facility)    
      INNER JOIN STORER S WITH (NOLOCK) ON (S.Storerkey = ORDERS.Storerkey)    
      INNER JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERDETAIL.OrderKey = MBOLDETAIL.OrderKey)  
      LEFT JOIN PalletDetail PTD WITH (NOLOCK) ON PTD.userdefine03 = ORDERS.mbolkey AND PTD.userdefine04=ORDERS.orderkey      
      LEFT JOIN storersodefault SOD WITH (NOLOCK) ON SOD.StorerKey = ORDERS.ConsigneeKey    
      LEFT JOIN STORER SD WITH (NOLOCK) ON (SD.Storerkey = SOD.Door)      
      LEFT JOIN #TMP_SHandling TSH ON TSH.Orderkey = ORDERS.OrderKey   --CS01       
      WHERE MBOL.Mbolkey = @c_mbolkey    
      ORDER BY  ORDERS.[route] ,ORDERS.C_Company,ISNULL(ORDERS.C_Address1,''),ISNULL(ORDERS.C_Address2,''),       
                ISNULL(ORDERS.C_Address3,''),ORDERS.Orderkey    
    
        OPEN CS_ORDERS_INFO    
    
      FETCH FROM CS_ORDERS_INFO INTO @c_OrderKey, @c_MBOLKey, @c_pmtterm, @c_ExtPOKey,    
                                 @c_OHUdf05,@c_MBOLKeyBarcode, --WL01    
                                 @c_ExternOrdKey, @c_IDS_Company,    
                                 @c_IDS_Address1, @c_IDS_Address2,    
                                 @c_IDS_Address3, @c_IDS_Address4,    
                                 @c_IDS_Phone1, @c_IDS_City, @c_BILLTO_Company,    
                                 @c_BILLTO_Address1, @c_BILLTO_Address2,    
                                 @c_BILLTO_Address3, @c_BILLTO_Address4,    
                                 @c_BILLTO_City, @c_ShipTO_Company,    
                                 @c_ShipTO_Address1, @c_ShipTO_Address2,    
                                 @c_ShipTO_Address3, @c_ShipTO_Address4,    
                                 @c_ShipTO_City, @c_ShipTO_Phone1,    
                                 @c_ShipTO_Contact1, @c_ShipTO_Country,    
                                 @c_From_Country, @c_StorerKey,    
                                 @c_ShipMode, @c_SONo, @c_PalletKey,@c_facility,@c_OrdGrp,           
                                 @c_OrderKey_Inv,@c_ohroute,@c_InvResetPageNo ,@c_ResetPageNoFlag           --CS01                               
   
        WHILE @@FETCH_STATUS = 0    
        BEGIN    
   --SELECT 'orders loop'
           -- Full Carton    
           SET @n_PrevCtnQty = 0      
          SET @c_LocalOrd ='N'    
          IF EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK)     
                              JOIN CODELKUP C WITH (NOLOCK) ON C.listname='LOGILOCAL' AND C.code = OH.ConsigneeKey    
                              WHERE OH.OrderKey=@c_OrderKey)    
          BEGIN    
                SET @c_LocalOrd = 'Y'    
         END    
    
       --SELECT @c_LocalOrd '@c_LocalOrd'      
    
         IF @c_facility IN ('BULIM','WGQAP','WGQBL')       
            BEGIN    
            INSERT INTO #TEMP_CTHTYPEDelNote54 (CartonType, SKU, QTY, TotalCtn, TotalQty, CartonNo,Palletkey,CLKUPUDF01)    
            SELECT 'SINGLE' , PD.SKU, SUM(PD.Qty)/COUNT(DISTINCT PD.CartonNo) , COUNT(DISTINCT PD.CartonNo) , SUM(PD.Qty) ,0    
               ,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END      
            ,ISNULL(C.UDF01,'')    
             -- ,CASE WHEN C.UDF01='P' THEN COUNT(DISTINCT CD.palletkey) ELSE 0 END    
            FROM PACKHEADER PH WITH (NOLOCK)    
            JOIN PackDetail AS PD WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo     
            JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=ph.OrderKey        
            JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.caseid = PD.LabelNo   AND PLTD.Sku=pd.sku     
            LEFT JOIN Containerdetail CD WITH (NOLOCK) ON CD.PalletKey=PLTD.PalletKey                                        
            LEFT JOIN Container CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey  AND CON.MBOLKey=ord.MBOLKey         
            LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CONTAINERT' AND C.UDF01='P' AND C.code=CON.ContainerType       
            LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.LISTNAME = 'LOGILOCAL' AND C1.code = ORD.ConsigneeKey      
            WHERE PH.orderkey = @c_OrderKey    
            AND PLTD.STORERKEY = @c_storerkey    
            AND EXISTS(SELECT 1 FROM PackDetail AS pd2 WITH(NOLOCK)    
                        WHERE PD2.PickSlipNo = PH.PickSlipNo    
                        AND   PD2.CartonNo = PD.CartonNo    
            AND 1 = CASE WHEN @c_LocalOrd='N' AND ISNULL(CON.ContainerKey,'') <> '' THEN 1 WHEN @c_LocalOrd='Y'  THEN 1 ELSE 0 END    
              GROUP BY pd2.CartonNo    
                        HAVING COUNT(DISTINCT PD2.SKU) = 1    
                        )    
            GROUP BY PD.SKU, PD.QTY ,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END      
                    ,ISNULL(C.UDF01,'')    
            UNION ALL    
            --INSERT INTO #TEMP_CTHTYPEDelNote54 (CartonType, SKU, QTY, TotalCtn, TotalQty, CartonNo,Palletkey)    
            SELECT 'MULTI' , PD.SKU, SUM(PD.Qty)/COUNT(DISTINCT PD.CartonNo) , 0, SUM(PD.Qty) ,PD.CartonNo    
             ,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END     
          ,ISNULL(C.UDF01,'')   
            --,CASE WHEN C.UDF01='P' THEN COUNT(DISTINCT CD.palletkey) ELSE 0 END                              
            FROM PACKHEADER PH WITH (NOLOCK)    
            JOIN PackDetail AS PD WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo     
            JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=ph.OrderKey        
            JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.caseid = PD.LabelNo  AND PLTD.Sku=pd.sku    
            JOIN Containerdetail CD WITH (NOLOCK) ON CD.PalletKey=PLTD.PalletKey    
            JOIN Container CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey  AND CON.MBOLKey=ord.MBOLKey        
            LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CONTAINERT' AND C.UDF01='P' AND C.code=CON.ContainerType    
            WHERE PH.orderkey = @c_OrderKey    
            AND PLTD.STORERKEY = @c_storerkey    
            AND NOT EXISTS(SELECT 1 FROM PackDetail AS pd2 WITH(NOLOCK)    
                     WHERE PD2.PickSlipNo = PH.PickSlipNo    
          AND   PD2.CartonNo = PD.CartonNo    
                     GROUP BY pd2.CartonNo    
                     HAVING COUNT(DISTINCT PD2.SKU) = 1    
                     )    
            GROUP BY PD.CartonNo, PD.SKU, PD.QTY  ,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END      
                     ,ISNULL(C.UDF01,'')    
         END    
         ELSE IF @c_facility = 'YPCN1'    
         BEGIN    
            INSERT INTO #TEMP_CTHTYPEDelNote54 (CartonType, SKU, QTY, TotalCtn, TotalQty, CartonNo,Palletkey,CLKUPUDF01)    
            SELECT 'SINGLE' , PD.SKU, SUM(PD.Qty)/COUNT(DISTINCT PD.CartonNo) , COUNT(DISTINCT PD.CartonNo) , SUM(PD.Qty) ,0    
              ,'N/A'--CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END      
             -- ,CASE WHEN C.UDF01='P' THEN COUNT(DISTINCT CD.palletkey) ELSE 0 END    
              ,''    
            FROM PACKHEADER PH WITH (NOLOCK)    
            JOIN PackDetail AS PD WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo     
            JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=ph.OrderKey        
            WHERE PH.orderkey = @c_OrderKey    
            --AND PLTD.STORERKEY = @c_StorerKey    
            AND EXISTS(SELECT 1 FROM PackDetail AS pd2 WITH(NOLOCK)    
                        WHERE PD2.PickSlipNo = PH.PickSlipNo    
                        AND   PD2.CartonNo = PD.CartonNo    
                        GROUP BY pd2.CartonNo    
                        HAVING COUNT(DISTINCT PD2.SKU) = 1    
                        )    
            GROUP BY PD.SKU, PD.QTY --,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END    
         UNION ALL    
            --INSERT INTO #TEMP_CTNTYPE37 (CartonType, SKU, QTY, TotalCtn, TotalQty, CartonNo,Palletkey)    
            SELECT 'MULTI' , PD.SKU, SUM(PD.Qty)/COUNT(DISTINCT PD.CartonNo) , 0, SUM(PD.Qty) ,PD.CartonNo    
            ,'N/A'--CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END    
            --,CASE WHEN C.UDF01='P' THEN COUNT(DISTINCT CD.palletkey) ELSE 0 END                               
            ,''   
            FROM PACKHEADER PH WITH (NOLOCK)    
            JOIN PackDetail AS PD WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo    
            JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=ph.OrderKey               
            WHERE PH.orderkey = @c_OrderKey    
            --AND PLTD.STORERKEY = @c_StorerKey    
            AND NOT EXISTS(SELECT 1 FROM PackDetail AS pd2 WITH(NOLOCK)    
                     WHERE PD2.PickSlipNo = PH.PickSlipNo    
                     AND   PD2.CartonNo = PD.CartonNo    
                     GROUP BY pd2.CartonNo    
                     HAVING COUNT(DISTINCT PD2.SKU) = 1    
                     )    
            GROUP BY PD.CartonNo, PD.SKU, PD.QTY --,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A'  END     
         END    
    
           DECLARE CS_SinglePack CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
           SELECT CartonType, SKU, QTY, CASE WHEN cartontype='SINGLE' THEN TotalCtn ELSE Cartonno END,    
           TotalQty, palletkey,clkupudf01                         
           FROM #TEMP_CTHTYPEDelNote54    
           ORDER BY CartonType desc,CartonNo    
    
           OPEN CS_SinglePack    
           FETCH NEXT FROM CS_SinglePack INTO @c_CartonType, @c_SKU, @n_CtnQty, @n_CtnCount, @n_PQty,@c_GetPalletKey,@C_CLKUPUDF01 --,@n_TTLPLT    
           WHILE @@FETCH_STATUS=0    
           BEGIN    
              IF @c_CartonType = 'MULTI'    
              BEGIN    
                 IF @n_CtnCount <> @n_PrevCtnQty    
                 BEGIN    
                    SET @n_NoOfCarton = 1    
                 END    
                 ELSE    
                    SET @n_NoOfCarton = 0    
    
                    SET @n_PrevCtnQty = @n_CtnCount    
              END    
              ELSE    
                  SET @n_NoOfCarton = @n_CtnCount    
    
              SELECT @c_Descr = S.Descr,    
                     @n_PGrossWgt = P.GrossWgt,    
                     @n_PCubeUom3 = P.cubeuom3,    
                     @c_PNetwgt   = p.NetWgt,    
                     @c_PCubeUom1 = P.cubeuom1,    
                     @n_CaseCnt   = P.CaseCnt    
              FROM SKU AS s WITH(NOLOCK)    
              JOIN PACK AS p WITH(NOLOCK) ON p.PACKKey = s.PACKKey    
              WHERE s.StorerKey = @c_StorerKey    
              AND   s.Sku = @c_sku    
    
              SET @n_PieceQty = 0    
              SET @n_PieceQty = @n_PQty % @n_CaseCnt    
              IF @n_PQty >= @n_CaseCnt    
                 SET @n_NoFullCarton = FLOOR( @n_PQty / @n_CaseCnt )    
              ELSE    
                 SET @n_NoFullCarton = 0    
    
    
              SET @n_CBM = (( @n_PieceQty * @n_PCubeUom3 ) / 1000000)  + (( @n_NoFullCarton * @c_PCubeUom1 ) / 1000000 )    
              SET @n_TTLWGT = (( @c_PNetwgt * @n_NoFullCarton) + (@n_PGrossWgt * @n_PieceQty))    
    
              --SELECT @n_CBM '@n_CBM', @n_PieceQty '@n_PieceQty', @n_NoFullCarton '@n_NoFullCarton', @n_CaseCnt '@n_CaseCnt', @n_PQty '@n_PQty'    
    
             IF @n_CBM < 0.01    
             SET @n_CBM = 0.01    
    
              SELECT TOP 1    
                      @c_UnitPrice = CONVERT(decimal(10,2),o.UnitPrice)    
                    ,@c_ODUDEF05  = ISNULL(o.Userdefine05,'')    
              FROM ORDERDETAIL AS o WITH(NOLOCK)    
              WHERE o.OrderKey = @c_OrderKey    
              AND   o.Sku = @c_sku    
      
             SET @n_TTLPLT = 0    
             SET @c_UDF01 = ''    
    
             IF @c_PreOrderKey <> @c_OrderKey    
             BEGIN     
               IF @n_lineNo = 1    
               BEGIN    
                   SELECT @n_TTLPLT= CASE WHEN C.UDF01='P' THEN COUNT(DISTINCT CD.palletkey)  ELSE 0 END    
                   FROM Containerdetail CD WITH (NOLOCK)    
                   JOIN Container CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey=@c_MBOLKey    
                   JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CONTAINERT' AND C.UDF01='P' AND C.code=CON.ContainerType    
                   GROUP BY C.UDF01    
                END    
      
    
                -- SELECT @n_TTLPLT= CASE WHEN C.UDF01='P' THEN COUNT(DISTINCT CD.palletkey)  ELSE 0 END      
                 SELECT @c_UDF01 = C.UDF01                                                
                 FROM PACKHEADER PH WITH (NOLOCK)    
                 JOIN PackDetail AS PD WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo    
                 JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.caseid = PD.LabelNo    
                 JOIN Containerdetail CD WITH (NOLOCK) ON CD.PalletKey=PLTD.PalletKey    
                 JOIN Container CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey    
                 LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CONTAINERT' AND C.UDF01='P' AND C.code=CON.ContainerType    
                 WHERE PH.orderkey = @c_OrderKey    
                 GROUP BY C.UDF01    
    
                  SET @n_EPWGT_Value = 0.00    
                  SET @n_EPCBM_Value = 0.00    
    
                 IF @c_facility in ('WGQAP','YPCN1','WGQBL')         
                 BEGIN    
    
                  SELECT @n_EPWGT_Value = CASE WHEN ISNUMERIC(c.udf02) = 1    
                                          THEN ISNULL(CAST(c.udf02 AS DECIMAL(6,2)),0.00) ELSE 0.00 END    
                  FROM CODELKUP C (NOLOCK)    
                  WHERE C.LISTNAME='LOGILOC'    
                  AND C.Code = @c_facility    
    
                 END    
                 ELSE    
                 BEGIN    
                    SELECT @n_EPWGT_Value = CASE WHEN ISNUMERIC(CON.Carrieragent) = 1    
                                            THEN ISNULL(CAST(CON.Carrieragent AS DECIMAL(6,2)),0.00) ELSE 0.00 END    
                    FROM PACKHEADER PH WITH (NOLOCK)    
                    JOIN PackDetail AS PD WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo    
                    JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=ph.OrderKey           --CS03a    
                    JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.caseid = PD.LabelNo --AND PLTD.StorerKey=ORD.StorerKey    
                    JOIN Containerdetail CD WITH (NOLOCK) ON CD.PalletKey=PLTD.PalletKey    
                    JOIN Container CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey=ord.MBOLKey              
                    JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CONTAINERT' AND C.UDF01='P' AND C.code=CON.ContainerType    
                    WHERE PH.orderkey = @c_OrderKey    
                    AND PLTD.STORERKEY = @c_StorerKey    
                 END    
    
    
                 IF @c_UDF01 = 'P'    
                 BEGIN    
                  SELECT @n_EPCBM_Value = CASE WHEN ISNUMERIC(c.udf03) = 1    
                                          THEN ISNULL(CAST(c.udf03 AS DECIMAL(6,2)),0.00) ELSE 0.00 END    
                  FROM CODELKUP C (NOLOCK)    
                  WHERE C.LISTNAME='LOGILOC'    
                  AND C.Code = @c_facility   
                END    
    
             END      
      
       SET @n_pltcbm= 0    
       SET @n_pltwgt = 0    
       SET @n_Cntvrec = 1    
       SET @n_fpltwgt = 0    
       SET @n_fpltcbm = 0    
    
       SELECT @n_Cntvrec = COUNT(1)    
       FROM  #TMP_PLTDETLOGI P --V_PalletDetail_LOGITECH P WITH (NOLOCK)          
       WHERE P.mbolkey = @c_mbolkey    
          
      IF ISNULL(@n_Cntvrec,0) = 0    
      BEGIN    
         SET @n_Cntvrec = 1    
      END    
    
      SELECT @n_pltcbm = sum(P.cbm/@n_Cntvrec)--sum((P.Length*P.Width*P.Height)/@n_Cntvrec)/1000000    
             ,@n_pltwgt = sum(P.PLTGrosswgt/@n_Cntvrec)    
             ,@n_fpltcbm = sum(P.cbm)--sum((P.Length*P.Width*P.Height)/@n_Cntvrec)/1000000    
             ,@n_fpltwgt = sum(P.PLTGrosswgt)    
       FROM #TMP_PLTDETLOGI P --V_PalletDetail_LOGITECH P WITH (NOLOCK)            
       WHERE P.mbolkey = @c_mbolkey    
     
    
              INSERT INTO #TEMP_DelNote54SG    
              (    
               -- Rowid -- this column value is auto-generated    
               MBOLKey,    
               pmtterm,    
               ExtPOKey,    
               OHUdf05,    
               MBOLKeyBarcode,       
               ExternOrdKey,    
               IDS_Company,    
               IDS_Address1,    
               IDS_Address2,    
               IDS_Address3,    
               IDS_Address4,    
               IDS_Phone1,    
               IDS_City,    
               BILLTO_Company,    
               BILLTO_Address1,    
               BILLTO_Address2,    
               BILLTO_Address3,    
               BILLTO_Address4,    
               BILLTO_City,    
               ShipTO_Company,    
               ShipTO_Address1,    
               ShipTO_Address2,    
               ShipTO_Address3,    
               ShipTO_Address4,    
               ShipTO_City,    
               ShipTO_Phone1,    
               ShipTO_Contact1,    
               ShipTO_Country,    
               From_Country,    
               StorerKey,    
               SKU,    
               Descr,    
               QtyShipped,    
               UnitPrice,    
               ShipMode,    
               SONo,    
               PCaseCnt,--36    
               Pqty,    
               PGrossWgt,    
               PCubeUom1,    
               PalletKey,    
               ODUDEF05,    
               CTNCOUNT,  --41    
               PieceQty,    
               TTLWGT,    
               CBM,    
               PCubeUom3,    
               PNetWgt,    
               TTLPLT                 
               ,ORDGRP                 
               ,EPWGT                 
               ,EPCBM                
               ,CLKUPUDF01              
               ,Orderkey               
               ,lott11                
               ,OrderKey_Inv          
               ,pltwgt                
               ,pltcbm                 
               ,Fpltwgt              
               ,Fpltcbm                
               ,epltwgt              
               ,epltcbm 
               ,InvResetPageNo          --CS01
               ,ResetPageNoFlag         --CS01       
              )    
              VALUES    
              (    
               @c_MBOLKey,    
               @c_pmtterm,    
               @c_ExtPOKey,    
               @c_OHUdf05 ,    
               @c_MBOLKeyBarcode,       
               @c_ExternOrdKey,    
               @c_IDS_Company,    
               @c_IDS_Address1,    
               @c_IDS_Address2,    
               @c_IDS_Address3,    
               @c_IDS_Address4,    
               @c_IDS_Phone1,    
               @c_IDS_City,    
               @c_BILLTO_Company,    
               @c_BILLTO_Address1,    
               @c_BILLTO_Address2,    
               @c_BILLTO_Address3,    
               @c_BILLTO_Address4,    
               @c_BILLTO_City,    
               @c_ShipTO_Company,    
               @c_ShipTO_Address1,    
               @c_ShipTO_Address2,    
               @c_ShipTO_Address3,    
               @c_ShipTO_Address4,    
               @c_ShipTO_City,    
               @c_ShipTO_Phone1,    
               @c_ShipTO_Contact1,    
               @c_ShipTO_Country,    
               @c_From_Country,    
               @c_StorerKey,    
               @c_SKU,    
               @c_Descr,    
               @n_PQty,    
               @c_UnitPrice,    
               @c_ShipMode,    
               @c_SONo,    
               @n_CtnQty, --36    
               @n_PQty,  --37    
               @n_PGrossWgt,    
               @c_PCubeUom1,    
               --@c_PalletKey,    
               @c_GetPalletKey,                  
               @c_ODUDEF05,    
               @n_NoOfCarton,  --41    
               @n_PieceQty,    
               @n_TTLWGT,    
               @n_CBM,    
               @n_PCubeUom3,    
               @c_PNetWgt    
               ,@n_TTLPLT                         
               ,@c_OrdGrp                          
               ,@n_EPWGT_Value,@n_EPCBM_Value      
               ,@C_CLKUPUDF01,@c_OrderKey,''         
               ,@c_OrderKey_Inv                    
               ,ISNULL(@n_pltwgt,0),ISNULL(@n_pltcbm,0)                 
               ,ISNULL(@n_fpltwgt,0),ISNULL(@n_fpltcbm,0)               
               ,ISNULL(@n_epltwgt,0),ISNULL(@n_epltcbm,0)  
               ,@c_InvResetPageNo,@c_ResetPageNoFlag                          --CS01               
              )    
    
               SET @c_PreOrderKey = @c_OrderKey    
               SET @n_lineNo = @n_lineNo + 1                    
    
    
               DELETE #TEMP_CTHTYPEDelNote54    
    
           FETCH NEXT FROM CS_SinglePack INTO @c_CartonType, @c_SKU, @n_CtnQty, @n_CtnCount, @n_PQty,@c_GetPalletKey,@C_CLKUPUDF01--,@n_TTLPLT       
           END    
           CLOSE CS_SinglePack    
           DEALLOCATE CS_SinglePack    
    
         FETCH FROM CS_ORDERS_INFO INTO @c_OrderKey, @c_MBOLKey, @c_pmtterm, @c_ExtPOKey,    
                                 @c_OHUdf05, @c_MBOLKeyBarcode,--WL01    
                                 @c_ExternOrdKey, @c_IDS_Company,    
                                 @c_IDS_Address1, @c_IDS_Address2,    
                                 @c_IDS_Address3, @c_IDS_Address4,    
                                 @c_IDS_Phone1, @c_IDS_City, @c_BILLTO_Company,    
                                 @c_BILLTO_Address1, @c_BILLTO_Address2,    
                                 @c_BILLTO_Address3, @c_BILLTO_Address4,    
                                 @c_BILLTO_City, @c_ShipTO_Company,    
                                 @c_ShipTO_Address1, @c_ShipTO_Address2,    
                                 @c_ShipTO_Address3, @c_ShipTO_Address4,    
                                 @c_ShipTO_City, @c_ShipTO_Phone1,    
                                 @c_ShipTO_Contact1, @c_ShipTO_Country,    
                                 @c_From_Country, @c_StorerKey,    
                                 @c_ShipMode, @c_SONo, @c_PalletKey,@c_facility,@c_OrdGrp        
                                ,@c_OrderKey_Inv,@c_ohroute  ,@c_InvResetPageNo ,@c_ResetPageNoFlag           --CS01                                     
    
        END    
    
        CLOSE CS_ORDERS_INFO    
        DEALLOCATE CS_ORDERS_INFO    
     
        DECLARE TH_ORDERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT DISTINCT mbolkey,orderkey,sku    
         FROM #TEMP_DelNote54SG    
         WHERE mbolkey=@c_MBOLKey    
         AND ShipTO_Country='TH'    
             
        OPEN TH_ORDERS    
            
       FETCH FROM TH_ORDERS INTO @c_Getmbolkey,@c_GetOrderKey,@c_getsku    
           
           
       WHILE @@FETCH_STATUS = 0    
       BEGIN    
            INSERT INTO #TEMP_madein54    
            (    
               MBOLKey,    
               OrderKey,    
               SKU,    
               lot11,    
               C_Company    
            )    
            SELECT DISTINCT  ORD.mbolkey, ORD.orderkey ,PD.sku,c.Description,ord.C_Company    
            FROM PICKDETAIL PD (NOLOCK)     
            JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=pd.OrderKey       
            JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.userdefine02  = PD.orderkey AND PLTD.Sku=pd.sku AND PLTD.StorerKey=ORD.StorerKey      
            JOIN Containerdetail CD WITH (NOLOCK) ON CD.PalletKey=PLTD.PalletKey    
            JOIN Container CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey=ord.MBOLKey        
            JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON (LOTT.SKU=PD.SKU AND LOTT.Storerkey=PD.Storerkey AND LOTT.lot=PD.Lot)    
            LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CTYCAT' AND C.code=LOTT.lottable11     
            WHERE ORD.mbolkey=@c_Getmbolkey AND ORD.orderkey = @c_GetOrderKey AND PD.sku = @c_getsku    
           
       FETCH FROM TH_ORDERS INTO @c_Getmbolkey,@c_GetOrderKey,@c_getsku    
       END    
            
        CLOSE TH_ORDERS    
        DEALLOCATE TH_ORDERS    
        
    --SELECT * FROM #TEMP_madein37        
    SET @n_CntRec = 0    
    SET @c_madein = ''    
        
    IF EXISTS (SELECT 1 FROM #TEMP_madein54  WHERE MBOLKey = @c_MBOLKey)    
    BEGIN    
      SET @c_UPDATECCOM = 'Y'                   
    END    
        
    SELECT @n_CntRec = COUNT(DISTINCT lot11),@C_Lottable11 = MIN(lot11)    
          ,@c_company=MIN(C_Company)    
    FROM  #TEMP_madein54     
    WHERE MBOLKey = @c_MBOLKey    
        
    IF @n_CntRec = 1    
    BEGIN    
      SET @c_madein = @C_Lottable11    
    END    
    ELSE    
    BEGIN    
         DECLARE MadeIn_loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT DISTINCT lot11    
         FROM #TEMP_madein54    
         WHERE mbolkey=@c_MBOLKey     
    
             
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
        
    IF @c_UPDATECCOM = 'Y'    
    BEGIN    
       UPDATE #TEMP_DelNote54SG    
       SET lott11 = @c_madein    
       ,ShipTO_Company = @c_company      
       WHERE MBOLKey = @c_MBOLKey     
    END    
        
    DELETE FROM #TEMP_madein54     
    
          
    SELECT @c_CLKUDF01 = CLK.UDF01    
          ,@c_CLKUDF02 = CLK.UDF02    
    FROM CODELKUP CLK (NOLOCK)    
    WHERE LISTNAME = 'LOGTHSHIP' AND Storerkey = @c_Storerkey      
     
    update #TEMP_DelNote54SG set     
    fpltwgt = case when CLKUPUDF01 <>'P'  then ((select sum (ttlwgt) from #TEMP_DelNote54SG) + ((select Sum (ttlplt) from #TEMP_DelNote54SG)* Epwgt) )else fpltwgt end,    
    fpltcbm = case when CLKUPUDF01 <>'P'  then ((select sum (cbm) from #TEMP_DelNote54SG)+ ((select Sum (ttlplt) from #TEMP_DelNote54SG)* Epcbm)) else fpltcbm end    
      
    update #TEMP_DelNote54SG set     
    epltwgt = case when CLKUPUDF01 <>'P'  then '0' else fpltwgt - (select sum (ttlwgt) from #TEMP_DelNote54SG) end,    
    epltcbm = case when CLKUPUDF01 <>'P'  then '0' else fpltcbm - (select sum (cbm) from #TEMP_DelNote54SG)end    
    

--SELECT * FROM #TEMP_DelNote54SG
    --CS01 S
    IF @c_ShipType= '' AND @c_CCountry IN ('ID','TH','VN') AND @c_SHPFlag IN ('D','E')   --SHP N not included here since it will print together with SHP E  
    BEGIN
       SELECT    
       Rowid    
      , MBOLKey    
      , pmtterm    
      , ExtPOKey    
      , OHUdf05    
      , MBOLKeyBarcode    
      , ExternOrdKey    
      , IDS_Company    
      , IDS_Address1    
      , IDS_Address2    
      , IDS_Address3    
      , IDS_Address4    
      , IDS_Phone1    
      , IDS_City    
      , BILLTO_Company    
      , BILLTO_Address1    
      , BILLTO_Address2    
      , BILLTO_Address3    
      , BILLTO_Address4    
      , BILLTO_City    
      , ShipTO_Company    
      , ShipTO_Address1    
      , ShipTO_Address2    
      , ShipTO_Address3    
      , ShipTO_Address4    
      , ShipTO_City    
      , ShipTO_Phone1    
      , ShipTO_Contact1    
      , ShipTO_Country    
      , From_Country    
      , StorerKey    
      , SKU    
      , Descr    
      , QtyShipped    
      , UnitPrice    
      , ShipMode    
      , SONo    
      , PCaseCnt    
      , Pqty    
      , PGrossWgt    
      , PCubeUom1    
      , PalletKey    
      , ODUDEF05    
      , CTNCOUNT    
      , PieceQty    
      , ROUND(TTLWGT, 2) AS TTLWGT    
      , ROUND(CBM, 2) AS CBM    
      , PCubeUom3    
      , PNetWgt             
      , TTLPLT                        
      , ORDGRP                       
      , EPWGT,EPCBM    
      , CLKUPUDF01    
      , Lott11       
      , OrderKey_Inv                   
      , ShipType = @c_ShipType       
      , InvoiceNo = OrderKey_Inv --CASE WHEN OrderKey_Inv = '' THEN MBOLKey ELSE 'A' + RTRIM(OrderKey_Inv) END     
      , CLKUDF01 = ISNULL(@c_CLKUDF01,'')     
      , CLKUDF02 = ISNULL(@c_CLKUDF02,'')     
      ,pltwgt as pltwgt,pltcbm as pltcbm                          
      ,fpltwgt as fpltwgt,fpltcbm as fpltcbm                    
      , epltwgt as epltwgt , epltcbm as epltcbm 
      ,InvResetPageNo      --CS01
      ,ResetPageNoFlag     --CS01 
      ,RecNo =  ROW_NUMBER() OVER(PARTITION BY MBOLKey ORDER BY MBOLKey,
                                 CASE WHEN OrderKey_Inv = '' THEN InvResetPageNo ELSE OrderKey_Inv END,
                               ShipTO_Company,ShipTO_Address1,ShipTO_Address2,ShipTO_Address3)             
      FROM #TEMP_DelNote54SG    
      WHERE InvResetPageNo LIKE @c_SHPFlag + '%'                           --CS01
      --ORDER BY mbolkey,ExternOrdKey, Rowid, sku, CTNCOUNT DESC     
      --ORDER BY Rowid     
      ORDER BY CASE WHEN @c_ShipType = 'L' THEN Rowid END                                           
              , CASE WHEN OrderKey_Inv = '' THEN InvResetPageNo ELSE OrderKey_Inv END , CASE WHEN @c_ShipType = '' THEN Rowid END     --CS01                  
              ,ShipTO_Company,ShipTO_Address1,ShipTO_Address2,ShipTO_Address3    
              --,CASE WHEN @c_ShipMode = 'L' THEN OrderKey_Inv END    
    END
    ELSE IF  @c_ShipType= '' AND @c_CCountry IN ('MY') AND @c_SHPFlag IN ('D','E','N')  
    BEGIN
        SELECT    
       Rowid    
      , MBOLKey    
      , pmtterm    
      , ExtPOKey    
      , OHUdf05    
      , MBOLKeyBarcode    
      , ExternOrdKey    
      , IDS_Company    
      , IDS_Address1    
      , IDS_Address2    
      , IDS_Address3    
      , IDS_Address4    
      , IDS_Phone1    
      , IDS_City    
      , BILLTO_Company    
      , BILLTO_Address1    
      , BILLTO_Address2    
      , BILLTO_Address3    
      , BILLTO_Address4    
      , BILLTO_City    
      , ShipTO_Company    
      , ShipTO_Address1    
      , ShipTO_Address2    
      , ShipTO_Address3    
      , ShipTO_Address4    
      , ShipTO_City    
      , ShipTO_Phone1    
      , ShipTO_Contact1    
      , ShipTO_Country    
      , From_Country    
      , StorerKey    
      , SKU    
      , Descr    
      , QtyShipped    
      , UnitPrice    
      , ShipMode    
      , SONo    
      , PCaseCnt    
      , Pqty    
      , PGrossWgt    
      , PCubeUom1    
      , PalletKey    
      , ODUDEF05    
      , CTNCOUNT    
      , PieceQty    
      , ROUND(TTLWGT, 2) AS TTLWGT    
      , ROUND(CBM, 2) AS CBM    
      , PCubeUom3    
      , PNetWgt             
      , TTLPLT                        
      , ORDGRP                       
      , EPWGT,EPCBM    
      , CLKUPUDF01    
      , Lott11       
      , OrderKey_Inv                   
      , ShipType = @c_ShipType       
      , InvoiceNo = OrderKey_Inv --CASE WHEN OrderKey_Inv = '' THEN MBOLKey ELSE 'A' + RTRIM(OrderKey_Inv) END     
      , CLKUDF01 = ISNULL(@c_CLKUDF01,'')     
      , CLKUDF02 = ISNULL(@c_CLKUDF02,'')     
      ,pltwgt as pltwgt,pltcbm as pltcbm                          
      ,fpltwgt as fpltwgt,fpltcbm as fpltcbm                    
      , epltwgt as epltwgt , epltcbm as epltcbm 
      ,InvResetPageNo      --CS01
      ,ResetPageNoFlag     --CS01   
      ,RecNo =  ROW_NUMBER() OVER(PARTITION BY MBOLKey ORDER BY MBOLKey,
                                 CASE WHEN OrderKey_Inv = '' THEN InvResetPageNo ELSE OrderKey_Inv END,
                               ShipTO_Company,ShipTO_Address1,ShipTO_Address2,ShipTO_Address3)               
      FROM #TEMP_DelNote54SG   
      WHERE LEFT(InvResetPageNo,1) = @c_SHPFlag                          --CS01 
      --ORDER BY mbolkey,ExternOrdKey, Rowid, sku, CTNCOUNT DESC     
      --ORDER BY Rowid     
      ORDER BY MBOLKey                                          
              , CASE WHEN OrderKey_Inv = '' THEN InvResetPageNo ELSE OrderKey_Inv END     --CS01                  
              ,ShipTO_Company,ShipTO_Address1,ShipTO_Address2,ShipTO_Address3    
              --,CASE WHEN @c_ShipMode = 'L' THEN OrderKey_Inv END          
    END
    ELSE
    BEGIN
      SELECT    
       Rowid    
      , MBOLKey    
      , pmtterm    
      , ExtPOKey    
      , OHUdf05    
      , MBOLKeyBarcode    
      , ExternOrdKey    
      , IDS_Company    
      , IDS_Address1    
      , IDS_Address2    
      , IDS_Address3    
      , IDS_Address4    
      , IDS_Phone1    
      , IDS_City    
      , BILLTO_Company    
      , BILLTO_Address1    
      , BILLTO_Address2    
      , BILLTO_Address3    
      , BILLTO_Address4    
      , BILLTO_City    
      , ShipTO_Company    
      , ShipTO_Address1    
      , ShipTO_Address2    
      , ShipTO_Address3    
      , ShipTO_Address4    
      , ShipTO_City    
      , ShipTO_Phone1    
      , ShipTO_Contact1    
      , ShipTO_Country    
      , From_Country    
      , StorerKey    
      , SKU    
      , Descr    
      , QtyShipped    
      , UnitPrice    
      , ShipMode    
      , SONo    
      , PCaseCnt    
      , Pqty    
      , PGrossWgt    
      , PCubeUom1    
      , PalletKey    
      , ODUDEF05    
      , CTNCOUNT    
      , PieceQty    
      , ROUND(TTLWGT, 2) AS TTLWGT    
      , ROUND(CBM, 2) AS CBM    
      , PCubeUom3    
      , PNetWgt             
      , TTLPLT                        
      , ORDGRP                       
      , EPWGT,EPCBM    
      , CLKUPUDF01    
      , Lott11       
      , OrderKey_Inv                   
      , ShipType = @c_ShipType       
      , InvoiceNo = OrderKey_Inv --CASE WHEN OrderKey_Inv = '' THEN MBOLKey ELSE 'A' + RTRIM(OrderKey_Inv) END     
      , CLKUDF01 = ISNULL(@c_CLKUDF01,'')     
      , CLKUDF02 = ISNULL(@c_CLKUDF02,'')     
      ,pltwgt as pltwgt,pltcbm as pltcbm                          
      ,fpltwgt as fpltwgt,fpltcbm as fpltcbm                    
      , epltwgt as epltwgt , epltcbm as epltcbm 
      ,InvResetPageNo      --CS01
      ,ResetPageNoFlag     --CS01    
      ,RecNo = Rowid           
      FROM #TEMP_DelNote54SG    
      --ORDER BY mbolkey,ExternOrdKey, Rowid, sku, CTNCOUNT DESC     
      --ORDER BY Rowid     
      ORDER BY CASE WHEN @c_ShipType = 'L' THEN Rowid END                                           
              , CASE WHEN OrderKey_Inv = '' THEN InvResetPageNo ELSE OrderKey_Inv END , CASE WHEN @c_ShipType = '' THEN Rowid END     --CS01                  
              ,ShipTO_Company,ShipTO_Address1,ShipTO_Address2,ShipTO_Address3    
              --,CASE WHEN @c_ShipMode = 'L' THEN OrderKey_Inv END    
  END  


QUIT:

   IF OBJECT_ID('tempdb..#TEMP_DelNote54SG','u') IS NOT NULL        
   BEGIN        
      DROP TABLE #TEMP_DelNote54SG;        
   END 

   IF OBJECT_ID('tempdb..#TEMP_CTHTYPEDelNote54','u') IS NOT NULL        
   BEGIN        
      DROP TABLE #TEMP_CTHTYPEDelNote54;        
   END 

   IF OBJECT_ID('tempdb..#TEMP_madein54','u') IS NOT NULL        
   BEGIN        
      DROP TABLE #TEMP_madein54;        
   END 

  
   IF OBJECT_ID('tempdb..#TMP_PLTDET2','u') IS NOT NULL        
   BEGIN        
      DROP TABLE #TMP_PLTDET2;        
   END 


   IF OBJECT_ID('tempdb..#TMP_PLTDET3','u') IS NOT NULL        
   BEGIN        
      DROP TABLE #TMP_PLTDET3;        
   END 

   IF OBJECT_ID('tempdb..#TMP_PLTDETLOGI','u') IS NOT NULL        
   BEGIN        
      DROP TABLE #TMP_PLTDETLOGI;        
   END 

   IF OBJECT_ID('tempdb..#TEMP_Orderkey','u') IS NOT NULL        
   BEGIN        
      DROP TABLE #TEMP_Orderkey;        
   END        
 
   IF OBJECT_ID('tempdb..#TMP_SHandling','u') IS NOT NULL        
   BEGIN        
      DROP TABLE #TMP_SHandling;        
   END   


IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_Success = 0  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_Starttcnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_Starttcnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_CommecialInvoice_03_sg'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_Success = 1  
      WHILE @@TRANCOUNT > @n_Starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END
               
   --CS01 E
        
  --select * from #TEMP_DelNote54SG    
    
    
END    

GO