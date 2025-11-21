SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
        
/************************************************************************/      
/* Stored Procedure: isp_Packing_List_103_SG                            */      
/* Creation Date: 03-aug-2021                                           */      
/* Copyright: IDS                                                       */      
/* Written by: mingle                                                   */      
/*                                                                      */      
/* Purpose:WMS-17356 CN&SG-Logitech-Packlist LOGIVMI order CR           */      
/*                                                                      */      
/*                                                                      */      
/* Called By: report dw = r_dw_Packing_List_103_SG_1 & 2                */      
/*                                                                      */      
/* PVCS Version: 1.2                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author    Ver.  Purposes                                */      
/* 13-JAN-2022  CSCHONG   1.0 Devops Scripts Combine                    */
/* 13-JAN-2022  CSCHONG   1.1 WMS-17744 Change print logic based on     */  
/*                              Orders.SpecialHandling (CS01)           */        
/* 10-May-2022  WLChooi   1.2 WMS-19628 Extend Userdefine02 column to   */
/*                            40 (WL01)                                 */
/* 17-Oct-2022  Calvin    1.3 JSM-102897 Fix MadeIn looping (CLVN01)    */
/************************************************************************/      
      
CREATE   PROC [dbo].[isp_Packing_List_103_SG] (      
   @c_MBOLKey  NVARCHAR(21)       
  ,@c_type     NVARCHAR(10)   = 'H1'   
  ,@c_ShipType NVARCHAR(10)   = ''      
  ,@c_SHPFlag  NVARCHAR(10)   = ''     --CS01
)       
AS       
BEGIN      
   SET NOCOUNT ON      
  -- SET ANSI_WARNINGS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET ANSI_DEFAULTS OFF      
         
   DECLARE @n_rowid         INT,      
           @n_rowcnt        INT,      
           @c_Getmbolkey    NVARCHAR(20),      
           @c_getExtOrdkey  NVARCHAR(20),      
           @c_sku           NVARCHAR(20),      
           @c_prev_sku NVARCHAR(20),      
           @n_ctnSKU        INT,      
           @c_pickslipno    NVARCHAR(20),      
           @n_CartonNo     INT,      
           @c_multisku      NVARCHAR(1),      
           @n_CtnCount      INT      
      
