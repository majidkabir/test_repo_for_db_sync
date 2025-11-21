SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Stored Procedure: isp_CommecialInvoice_03_sg                         */      
/* Creation Date: 18-FEB-2021                                           */      
/* Copyright: IDS                                                       */      
/* Written by: CSCHONG                                                  */      
/*                                                                      */      
/* Purpose:WMS-16134 - SG - Logitech - Commercial Invoice [CR]          */      
/*                                                                      */      
/*                                                                      */      
/* Called By: report dw = r_dw_commercialinvoice_03_sg                  */      
/*                                                                      */      
/* PVCS Version: 3.5                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author    Ver.  Purposes                                */      
/* 11-MAY-2017  CSCHONG   1.0   WMS-1745 - Add new field (CS01)         */      
/* 11-May-2017  CSCHONG   1.0   WMS-1745 -Revise Field mapping (CS02)   */      
/* 08-JUN-2017  CSCHONG   1.1   WMS-1745 - Revise Address field (CS03)  */      
/* 15-JUN-2017  CSCHONG   1.2   Fix total amout bug (CS04)              */      
/* 24-JUL-2017  CSCHONG   1.3   WMS-2433 - Revise report layout(CS05)   */      
/* 29-NOV-2017  WLCHOOI   1.4   WMS-3442 - Revise report layout(WL01)   */      
/* 24-MAY-2018  CSCHONG   1.5   WMS-5114 - revised report logic (CS06)  */      
/* 24-MAY-2018  Wan01     1.6   WMS-5402 - [SG] Logitech - Commercial   */      
/*                              Invoice Order                           */      
/* 18-OCT-2018  WLCHOOI   1.7   WMS-6667 - Revise logic of displaying   */      
/*                              model number (WL02)                     */        
/* 18-FEB-2019  WLCHOOI   1.8   WMS-6667 - Left Join for SKUINFO (WL02) */      
/* 01-MAR-2019  TANJH     1.9   Missing MadeIn                (JHTAN01) */        
/* 26-MAR-2019  Grick     2.0   INC0606047 - Display model number in PB */      
/*                              fully (G01)                             */      
/* 15-APR-2019  WAN02     1.12  Fix temp Table blocking. Drop temp table*/      
/*                              When Quit SP                            */   
/* 05-AUG-2019  CSCHONG   2.1   WMS-9968 revised field logic (CS07)     */     
/* 19-Nov-2019  WLChooi   2.2   WMS-11134 - Modify condition to show    */  
/*                              Ship To: or Consignee and Show FOB(WL03)*/  
/* 23-APR-2020  WLChooi   2.3   WMS-13022 - ShowModelNumber by ReportCFG*/  
/*                              (WL04)                                  */               
/* 17-JUL-2020  WLChooi   2.4   WMS-14275 - Change Tax Calculation Logic*/  
/*                              (WL05)                                  */         
/* 22-JUL-2020  WLChooi   2.5   WMS-14394 - Add new condition to show   */  
/*                              remark for CN only (WL06)               */    
/* 18-FEB-2021  CSCHONG   2.6   WMS-16134 revised report group (CS08)   */   
/* 16-JUL-2021  CSCHONG   2.7   WMS-16134 fix sorting issue (CS09)      */  
/* 21-JUL-2021  CSCHONG   2.8   WMS-16134 Fix moade in issue (CS09a)    */  
/* 30-AUG-2021  CLVNKHOR  2.9   JSM-17697 Fix MadeIn Loop Bug (CLVN01)  */  
/* 06-Oct-2021  WLChooi   3.0   DevOps Combine Script                   */
/* 06-Oct-2021  WLChooi   3.1   WMS-18105 - Modify column logic (WL07)  */
/* 06-Dec-2021  WLChooi   3.2   Bug Fix for WMS-18105 (WL08)            */
/* 14-Dec-2021  WLChooi   3.3   WMS-18504 - Change print logic based on */
/*                              Orders.SpecialHandling (WL09)           */
/* 22-Apr-2022  WLChooi   3.4   Bug Fix for WMS-18504 (WL10)            */
/* 26-Aug-2022  WLChooi   3.5   WMS-20573 - ShowFOB Logic Change (WL11) */
/************************************************************************/      
      
