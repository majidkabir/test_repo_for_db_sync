SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
        
/************************************************************************/      
/* Stored Procedure: isp_Packing_List_37_SG                             */      
/* Creation Date: 05-May-2017                                           */      
/* Copyright: IDS                                                       */      
/* Written by: CSCHONG                                                  */      
/*                                                                      */      
/* Purpose:MS-1747 - SG Logitech Packing List Report                    */      
/*                                                                      */      
/*                                                                      */      
/* Called By: report dw = r_dw_Packing_List_37_SG                       */      
/*                                                                      */      
/* PVCS Version: 3.0                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author    Ver.  Purposes                                */      
/* 11-May-2017  CSCHONG   1.0   WMS-1747 -Revise Field mapping (CS01)   */      
/* 08-JUN-2017  CSCHONG   1.1   WMS-1747 - Revise Address field (CS02)  */      
/* 30-JUN-2017  CSCHONG   1.2   WMS-2311 - revise field logic (CS03)    */      
/* 14-JUL-2017  JYHBIN    1.3   Resolve Bug                              */      
/* 27-JUL-2017  CSCHONG   1.3   fix duplicated issue, CN1 process (CS03a)*/      
/* 24-JUL-2017  CSCHONG   1.4   WMS-2432 - Revise report layout(CS04)   */      
/* 16-Aug-2017  CSCHONG   1.5   Fix total pallet issue (CS04a)          */      
/* 21-Aug-2017  CSCHONG   1.6   fix totalqty issue (CS04b)              */      
/* 29-Aug-2017  MengTah   1.7   IN00451304 Group by PD.QTY (MT01)       */      
/* 07-DEC-2017  CSCHONG   1.8   WMS-3441 add new logic (CS05)           */    
/* 18-OCT-2018  WLCHOOI   1.9   WMS-6668 - Revise logic of displaying   */    
/*                              model number and add new Facility (WL01)*/     
/* 19-FEB-2019  CHEEMUN   2.0   INC0582740 - Clear @c_ODUDEF05 value    */     
/* 17-JUN-2019  CSCHONG   2.1   WMS-8806 revised field logic (CS06)     */      
/* 05-AUG-2019  CSCHONG   2.2   WMS-9970 revised field logic (CS07)     */          
/* 30-JAN-2020  CSCHONG   2.3   WMS-11894 revised field logic (CS08)    */        
/* 23-APR-2020  WLChooi   2.4   WMS-13021 - ShowModelNumber by ReportCFG*/    
/*                              (WL02)                                  */      
/* 23-Jun-2020  CSCHONG   2.5   WMS-13800/14980 add new field (CS09)    */                                              
/* 08-Dec-2020  CSCHONG   2.6   WMS-14980 revised mapping (CS09a)       */        
/* 01-FEB-2021  CSCHONG   2.7   Performance tunning - replace view table*/    
/*                              with Temp table (CS10)                  */    
/* 18-FEB-2021  CSCHONG   2.8   WMS-16135 revised report grouping (CS11)*/       
/* 16-JUL-2021  CSCHONG   2.9   WMS-16135 fix sorting issue (CS11a)     */ 
/* 10-May-2022  WLChooi   3.0   DevOps Combine Script                   */
/* 10-May-2022  WLChooi   3.0   WMS-19628 Extend Userdefine02 column to */
/*                              40 (WL03)                               */
/************************************************************************/      
      