DECLARE @c_OrderKey            NVARCHAR(10)      
       ,@c_pmtterm             NVARCHAR(10)      
       ,@c_ExtPOKey            NVARCHAR(20)      
       ,@c_OHUdf05             NVARCHAR(20)      
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
       ,@c_ODUDEF05            NVARCHAR(50)         
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
       ,@c_shiptitle           NVARCHAR(30)                        
       ,@c_GetPalletKey        NVARCHAR(30)                         
       ,@n_TTLPLT              INT                                     
       ,@c_PreOrderKey         NVARCHAR(10)                            
       ,@c_ChkPalletKey        NVARCHAR(30)                           
       ,@c_facility            NVARCHAR(5)                                  
       ,@c_Con_Company         NVARCHAR(45)                         
       ,@c_Con_Address1        NVARCHAR(45)                          
       ,@c_Con_Address2        NVARCHAR(45)                          
       ,@c_Con_Address3        NVARCHAR(45)                           
       ,@c_Con_Address4        NVARCHAR(45)                         
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
       ,@c_lott11              NVARCHAR(50)                        
       ,@c_company             NVARCHAR(45)                       
       ,@c_UPDATECCOM          NVARCHAR(1)                        
       ,@c_dest                NVARCHAR(100)                       
       ,@c_PLTNo               NVARCHAR(80)                            
       ,@n_pltwgt              FLOAT                              
       ,@n_pltcbm              FLOAT                                  
       ,@n_Cntvrec             INT                                  
    --   ,@n_fpltwgt             INT                              
       ,@n_fpltwgt             FLOAT                              
       ,@n_fpltcbm             FLOAT                                
    -- ,@C_getCLKUPUDF01   NVARCHAR(15)    
       ,@n_epltwgt             FLOAT   =0                          
       ,@n_epltcbm             FLOAT   =0                       
       ,@c_getstorerkey        NVARCHAR(20)                    
       ,@c_OrderKey_Inv        NVARCHAR(50)                    
       ,@c_ordudf05        NVARCHAR(20)
                               
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
                     
           
   CREATE TABLE #TEMP_PackList103      
         (  Rowid            INT IDENTITY(1,1),      
            MBOLKey          NVARCHAR(20) NULL,      
            pmtterm          NVARCHAR(10) NULL,      
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
            QtyShipped       INT NULL,      
            UnitPrice        DECIMAL(10,2) NULL,      
            ShipMode         NVARCHAR(18) NULL,      
            SONo             NVARCHAR(30) NULL,      
            PCaseCnt         INT,      
            Pqty             INT,      
            PGrossWgt        FLOAT,      
            PCubeUom1        FLOAT,      
            PalletKey        NVARCHAR(30) NULL,       
            ODUDEF05         NVARCHAR(50) NULL,       
            CTNCOUNT         INT ,      
            PieceQty         INT,      
            TTLWGT           FLOAT,      
            CBM              FLOAT,      
            PCubeUom3        FLOAT,      
            PNetWgt          FLOAT,      
            ShipTitle        NVARCHAR(30) NULL ,                                
            TTLPLT           INT ,                                             
            CON_Company      NVARCHAR(45) NULL,                                
            CON_Address1     NVARCHAR(45) NULL,                                  
            CON_Address2     NVARCHAR(45) NULL,                                
            CON_Address3     NVARCHAR(45) NULL,                                  
            CON_Address4     NVARCHAR(45) NULL,                                 
            ORDGRP           NVARCHAR(20) NULL,                                  
            EPWGT            FLOAT,             
            EPCBM            FLOAT,      
            CLKUPUDF01       NVARCHAR(5)   NULL,                                
            Orderkey         NVARCHAR(20)  NULL,                                     
            lott11           NVARCHAR(250) NULL,                                  
            Dest             NVARCHAR(250) NULL,                                                                                                                                       
            PltNo            NVARCHAR(250) NULL,                                
            pltwgt           FLOAT,                                              
            pltcbm           FLOAT,                                             
            Fpltwgt          FLOAT,                                             
            Fpltcbm          FLOAT                                          
           ,epltwgt          FLOAT                                            
           ,epltcbm          FLOAT                                        
           ,InvoiceNo        NVARCHAR(50) NULL                                
           ,ordudf05         NVARCHAR(20) NULL 
           ,InvResetPageNo   NVARCHAR(100) NULL       --CS01  
           ,ResetPageNoFlag  NVARCHAR(10)  NULL       --CS01     
         )      
               
               
        CREATE TABLE #TEMP_CTNTYPE103 (      
         CartonType NVARCHAR(20) NULL,      
         SKU        NVARCHAR(20) NULL,      
         QTY        INT,      
         TotalCtn   INT,      
         TotalQty   INT,      
         CartonNo   INT,      
         Palletkey  NVARCHAR(20) NULL,      
         CLKUPUDF01 NVARCHAR(15) NULL      
        )      
                   
         CREATE TABLE #TEMP_madein103 (      
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
  
      IF @c_CCountry IN ('ID','TH','VN')  
      BEGIN  
         --Maximum print 2 reports, as SHP E & N will be combined, only SHP D will be splitted  
         IF @c_SHPFlag = 'N' AND @c_MinSH <> 'N' AND EXISTS (SELECT 1 FROM ORDERS OH (NOLOCK)  
                                                              WHERE OH.MBOLKey = @c_MBOLKey  
                                                              AND OH.C_Country IN ('ID','TH','VN','MY')  
                                                              AND OH.SpecialHandling = @c_SHPFlag)   
         BEGIN  
            SET @n_Continue = 3  
            SET @c_Errmsg = CONVERT(CHAR(250),@n_Err)  
            SET @n_Err = 69500  
            SET @c_Errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': No Report will be printed. Special Handling = ''N'' is already printed on previous RCM (isp_Packing_List_103_SG)'   
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
                       + UPPER(@c_SHPFlag) + ''' is not found (isp_Packing_List_103_SG)'   
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
  
         UPDATE #TMP_SHandling  
         SET CombineSHandling = CASE WHEN CombineSHandling IN ('D','E','N') THEN OriginalSHandling ELSE @c_CombineStr END
           , SHandlingFlag = 'Y'  
         WHERE SHandlingFlag = 'N'  
         AND Country IN ('ID','TH','VN')  
         AND CombineSHandling IN ('DN','D','E','N','EN')  
         --For ORDERS.C_Country IN ('MY') - END  
      END    
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
              
        SET @c_multisku = 'N'      
        SET @c_PreOrderKey = ''                    
        SET @n_EPWGT_Value = 0.00                 
        SET @n_EPCBM_value = 0.00      
        SET @n_lineNo = 1                         
        SET @C_CLKUPUDF01 =''      
        SET @c_madein = ''      
        SET @c_delimiter =','                      
        SET @c_lott11 = ''                       
        SET @c_company = ''                     
        SET @c_UPDATECCOM = 'N'               
        SET @c_dest       = ''                   
        SET @c_PLTNo      = ''                      
    
      SELECT TOP 1  @c_dest = C.UDF01    
                   ,@c_PLTNo = C.UDF02    
      FROM MBOL WITH (NOLOCK)      
      JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)      
      JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)      
      LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME = 'LOGTHSHIP'     
                                            AND C.storerkey = ORDERS.Storerkey    
      WHERE MBOL.Mbolkey = @c_mbolkey    
    
      IF ISNULL(@c_dest,'') = ''    
      BEGIN    
        SET @c_dest = 'Bangkok Thailand'    
      END    
    
      IF ISNULL(@c_PLTNo,'') = ''    
      BEGIN    
        SET @c_PLTNo = 'PALLET XX/XX'    
      END    
          
          
        DECLARE CS_ORDERS_INFO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
        SELECT  DISTINCT ORDERS.OrderKey,      
                MBOL.Mbolkey AS MBOLKEY,      
                ORDERS.PmtTerm,      
                ORDERS.ExternPOKey,      
                ORDERS.Userdefine05,      
                ORDERS.ExternOrderKey,      
                --S.B_Company AS IDS_Company,        
                --CASE WHEN  ORDERS.facility='YPCN1' THEN ISNULL(S.company,'') ELSE ISNULL(S.B_Company,'') END,      
                --CASE WHEN  ORDERS.facility='YPCN1' THEN ISNULL(S.Address1,'') ELSE ISNULL(S.B_Address1,'') END AS IDS_Address1,        
                --CASE WHEN  ORDERS.facility='YPCN1' THEN ISNULL(S.Address2,'') ELSE ISNULL(S.B_Address2,'') END AS IDS_Address2,       
                --CASE WHEN  ORDERS.facility='YPCN1' THEN ISNULL(S.Address3,'') ELSE ISNULL(S.B_Address3,'') END AS IDS_Address3,        
                --CASE WHEN  ORDERS.facility='YPCN1' THEN '' ELSE ISNULL(S.B_Address4,'') END AS IDS_Address4,       
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
                ISNULL(ORDERS.B_Zip,'') + SPACE(2) +  ISNULL(ORDERS.B_Country,'')) AS BILLTO_City,            
                CASE WHEN ORDERS.Ordergroup <> 'S01' THEN      
                CASE WHEN ORDERS.facility IN ('WGQAP','BULIM') AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%') THEN     
                CASE WHEN ORDERS.c_country = 'HK'  THEN ISNULL(SHK.company,'')      
                WHEN ORDERS.c_country = 'TW'  THEN ISNULL(STW.company,'')      
                ELSE ISNULL(ORDERS.C_Company,'') END      
                ELSE ISNULL(ORDERS.C_Company,'') END       
                ELSE             
                CASE WHEN ORDERS.type='WR' THEN ORDERS.c_company ELSE '' END      
                END AS ShipTO_Company,            
                CASE WHEN ORDERS.Ordergroup <> 'S01' THEN        
                CASE WHEN ORDERS.facility IN ('WGQAP','BULIM') AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%') THEN      
                CASE WHEN ORDERS.c_country = 'HK'  THEN ISNULL(SHK.Address1,'')      
                WHEN ORDERS.c_country = 'TW'  THEN ISNULL(STW.Address1,'')      
                ELSE ISNULL(ORDERS.C_Address1,'') END      
                ELSE ISNULL(ORDERS.C_Address1,'') END       
                ELSE      
                ISNULL(ORDERS.C_Address1,'') END AS ShipTO_Address1,            
                CASE WHEN ORDERS.Ordergroup <> 'S01' THEN        
                CASE WHEN ORDERS.facility IN ('WGQAP','BULIM') AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%') THEN        
                CASE WHEN ORDERS.c_country = 'HK'  THEN ISNULL(SHK.Address2,'')      
                WHEN ORDERS.c_country = 'TW'  THEN ISNULL(STW.Address2,'')      
                ELSE ISNULL(ORDERS.C_Address2,'') END      
                ELSE ISNULL(ORDERS.C_Address2,'') END       
                ELSE      
                ISNULL(ORDERS.C_Address2,'') END  AS ShipTO_Address2,         
                CASE WHEN ORDERS.Ordergroup <> 'S01' THEN         
                CASE WHEN ORDERS.facility IN ('WGQAP','BULIM')  AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%') THEN     
                CASE WHEN ORDERS.c_country = 'HK'  THEN ISNULL(SHK.Address3,'')      
                      WHEN ORDERS.c_country = 'TW'  THEN ISNULL(STW.Address3,'')      
                ELSE ISNULL(ORDERS.C_Address3,'') END      
                ELSE ISNULL(ORDERS.C_Address3,'') END       
                ELSE      
                ISNULL(ORDERS.C_Address3,'') END AS ShipTO_Address3,              
                CASE WHEN ORDERS.Ordergroup <> 'S01' THEN        
                CASE WHEN ORDERS.facility IN ('WGQAP','BULIM')AND ORDERS.c_country IN ('HK','TW')        
                     AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%') THEN ''       
                 ELSE ISNULL(ORDERS.C_Address4,'') END       
                 ELSE      
                 ISNULL(ORDERS.C_Address4,'') END AS ShipTO_Address4,                   
                 LTRIM(ISNULL(ORDERS.C_City,'') + SPACE(2) + ISNULL(ORDERS.C_State,'') + SPACE(2) +      
                 ISNULL(ORDERS.C_Zip,'') + SPACE(2) +  ISNULL(ORDERS.C_Country,'')) AS ShipTO_City,      
                 ISNULL(ORDERS.C_phone1,'') AS ShipTo_phone1,ISNULL( ORDERS.C_contact1,'') AS ShipTo_contact1,       
                 ISNULL(ORDERS.C_country,'') AS ShipTo_country,  ISNULL(S.country,'') AS From_country,       
                 ORDERS.StorerKey,      
                 ORDERS.Userdefine03 AS ShipMode,      
                 ORDERS.Userdefine01 AS SONo      
                 ,''--ISNULL(PTD.Palletkey,'N/A') AS palletkey                                  
                 ,CASE WHEN ORDERS.Ordergroup <> 'S01' THEN         
                        --CASE WHEN ORDERS.facility='WGQAP' AND ORDERS.c_country IN ('HK','TW')         
                        --AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%' )    
                  CASE WHEN ORDERS.facility IN ('WGQAP','BULIM') AND ORDERS.c_country IN ('HK','TW')       
                           AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%')          
                  THEN 'Consignee:'       
                        ELSE 'Ship To:' END       
                  ELSE      
                  'Ship To/Notify To:' END AS ShipTitle ,                           
                  ORDERS.facility,                                                        
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
                ,ORDERS.OrderGroup AS OrdGrp          
                --,OrderKey_Inv = CASE WHEN @c_ShipType = 'L' THEN ORDERS.Orderkey 
                --                     WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'O' THEN  MBOL.Mbolkey 
                --                     WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'D' THEN  'D' + MBOL.Mbolkey  
                --                     WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'E' THEN  'E' + MBOL.Mbolkey
                --                     WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'N' THEN  'N' + MBOL.Mbolkey 
                --                     ELSE '' END  
                ,OrderKey_Inv = CASE WHEN @c_ShipType = 'L' THEN 'A' + ORDERS.Orderkey     
                                    WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'O' AND TSH.SHandlingFlag = '' THEN  MBOL.Mbolkey             --CS01   
                                    WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'D' AND TSH.SHandlingFlag = '' THEN  'D' + MBOL.Mbolkey       --CS01
                                    WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'E' AND TSH.SHandlingFlag = '' THEN  'E' + MBOL.Mbolkey       --CS01
                                    WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'N' AND TSH.SHandlingFlag = '' THEN  'N' + MBOL.Mbolkey        --CS01 
                                    WHEN @c_ShipType = '' AND ORDERS.SpecialHandling IN ('D','E','N') AND TSH.SHandlingFlag = 'N' THEN TSH.CombineSHandling + MBOL.Mbolkey  END  --CS01    
               ,InvResetPageNo  =  CASE WHEN @c_ShipType = '' AND TSH.SHandlingFlag = 'Y' THEN TSH.CombineSHandling + MBOL.Mbolkey END             --CS01    
               ,ResetPageNoFlag =  CASE WHEN ORDERS.C_Country IN ('ID','TH','VN','MY') AND TSH.SHandlingFlag = 'Y' THEN 'Y' ELSE 'N' END            --CS01
              FROM MBOL WITH (NOLOCK)      
              INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)      
              INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)      
              INNER JOIN STORER S WITH (NOLOCK) ON (S.Storerkey = ORDERS.Storerkey)           
              LEFT JOIN STORER STW WITH (NOLOCK) ON (STW.Storerkey = 'LOGITWDDP')          
              LEFT JOIN STORER SHK WITH (NOLOCK) ON (SHK.Storerkey = 'LOGIHKDDP')              
              LEFT JOIN STORER MWRHK WITH (NOLOCK) ON (MWRHK.Storerkey = 'LOGISMWRHK')          
              LEFT JOIN STORER MWRTW WITH (NOLOCK) ON (MWRTW.Storerkey = 'LOGISMWRTW')       
              LEFT JOIN STORER MWRAU WITH (NOLOCK) ON (MWRAU.Storerkey = 'LOGISMWRAU')          
              LEFT JOIN STORER MWRNZ WITH (NOLOCK) ON (MWRNZ.Storerkey = 'LOGISMWRNZ')          
              LEFT JOIN storersodefault SOD WITH (NOLOCK) ON SOD.StorerKey = ORDERS.ConsigneeKey    
              LEFT JOIN STORER SD WITH (NOLOCK) ON (SD.Storerkey = SOD.Door)      
              LEFT JOIN #TMP_SHandling TSH ON TSH.Orderkey = ORDERS.OrderKey   --CS01          
              WHERE MBOL.Mbolkey = @c_mbolkey      
              
       OPEN CS_ORDERS_INFO      
              
      FETCH FROM CS_ORDERS_INFO INTO @c_OrderKey, @c_MBOLKey, @c_pmtterm, @c_ExtPOKey,      
                                 @c_OHUdf05, @c_ExternOrdKey, @c_IDS_Company,      
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
                                 @c_ShipMode, @c_SONo, @c_PalletKey,@c_shiptitle,@c_facility,          
                                 @c_Con_Company, @c_Con_Address1, @c_Con_Address2,                       
                                 @c_Con_Address3, @c_Con_Address4,@c_OrdGrp,@c_Orderkey_inv ,@c_InvResetPageNo ,@c_ResetPageNoFlag           --CS01             
              
        WHILE @@FETCH_STATUS = 0      
        BEGIN      
           -- Full Carton      
           SET @n_PrevCtnQty = 0      
                      
         IF @c_facility IN ('BULIM','WGQAP','WGQBL')      
         BEGIN      
           INSERT INTO #TEMP_CTNTYPE103 (CartonType, SKU, QTY, TotalCtn, TotalQty, CartonNo,Palletkey,CLKUPUDF01)                  
            SELECT 'SINGLE' , PD.SKU, SUM(PD.Qty)/COUNT(DISTINCT PD.CartonNo) , COUNT(DISTINCT PD.CartonNo) , SUM(PD.Qty) ,0       
              ,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END      
             -- ,CASE WHEN C.UDF01='P' THEN COUNT(DISTINCT CD.palletkey) ELSE 0 END     
             ,ISNULL(C.UDF01,'')                                                     
            FROM PACKHEADER PH WITH (NOLOCK)       
            JOIN PackDetail AS PD WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo           
            JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=ph.OrderKey        
            JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.caseid = PD.LabelNo AND PLTD.Sku=pd.sku --AND PLTD.StorerKey=ORD.StorerKey        
            JOIN Containerdetail CD WITH (NOLOCK) ON CD.PalletKey=PLTD.PalletKey      
            JOIN Container CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey=ord.MBOLKey         
            LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CONTAINERT' AND C.UDF01='P' AND C.code=CON.ContainerType      
            WHERE PH.orderkey = @c_OrderKey       
            AND PLTD.STORERKEY = @c_StorerKey      
            AND EXISTS(SELECT 1 FROM PackDetail AS pd2 WITH(NOLOCK)       
                        WHERE PD2.PickSlipNo = PH.PickSlipNo       
                        AND   PD2.CartonNo = PD.CartonNo       
                        GROUP BY pd2.CartonNo      
                        HAVING COUNT(DISTINCT PD2.SKU) = 1       
                        )        
            GROUP BY PD.SKU,PD.qty,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END        
                     ,ISNULL(C.UDF01,'')        
            UNION ALL      
            --INSERT INTO #TEMP_CTNTYPE103 (CartonType, SKU, QTY, TotalCtn, TotalQty, CartonNo,Palletkey)       
            SELECT 'MULTI' , PD.SKU, SUM(PD.Qty)/COUNT(DISTINCT PD.CartonNo) , 0, SUM(PD.Qty) ,PD.CartonNo       
            ,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END       
            --,CASE WHEN C.UDF01='P' THEN COUNT(DISTINCT CD.palletkey) ELSE 0 END                            
            ,ISNULL(C.UDF01,'')      
            FROM PACKHEADER PH WITH (NOLOCK)       
            JOIN PackDetail AS PD WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo              
            JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=ph.OrderKey               
            JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.caseid = PD.LabelNo AND PLTD.Sku=pd.sku--AND PLTD.StorerKey=ORD.StorerKey         
            JOIN Containerdetail CD WITH (NOLOCK) ON CD.PalletKey=PLTD.PalletKey       
            JOIN Container CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey=ord.MBOLKey               
            LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CONTAINERT' AND C.UDF01='P' AND C.code=CON.ContainerType      
            WHERE PH.orderkey = @c_OrderKey       
            AND PLTD.STORERKEY = @c_StorerKey      
            AND NOT EXISTS(SELECT 1 FROM PackDetail AS pd2 WITH(NOLOCK)       
                     WHERE PD2.PickSlipNo = PH.PickSlipNo       
                     AND   PD2.CartonNo = PD.CartonNo      
                     GROUP BY pd2.CartonNo      
                     HAVING COUNT(DISTINCT PD2.SKU) = 1       
                     )        
           GROUP BY PD.CartonNo, PD.SKU,PD.Qty ,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A'  END        
                     ,ISNULL(C.UDF01,'')           
         END      
         ELSE IF @c_facility = 'YPCN1'      
         BEGIN      
          INSERT INTO #TEMP_CTNTYPE103 (CartonType, SKU, QTY, TotalCtn, TotalQty, CartonNo,Palletkey,CLKUPUDF01)                  
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
            GROUP BY PD.SKU,PD.Qty --,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END       
            UNION ALL      
            --INSERT INTO #TEMP_CTNTYPE103 (CartonType, SKU, QTY, TotalCtn, TotalQty, CartonNo,Palletkey)       
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
            GROUP BY PD.CartonNo, PD.SKU,PD.Qty --,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A'  END        
         END                 
                 
           --SELECT * FROM #TEMP_CTNTYPE103      
                 
           DECLARE CS_SinglePack CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                 
           SELECT CartonType, SKU, QTY, CASE WHEN cartontype='SINGLE' THEN TotalCtn ELSE Cartonno END,      
           TotalQty, palletkey,CLKUPUDF01      
           FROM #TEMP_CTNTYPE103      
           ORDER BY CartonType desc,CartonNo      
                  
           OPEN CS_SinglePack      
           FETCH NEXT FROM CS_SinglePack INTO @c_CartonType, @c_SKU, @n_CtnQty, @n_CtnCount, @n_PQty,@c_GetPalletKey--,@n_TTLPLT        
                                              ,@C_CLKUPUDF01      
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
                      
              SET @c_ODUDEF05 = ''     --INC0582740    
               
              SELECT TOP 1      
                      @c_UnitPrice = CONVERT(decimal(10,2),o.UnitPrice)      
                     ,@c_ODUDEF05  = CASE WHEN OH.C_COUNTRY IN ('IN','KR') THEN ISNULL(SKUINFO.EXTENDEDFIELD05,'')        
                                          WHEN ISNULL(CL.Short,'N') = 'Y'    
                                          THEN CASE WHEN LEN(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,'')))) > 20    
                                                    THEN SUBSTRING(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))),1,20) + ' ' + SUBSTRING(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))),21,LEN(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,'')))))    
                                                    ELSE ISNULL(SKUINFO.EXTENDEDFIELD05,'') END     
                                          ELSE '' END
                     ,@c_ordudf05 = ISNULL(O.USERDEFINE05,'')    
              FROM ORDERDETAIL AS O WITH(NOLOCK)      
              INNER JOIN ORDERS AS OH WITH (NOLOCK) ON (O.OrderKey = OH.OrderKey)     
              INNER JOIN SKU WITH (NOLOCK) ON (O.StorerKey = SKU.StorerKey AND O.Sku = SKU.Sku)    
              INNER JOIN SKUINFO WITH (NOLOCK) ON (SKUINFO.StorerKey = SKU.StorerKey AND O.Sku = SKUINFO.Sku AND SKU.SKU = SKUINFO.SKU)    
              LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.Listname = 'REPORTCFG' AND CL.Code = 'ShowModelNumber' AND CL.Storerkey = OH.Storerkey    
                                                      AND CL.code2 = OH.Facility)     
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
                JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=ph.OrderKey                 
                JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.caseid = PD.LabelNo --AND PLTD.StorerKey=ORD.StorerKey      
                JOIN Containerdetail CD WITH (NOLOCK) ON CD.PalletKey=PLTD.PalletKey       
                JOIN Container CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey=ord.MBOLKey               
                JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CONTAINERT' AND C.UDF01='P' AND C.code=CON.ContainerType      
                WHERE PH.orderkey = @c_OrderKey       
                AND PLTD.STORERKEY = @c_StorerKey      
                GROUP BY C.UDF01      
             
       --SELECT @c_ChkPalletKey = CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(CD.ContainerLineNumber,'0',''),'') ELSE 'N/A' END       
       --FROM PACKHEADER PH WITH (NOLOCK)       
       --          JOIN PackDetail AS PD WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo        
       --JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.caseid = PD.LabelNo       
       --JOIN Containerdetail CD WITH (NOLOCK) ON CD.PalletKey=PLTD.PalletKey      
       --JOIN Container CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey      
       --LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CONTAINERT' AND C.UDF01='P' AND C.code=CON.ContainerType      
       --WHERE PH.orderkey = @c_OrderKey       
       --GROUP BY C.UDF01,ISNULL(REPLACE(CD.ContainerLineNumber,'0',''),'')       
             
             
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
        JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=ph.OrderKey               
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
       FROM  #TMP_PLTDETLOGI--V_PalletDetail_LOGITECH P WITH (NOLOCK)      
       WHERE mbolkey = @c_mbolkey    
          
      IF ISNULL(@n_Cntvrec,0) = 0    
      BEGIN    
         SET @n_Cntvrec = 1    
      END    
    
       SELECT @n_pltcbm = sum(P.cbm/@n_Cntvrec)--sum((P.Length*P.Width*P.Height)/@n_Cntvrec)/1000000    
             ,@n_pltwgt = sum(P.PLTGrosswgt/@n_Cntvrec)    
             ,@n_fpltcbm = sum(P.cbm)--sum((P.Length*P.Width*P.Height)/@n_Cntvrec)/1000000    
             ,@n_fpltwgt = sum(P.PLTGrosswgt)    
       FROM #TMP_PLTDETLOGI P--V_PalletDetail_LOGITECH P WITH (NOLOCK)       
       WHERE P.mbolkey = @c_mbolkey    
        
                           
              INSERT INTO #TEMP_PackList103      
              (      
               -- Rowid -- this column value is auto-generated      
               MBOLKey,      
               pmtterm,      
               ExtPOKey,      
               OHUdf05,      
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
               PCaseCnt,      
               Pqty,      
               PGrossWgt,      
               PCubeUom1,      
               PalletKey,      
               ODUDEF05,      
               CTNCOUNT,      
               PieceQty,      
               TTLWGT,      
               CBM,      
               PCubeUom3,      
               PNetWgt      
               ,ShipTitle                   
               ,TTLPLT                     
               ,CON_Company                 
               ,CON_Address1               
               ,CON_Address2              
               ,CON_Address3                
               ,CON_Address4               
               ,ORDGRP                     
               ,EPWGT                      
               ,EPCBM                      
               ,CLKUPUDF01               
               ,Orderkey                   
               ,Lott11                  
               ,Dest                    
               ,PltNo                      
               ,pltwgt                    
               ,pltcbm                  
               ,Fpltwgt                  
               ,Fpltcbm                   
               ,Epltwgt                   
               ,Epltcbm                  
               ,InvoiceNo            
               ,ordudf05
               ,InvResetPageNo          --CS01
               ,ResetPageNoFlag         --CS01   
              )      
              VALUES      
              (      
               @c_MBOLKey,      
               @c_pmtterm,      
               @c_ExtPOKey,      
               @c_OHUdf05 ,      
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
               @n_CtnQty,      
               @n_PQty,      
               @n_PGrossWgt,      
               @c_PCubeUom1,      
               @c_GetPalletKey,                               
               @c_ODUDEF05,      
               @n_NoOfCarton,      
               @n_PieceQty,      
               @n_TTLWGT,      
               @n_CBM,      
               @n_PCubeUom3,      
               @c_PNetWgt      
              ,@c_shiptitle                                   
              ,@n_TTLPLT                                    
              ,@c_CON_Company, @c_CON_Address1               
              ,@c_CON_Address2,@c_CON_Address3              
              ,@c_CON_Address4,@c_OrdGrp                    
              ,@n_EPWGT_Value,@n_EPCBM_Value                  
              ,@C_CLKUPUDF01,@c_orderkey,''                  
              ,@c_dest,@c_PLTNo                            
              ,ISNULL(@n_pltwgt,0),ISNULL(@n_pltcbm,0)     
              ,ISNULL(@n_fpltwgt,0),ISNULL(@n_fpltcbm,0)             
              ,ISNULL(@n_epltwgt,0), ISNULL(@n_epltcbm,0)
              ,CASE WHEN  @c_ShipType = 'L' THEN 'A' + @c_OrderKey_Inv ELSE @c_OrderKey_Inv END  
              ,@c_ordudf05
              ,@c_InvResetPageNo,@c_ResetPageNoFlag                          --CS01           
              )      
                       
           SET @c_PreOrderKey = @c_OrderKey      
           SET @n_lineNo = @n_lineNo + 1                    
                 
           DELETE FROM #TEMP_CTNTYPE103      
                        
           FETCH NEXT FROM CS_SinglePack INTO @c_CartonType, @c_SKU, @n_CtnQty, @n_CtnCount, @n_PQty,@c_GetPalletKey--,@n_TTLPLT       
                                              ,@C_CLKUPUDF01           
           END      
           CLOSE CS_SinglePack      
           DEALLOCATE CS_SinglePack      
                 
         FETCH FROM CS_ORDERS_INFO INTO @c_OrderKey, @c_MBOLKey, @c_pmtterm, @c_ExtPOKey,      
                                       @c_OHUdf05, @c_ExternOrdKey, @c_IDS_Company,      
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
                                       @c_ShipMode, @c_SONo, @c_PalletKey,@c_shiptitle,@c_facility,        
                                       @c_Con_Company, @c_Con_Address1, @c_Con_Address2,                    
                                       @c_Con_Address3, @c_Con_Address4,@c_OrdGrp,@c_Orderkey_inv ,@c_InvResetPageNo ,@c_ResetPageNoFlag           --CS01      
        END      
              
        CLOSE CS_ORDERS_INFO      
        DEALLOCATE CS_ORDERS_INFO      
                   
         DECLARE TH_ORDERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
         SELECT DISTINCT mbolkey,orderkey,sku      
         FROM #TEMP_PackList103      
         WHERE mbolkey=@c_MBOLKey      
         AND ShipTO_Country='TH'      
               
        OPEN TH_ORDERS      
              
       FETCH FROM TH_ORDERS INTO @c_Getmbolkey,@c_GetOrderKey,@c_getsku      
             
             
       WHILE @@FETCH_STATUS = 0      
       BEGIN      
           INSERT INTO #TEMP_madein103      
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
          
    --SELECT * FROM #TEMP_madein103          
    SET @n_CntRec = 0      
    SET @c_madein = ''      
          
    IF EXISTS (SELECT 1 FROM #TEMP_madein103  WHERE MBOLKey = @c_MBOLKey)      
    BEGIN      
      SET @c_UPDATECCOM = 'Y'                     
    END      
          
    SELECT @n_CntRec = COUNT(DISTINCT lot11),@c_lott11 = MIN(lot11)      
          ,@c_company=MIN(C_Company)      
    FROM  #TEMP_madein103       
    WHERE MBOLKey = @c_MBOLKey      
          
    SET @n_lineNo = 1      
    SET @n_lineNo = @n_CntRec      
          
    IF @n_CntRec = 1 --AND @n_lineNo = 1      
    BEGIN      
     SET @c_madein = @c_lott11      
    END      
    ELSE IF @n_CntRec > 1      
    BEGIN      
        DECLARE MadeIn_loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
         SELECT DISTINCT lot11      
         FROM #TEMP_madein103      
         WHERE mbolkey=@c_MBOLKey       
      
               
        OPEN MadeIn_loop      
              
       FETCH FROM MadeIn_loop INTO @c_lott11      
             
       WHILE @@FETCH_STATUS = 0      
       BEGIN      
           
	  --(CLVN01) START--	   
      --IF @n_CntRec >=2      
      --BEGIN      
      -- IF @n_lineno >= 2       
      -- BEGIN      
      --   SET @c_madein = @c_lott11 + @c_delimiter      
      -- END      
      -- ELSE      
      --  BEGIN      
      --   SET @c_madein = @c_madein + @c_lott11      
      --   END       
      --END      
      --    
      --SET @n_lineno = @n_lineno - 1      

	    IF @n_CntRec >=2        
          BEGIN        
             SET @c_madein = @c_madein + @c_lott11 + @c_delimiter    --(CLVN01)    
          END        
          ELSE        
          BEGIN        
             SET @c_madein = @c_madein + @c_lott11        
          END          
      
        SET @n_CntRec = @n_CntRec - 1
      --(CLVN01) END--
	  
      FETCH FROM MadeIn_loop INTO @c_lott11      
      END      
              
        CLOSE MadeIn_loop      
        DEALLOCATE MadeIn_loop      
    END       
          
          
    UPDATE #TEMP_PackList103      
    SET lott11 = @c_madein      
        ,ShipTO_Company = CASE WHEN  @c_UPDATECCOM = 'Y'  THEN @c_company ELSE ShipTO_Company END      
    WHERE MBOLKey = @c_MBOLKey       
          
          
    DELETE FROM #TEMP_madein103      
          
    --CS05 End      
          
   IF @c_type = 'H1' GOTO TYPE_H1         
   IF @c_type = 'S01' GOTO TYPE_S01      
   IF @c_type = 'S02' GOTO TYPE_S02      
          
      
 TYPE_H1:      
      
  /*SELECT       
   Rowid                  
  , MBOLKey                
  , pmtterm                
  , ExtPOKey               
  , OHUdf05                
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
  , shiptitle                                    
  ,TTLPLT                                     
  ,CON_Company, CON_Address1                
  ,CON_Address2,CON_Address3                 
  ,CON_Address4,ORDGRP                         
  ,EPWGT,EPCBM                               
  ,CLKUPUDF01                                 
  --,orderkey      
  ,lott11                                    
  ,Dest                                    
  ,PltNo                                   
  ,pltwgt,pltcbm,Fpltwgt,Fpltcbm           
  FROM #TEMP_PackList103      
  ORDER BY mbolkey,ExternOrdKey, Rowid, sku, CTNCOUNT DESC*/    
         
  update #temp_Packlist103 set     
  fpltwgt = case when clkupudf01 <>'P'  then ((select sum (ttlwgt) from #temp_Packlist103) + ((select Sum (ttlplt) from #temp_Packlist103)* Epwgt) )else fpltwgt end,    
  fpltcbm = case when clkupudf01 <>'P'  then ((select sum (cbm) from #temp_Packlist103)+ ((select Sum (ttlplt) from #temp_Packlist103)* Epcbm)) else fpltcbm end    
      
  update #temp_Packlist103 set     
  epltwgt = case when clkupudf01 <>'P'  then '0' else fpltwgt - (select sum (ttlwgt) from #temp_Packlist103) end,    
  epltcbm = case when clkupudf01 <>'P'  then '0' else fpltcbm - (select sum (cbm) from #temp_Packlist103)end       
    
  --select * from #temp_Packlist103    
  --ORDER BY MBOLKey,InvoiceNo

--CS01 S
    IF @c_ShipType= '' AND @c_CCountry IN ('ID','TH','VN') AND @c_SHPFlag IN ('D','E')   --SHP N not included here since it will print together with SHP E  
    BEGIN
      SELECT *,RecNo =  ROW_NUMBER() OVER(PARTITION BY MBOLKey ORDER BY MBOLKey,
                                 CASE WHEN InvoiceNo = '' THEN InvResetPageNo ELSE InvoiceNo END,
                               ShipTO_Company,ShipTO_Address1,ShipTO_Address2,ShipTO_Address3)                
      FROM #temp_Packlist103                 
      WHERE InvResetPageNo LIKE @c_SHPFlag + '%'                           --CS01    
      ORDER BY CASE WHEN @c_ShipType = 'L' THEN Rowid END                                           
              , CASE WHEN InvoiceNo = '' THEN InvResetPageNo ELSE InvoiceNo END , CASE WHEN @c_ShipType = '' THEN Rowid END     --CS01                  
              ,ShipTO_Company,ShipTO_Address1,ShipTO_Address2,ShipTO_Address3    
              --,CASE WHEN @c_ShipMode = 'L' THEN OrderKey_Inv END    
    END
    ELSE IF  @c_ShipType= '' AND @c_CCountry IN ('MY') AND @c_SHPFlag IN ('D','E','N')  
    BEGIN
       SELECT *,RecNo =  ROW_NUMBER() OVER(PARTITION BY MBOLKey ORDER BY MBOLKey,
                                 CASE WHEN InvoiceNo = '' THEN InvResetPageNo ELSE InvoiceNo END,
                               ShipTO_Company,ShipTO_Address1,ShipTO_Address2,ShipTO_Address3) 
      from #temp_Packlist103     
      WHERE LEFT(InvResetPageNo,1) = @c_SHPFlag                          --CS01 
      --ORDER BY mbolkey,ExternOrdKey, Rowid, sku, CTNCOUNT DESC     
      --ORDER BY Rowid     
      ORDER BY MBOLKey                                          
              , CASE WHEN InvoiceNo = '' THEN InvResetPageNo ELSE InvoiceNo END     --CS01                  
              ,ShipTO_Company,ShipTO_Address1,ShipTO_Address2,ShipTO_Address3    
              --,CASE WHEN @c_ShipMode = 'L' THEN OrderKey_Inv END          
    END
    ELSE
    BEGIN
      SELECT *,recno=Rowid
      from #temp_Packlist103      
      --ORDER BY mbolkey,ExternOrdKey, Rowid, sku, CTNCOUNT DESC     
      --ORDER BY Rowid     
      ORDER BY CASE WHEN @c_ShipType = 'L' THEN Rowid END                                           
              , CASE WHEN InvoiceNo = '' THEN InvResetPageNo ELSE InvoiceNo END , CASE WHEN @c_ShipType = '' THEN Rowid END     --CS01                  
              ,ShipTO_Company,ShipTO_Address1,ShipTO_Address2,ShipTO_Address3    
              --,CASE WHEN @c_ShipMode = 'L' THEN OrderKey_Inv END    
  END 
        
  GOTO QUIT      
      
       
  --restructure for select distinct Type S01 and S02      
      
   TYPE_S01:      
          
    SELECT  distinct 1 as Rowid            ,         
    MBOLKey          ,         
   '' as ExternOrdKey     ,         
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
    ORDGRP           ,
    InvoiceNo                         
  FROM #TEMP_PackList103      
  WHERE MBOLKey = @c_MBOLKey      
  AND ORDGRP = 'S01'      
  ORDER BY mbolkey,InvoiceNo,ExternOrdKey,ORDGRP     
        
   GOTO QUIT      
      
   TYPE_S02:      
          
    SELECT DISTINCT 1 as Rowid            ,         
    MBOLKey          ,         
    '' as ExternOrdKey     ,         
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
  FROM #TEMP_PackList103      
  WHERE MBOLKey = @c_MBOLKey      
  AND ORDGRP <> 'S01'      
  ORDER BY mbolkey,ExternOrdKey      
        
   GOTO QUIT      
      
QUIT:      

IF OBJECT_ID('tempdb..#TEMP_PackList103','u') IS NOT NULL        
   BEGIN        
      DROP TABLE #TEMP_PackList103;        
   END 

   IF OBJECT_ID('tempdb..#TEMP_CTNTYPE103','u') IS NOT NULL        
   BEGIN        
      DROP TABLE #TEMP_CTNTYPE103;        
   END 

   IF OBJECT_ID('tempdb..#TEMP_madein103','u') IS NOT NULL        
   BEGIN        
      DROP TABLE #TEMP_madein103;        
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
END 

GO