CREATE PROC [dbo].[isp_CommecialInvoice_03_sg] (      
    @c_MBOLKey  NVARCHAR(21)        
   ,@c_type     NVARCHAR(10)   = 'H1'      
   ,@c_Orderkey NVARCHAR(10)   = ''  -- Wan01      
   ,@c_ShipType NVARCHAR(10)   = ''  -- Wan01   
   ,@c_SHPFlag  NVARCHAR(10)   = ''  -- WL09   
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
         @n_getttlamt     DECIMAL(10,2)                   --CS04      
        ,@c_Con_Company   NVARCHAR(45)                    --CS05      
        ,@c_Con_Address1  NVARCHAR(45)                    --CS05       
        ,@c_Con_Address2  NVARCHAR(45)                    --CS05       
        ,@c_Con_Address3  NVARCHAR(45)                    --CS05       
        ,@c_Con_Address4  NVARCHAR(45)                    --CS05       
        ,@c_OrdGrp        NVARCHAR(20)                    --CS05            
        --,@c_orderkey      NVARCHAR(20)                  --(Wan01)      
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
        ,@c_UPDATECCOM    NVARCHAR(1)     -- WL01      
        ,@c_getconsignee  NVARCHAR(45)    --CS06      
    
        ,@c_OrderKey_Inv  NVARCHAR(50)    --(Wan01)   --WL09   
        ,@c_NSQLCountry   NVARCHAR(10)    --WL06  

        ,@c_SpecialHandling   NVARCHAR(250) = ''   --WL09
        ,@c_SplitFlag         NVARCHAR(10)  = 'N'  --WL09
        ,@c_CombineStr        NVARCHAR(4000) = ''  --WL09
        ,@c_AllSHPFlag        NVARCHAR(250) = ''   --WL09
        ,@c_CCountry          NVARCHAR(100) = ''   --WL09
        ,@n_Continue          INT = 1         --WL09
        ,@n_Err               INT = 0         --WL09
        ,@b_Success           INT = 1         --WL09
        ,@n_Starttcnt         INT = @@TRANCOUNT   --WL09
        ,@c_Errmsg            NVARCHAR(255)   --WL09
          
    --WL06 START  
    SELECT @c_NSQLCountry = NSQLValue  
    FROM NSQLCONFIG (NOLOCK)  
    WHERE ConfigKey = 'Country'  
    --WL06 END     
        
    CREATE TABLE #TEMP_CommINV03      
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
             QtyShipped       INT NULL,      
             UnitPrice        DECIMAL(10,2) NULL,      
             Currency         NVARCHAR(18) NULL,      
             ShipMode         NVARCHAR(18) NULL,      
             SONo             NVARCHAR(30) NULL,      
             consigneekey     NVARCHAR(20) NULL,      
             ODUDF05          NVARCHAR(250) NULL,       --CS01, G01, WL04   --WL07      
             Taxtitle         NVARCHAR(20) NULL,      
             Amt              FLOAT ,                  --CS01      
             TaxAmt           FLOAT NULL,              --CS01      
             TaxCurSymbol     NVARCHAR(20) NULL,      
             TTLAmt           DECIMAL(10,2)  NULL,      
             ShipTitle        NVARCHAR(30) NULL,       --CS03      
             CON_Company      NVARCHAR(45) NULL,       --CS05      
             CON_Address1     NVARCHAR(45) NULL,       --CS05       
             CON_Address2     NVARCHAR(45) NULL,       --CS05      
             CON_Address3     NVARCHAR(45) NULL,       --CS05      
             CON_Address4     NVARCHAR(45) NULL,       --CS05      
             ORDGRP           NVARCHAR(20) NULL,       --CS05      
             PalletKey        NVARCHAR(20) NULL,       --WL01      
             TTLPLT           INT NULL,      
             Orderkey         NVARCHAR(20)  NULL,      
             Madein           NVARCHAR(250) NULL      
          ,  OrderKey_Inv     NVARCHAR(20)  NULL       --(Wan01)   --WL09        
          ,  FreightCharges   INT           NULL       --WL03  
          ,  ShowFOB          NVARCHAR(1)   NULL       --WL03  
          ,  ShowRemark       NVARCHAR(1)   NULL       --WL06  
          ,  InvResetPageNo   NVARCHAR(100) NULL       --WL09
          ,  ResetPageNoFlag  NVARCHAR(10)  NULL       --WL09
          ,  FOBDescr         NVARCHAR(30)  NULL       --WL11
          )      
                
    --WL01 Start      
    CREATE TABLE #TEMP_madein03 (      
    MBOLKey        NVARCHAR(20) NULL,      
    OrderKey       NVARCHAR(20) NULL,      
    SKU            NVARCHAR(20) NULL,      
    lot11          NVARCHAR(50) NULL,      
    company        NVARCHAR(45) NULL      
 ,  OrderKey_Inv     NVARCHAR(20)                     --(Wan01)   --WL09         
    )      
    
    SET @c_UPDATECCOM = 'N'                    
    --WL01 End      
    
    --(Wan01) - START      
    CREATE TABLE #TEMP_Orderkey      
             (  MBOLKey          NVARCHAR(20) NULL,      
                Orderkey         NVARCHAR(20) NOT NULL    PRIMARY KEY,      
             )      
    
    SET @c_Orderkey = ISNULL(RTRIM(@c_Orderkey), '')      
    SET @c_ShipType = ISNULL(RTRIM(@c_ShipType), '')      
    IF @c_Orderkey <> ''  AND EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK) WHERE OH.Orderkey = RIGHT(@c_Orderkey,10)) -- Sub Report --CS09       
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
    
    --(Wan01) - END    
    
   --WL09 S
   --Cater for SHP = 'O' if called from DW for SHP IN ('D','E','N'), will not mixed
   IF @c_SHPFlag IN ('D','E','N')   --WL10
   BEGIN
      CREATE TABLE #TMP_OHSHP (
         SHP   NVARCHAR(100)
      )

      INSERT INTO #TMP_OHSHP
      SELECT DISTINCT ISNULL(ORDERS.SpecialHandling,'')
      FROM ORDERS (NOLOCK)
      WHERE ORDERS.MBOLKey = @c_MBOLKey

      IF EXISTS (SELECT 1 FROM #TMP_OHSHP
                 WHERE SHP = 'O')
      BEGIN
         SET @c_SHPFlag = ''
      END
   END

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

      IF @c_CCountry IN ('ID','TH','VN')
      BEGIN
         --Maximum print 2 reports, as SHP E & N will be combined, only SHP D will be splitted
         IF @c_SHPFlag = 'N' AND @c_AllSHPFlag <> 'N'
         BEGIN
            SET @n_Continue = 3
            SET @c_Errmsg = CONVERT(CHAR(250),@n_Err)
            SET @n_Err = 69500
            SET @c_Errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': No Report will be printed. Special Handling = ''N'' is already printed on previous RCM (isp_CommecialInvoice_03_sg)' 
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
                                            FROM dbo.fnc_DelimSplit(',', @c_SHPFlag) FDS1))
      BEGIN
         SET @n_Continue = 3
         SET @c_Errmsg = CONVERT(CHAR(250),@n_Err)
         SET @n_Err = 69501
         SET @c_Errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': No Report will be printed. Special Handling = ''' 
                       + UPPER(@c_SHPFlag) + ''' is not found (isp_CommecialInvoice_03_sg)' 
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
         AND CombineSHandling IN ('DEN','DE','DN','EN')
         --For ORDERS.C_Country IN ('MY') - END
      END

      SET @c_GetCountry  = ''
      SET @c_GetOrderKey = ''
         
      IF @c_type = 'DBUG'
         SELECT 'Overall',* FROM #TMP_SHandling TSH
   END
   --WL09 E   

    INSERT INTO #TEMP_CommINV03      
    SELECT  MBOL.Mbolkey AS MBOLKEY,      
           ORDERS.PmtTerm,      
           Lott.lottable11,      
           ORDERS.ExternPOKey,      
           ORDERS.Userdefine05,      
           ORDERS.ExternOrderKey,      
           /*CS07 START*/  
           CASE WHEN MIN(ISNULL(SOD.Door,''))<> '' THEN MIN(ISNULL(SD.B_Company,''))  
         ELSE MIN(ISNULL(S.B_Company,'')) END AS IDS_Company,  
           CASE WHEN MIN(ISNULL(SOD.Door,''))<> '' THEN MIN(ISNULL(SD.B_Address1,''))  
        ELSE MIN(ISNULL(S.B_Address1,'')) END AS IDS_Address1,  
           CASE WHEN MIN(ISNULL(SOD.Door,''))<> '' THEN MIN(ISNULL(SD.B_Address2,''))  
        ELSE MIN(ISNULL(S.B_Address2,'')) END AS IDS_Address2,  
           CASE WHEN MIN(ISNULL(SOD.Door,''))<> '' THEN MIN(ISNULL(SD.B_Address3,''))  
        ELSE MIN(ISNULL(S.B_Address3,'')) END AS IDS_Address3,  
           CASE WHEN MIN(ISNULL(SOD.Door,''))<> '' THEN MIN(ISNULL(SD.B_Address4,''))  
        ELSE MIN(ISNULL(S.B_Address4,'')) END AS IDS_Address4,  
           CASE WHEN MIN(ISNULL(SOD.Door,''))<> '' THEN MIN(ISNULL(SD.B_Phone1,''))  
        ELSE MIN(ISNULL(S.B_Phone1,'')) END AS IDS_Phone1,  
         /*CS07 End*/      
           (ISNULL(S.b_city,'') + SPACE(2) + ISNULL(S.B_state,'') + SPACE(2) +  ISNULL(s.B_zip,'') +      
            ISNULL(S.B_country,'') ) AS IDS_City,      
           ISNULL(ORDERS.B_Company,'') AS BILLTO_Company,      
           ISNULL(ORDERS.B_Address1,'') AS BILLTO_Address1,      
           ISNULL(ORDERS.B_Address2,'') AS BILLTO_Address2,      
           ISNULL(ORDERS.B_Address3,'') AS BILLTO_Address3,      
           ISNULL(ORDERS.B_Address4,'') AS BILLTO_Address4,      
           (ISNULL(ORDERS.B_City,'') + SPACE(2) + ISNULL(ORDERS.B_State,'') + SPACE(2) +      
           ISNULL(ORDERS.B_Zip,'') + SPACE(2) +   ISNULL(ORDERS.B_Country,'')) AS BILLTO_City,      
           /*CS03 start*/      
            CASE WHEN ORDERS.Ordergroup <> 'S01' THEN      
               CASE WHEN ORDERS.facility IN ('WGQAP','BULIM') AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%')   THEN    --WL01  
                    CASE WHEN ORDERS.c_country = 'HK' THEN ISNULL(SHK.company,'')      
                         WHEN ORDERS.c_country = 'TW' THEN ISNULL(STW.company,'')      
                         ELSE ISNULL(ORDERS.C_Company,'') END      
                    ELSE ISNULL(ORDERS.C_Company,'') END       
                 ELSE       
                 /*CS05 Start*/      
                    CASE WHEN ORDERS.type='WR' THEN ORDERS.c_company ELSE '' END       
                 END AS ShipTO_Company,      
                 /*CS05 End*/      
           CASE  WHEN ORDERS.Ordergroup <> 'S01' THEN     --CS05      
                    CASE WHEN ORDERS.facility IN ('WGQAP','BULIM') AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%')  THEN    --WL01      
                             CASE WHEN ORDERS.c_country = 'HK' THEN ISNULL(SHK.Address1,'')      
                                  WHEN ORDERS.c_country = 'TW' THEN ISNULL(STW.Address1,'')      
                                  ELSE ISNULL(ORDERS.C_Address1,'')       
                  END      
                         ELSE ISNULL(ORDERS.C_Address1,'') END       
                 ELSE      
                   ISNULL(ORDERS.C_Address1,'')       
                 END AS ShipTO_Address1,                  --CS05      
           CASE  WHEN ORDERS.Ordergroup <> 'S01' THEN     --CS05      
                 CASE WHEN ORDERS.facility IN ('WGQAP','BULIM')  AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%') THEN    --WL01      
                       CASE WHEN ORDERS.c_country = 'HK' THEN ISNULL(SHK.Address2,'')      
                            WHEN ORDERS.c_country = 'TW' THEN ISNULL(STW.Address2,'')      
                            ELSE ISNULL(ORDERS.C_Address2,'') END      
                      ELSE ISNULL(ORDERS.C_Address2,'') END       
                 ELSE     
                      ISNULL(ORDERS.C_Address2,'')       
                 END AS ShipTO_Address2,                  --CS05      
           CASE WHEN ORDERS.Ordergroup <> 'S01'  THEN     --CS05      
                    CASE WHEN ORDERS.facility IN ('WGQAP','BULIM') AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%')    --WL01        
                         THEN      
                             CASE WHEN ORDERS.c_country = 'HK'  THEN ISNULL(SHK.Address3,'')      
                                  WHEN ORDERS.c_country = 'TW'  THEN ISNULL(STW.Address3,'')      
                                  ELSE ISNULL(ORDERS.C_Address3,'') END      
                         ELSE ISNULL(ORDERS.C_Address3,'') END       
                ELSE      
                   ISNULL(ORDERS.C_Address3,'')       
                END  AS ShipTO_Address3,                  --CS05      
           CASE WHEN ORDERS.Ordergroup <> 'S01' THEN      --CS04          
                     CASE WHEN ORDERS.facility='WGQAP' AND ORDERS.c_country IN ('HK','TW')       
                               AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%' )  
                          THEN ''       
                          ELSE ISNULL(ORDERS.C_Address4,'') END       
                ELSE      
                   ISNULL(ORDERS.C_Address4,'')       
                END AS ShipTO_Address4,                   --CS05      
           CASE WHEN ORDERS.facility='WGQAP' AND ORDERS.c_country IN ('HK','TW')      
                AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%')       
                THEN ''       
                ELSE (ISNULL(ORDERS.C_City,'') + SPACE(2) + ISNULL(ORDERS.C_State,'') + SPACE(2) +      
                      ISNULL(ORDERS.C_Zip,'') + SPACE(2) +   ISNULL(ORDERS.C_Country,''))       
                END AS ShipTO_City,      
           /*CS03 End*/      
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
           --ORDERDETAIL.Userdefine05 AS ODUDF05,     
           --WL04 START   
           --WL02 START 
           --WL07 S     
           CASE WHEN ORDERS.C_COUNTRY IN ('IN','KR') THEN REPLACE(TRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,'')),'/','/ ') + CASE WHEN ISNULL(SKUINFO.EXTENDEDFIELD08,'') <> '' THEN REPLACE(TRIM(ISNULL(SKUINFO.EXTENDEDFIELD08,'')),'/','/ ') ELSE '' END --G01   --WL08   
                WHEN ISNULL(CL1.Short,'N') = 'Y' --WL04  
                THEN CASE WHEN LEN(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))) + LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD08,'')))) > 20 AND LEN(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))) + LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD08,'')))) <= 40
                          THEN SUBSTRING(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))) + LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD08,''))),1,20) + ' ' + 
                               SUBSTRING(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))) + LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD08,''))),21,20)  
                          WHEN LEN(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))) + LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD08,'')))) > 40 AND LEN(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))) + LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD08,'')))) <= 60
                          THEN SUBSTRING(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))) + LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD08,''))),1,20)  + ' ' + 
                               SUBSTRING(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))) + LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD08,''))),21,20) + ' ' +  
                               SUBSTRING(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))) + LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD08,''))),41,20)
                          ELSE LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))) + LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD08,''))) END  
           ELSE ''        
           END AS ODUDF05,    
           --WL07 E  
           --WL02 END      
           --WL04 END  
            'Tax:',      
           ROUND(SUM(PICKDETAIL.Qty)*CONVERT(decimal(10,2),ORDERDETAIL.UnitPrice),2) AS Amt,      
           --ROUND((SUM(PICKDETAIL.Qty)*CONVERT(decimal(10,2),ORDERDETAIL.UnitPrice)*0.07),2) AS taxamt   --WL05    
           CASE WHEN ORDERS.facility IN ('BULIM') THEN   --WL05    
           ROUND((SUM(PICKDETAIL.Qty)*CONVERT(decimal(10,2),ORDERDETAIL.UnitPrice)*(CASE WHEN ISNUMERIC(MAX(CL2.Short)) = 1   --WL05   
     THEN ROUND(CAST(MAX(CL2.Short) AS INT)/100.00,2) ELSE 0 END)),2) ELSE 0.00 END AS taxamt   --WL05      
           ,MAX(ORDERDETAIL.Userdefine03) AS TaxCurSymbol,0,    --CS01      
           CASE WHEN ORDERS.Ordergroup <> 'S01' THEN            --CS04      
                    --CASE WHEN ORDERS.facility='WGQAP' AND ORDERS.c_country IN ('HK','TW') AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%')    --WL03  
                    CASE WHEN ORDERS.facility IN ('WGQAP','BULIM') AND ORDERS.c_country IN ('HK','TW') --WL03 (New Facility)  
                         AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%')      --WL03     
                    THEN 'Consignee:'       
                    ELSE 'Ship To:' END       
                ELSE      
                      'Ship To/Notify To:'       
                END AS ShipTitle,                         --CS05      
            /*CS05 Start*/        
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
           ,'' AS palletkey,0,ORDERS.Orderkey,'' AS madein          --WL01       
           --CS08 START   
           --, OrderKey_Inv = CASE WHEN @c_ShipType = 'L' THEN ORDERS.Orderkey ELSE '' END  --(Wan01)
           --WL09 S     
           ,OrderKey_Inv = CASE WHEN @c_ShipType = 'L' THEN ORDERS.Orderkey   
                                WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'O' AND TSH.SHandlingFlag = '' THEN  MBOL.Mbolkey   
                                WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'D' AND TSH.SHandlingFlag = '' THEN  'D' + MBOL.Mbolkey    
                                WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'E' AND TSH.SHandlingFlag = '' THEN  'E' + MBOL.Mbolkey  
                                WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'N' AND TSH.SHandlingFlag = '' THEN  'N' + MBOL.Mbolkey   
                                WHEN @c_ShipType = '' AND ORDERS.SpecialHandling IN ('D','E','N') AND TSH.SHandlingFlag = 'N' THEN TSH.CombineSHandling + MBOL.Mbolkey 
                                --WHEN @c_ShipType = '' AND TSH.SpecialHandling    = 'D' AND TSH.SHandlingFlag = 'Y' THEN  'D' + MBOL.Mbolkey  
                                --WHEN @c_ShipType = '' AND TSH.SpecialHandling   <> 'D' AND TSH.SHandlingFlag = 'Y' THEN  TSH.SpecialHandling + MBOL.Mbolkey   
                                ELSE '' END    
             --CS08 END    
           --WL09 E
           , FreightCharges = CASE WHEN ISNUMERIC(ISNULL(CL.Short,0)) = 1 THEN ISNULL(CL.Short,0) ELSE 0 END --WL03  
           , ShowFOB = CASE WHEN ISNULL(CL.Short,'') = '' THEN 'N' ELSE 'Y' END                              --WL03  
           --WL06 START  
           , ShowRemark = CASE WHEN ORDERS.C_Country IN ('TW') AND ORDERS.Facility IN ('WGQAP','BULIM')  
                                AND ORDERS.ConsigneeKey IN ('4925968') AND @c_NSQLCountry = 'CN'  
                                THEN 'Y' ELSE 'N' END  
           --WL06 END  
           /*CS05 end*/   
           , InvResetPageNo  =  CASE WHEN @c_ShipType = '' AND TSH.SHandlingFlag = 'Y' THEN TSH.CombineSHandling + MBOL.Mbolkey END     --WL09  
           , ResetPageNoFlag =  CASE WHEN ORDERS.C_Country IN ('ID','TH','VN','MY') AND TSH.SHandlingFlag = 'Y' THEN 'Y' ELSE 'N' END   --WL09
           , FOBDescr = CASE WHEN ISNULL(CL.UDF03,'') = '' THEN 'Freight FCA' ELSE TRIM(ISNULL(CL.UDF03,'')) END   --WL11
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
           LEFT JOIN SKUINFO WITH (NOLOCK) ON (SKUINFO.StorerKey = SKU.StorerKey      
                                       AND ORDERDETAIL.Sku = SKUINFO.Sku AND SKU.SKU = SKUINFO.SKU) --WL02      
           LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.Listname = 'FOB' AND CL.Long = ORDERS.Userdefine05 AND CL.Code = ORDERS.Consigneekey  --WL03  
                                              AND CL.UDF01 = ORDERS.C_Country AND CL.Storerkey = ORDERS.Storerkey  
           LEFT JOIN CODELKUP CL1 WITH (NOLOCK) ON (CL1.Listname = 'REPORTCFG' AND CL1.Code = 'ShowModelNumber' AND CL1.Storerkey = ORDERS.Storerkey  
                                                    AND CL1.code2 = ORDERS.Facility) --WL04  
           /*CS03 Start*/       
           LEFT JOIN STORER STW WITH (NOLOCK) ON (STW.Storerkey = 'LOGITWDDP')          
           LEFT JOIN STORER SHK WITH (NOLOCK) ON (SHK.Storerkey = 'LOGIHKDDP')      
           /*CS03 END*/      
           /*CS05 Start*/      
           LEFT JOIN STORER MWRHK WITH (NOLOCK) ON (MWRHK.Storerkey = 'LOGISMWRHK')          
           LEFT JOIN STORER MWRTW WITH (NOLOCK) ON (MWRTW.Storerkey = 'LOGISMWRTW')       
           LEFT JOIN STORER MWRAU WITH (NOLOCK) ON (MWRAU.Storerkey = 'LOGISMWRAU')          
           LEFT JOIN STORER MWRNZ WITH (NOLOCK) ON (MWRNZ.Storerkey = 'LOGISMWRNZ')       
           /*CS05 End*/   
           /*CS07 Start*/  
           LEFT JOIN storersodefault SOD WITH (NOLOCK) ON SOD.StorerKey = ORDERS.ConsigneeKey  
           LEFT JOIN STORER SD WITH (NOLOCK) ON (SD.Storerkey = SOD.Door)  
           /*CS07 End*/                                       
           --WL05 START  
           OUTER APPLY (SELECT TOP 1 CODELKUP.Short   
                        FROM CODELKUP (NOLOCK)   
                        WHERE Listname = 'LOGIGST' AND Code = 'GST'  
                        AND (Storerkey = ORDERS.Storerkey OR Storerkey = '')  
                        ORDER BY CASE WHEN Storerkey = '' THEN 2 ELSE 1 END) AS CL2  
           --WL05 END                
           LEFT JOIN #TMP_SHandling TSH ON TSH.Orderkey = ORDERS.OrderKey   --WL09
    WHERE MBOL.Mbolkey = @c_mbolkey      
    AND EXISTS (SELECT 1 FROM #TEMP_Orderkey TMP WHERE TMP.Orderkey = ORDERS.Orderkey)     --(Wan01)      
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
           ORDERS.Userdefine01 ,ORDERS.Consigneekey,ORDERDETAIL.Userdefine05                 --CS01      
           ,ISNULL(SKUINFO.EXTENDEDFIELD05,'') --WL02      
           --WL04 START  
           --WL07 S
           ,CASE WHEN ORDERS.C_COUNTRY IN ('IN','KR') THEN REPLACE(TRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,'')),'/','/ ') + CASE WHEN ISNULL(SKUINFO.EXTENDEDFIELD08,'') <> '' THEN REPLACE(TRIM(ISNULL(SKUINFO.EXTENDEDFIELD08,'')),'/','/ ') ELSE '' END --G01   --WL07   --WL08
                 WHEN ISNULL(CL1.Short,'N') = 'Y' --WL04  
                 THEN CASE WHEN LEN(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))) + LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD08,'')))) > 20 AND LEN(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))) + LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD08,'')))) <= 40
                           THEN SUBSTRING(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))) + LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD08,''))),1,20) + ' ' + 
                                SUBSTRING(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))) + LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD08,''))),21,20)  
                           WHEN LEN(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))) + LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD08,'')))) > 40 AND LEN(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))) + LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD08,'')))) <= 60
                           THEN SUBSTRING(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))) + LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD08,''))),1,20)  + ' ' + 
                                SUBSTRING(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))) + LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD08,''))),21,20) + ' ' +  
                                SUBSTRING(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))) + LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD08,''))),41,20)
                           ELSE LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))) + LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD08,''))) END  
            ELSE '' END      
            --WL07 E   
           --WL04 END  
           ,ORDERS.Facility,ORDERS.C_Country,ORDERS.UserDefine05,SHK.company,STW.company     --CS03      
           ,SHK.Address1,STW.Address1 ,SHK.Address2,STW.Address2 ,SHK.Address3,STW.Address3  --CS03      
           ,ORDERS.Ordergroup ,ORDERS.type,ISNULL(MWRHK.company,''),ISNULL(MWRTW.company,'') --CS03      
           ,ISNULL(MWRAU.company,''),ISNULL(MWRNZ.company,''),ISNULL(MWRHK.Address1,'')      
           ,ISNULL(MWRTW.Address1,''),ISNULL(MWRAU.Address1,''),ISNULL(MWRNZ.Address1,'')      
           ,ISNULL(MWRHK.Address2,''),ISNULL(MWRTW.Address2,''),ISNULL(MWRAU.Address2,''),ISNULL(MWRNZ.Address2,'')      
           ,ISNULL(MWRHK.Address3,'')      
           ,ISNULL(MWRTW.Address3,''),ISNULL(MWRAU.Address3,''),ISNULL(MWRNZ.Address3,'')      
           ,ISNULL(MWRHK.Address4,'')      
           ,ISNULL(MWRTW.Address4,''),ISNULL(MWRAU.Address4,''),ISNULL(MWRNZ.Address4,'')      
           ,ORDERS.Orderkey      
           ,CASE WHEN ISNUMERIC(ISNULL(CL.Short,0)) = 1 THEN ISNULL(CL.Short,0) ELSE 0 END --WL03  
           ,CASE WHEN ISNULL(CL.Short,'') = '' THEN 'N' ELSE 'Y' END                       --WL03  
           ,ORDERS.SpecialHandling  
           ,TSH.CombineSHandling   --WL09
           ,TSH.SHandlingFlag     --WL09
           ,CASE WHEN ISNULL(CL.UDF03,'') = '' THEN 'Freight FCA' ELSE TRIM(ISNULL(CL.UDF03,'')) END   --WL11
           --CS08 START  
           --,CASE WHEN @c_ShipType = 'L' THEN 'A' + ORDERS.Orderkey   
           --                       WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'O' THEN  MBOL.Mbolkey   
           --                       WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'D' THEN  'D' + MBOL.Mbolkey    
           --                       WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'E' THEN  'E' + MBOL.Mbolkey  
           --                       WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'N' THEN  'N' + MBOL.Mbolkey   
           --                        ELSE '' END     
           --CS08 END   
          
    SET @c_FromCountry = ''  --WL01       
    SET @n_lineNo = 1              
    SET @c_palletkey = ''      
    SET @c_delimiter =','     
       
    DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR        
    SELECT DISTINCT mbolkey,ExternOrdKey,sum(TaxAmt),Orderkey,StorerKey--sum(UnitPrice*QtyShipped)  --WL01       
          ,  OrderKey_Inv                                                --(Wan01)                 
    FROM   #TEMP_CommINV03          
    WHERE mbolkey=@c_MBOLKey       
    GROUP BY mbolkey,ExternOrdKey,Orderkey,StorerKey      
          ,  OrderKey_Inv                                                --(Wan01)       
         
    OPEN CUR_RESULT         
            
    FETCH NEXT FROM CUR_RESULT INTO @c_Getmbolkey,@c_getExtOrdkey,@n_getamt,@c_orderkey,@c_storerkey  -- WL01      
                                  , @c_OrderKey_Inv                      --(Wan01)         
            
    WHILE @@FETCH_STATUS <> -1        
    BEGIN         
             
       IF @c_OrderKey_Inv <> ''                                           --(JHTAN01)  (Wan01) ORI:  IF @c_OrderKey_Inv = ''      
       BEGIN                                                             --(Wan01)      
          SELECT TOP 1                                                   --(Wan01)      
             @c_getCountry = b_country                                   --(Wan01)      
          ,  @c_FromCountry=C_Country                                    --(Wan01)      
          ,  @c_getconsignee = consigneekey                              --(Wan01)               
          FROM ORDERS (NOLOCK)                                           --(Wan01)      
          WHERE MBOLKey=@c_getmbolkey --AND OrderKey=@c_OrderKey_Inv       --(Wan01)     --(CS09a)           
          AND OrderKey = @c_Orderkey                                                     --(CS09a)  
       END                                                               --(Wan01)      
       ELSE                                                              --(Wan01)      
       BEGIN      
          SELECT TOP 1 @c_getCountry = b_country,@c_FromCountry=C_Country   -- WL01       
          ,@c_getconsignee = consigneekey                                   --CS06      
          FROM ORDERS (NOLOCK)      
          WHERE MBOLKey=@c_getmbolkey AND ExternOrderKey=@c_getExtOrdkey         
       END                                                               --(Wan01)       
    
       SET @n_amt = 0       
       SET @n_getttlamt = 0           --CS04      
       SET @c_PreOrderKey = ''      
       SET @n_TTLPLT = 0      
        
   --SELECT @c_FromCountry '@c_FromCountry', @c_getCountry '@c_getCountry', @c_getconsignee '@c_getconsignee', @c_OrderKey_Inv '@c_OrderKey_Inv'  
     --SELECT 'chk1',* FROM #TEMP_CommINV03 WHERE mbolkey=@c_Getmbolkey      
     ----  AND   OrderKey_Inv = @c_OrderKey_Inv  

                
  --  SELECT @c_OrderKey_Inv '@c_OrderKey_Inv',n_amt = SUM(amt)      
     --        ,n_getttlamt = SUM (TaxAmt)       
     --  FROM   #TEMP_CommINV03       
     --  WHERE mbolkey=@c_Getmbolkey      
     --  AND   OrderKey_Inv = @c_OrderKey_Inv                            --(Wan01)           
     --  GROUP BY MBOLKey      
                   
       SELECT @n_amt = SUM(amt)      
             ,@n_getttlamt = SUM (TaxAmt)       
       FROM   #TEMP_CommINV03       
       WHERE mbolkey=@c_Getmbolkey      
       AND   OrderKey_Inv = @c_OrderKey_Inv                            --(Wan01)           
       GROUP BY MBOLKey      
         
       --WL05 START  
       --IF @c_getCountry = 'SG' and @c_getconsignee <> '31624'       
       --BEGIN      
       --   --SET @n_amt = @n_getamt * 0.07      
                
       --   --SET @n_TTLTaxamt = @n_getttlamt + @n_amt                  --CS04      
       --   SET @n_TTLTaxamt = convert(decimal(10,2),(@n_getttlamt + @n_amt))               --CS04      
          
       --   --SELECT @n_getamt AS '@n_getamt',@n_amt AS '@n_amt',@n_TTLTaxamt AS '@n_TTLTaxamt',@n_getttlamt AS '@n_getttlamt'      
       --END   
       IF @c_FromCountry = 'SG'   
       BEGIN  
          SET @n_TTLTaxamt = convert(decimal(10,2),(@n_getttlamt + @n_amt))  
       END  
       --WL05 END    
       ELSE      
       BEGIN      
          SET @n_TTLTaxamt = @n_amt      
       END         
          
       --WL01 Start      
             
       IF @c_FromCountry='TH'      
       BEGIN      
          IF @c_PreOrderKey <> @c_OrderKey      
          BEGIN      
              /*CS04a start*/      
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
          /*CS03 Start*/      
          JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=ph.OrderKey    --CS03a      
          JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.caseid = PD.LabelNo  AND PLTD.Sku=pd.sku --CS04b      
          JOIN Containerdetail CD WITH (NOLOCK) ON CD.PalletKey=PLTD.PalletKey      
          JOIN Container CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey  AND CON.MBOLKey=ord.MBOLKey     --CS03a      
          LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CONTAINERT' AND C.UDF01='P' AND C.code=CON.ContainerType      
          WHERE PH.orderkey = @c_OrderKey      
          AND PLTD.STORERKEY = @c_storerkey      
                   
          DECLARE TH_ORDERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
          SELECT DISTINCT mbolkey,orderkey,sku      
          FROM #TEMP_CommINV03      
          WHERE mbolkey=@c_MBOLKey      
          AND   OrderKey_Inv = @c_OrderKey_Inv                            --(Wan01)        
          AND ShipTO_Country='TH'      
                
          OPEN TH_ORDERS      
               
          FETCH FROM TH_ORDERS INTO @c_Getmbolkey,@c_GetOrderKey,@c_getsku      
    
          WHILE @@FETCH_STATUS = 0      
          BEGIN      
             INSERT INTO #TEMP_madein03      
             (      
                MBOLKey,      
                OrderKey,      
                SKU,      
                lot11,      
                company      
             ,  OrderKey_Inv                                       --(Wan01)        
             )      
             SELECT DISTINCT  ORD.mbolkey, ORD.orderkey ,PD.sku,c.Description,ord.C_Company      
                   ,  OrderKey_Inv = @c_OrderKey_Inv                      --(Wan01)        
             FROM PICKDETAIL PD (NOLOCK)       
             JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=pd.OrderKey    --CS03a      
             JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.userdefine02  = PD.orderkey AND PLTD.Sku=pd.sku AND PLTD.StorerKey=ORD.StorerKey   --CS04b      
             JOIN Containerdetail CD WITH (NOLOCK) ON CD.PalletKey=PLTD.PalletKey      
             JOIN Container CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey=ord.MBOLKey     --CS03a      
             JOIN LOTATTRIBUTE LOTT WITH (NOLOCK) ON (LOTT.SKU=PD.SKU AND LOTT.Storerkey=PD.Storerkey AND LOTT.lot=PD.Lot)      
             LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CTYCAT' AND C.code=LOTT.lottable11       
             WHERE ORD.mbolkey=@c_Getmbolkey AND ORD.orderkey = @c_GetOrderKey AND PD.sku = @c_getsku      
              
             FETCH FROM TH_ORDERS INTO @c_Getmbolkey,@c_GetOrderKey,@c_getsku      
          END      
               
          CLOSE TH_ORDERS      
          DEALLOCATE TH_ORDERS      
           
        --SELECT * FROM #TEMP_madein03          
          SET @n_CntRec = 0      
          SET @c_madein = ''      
    
          IF EXISTS (SELECT 1 FROM #TEMP_madein03  WHERE MBOLKey = @c_MBOLKey      
                     AND   OrderKey_Inv = @c_OrderKey_Inv              --(Wan01)        
                    )      
          BEGIN      
             SET @c_UPDATECCOM = 'Y'               --WL01      
          END      
           
          SELECT @n_CntRec = COUNT(DISTINCT lot11),@C_Lottable11 = MIN(lot11)      
              ,@c_company=MIN(company)      
          FROM  #TEMP_madein03       
          WHERE MBOLKey = @c_MBOLKey      
          AND   OrderKey_Inv = @c_OrderKey_Inv                         --(Wan01)      
          
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
             FROM #TEMP_madein03                 WHERE mbolkey=@c_MBOLKey      
             AND   OrderKey_Inv = @c_OrderKey_Inv                      --(Wan01)       
    
             OPEN MadeIn_loop      
    
             FETCH FROM MadeIn_loop INTO @c_lott11      
    
             WHILE @@FETCH_STATUS = 0      
             BEGIN      
    
                IF @n_CntRec >=2      
                BEGIN      
                   SET @c_madein = @c_madein + @c_lott11 + @c_delimiter    --(CLVN01)  
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
                  
          UPDATE #TEMP_CommINV03      
          SET  TTLPLT = @n_TTLPLT      
          WHERE MBOLKey=@c_Getmbolkey      
          AND Orderkey=@c_GetOrderKey      
          AND SKU = @c_getsku      
       END      
          
       --WL01 END      
       -- select @c_company '@c_company'      
       UPDATE #TEMP_CommINV03      
       SET TaxAmt = CASE WHEN @c_getCountry = 'SG' AND @c_getconsignee <>'31624' THEN TaxAmt ELSE 0.00  END  --CS06      
           ,TTLAmt = @n_TTLTaxamt
           ,TaxCurSymbol = TaxCurSymbol      
           ,Madein = @c_madein      
           ,ShipTO_Company = CASE WHEN @c_UPDATECCOM = 'Y' THEN @c_company ELSE ShipTO_Company END   --WL01      
       WHERE MBOLKey=@c_Getmbolkey      
       AND   OrderKey_Inv = @c_OrderKey_Inv                            --(Wan01)      
       --AND ExternOrdKey = @c_getExtOrdkey          
          
       SET @c_PreOrderKey = @c_OrderKey   --WL01       
       SET @n_lineNo = @n_lineNo + 1      --WL01       
          
       FETCH NEXT FROM CUR_RESULT INTO @c_Getmbolkey,@c_getExtOrdkey,@n_getamt,@c_orderkey,@c_storerkey  --WL01       
                                     , @c_OrderKey_Inv                  --(Wan01)        
    END      
    CLOSE CUR_RESULT      
    DEALLOCATE CUR_RESULT      
    
    IF @c_ShipType <> 'L'      
    BEGIN               
        -- WL01 Start      
       SET @c_company = ''      
       SELECT TOP 1 @c_company = company      
       FROM #TEMP_madein03 AS tm      
       WHERE tm.MBOLKey = @c_Getmbolkey      
          
       UPDATE #TEMP_CommINV03      
       SET  PalletKey =  CASE WHEN @c_FromCountry = 'TH' THEN @c_palletkey ELSE PalletKey END      
           --,Madein =  CASE WHEN @c_FromCountry = 'TH' THEN @c_madein ELSE Madein END     --(CLVN01)  
           ,ShipTO_Company = CASE WHEN @c_FromCountry = 'TH' THEN @c_company ELSE ShipTO_Company END      
       WHERE MBOLKey=@c_Getmbolkey         
    END      
    
    DELETE FROM #TEMP_madein03      
    -- WL01 END      
    
    IF @c_type = 'H1' GOTO TYPE_H1         
    IF @c_type = 'S01' GOTO TYPE_S01      
    IF @c_type = 'S02' GOTO TYPE_S02      
           
       
    TYPE_H1:  
    
      --WL09 S
      IF @c_CCountry IN ('ID','TH','VN') AND @c_SHPFlag IN ('D','E')   --SHP N not included here since it will print together with SHP E
      BEGIN
         SELECT Rowid       
             ,  MBOLKey                  
             ,  pmtterm                  
             ,  Lottable11               
             ,  ExtPOKey                 
             ,  OHUdf05                  
             ,  ExternOrdKey             
             ,  IDS_Company              
             ,  IDS_Address1             
             ,  IDS_Address2             
             ,  IDS_Address3             
             ,  IDS_Address4             
             ,  IDS_Phone1               
             ,  IDS_City                 
             ,  BILLTO_Company           
             ,  BILLTO_Address1          
             ,  BILLTO_Address2          
             ,  BILLTO_Address3          
             ,  BILLTO_Address4          
             ,  BILLTO_City              
             ,  ShipTO_Company           
             ,  ShipTO_Address1          
             ,  ShipTO_Address2          
             ,  ShipTO_Address3          
             ,  ShipTO_Address4          
             ,  ShipTO_City              
             ,  ShipTO_Phone1            
             ,  ShipTO_Contact1          
             ,  ShipTO_Country           
             ,  From_Country             
             ,  StorerKey                
             ,  SKU                      
             ,  Descr                    
             ,  QtyShipped               
             ,  UnitPrice                
             ,  Currency                 
             ,  ShipMode                 
             ,  SONo                     
             ,  consigneekey             
             ,  ODUDF05                  
             ,  Taxtitle                 
             ,  Amt                      
             ,  TaxAmt                   
             ,  TaxCurSymbol             
             ,  TTLAmt                   
             ,  ShipTitle             
             ,  CON_Company            
             ,  CON_Address1            
             ,  CON_Address2           
             ,  CON_Address3          
             ,  CON_Address4           
             ,  ORDGRP                
             ,  PalletKey
             ,  TTLPLT
             ,  Madein      
             ,  ShipType = @c_ShipType      
             ,  OrderKey_Inv = CASE WHEN @c_ShipType = 'L' THEN 'A' +  OrderKey_Inv  ELSE  OrderKey_Inv END   
             ,  InvoiceNo =  CASE WHEN @c_ShipType = 'L' THEN 'A' +  OrderKey_Inv  ELSE  OrderKey_Inv END  --CASE WHEN OrderKey_Inv = '' THEN MBOLKey ELSE 'A' + RTRIM(OrderKey_Inv) END      --CS08  
             ,  FreightCharges       --WL03   
             ,  ShowFOB              --WL03  
             ,  ShowRemark           --WL06  
             ,  @c_NSQLCountry AS NSQLCountry   --WL06  
             ,  InvResetPageNo   --WL09
             ,  ResetPageNoFlag  --WL09
             ,  FOBDescr   --WL11
         FROM #TEMP_CommINV03      
         WHERE (InvResetPageNo LIKE @c_SHPFlag + '%' OR OrderKey_Inv LIKE @c_SHPFlag + '%')
         ORDER BY mbolkey,CASE WHEN OrderKey_Inv = '' THEN InvResetPageNo ELSE OrderKey_Inv END,ExternOrdKey   --CS09   --WL09
      END
      ELSE IF @c_CCountry IN ('MY') AND @c_SHPFlag IN ('D','E','N')
      BEGIN
         SELECT Rowid       
             ,  MBOLKey                  
             ,  pmtterm                  
             ,  Lottable11               
             ,  ExtPOKey                 
             ,  OHUdf05                  
             ,  ExternOrdKey             
             ,  IDS_Company              
             ,  IDS_Address1             
             ,  IDS_Address2             
             ,  IDS_Address3             
             ,  IDS_Address4             
             ,  IDS_Phone1               
             ,  IDS_City                 
             ,  BILLTO_Company           
             ,  BILLTO_Address1          
             ,  BILLTO_Address2          
             ,  BILLTO_Address3          
             ,  BILLTO_Address4          
             ,  BILLTO_City              
             ,  ShipTO_Company           
             ,  ShipTO_Address1          
             ,  ShipTO_Address2          
             ,  ShipTO_Address3          
             ,  ShipTO_Address4          
             ,  ShipTO_City              
             ,  ShipTO_Phone1            
             ,  ShipTO_Contact1          
             ,  ShipTO_Country           
             ,  From_Country             
             ,  StorerKey                
             ,  SKU                      
             ,  Descr                    
             ,  QtyShipped               
             ,  UnitPrice                
             ,  Currency                 
             ,  ShipMode                 
             ,  SONo                     
             ,  consigneekey             
             ,  ODUDF05                  
             ,  Taxtitle                 
             ,  Amt                      
             ,  TaxAmt                   
             ,  TaxCurSymbol             
             ,  TTLAmt                   
             ,  ShipTitle             
             ,  CON_Company            
             ,  CON_Address1            
             ,  CON_Address2           
             ,  CON_Address3          
             ,  CON_Address4           
             ,  ORDGRP                
             ,  PalletKey
             ,  TTLPLT
             ,  Madein      
             ,  ShipType = @c_ShipType      
             ,  OrderKey_Inv = CASE WHEN @c_ShipType = 'L' THEN 'A' +  OrderKey_Inv  ELSE  OrderKey_Inv END   
             ,  InvoiceNo =  CASE WHEN @c_ShipType = 'L' THEN 'A' +  OrderKey_Inv  ELSE  OrderKey_Inv END  --CASE WHEN OrderKey_Inv = '' THEN MBOLKey ELSE 'A' + RTRIM(OrderKey_Inv) END      --CS08  
             ,  FreightCharges       --WL03   
             ,  ShowFOB              --WL03  
             ,  ShowRemark           --WL06  
             ,  @c_NSQLCountry AS NSQLCountry   --WL06  
             ,  InvResetPageNo   --WL09
             ,  ResetPageNoFlag  --WL09
             ,  FOBDescr   --WL11
         FROM #TEMP_CommINV03   
         WHERE (LEFT(InvResetPageNo,1) = @c_SHPFlag OR LEFT(OrderKey_Inv,1) = @c_SHPFlag) 
         ORDER BY mbolkey,CASE WHEN OrderKey_Inv = '' THEN InvResetPageNo ELSE OrderKey_Inv END,ExternOrdKey   --CS09   --WL09
      END
      ELSE
      BEGIN
         SELECT Rowid       
             ,  MBOLKey                  
             ,  pmtterm                  
             ,  Lottable11               
             ,  ExtPOKey                 
             ,  OHUdf05                  
             ,  ExternOrdKey             
             ,  IDS_Company              
             ,  IDS_Address1             
             ,  IDS_Address2             
             ,  IDS_Address3             
             ,  IDS_Address4             
             ,  IDS_Phone1               
             ,  IDS_City                 
             ,  BILLTO_Company           
             ,  BILLTO_Address1          
             ,  BILLTO_Address2          
             ,  BILLTO_Address3          
             ,  BILLTO_Address4          
             ,  BILLTO_City              
             ,  ShipTO_Company           
             ,  ShipTO_Address1          
             ,  ShipTO_Address2          
             ,  ShipTO_Address3          
             ,  ShipTO_Address4          
             ,  ShipTO_City              
             ,  ShipTO_Phone1            
             ,  ShipTO_Contact1          
             ,  ShipTO_Country           
             ,  From_Country             
             ,  StorerKey                
             ,  SKU                      
             ,  Descr                    
             ,  QtyShipped               
             ,  UnitPrice                
             ,  Currency                 
             ,  ShipMode                 
             ,  SONo                     
             ,  consigneekey             
             ,  ODUDF05                  
             ,  Taxtitle                 
             ,  Amt                      
             ,  TaxAmt                   
             ,  TaxCurSymbol             
             ,  TTLAmt                   
             ,  ShipTitle             
             ,  CON_Company            
             ,  CON_Address1            
             ,  CON_Address2           
             ,  CON_Address3          
             ,  CON_Address4           
             ,  ORDGRP                
             ,  PalletKey
             ,  TTLPLT
             ,  Madein      
             ,  ShipType = @c_ShipType      
             ,  OrderKey_Inv = CASE WHEN @c_ShipType = 'L' THEN 'A' +  OrderKey_Inv  ELSE  OrderKey_Inv END   
             ,  InvoiceNo =  CASE WHEN @c_ShipType = 'L' THEN 'A' +  OrderKey_Inv  ELSE  OrderKey_Inv END  --CASE WHEN OrderKey_Inv = '' THEN MBOLKey ELSE 'A' + RTRIM(OrderKey_Inv) END      --CS08  
             ,  FreightCharges       --WL03   
             ,  ShowFOB              --WL03  
             ,  ShowRemark           --WL06  
             ,  @c_NSQLCountry AS NSQLCountry   --WL06  
             ,  InvResetPageNo   --WL09
             ,  ResetPageNoFlag  --WL09
             ,  FOBDescr   --WL11
         FROM #TEMP_CommINV03      
         ORDER BY mbolkey,CASE WHEN OrderKey_Inv = '' THEN InvResetPageNo ELSE OrderKey_Inv END,ExternOrdKey   --CS09   --WL09
      END
      --WL09 E    
       
        
           
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
             CON_Address4     ,       
             ORDGRP           ,  
             ShowRemark       ,   --WL06  
             @c_NSQLCountry AS NSQLCountry   --WL06  
       FROM #TEMP_CommINV03      
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
          ORDGRP           ,  
          ShowRemark       ,   --WL06  
          @c_NSQLCountry AS NSQLCountry   --WL06  
    FROM #TEMP_CommINV03      
    WHERE MBOLKey = @c_MBOLKey      
    ORDER BY mbolkey,ExternOrdKey      
          
     GOTO QUIT      
QUIT:      
   --(Wan02) - START       
   IF OBJECT_ID('tempdb..#TEMP_CommINV03','u') IS NOT NULL      
   BEGIN      
      DROP TABLE #TEMP_CommINV03;      
   END      
         
   IF OBJECT_ID('tempdb..#TEMP_madein03','u') IS NOT NULL      
   BEGIN      
      DROP TABLE #TEMP_madein03;      
   END      
      
   IF OBJECT_ID('tempdb..#TEMP_Orderkey','u') IS NOT NULL      
   BEGIN      
      DROP TABLE #TEMP_Orderkey;      
   END      
   --(Wan02) - END    
   
   --WL09 S
   IF OBJECT_ID('tempdb..#TMP_SHandling','u') IS NOT NULL      
   BEGIN      
      DROP TABLE #TMP_SHandling;      
   END 

   IF OBJECT_ID('tempdb..#TMP_OHSHP','u') IS NOT NULL      
   BEGIN      
      DROP TABLE #TMP_OHSHP;      
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
   --WL09 E
END   

GO