CREATE PROC [dbo].[isp_Packing_List_37_SG] (      
   @c_MBOLKey  NVARCHAR(21)       
  ,@c_type     NVARCHAR(10)   = 'H1'   
  ,@c_ShipType NVARCHAR(10)   = ''  -- CS11     
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
       ,@c_ODUDEF05            NVARCHAR(50)   --WL02      
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
       ,@c_shiptitle           NVARCHAR(30)                    --CS02      
       ,@c_GetPalletKey        NVARCHAR(30)                    --CS03      
       ,@n_TTLPLT              INT                             --CS03         
       ,@c_PreOrderKey         NVARCHAR(10)                    --CS03         
       ,@c_ChkPalletKey        NVARCHAR(30)                    --CS03       
       ,@c_facility            NVARCHAR(5)                     --CS03a                
       ,@c_Con_Company         NVARCHAR(45)                    --CS04      
       ,@c_Con_Address1        NVARCHAR(45)                    --CS04       
       ,@c_Con_Address2        NVARCHAR(45)                    --CS04       
       ,@c_Con_Address3        NVARCHAR(45)                    --CS04       
       ,@c_Con_Address4        NVARCHAR(45)                    --CS04       
       ,@c_OrdGrp              NVARCHAR(20)                    --CS04        
       ,@n_EPWGT_Value         DECIMAL(6,2)                    --CS04      
       ,@n_EPCBM_Value         DECIMAL(6,2)                    --CS04        
       ,@c_UDF01               NVARCHAR(5)                     --CS04         
       ,@n_lineNo              INT                             --CS04a          
       ,@C_CLKUPUDF01          NVARCHAR(15)                    --CS05      
       ,@C_Lottable11          NVARCHAR(30)                    --CS05      
       ,@c_madein              NVARCHAR(250)                   --CS05      
       ,@c_delimiter           NVARCHAR(1)                     --CS05       
       ,@c_GetOrderKey         NVARCHAR(10)                    --CS05       
       ,@c_getsku              NVARCHAR(20)                    --CS05      
       ,@n_CntRec              INT                             --CS05         
       ,@c_lott11              NVARCHAR(50)                    --CS05      
       ,@c_company             NVARCHAR(45)                    --CS05      
       ,@c_UPDATECCOM          NVARCHAR(1)                     --CS05     
       ,@c_dest                NVARCHAR(100)                   --CS06    
       ,@c_PLTNo               NVARCHAR(80)                    --CS06         
       ,@n_pltwgt              FLOAT                           --CS09    
       ,@n_pltcbm              FLOAT                           --CS09        
       ,@n_Cntvrec             INT                             --CS09        
    --   ,@n_fpltwgt             INT                           --CS09    
       ,@n_fpltwgt             FLOAT                           --CS09a    
       ,@n_fpltcbm             FLOAT                           --CS09      
    -- ,@C_getCLKUPUDF01   NVARCHAR(15)    
       ,@n_epltwgt             FLOAT   =0                      --CS09a    
       ,@n_epltcbm             FLOAT   =0                      --CS09a  
       ,@c_getstorerkey        NVARCHAR(20)                    --CS11
       ,@c_OrderKey_Inv        NVARCHAR(50)                    --CS11
                               
            
                     
           
   CREATE TABLE #TEMP_PackList37      
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
            ODUDEF05         NVARCHAR(50) NULL,   --WL02    
            CTNCOUNT         INT ,      
            PieceQty         INT,      
            TTLWGT           FLOAT,      
            CBM              FLOAT,      
            PCubeUom3        FLOAT,      
            PNetWgt          FLOAT,      
            ShipTitle        NVARCHAR(30) NULL ,                           --CS02      
            TTLPLT           INT ,                                          --CS03      
            CON_Company      NVARCHAR(45) NULL,                             --CS04      
            CON_Address1     NVARCHAR(45) NULL,                             --CS04       
            CON_Address2     NVARCHAR(45) NULL,                             --CS04      
            CON_Address3     NVARCHAR(45) NULL,                             --CS04      
            CON_Address4     NVARCHAR(45) NULL,                             --CS04      
            ORDGRP           NVARCHAR(20) NULL,                             --CS04      
            EPWGT            FLOAT,             
            EPCBM            FLOAT,      
            CLKUPUDF01       NVARCHAR(5)   NULL,                            --CS05      
            Orderkey         NVARCHAR(20)  NULL,                            --CS05          
            lott11           NVARCHAR(250) NULL,                            --CS05       
            Dest             NVARCHAR(250) NULL,                            --CS05                                                                                                              
            PltNo            NVARCHAR(250) NULL,                            --CS05     
            pltwgt           FLOAT,                                         --CS09      
            pltcbm           FLOAT,                                         --CS09    
            Fpltwgt          FLOAT,                                         --CS09      
            Fpltcbm          FLOAT                                          --CS09    
           ,epltwgt          FLOAT                                          --CS09a    
           ,epltcbm          FLOAT                                          --CS09a  
           ,InvoiceNo        NVARCHAR(50)                                   --CS10  
         )      
               
               
        CREATE TABLE #TEMP_CTNTYPE37 (      
         CartonType NVARCHAR(20) NULL,      
         SKU        NVARCHAR(20) NULL,      
         QTY        INT,      
         TotalCtn   INT,      
         TotalQty   INT,      
         CartonNo   INT,      
         Palletkey  NVARCHAR(20) NULL,      
         CLKUPUDF01 NVARCHAR(15) NULL --WL01      
        )      
              
        --CS05 Start      
         CREATE TABLE #TEMP_madein37 (      
         MBOLKey        NVARCHAR(20) NULL,      
         OrderKey       NVARCHAR(20) NULL,      
         SKU            NVARCHAR(20) NULL,      
         lot11          NVARCHAR(50) NULL,      
         C_Company      NVARCHAR(45) NULL      
        )      
              
        --CS05 End      
    
       --CS10 START    
    
        CREATE TABLE #TMP_PLTDET2 (    
        PLTKEY        NVARCHAR(30) NULL,    
        MBOLKEY       NVARCHAR(20) NULL,    
        PLTDETUDF02   NVARCHAR(40) NULL,   --WL03    
        ExtOrdKey     NVARCHAR(50) NULL,    
        C_Company     NVARCHAR(45) NULL )    
    
           
        CREATE TABLE #TMP_PLTDET3 (    
        RN            INT,    
        PLTKEY        NVARCHAR(30) NULL,    
        MBOLKEY       NVARCHAR(20) NULL,    
        PLTDETUDF02   NVARCHAR(30) NULL,   --WL03     
        GrpExtOrdKey  NVARCHAR(500) NULL,    
        C_Company     NVARCHAR(45) NULL   )    
    
        CREATE TABLE #TMP_PLTDETLOGI (    
        PalletNO            INT,    
        PLTKEY              NVARCHAR(30) NULL,    
        MBOLKEY             NVARCHAR(20) NULL,    
        PalletType          NVARCHAR(30) NULL,    
        PLTDETUDF02         NVARCHAR(30) NULL,    
        PLTLength           FLOAT NULL,    
        PLTWidth            FLOAT NULL,    
        PLTHeight           FLOAT NULL,    
        CBM                 FLOAT NULL,    
        PLTGrosswgt         FLOAT NULL,    
        LOC                 NVARCHAR(20) NULL,    
        ExtOrdKey           NVARCHAR(500) NULL,    
        C_Company           NVARCHAR(45) NULL )    
    
        --CS11 START
        SET @c_getstorerkey = ''

        SELECT TOP 1 @c_getstorerkey = ORDERS.Storerkey
        FROM MBOL WITH (NOLOCK)
        JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
        JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)  
        WHERE MBOL.MbolKey = @c_MBOLKey
        --CS11 END

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
       --CS10 END    
              
        SET @c_multisku = 'N'      
        SET @c_PreOrderKey = ''              --CS03      
        SET @n_EPWGT_Value = 0.00            --CS04      
        SET @n_EPCBM_value = 0.00      
        SET @n_lineNo = 1                    --CS04a      
        SET @C_CLKUPUDF01 =''      
        SET @c_madein = ''      
        SET @c_delimiter =','                 --CS05      
        SET @c_lott11 = ''                    --CS05      
        SET @c_company = ''                   --CS05      
        SET @c_UPDATECCOM = 'N'               --CS05    
        SET @c_dest       = ''                --CS06    
        SET @c_PLTNo      = ''                --CS06       
    
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
            /*CS07 START*/    
                --CASE WHEN  ORDERS.facility='YPCN1' THEN ISNULL(S.company,'') ELSE ISNULL(S.B_Company,'') END, --CS02      
                --CASE WHEN  ORDERS.facility='YPCN1' THEN ISNULL(S.Address1,'') ELSE ISNULL(S.B_Address1,'') END AS IDS_Address1,  --CS02      
                --CASE WHEN  ORDERS.facility='YPCN1' THEN ISNULL(S.Address2,'') ELSE ISNULL(S.B_Address2,'') END AS IDS_Address2,  --CS02      
                --CASE WHEN  ORDERS.facility='YPCN1' THEN ISNULL(S.Address3,'') ELSE ISNULL(S.B_Address3,'') END AS IDS_Address3,  --CS02,      
                --CASE WHEN  ORDERS.facility='YPCN1' THEN '' ELSE ISNULL(S.B_Address4,'') END AS IDS_Address4,  --CS02,      
                --CASE WHEN  ORDERS.facility='YPCN1' THEN ISNULL(S.Phone1,'')  ELSE ISNULL(S.B_Phone1,'')  END AS IDS_Phone1,  --CS02     
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
            /*CS07 END*/     
                (ISNULL(S.b_city,'') + SPACE(2) + ISNULL(S.B_state,'') + SPACE(2) +  ISNULL(s.B_zip,'') +      
                 ISNULL(S.B_country,'') ) AS IDS_City,      
                ORDERS.B_Company AS BILLTO_Company,      
                ISNULL(ORDERS.B_Address1,'') AS BILLTO_Address1,      
                ISNULL(ORDERS.B_Address2,'') AS BILLTO_Address2,      
                ISNULL(ORDERS.B_Address3,'') AS BILLTO_Address3,      
                ISNULL(ORDERS.B_Address4,'') AS BILLTO_Address4,      
                LTRIM(ISNULL(ORDERS.B_City,'') + SPACE(2) + ISNULL(ORDERS.B_State,'') + SPACE(2) +      
                ISNULL(ORDERS.B_Zip,'') + SPACE(2) +  ISNULL(ORDERS.B_Country,'')) AS BILLTO_City,      
                /*CS02 start*/      
                CASE WHEN ORDERS.Ordergroup <> 'S01' THEN      
                CASE WHEN ORDERS.facility IN ('WGQAP','BULIM') AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%') THEN  --CS08    
                CASE WHEN ORDERS.c_country = 'HK'  THEN ISNULL(SHK.company,'')      
                WHEN ORDERS.c_country = 'TW'  THEN ISNULL(STW.company,'')      
                ELSE ISNULL(ORDERS.C_Company,'') END      
                ELSE ISNULL(ORDERS.C_Company,'') END       
                ELSE       
                /*CS04 Start*/      
                CASE WHEN ORDERS.type='WR' THEN ORDERS.c_company ELSE '' END      
                END AS ShipTO_Company,      
                /*CS04 End*/      
                CASE WHEN ORDERS.Ordergroup <> 'S01' THEN   --CS04      
                CASE WHEN ORDERS.facility IN ('WGQAP','BULIM') AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%') THEN  --CS08    
                CASE WHEN ORDERS.c_country = 'HK'  THEN ISNULL(SHK.Address1,'')      
                WHEN ORDERS.c_country = 'TW'  THEN ISNULL(STW.Address1,'')      
                ELSE ISNULL(ORDERS.C_Address1,'') END      
                ELSE ISNULL(ORDERS.C_Address1,'') END       
                ELSE      
                ISNULL(ORDERS.C_Address1,'') END AS ShipTO_Address1,      --CS04      
                CASE WHEN ORDERS.Ordergroup <> 'S01' THEN   --CS04      
                CASE WHEN ORDERS.facility IN ('WGQAP','BULIM') AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%') THEN   --CS08     
                CASE WHEN ORDERS.c_country = 'HK'  THEN ISNULL(SHK.Address2,'')      
                WHEN ORDERS.c_country = 'TW'  THEN ISNULL(STW.Address2,'')      
                ELSE ISNULL(ORDERS.C_Address2,'') END      
                ELSE ISNULL(ORDERS.C_Address2,'') END       
                ELSE      
                ISNULL(ORDERS.C_Address2,'') END  AS ShipTO_Address2,    --CS04      
                CASE WHEN ORDERS.Ordergroup <> 'S01' THEN   --CS04      
                CASE WHEN ORDERS.facility IN ('WGQAP','BULIM')  AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%') THEN  --CS08    
                CASE WHEN ORDERS.c_country = 'HK'  THEN ISNULL(SHK.Address3,'')      
                      WHEN ORDERS.c_country = 'TW'  THEN ISNULL(STW.Address3,'')      
                ELSE ISNULL(ORDERS.C_Address3,'') END      
                ELSE ISNULL(ORDERS.C_Address3,'') END       
                ELSE      
                ISNULL(ORDERS.C_Address3,'') END AS ShipTO_Address3,        --CS04      
                CASE WHEN ORDERS.Ordergroup <> 'S01' THEN   --CS04      
                CASE WHEN ORDERS.facility IN ('WGQAP','BULIM')AND ORDERS.c_country IN ('HK','TW')     --CS08    
                     AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%') THEN ''       
                 ELSE ISNULL(ORDERS.C_Address4,'') END       
                 ELSE      
                 ISNULL(ORDERS.C_Address4,'') END AS ShipTO_Address4,       --CS04      
                 /*CS02 End*/      
                 LTRIM(ISNULL(ORDERS.C_City,'') + SPACE(2) + ISNULL(ORDERS.C_State,'') + SPACE(2) +      
                 ISNULL(ORDERS.C_Zip,'') + SPACE(2) +  ISNULL(ORDERS.C_Country,'')) AS ShipTO_City,      
                 ISNULL(ORDERS.C_phone1,'') AS ShipTo_phone1,ISNULL( ORDERS.C_contact1,'') AS ShipTo_contact1,       
                 ISNULL(ORDERS.C_country,'') AS ShipTo_country,  ISNULL(S.country,'') AS From_country,       
                 ORDERS.StorerKey,      
                 ORDERS.Userdefine03 AS ShipMode,      
                 ORDERS.Userdefine01 AS SONo      
                 ,''--ISNULL(PTD.Palletkey,'N/A') AS palletkey                             --CS03      
                 ,CASE WHEN ORDERS.Ordergroup <> 'S01' THEN   --CS04      
                        --CASE WHEN ORDERS.facility='WGQAP' AND ORDERS.c_country IN ('HK','TW')       --CS08 START    
                        --AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%' )    
                  CASE WHEN ORDERS.facility IN ('WGQAP','BULIM') AND ORDERS.c_country IN ('HK','TW')       
                           AND (ORDERS.userdefine05 LIKE 'DDP%' OR ORDERS.userdefine05 LIKE 'FOB%')      --CS08 END     
                  THEN 'Consignee:'       
                        ELSE 'Ship To:' END       
                  ELSE      
                  'Ship To/Notify To:' END AS ShipTitle ,                      --CS02      --CS04      
                  ORDERS.facility,                                         --CS03a       
                  /*CS04 Start*/        
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
                /*CS04 end*/                                                      --CS02      
                /*CS10 START*/
                ,OrderKey_Inv = CASE WHEN @c_ShipType = 'L' THEN ORDERS.Orderkey 
                                     WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'O' THEN  MBOL.Mbolkey 
                                     WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'D' THEN  'D' + MBOL.Mbolkey  
                                     WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'E' THEN  'E' + MBOL.Mbolkey
                                     WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'N' THEN  'N' + MBOL.Mbolkey 
                                     ELSE '' END  
                /*CS10 END*/
              FROM MBOL WITH (NOLOCK)      
              INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)      
              INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)      
              INNER JOIN STORER S WITH (NOLOCK) ON (S.Storerkey = ORDERS.Storerkey)      
              /*CS02 Start*/       
              LEFT JOIN STORER STW WITH (NOLOCK) ON (STW.Storerkey = 'LOGITWDDP')          
              LEFT JOIN STORER SHK WITH (NOLOCK) ON (SHK.Storerkey = 'LOGIHKDDP')         
              /*CS04 Start*/      
              LEFT JOIN STORER MWRHK WITH (NOLOCK) ON (MWRHK.Storerkey = 'LOGISMWRHK')          
              LEFT JOIN STORER MWRTW WITH (NOLOCK) ON (MWRTW.Storerkey = 'LOGISMWRTW')       
              LEFT JOIN STORER MWRAU WITH (NOLOCK) ON (MWRAU.Storerkey = 'LOGISMWRAU')          
              LEFT JOIN STORER MWRNZ WITH (NOLOCK) ON (MWRNZ.Storerkey = 'LOGISMWRNZ')       
              /*CS04 End*/    
              /*CS07 Start*/    
              LEFT JOIN storersodefault SOD WITH (NOLOCK) ON SOD.StorerKey = ORDERS.ConsigneeKey    
              LEFT JOIN STORER SD WITH (NOLOCK) ON (SD.Storerkey = SOD.Door)    
              /*CS07 End*/           
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
                                 @c_ShipMode, @c_SONo, @c_PalletKey,@c_shiptitle,@c_facility,       --CS03a      
                                 @c_Con_Company, @c_Con_Address1, @c_Con_Address2,                  --CS04      
                                 @c_Con_Address3, @c_Con_Address4,@c_OrdGrp,@c_Orderkey_inv         --CS04        --CS10
              
        WHILE @@FETCH_STATUS = 0      
        BEGIN      
           -- Full Carton      
           SET @n_PrevCtnQty = 0      
              
        /*CS03a Start*/         
         IF @c_facility IN ('BULIM','WGQAP','WGQBL') --(WL01) New Facility     
         BEGIN      
           INSERT INTO #TEMP_CTNTYPE37 (CartonType, SKU, QTY, TotalCtn, TotalQty, CartonNo,Palletkey,CLKUPUDF01)                  
            SELECT 'SINGLE' , PD.SKU, SUM(PD.Qty)/COUNT(DISTINCT PD.CartonNo) , COUNT(DISTINCT PD.CartonNo) , SUM(PD.Qty) ,0       
              ,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END  --CS03      
             -- ,CASE WHEN C.UDF01='P' THEN COUNT(DISTINCT CD.palletkey) ELSE 0 END --CS03      
             ,ISNULL(C.UDF01,'')                                                    --CS05      
            FROM PACKHEADER PH WITH (NOLOCK)       
            JOIN PackDetail AS PD WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo       
            /*CS03 Start*/      
            JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=ph.OrderKey    --CS03a      
            JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.caseid = PD.LabelNo AND PLTD.Sku=pd.sku --AND PLTD.StorerKey=ORD.StorerKey   --CS04b      
            JOIN Containerdetail CD WITH (NOLOCK) ON CD.PalletKey=PLTD.PalletKey      
            JOIN Container CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey=ord.MBOLKey     --CS03a      
            LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CONTAINERT' AND C.UDF01='P' AND C.code=CON.ContainerType      
            WHERE PH.orderkey = @c_OrderKey       
            AND PLTD.STORERKEY = @c_StorerKey      
            AND EXISTS(SELECT 1 FROM PackDetail AS pd2 WITH(NOLOCK)       
                        WHERE PD2.PickSlipNo = PH.PickSlipNo       
                        AND   PD2.CartonNo = PD.CartonNo       
                        GROUP BY pd2.CartonNo      
                        HAVING COUNT(DISTINCT PD2.SKU) = 1       
                        )        
            GROUP BY PD.SKU,PD.qty,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END   --MT01      
                     ,ISNULL(C.UDF01,'')        
            UNION ALL      
            --INSERT INTO #TEMP_CTNTYPE37 (CartonType, SKU, QTY, TotalCtn, TotalQty, CartonNo,Palletkey)       
            SELECT 'MULTI' , PD.SKU, SUM(PD.Qty)/COUNT(DISTINCT PD.CartonNo) , 0, SUM(PD.Qty) ,PD.CartonNo       
            ,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END  --CS03      
            --,CASE WHEN C.UDF01='P' THEN COUNT(DISTINCT CD.palletkey) ELSE 0 END                           --CS03      
            ,ISNULL(C.UDF01,'')      
            FROM PACKHEADER PH WITH (NOLOCK)       
            JOIN PackDetail AS PD WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo        
             /*CS03 Start*/      
            JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=ph.OrderKey           --CS03a      
            JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.caseid = PD.LabelNo AND PLTD.Sku=pd.sku--AND PLTD.StorerKey=ORD.StorerKey    --CS04b      
            JOIN Containerdetail CD WITH (NOLOCK) ON CD.PalletKey=PLTD.PalletKey       
            JOIN Container CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey=ord.MBOLKey          --CS03a      
            LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CONTAINERT' AND C.UDF01='P' AND C.code=CON.ContainerType      
            WHERE PH.orderkey = @c_OrderKey       
            AND PLTD.STORERKEY = @c_StorerKey      
            AND NOT EXISTS(SELECT 1 FROM PackDetail AS pd2 WITH(NOLOCK)       
                     WHERE PD2.PickSlipNo = PH.PickSlipNo       
                     AND   PD2.CartonNo = PD.CartonNo      
                     GROUP BY pd2.CartonNo      
                     HAVING COUNT(DISTINCT PD2.SKU) = 1       
                     )        
           GROUP BY PD.CartonNo, PD.SKU,PD.Qty ,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A'  END   --MT01      
                     ,ISNULL(C.UDF01,'')           
         END      
         ELSE IF @c_facility = 'YPCN1'      
         BEGIN      
          INSERT INTO #TEMP_CTNTYPE37 (CartonType, SKU, QTY, TotalCtn, TotalQty, CartonNo,Palletkey,CLKUPUDF01)                  
            SELECT 'SINGLE' , PD.SKU, SUM(PD.Qty)/COUNT(DISTINCT PD.CartonNo) , COUNT(DISTINCT PD.CartonNo) , SUM(PD.Qty) ,0       
              ,'N/A'--CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END  --CS03      
             -- ,CASE WHEN C.UDF01='P' THEN COUNT(DISTINCT CD.palletkey) ELSE 0 END --CS03      
             ,''      
            FROM PACKHEADER PH WITH (NOLOCK)       
            JOIN PackDetail AS PD WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo       
            /*CS03 Start*/      
            JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=ph.OrderKey    --CS03a      
            WHERE PH.orderkey = @c_OrderKey       
            --AND PLTD.STORERKEY = @c_StorerKey      
            AND EXISTS(SELECT 1 FROM PackDetail AS pd2 WITH(NOLOCK)       
                        WHERE PD2.PickSlipNo = PH.PickSlipNo       
                        AND   PD2.CartonNo = PD.CartonNo       
                        GROUP BY pd2.CartonNo      
                        HAVING COUNT(DISTINCT PD2.SKU) = 1       
                        )        
            GROUP BY PD.SKU,PD.Qty --,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END  --MT01      
            UNION ALL      
            --INSERT INTO #TEMP_CTNTYPE37 (CartonType, SKU, QTY, TotalCtn, TotalQty, CartonNo,Palletkey)       
            SELECT 'MULTI' , PD.SKU, SUM(PD.Qty)/COUNT(DISTINCT PD.CartonNo) , 0, SUM(PD.Qty) ,PD.CartonNo       
            ,'N/A'--CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END  --CS03      
            --,CASE WHEN C.UDF01='P' THEN COUNT(DISTINCT CD.palletkey) ELSE 0 END                           --CS03      
            ,''      
            FROM PACKHEADER PH WITH (NOLOCK)       
            JOIN PackDetail AS PD WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo        
             /*CS03 Start*/      
            JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=ph.OrderKey           --CS03a      
            WHERE PH.orderkey = @c_OrderKey       
            --AND PLTD.STORERKEY = @c_StorerKey      
            AND NOT EXISTS(SELECT 1 FROM PackDetail AS pd2 WITH(NOLOCK)       
                     WHERE PD2.PickSlipNo = PH.PickSlipNo       
                     AND   PD2.CartonNo = PD.CartonNo      
                     GROUP BY pd2.CartonNo      
                     HAVING COUNT(DISTINCT PD2.SKU) = 1       
                     )        
            GROUP BY PD.CartonNo, PD.SKU,PD.Qty --,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A'  END   --MT01      
         END          
           /*CS03a end*/         
                 
           --SELECT * FROM #TEMP_CTNTYPE37      
                 
           DECLARE CS_SinglePack CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                 
           SELECT CartonType, SKU, QTY, CASE WHEN cartontype='SINGLE' THEN TotalCtn ELSE Cartonno END,      
           TotalQty, palletkey,CLKUPUDF01      
           FROM #TEMP_CTNTYPE37      
           ORDER BY CartonType desc,CartonNo      
                  
           OPEN CS_SinglePack      
           FETCH NEXT FROM CS_SinglePack INTO @c_CartonType, @c_SKU, @n_CtnQty, @n_CtnCount, @n_PQty,@c_GetPalletKey--,@n_TTLPLT   --CS03      
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
                     ,@c_ODUDEF05  = CASE WHEN OH.C_COUNTRY IN ('IN','KR') THEN ISNULL(SKUINFO.EXTENDEDFIELD05,'')  --WL01    
                                          --WL02 START    
                                          WHEN ISNULL(CL.Short,'N') = 'Y'    
                                          THEN CASE WHEN LEN(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,'')))) > 20    
                                                    THEN SUBSTRING(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))),1,20) + ' ' + SUBSTRING(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,''))),21,LEN(LTRIM(RTRIM(ISNULL(SKUINFO.EXTENDEDFIELD05,'')))))    
                                                    ELSE ISNULL(SKUINFO.EXTENDEDFIELD05,'') END    
                                          --WL02 END    
                                          ELSE '' END--WL01    
              FROM ORDERDETAIL AS O WITH(NOLOCK)      
              INNER JOIN ORDERS AS OH WITH (NOLOCK) ON (O.OrderKey = OH.OrderKey)  --WL01    
              INNER JOIN SKU WITH (NOLOCK) ON (O.StorerKey = SKU.StorerKey AND O.Sku = SKU.Sku)--WL01    
              INNER JOIN SKUINFO WITH (NOLOCK) ON (SKUINFO.StorerKey = SKU.StorerKey AND O.Sku = SKUINFO.Sku AND SKU.SKU = SKUINFO.SKU)--WL01    
              LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.Listname = 'REPORTCFG' AND CL.Code = 'ShowModelNumber' AND CL.Storerkey = OH.Storerkey    
                                                      AND CL.code2 = OH.Facility) --WL02    
              WHERE o.OrderKey = @c_OrderKey       
              AND   o.Sku = @c_sku       
                    
             /*Cs03 Start*/       
             SET @n_TTLPLT = 0      
             SET @c_UDF01 = ''      
             IF @c_PreOrderKey <> @c_OrderKey      
             BEGIN      
                    
              /*CS04a start*/      
              IF @n_lineNo = 1      
              BEGIN      
                SELECT @n_TTLPLT= CASE WHEN C.UDF01='P' THEN COUNT(DISTINCT CD.palletkey)  ELSE 0 END      
                FROM Containerdetail CD WITH (NOLOCK)       
                JOIN Container CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey=@c_MBOLKey      
                JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CONTAINERT' AND C.UDF01='P' AND C.code=CON.ContainerType      
                GROUP BY C.UDF01      
              END      
      
              /*CS04a End*/      
               -- SELECT @n_TTLPLT= CASE WHEN C.UDF01='P' THEN COUNT(DISTINCT CD.palletkey)  ELSE 0 END  --CS04a      
                SELECT @c_UDF01 = C.UDF01      
                FROM PACKHEADER PH WITH (NOLOCK)       
                JOIN PackDetail AS PD WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo        
                JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=ph.OrderKey           --CS03a      
                JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.caseid = PD.LabelNo --AND PLTD.StorerKey=ORD.StorerKey      
                JOIN Containerdetail CD WITH (NOLOCK) ON CD.PalletKey=PLTD.PalletKey       
                JOIN Container CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey=ord.MBOLKey          --CS03a      
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
              
       IF @c_facility in ('WGQAP','YPCN1','WGQBL') --(WL01) New Facility     
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
        JOIN Container CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey AND CON.MBOLKey=ord.MBOLKey          --CS03a      
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
      --CS09 START    
       SET @n_pltcbm= 0    
       SET @n_pltwgt = 0    
       SET @n_Cntvrec = 1    
       SET @n_fpltwgt = 0    
       SET @n_fpltcbm = 0    
    
       SELECT @n_Cntvrec = COUNT(1)    
       FROM  #TMP_PLTDETLOGI--V_PalletDetail_LOGITECH P WITH (NOLOCK)  --CS10     
       WHERE mbolkey = @c_mbolkey    
          
      IF ISNULL(@n_Cntvrec,0) = 0    
      BEGIN    
         SET @n_Cntvrec = 1    
      END    
    
       SELECT @n_pltcbm = sum(P.cbm/@n_Cntvrec)--sum((P.Length*P.Width*P.Height)/@n_Cntvrec)/1000000    
             ,@n_pltwgt = sum(P.PLTGrosswgt/@n_Cntvrec)    
             ,@n_fpltcbm = sum(P.cbm)--sum((P.Length*P.Width*P.Height)/@n_Cntvrec)/1000000    
             ,@n_fpltwgt = sum(P.PLTGrosswgt)    
       FROM #TMP_PLTDETLOGI P--V_PalletDetail_LOGITECH P WITH (NOLOCK)    --CS10    
       WHERE P.mbolkey = @c_mbolkey    
    
     --CS09 END     
                           
              INSERT INTO #TEMP_PackList37      
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
               ,ShipTitle             --CS02      
               ,TTLPLT                --CS03      
               ,CON_Company           --CS04      
               ,CON_Address1          --CS04      
               ,CON_Address2          --CS04      
               ,CON_Address3          --CS04      
               ,CON_Address4          --CS04      
               ,ORDGRP                --CS04      
               ,EPWGT                 --CS04      
               ,EPCBM                 --CS04      
               ,CLKUPUDF01            --CS05      
               ,Orderkey              --CS05      
               ,Lott11                --CS05    
               ,Dest                  --CS06    
               ,PltNo                 --CS06       
               ,pltwgt                --CS09    
               ,pltcbm                --CS09    
               ,Fpltwgt               --CS09    
               ,Fpltcbm               --CS09    
               ,Epltwgt               --CS09a    
               ,Epltcbm               --CS09a    
               ,InvoiceNo             --CS11
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
               @c_GetPalletKey,                         --CS03      
               @c_ODUDEF05,      
               @n_NoOfCarton,      
               @n_PieceQty,      
               @n_TTLWGT,      
               @n_CBM,      
               @n_PCubeUom3,      
               @c_PNetWgt      
              ,@c_shiptitle                             --CS02      
              ,@n_TTLPLT                                --CS03      
              ,@c_CON_Company, @c_CON_Address1          --CS04      
              ,@c_CON_Address2,@c_CON_Address3          --CS04      
              ,@c_CON_Address4,@c_OrdGrp                --CS04      
              ,@n_EPWGT_Value,@n_EPCBM_Value            --CS04      
              ,@C_CLKUPUDF01,@c_orderkey,''             --CS05      
              ,@c_dest,@c_PLTNo                         --CS06    
              ,ISNULL(@n_pltwgt,0),ISNULL(@n_pltcbm,0)  --CS09    
              ,ISNULL(@n_fpltwgt,0),ISNULL(@n_fpltcbm,0)          --CS09    
              ,ISNULL(@n_epltwgt,0), ISNULL(@n_epltcbm,0),
              CASE WHEN  @c_ShipType = 'L' THEN 'A' + @c_OrderKey_Inv ELSE @c_OrderKey_Inv END  --CS09a     --CS11
              )      
                       
           SET @c_PreOrderKey = @c_OrderKey      
           SET @n_lineNo = @n_lineNo + 1                --CS04a      
                 
           DELETE FROM #TEMP_CTNTYPE37      
                        
           FETCH NEXT FROM CS_SinglePack INTO @c_CartonType, @c_SKU, @n_CtnQty, @n_CtnCount, @n_PQty,@c_GetPalletKey--,@n_TTLPLT  --CS03      
                                              ,@C_CLKUPUDF01       --CS05      
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
                                       @c_ShipMode, @c_SONo, @c_PalletKey,@c_shiptitle,@c_facility,    --CS03a      
                                       @c_Con_Company, @c_Con_Address1, @c_Con_Address2,               --CS04      
                                       @c_Con_Address3, @c_Con_Address4,@c_OrdGrp,@c_Orderkey_inv      --CS04  --CS10    
        END      
              
        CLOSE CS_ORDERS_INFO      
        DEALLOCATE CS_ORDERS_INFO      
              
         --CS05 Start      
         DECLARE TH_ORDERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
         SELECT DISTINCT mbolkey,orderkey,sku      
         FROM #TEMP_PackList37      
         WHERE mbolkey=@c_MBOLKey      
         AND ShipTO_Country='TH'      
               
        OPEN TH_ORDERS      
              
       FETCH FROM TH_ORDERS INTO @c_Getmbolkey,@c_GetOrderKey,@c_getsku      
             
             
       WHILE @@FETCH_STATUS = 0      
       BEGIN      
           INSERT INTO #TEMP_madein37      
           (      
            MBOLKey,      
            OrderKey,      
            SKU,      
            lot11,      
            C_Company      
           )      
           SELECT DISTINCT  ORD.mbolkey, ORD.orderkey ,PD.sku,c.Description,ord.C_Company      
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
          
    --SELECT * FROM #TEMP_madein37          
    SET @n_CntRec = 0      
    SET @c_madein = ''      
          
    IF EXISTS (SELECT 1 FROM #TEMP_madein37  WHERE MBOLKey = @c_MBOLKey)      
    BEGIN      
      SET @c_UPDATECCOM = 'Y'               --CS05      
    END      
          
    SELECT @n_CntRec = COUNT(DISTINCT lot11),@c_lott11 = MIN(lot11)      
          ,@c_company=MIN(C_Company)      
    FROM  #TEMP_madein37       
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
         FROM #TEMP_madein37      
         WHERE mbolkey=@c_MBOLKey       
      
               
        OPEN MadeIn_loop      
              
       FETCH FROM MadeIn_loop INTO @c_lott11      
             
       WHILE @@FETCH_STATUS = 0      
       BEGIN      
            
       IF @n_CntRec >=2      
       BEGIN      
        IF @n_lineno >= 2       
        BEGIN      
          SET @c_madein = @c_lott11 + @c_delimiter      
        END      
        ELSE      
         BEGIN      
          SET @c_madein = @c_madein + @c_lott11      
          END       
       END      
           
       SET @n_lineno = @n_lineno - 1      
             
      FETCH FROM MadeIn_loop INTO @c_lott11      
      END      
              
        CLOSE MadeIn_loop      
        DEALLOCATE MadeIn_loop      
    END       
          
          
    UPDATE #TEMP_PackList37      
    SET lott11 = @c_madein      
        ,ShipTO_Company = CASE WHEN  @c_UPDATECCOM = 'Y'  THEN @c_company ELSE ShipTO_Company END   --CS05      
    WHERE MBOLKey = @c_MBOLKey       
          
          
    DELETE FROM #TEMP_madein37      
          
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
  , shiptitle                            --CS02         
  ,TTLPLT                                --CS03       
  ,CON_Company, CON_Address1             --CS04      
  ,CON_Address2,CON_Address3             --CS04      
  ,CON_Address4,ORDGRP                   --CS04      
  ,EPWGT,EPCBM                           --CS04      
  ,CLKUPUDF01                            --CS05      
  --,orderkey      
  ,lott11                                --CS05      
  ,Dest                                  --CS06    
  ,PltNo                                 --CS06    
  ,pltwgt,pltcbm,Fpltwgt,Fpltcbm         --CS09    
  FROM #TEMP_PackList37      
  ORDER BY mbolkey,ExternOrdKey, Rowid, sku, CTNCOUNT DESC*/    
      
  --CS09a START    
  update #temp_Packlist37 set     
  fpltwgt = case when clkupudf01 <>'P'  then ((select sum (ttlwgt) from #temp_Packlist37) + ((select Sum (ttlplt) from #temp_Packlist37)* Epwgt) )else fpltwgt end,    
  fpltcbm = case when clkupudf01 <>'P'  then ((select sum (cbm) from #temp_Packlist37)+ ((select Sum (ttlplt) from #temp_Packlist37)* Epcbm)) else fpltcbm end    
      
  update #temp_Packlist37 set     
  epltwgt = case when clkupudf01 <>'P'  then '0' else fpltwgt - (select sum (ttlwgt) from #temp_Packlist37) end,    
  epltcbm = case when clkupudf01 <>'P'  then '0' else fpltcbm - (select sum (cbm) from #temp_Packlist37)end    
  --CS09a END    
    
  select * from #temp_Packlist37    
  ORDER BY MBOLKey,InvoiceNo
        
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
    InvoiceNo                    --CS11
  FROM #TEMP_PackList37      
  WHERE MBOLKey = @c_MBOLKey      
  AND ORDGRP = 'S01'      
  ORDER BY mbolkey,InvoiceNo,ExternOrdKey,ORDGRP   --CS11a   
        
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
  FROM #TEMP_PackList37      
  WHERE MBOLKey = @c_MBOLKey      
  AND ORDGRP <> 'S01'      
  ORDER BY mbolkey,ExternOrdKey      
        
   GOTO QUIT      
      
QUIT:      
END 

GO