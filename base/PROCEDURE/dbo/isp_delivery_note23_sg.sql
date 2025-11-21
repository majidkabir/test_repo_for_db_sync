SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/*************************************************************************/  
/* Stored Procedure: isp_Delivery_Note23_SG                               */  
/* Creation Date: 24-JUL-2020                                             */  
/* Copyright: IDS                                                         */  
/* Written by: CSCHONG                                                    */  
/*                                                                        */  
/* Purpose:WMS-1761 - SG Logitech Delivery Note Report                    */  
/*                                                                        */  
/*                                                                        */  
/* Called By: report dw = r_dw_delivery_note_23_SG                        */  
/*                                                                        */  
/* PVCS Version: 3.1                                                      */  
/*                                                                        */  
/* Version: 5.4                                                           */  
/*                                                                        */  
/* Data Modifications:                                                    */  
/*                                                                        */  
/* Updates:                                                               */  
/* Date         Author    Ver.  Purposes                                  */  
/* 11-May-2017  CSCHONG   1.0   WMS-1761- Revise Field mapping (CS01)     */  
/* 13-JUN-2017  CSCHONG   1.1   WMS-1761 - Revise Address field (CS02)    */  
/* 30-JUN-2017  CSCHONG   1.2   WMS-2312 - Revise palletkey field (CS03)  */  
/* 27-JUL-2017  CSCHONG   1.3   fix duplicated issue, CN1 process (CS03a) */  
/* 08-AUG-2017  CSCHONG   1.4   WMS-2606 - Revise report layout(CS04)     */  
/* 16-Aug-2017  CSCHONG   1.5   Fix total pallet issue (CS04a)            */  
/* 21-Aug-2017  CSCHONG   1.6   fox totalqty issue (CS04b)                */  
/* 29-Aug-2017  MengTah   1.7   IN00451304-GROUP BY PD.QTY (MT01)         */  
/* 10-Oct-2017  WLCHOOI   1.8   WMS-3172 -Add Facility.Userdefine06 (WL01)*/  
/* 17-Nov-2017  WLCHOOI   1.9   WMS-3443 -Add remarks (WL02)              */  
/* 17-Oct-2018  CSCHONG   2.0   WMS-6053 - revised report logic (CS05)    */  
/* 17-JAN-2019  CSCHONG   2.1   WMS-3995 - revised logic (CS06)           */  
/* 02-MAY-2019  WLCHOOI   2.2   WMS-8807 - Use Codelkup to show harcode   */  
/*                                         text (WL03)                    */  
/* 05-AUG-2019  CSCHONG   2.3   WMS-9969 revised field logic (CS07)       */  
/* 24-JUL-2020  CSCHONG   2.4   WMS-14317 - revised field mapping         */  
/*                              with new datawindow (CS08)                */  
/* 09-SEP-2020  CSCHONG   2.5   WMS-14983 revised sorting rule (CS09)     */  
/* 08-Dec-2020  CSCHONG   2.6   WMS-14983 revised mapping (CS09a)         */  
/* 18-FEB-2021  CSCHONG   2.7   WMS-16133 revised field logic & Performance*/  
/*                              tunning - replace view table to TEMP (CS10) */   
/* 18-MAY-2021  CSCHONG   2.8   WMS-16133 revised print logic (CS11)      */  
/* 16-JUL-2021  CSCHONG   2.9   WMS-16133 revised sorting for report page */  
/*                              break issue (CS12)                         */  
/* 23-JUL-2021  CSCHONG   3.0   WMS-16133 Fix L shiptype sorting (CS12a)  */
/* 10-May-2022  WLChooi   3.1   DevOps Combine Script                     */
/* 10-May-2022  WLChooi   3.1   WMS-19628 Extend Userdefine02 column to   */
/*                              40 (WL04)                                 */
/**************************************************************************/  
  
CREATE PROC [dbo].[isp_Delivery_Note23_SG] (  
    @c_MBOLKey NVARCHAR(21)  
   ,@c_ShipType NVARCHAR(10)   = ''  -- CS05    
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
       ,@c_MBOLKeyBarcode      NVARCHAR(20)  --WL01  
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
       ,@c_GetPalletKey        NVARCHAR(30)                    --CS03  
       ,@n_TTLPLT              INT                             --CS03  
       ,@c_PreOrderKey         NVARCHAR(10)                    --CS03  
       ,@c_ChkPalletKey        NVARCHAR(30)                    --CS03  
       ,@c_facility            NVARCHAR(5)                     --CS03a  
       ,@c_OrdGrp              NVARCHAR(20)                    --CS04  
       ,@n_EPWGT_Value         DECIMAL(6,2)                    --CS04  
       ,@n_EPCBM_Value         DECIMAL(6,2)                    --CS04  
       ,@c_UDF01               NVARCHAR(5)                     --CS04  
       ,@n_lineNo              INT                             --CS04a                                              
       ,@C_CLKUPUDF01          NVARCHAR(15)     --WL02 start  
       ,@C_Lottable11          NVARCHAR(30)     --WL02  
       ,@c_madein              NVARCHAR(250)  
       ,@c_delimiter           NVARCHAR(1)       
       ,@c_GetOrderKey         NVARCHAR(10)        
       ,@c_getsku              NVARCHAR(20)      
       ,@n_CntRec              INT  
       ,@c_company             NVARCHAR(45)  
       ,@c_lott11              NVARCHAR(30)    -- WL02 End  
       ,@c_UPDATECCOM          NVARCHAR(1)     -- WL02  
       ,@c_OrderKey_Inv        NVARCHAR(50)     --CS05  
       ,@c_CLKUDF01            NVARCHAR(60) = '' --WL03  
       ,@c_CLKUDF02            NVARCHAR(60) = '' --WL03  
       ,@n_pltwgt              FLOAT                           --CS08  
       ,@n_pltcbm              FLOAT                           --CS08      
       ,@n_Cntvrec           INT                             --CS08   
       --,@n_fpltwgt             INT                           --CS08  
       ,@n_fpltwgt             FLOAT                           --CS09a  
       ,@n_fpltcbm             FLOAT                           --CS08    
       ,@c_ohroute             NVARCHAR(20)                    --CS09    
       ,@n_epltwgt             FLOAT                           --CS09a  
       ,@n_epltcbm             FLOAT                           --CS09a     
       ,@c_getstorerkey        NVARCHAR(20)                    --CS10  
       ,@c_LocalOrd            NVARCHAR(5)                     --CS11  
  
 CREATE TABLE #TEMP_DelNote23SG  
         (  Rowid            INT IDENTITY(1,1),  
            MBOLKey          NVARCHAR(20) NULL,  
            pmtterm          NVARCHAR(10) NULL,  
            --Lottable11       NVARCHAR(30) NULL,  
            ExtPOKey         NVARCHAR(20) NULL,  
            OHUdf05          NVARCHAR(20) NULL,  
            MBOLKeyBarcode   NVARCHAR(20) NULL, --WL01  
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
            --Currency         NVARCHAR(18) NULL,  
            ShipMode         NVARCHAR(18) NULL,  
            SONo             NVARCHAR(30) NULL,  
            PCaseCnt         INT,  
            Pqty             INT,  
            PGrossWgt        FLOAT,  
            PCubeUom1        FLOAT,  
            PalletKey        NVARCHAR(30) NULL,  
            --ODUDEF05         NVARCHAR(30) NULL,  
            CTNCOUNT         INT ,  
            PieceQty         INT,  
            TTLWGT           FLOAT,  
            CBM              FLOAT,  
            PCubeUom3        FLOAT,  
            PNetWgt          FLOAT,  
            TTLPLT           INT,                   --CS03  
            ORDGRP           NVARCHAR(20) NULL,    --CS04  
            EPWGT            FLOAT,  
            EPCBM            FLOAT,  
            CLKUPUDF01       NVARCHAR(5)    NULL,   --WL02 start  
            Orderkey         NVARCHAR(20)   NULL,  
            lott11           NVARCHAR(250)  NULL, -- WL02 End     
            OrderKey_Inv     NVARCHAR(50) NULL,    --(CS05)   
            pltwgt           FLOAT,                                         --CS08    
            pltcbm           FLOAT,                                         --CS08     
            Fpltwgt          FLOAT,                                         --CS08    
            Fpltcbm          FLOAT                                          --CS08       
           -- OHROUTE          NVARCHAR(20)                                   --CS09  
           ,epltwgt          FLOAT NULL                                     --CS09a             
           ,epltcbm          FLOAT NULL                                     --CS09a  
         )  
  
  
    CREATE TABLE #TEMP_CTHTYPEDelNote23 (  
         CartonType   NVARCHAR(20) NULL,  
         SKU          NVARCHAR(20) NULL,  
         QTY          INT,  
         TotalCtn     INT,  
         TotalQty     INT,  
         CartonNo     INT,  
         Palletkey    NVARCHAR(20) NULL,  
         CLKUPUDF01   NVARCHAR(15) NULL--WL02   
        -- ,Lottable11     NVARCHAR(15) NULL --WL02    
    )  
      
         --WL02 start  
         CREATE TABLE #TEMP_madein23 (  
         MBOLKey        NVARCHAR(20) NULL,  
         OrderKey       NVARCHAR(20) NULL,  
         SKU            NVARCHAR(20) NULL,  
         lot11          NVARCHAR(50) NULL,  
         C_Company      NVARCHAR(45) NULL  
        )  
  
        -- WL02 End  
  
     --CS10 START      
      
        CREATE TABLE #TMP_PLTDET2 (      
        PLTKEY        NVARCHAR(30) NULL,      
        MBOLKEY       NVARCHAR(20) NULL,      
        PLTDETUDF02   NVARCHAR(40) NULL,   --WL04      
        ExtOrdKey     NVARCHAR(50) NULL,      
        C_Company     NVARCHAR(45) NULL )      
      
             
        CREATE TABLE #TMP_PLTDET3 (      
        RN            INT,      
        PLTKEY        NVARCHAR(30) NULL,      
        MBOLKEY       NVARCHAR(20) NULL,      
        PLTDETUDF02   NVARCHAR(40) NULL,   --WL04      
        GrpExtOrdKey  NVARCHAR(500) NULL,      
        C_Company     NVARCHAR(45) NULL   )      
      
        CREATE TABLE #TMP_PLTDETLOGI (      
        PalletNO            INT,      
        PLTKEY              NVARCHAR(30) NULL,      
        MBOLKEY             NVARCHAR(20) NULL,      
        PalletType          NVARCHAR(30) NULL,      
        PLTDETUDF02         NVARCHAR(40) NULL,   --WL04      
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
       --CS10 END    
  
        SET @c_multisku = 'N'  
        SET @n_EPWGT_Value = 0.00            --CS04  
        SET @n_EPCBM_value = 0.00  
        SET @n_lineNo = 1                    --CS04a  
        SET @c_delimiter =','                --WL02  
        SET @c_UPDATECCOM = 'N'              --WL02  
        SET @c_LocalOrd = 'N'                --CS11  
  
        DECLARE CS_ORDERS_INFO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
        SELECT DISTINCT ORDERS.OrderKey,  
                CASE WHEN FACILITY.Userdefine06='Y' THEN 'SH'+ISNULL(MBOL.Mbolkey,'') ELSE ISNULL(MBOL.Mbolkey,'') END AS MBOLKEY, --WL01  
                ORDERS.PmtTerm,  
                ORDERS.ExternPOKey,  
                ORDERS.Userdefine05,  
                CASE WHEN  FACILITY.Userdefine06='Y' THEN 'SH'+ISNULL(MBOL.Mbolkey,'')  ELSE NULL  END as BarcodeValue, --WL01  
                ORDERS.ExternOrderKey,  
            --CS07 START  
                --CASE WHEN  ORDERS.facility='YPCN1' THEN ISNULL(S.company,'') ELSE ISNULL(S.B_Company,'') END, --CS02  
                --CASE WHEN  ORDERS.facility='YPCN1' THEN ISNULL(S.Address1,'') ELSE ISNULL(S.B_Address1,'') END AS IDS_Address1,  --CS02  
                --CASE WHEN  ORDERS.facility='YPCN1' THEN ISNULL(S.Address2,'') ELSE ISNULL(S.B_Address2,'') END AS IDS_Address2,  --CS02  
                --CASE WHEN  ORDERS.facility='YPCN1' THEN ISNULL(S.Address3,'') ELSE ISNULL(S.B_Address3,'') END AS IDS_Address3,  --CS02,  
                -- CASE WHEN  ORDERS.facility='YPCN1' THEN '' ELSE ISNULL(S.B_Address4,'') END AS IDS_Address4,  --CS02,  
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
            --CS07 END  
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
                ,ORDERS.facility                                         --CS03a  
               ,ORDERS.OrderGroup AS OrdGrp                              --CS04  
               --,OrderKey_Inv = CASE WHEN @c_ShipType = 'L' THEN ORDERS.Orderkey ELSE '' END  --(CS05)    --(CS10)  
                --CS10 START  
                 ,OrderKey_Inv = CASE WHEN @c_ShipType = 'L' THEN 'A' + ORDERS.Orderkey   
                                    WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'O' THEN  MBOL.Mbolkey   
                                    WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'D' THEN  'D' + MBOL.Mbolkey    
                                    WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'E' THEN  'E' + MBOL.Mbolkey  
                                    WHEN @c_ShipType = '' AND ORDERS.SpecialHandling = 'N' THEN  'N' + MBOL.Mbolkey   
                                     ELSE '' END    
                --CS10 END  
               ,ORDERS.[route]                                                               --(CS09)    
      FROM MBOL WITH (NOLOCK)  
      INNER JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)  
      INNER JOIN ORDERS WITH (NOLOCK) ON (ORDERS.OrderKey = MBOLDETAIL.OrderKey)  
      INNER JOIN FACILITY WITH (NOLOCK) ON (FACILITY.facility = Orders.facility)--WL01  
      INNER JOIN STORER S WITH (NOLOCK) ON (S.Storerkey = ORDERS.Storerkey)  
      LEFT JOIN PalletDetail PTD WITH (NOLOCK) ON PTD.userdefine03 = ORDERS.mbolkey AND PTD.userdefine04=ORDERS.orderkey  
      /*CS07 Start*/  
      LEFT JOIN storersodefault SOD WITH (NOLOCK) ON SOD.StorerKey = ORDERS.ConsigneeKey  
      LEFT JOIN STORER SD WITH (NOLOCK) ON (SD.Storerkey = SOD.Door)  
      /*CS07 End*/         
      WHERE MBOL.Mbolkey = @c_mbolkey  
      ORDER BY  ORDERS.[route] ,ORDERS.C_Company,ISNULL(ORDERS.C_Address1,''),ISNULL(ORDERS.C_Address2,''),   --(CS09) --(CS12)  
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
  @c_ShipMode, @c_SONo, @c_PalletKey,@c_facility,@c_OrdGrp,       --CS04    --CS03a  
                                 @c_OrderKey_Inv,@c_ohroute                                      --CS09  
  
        WHILE @@FETCH_STATUS = 0  
        BEGIN  
           -- Full Carton  
           SET @n_PrevCtnQty = 0  
          --CS11 START  
          SET @c_LocalOrd ='N'  
          IF EXISTS (SELECT 1 FROM ORDERS OH WITH (NOLOCK)   
                              JOIN CODELKUP C WITH (NOLOCK) ON C.listname='LOGILOCAL' AND C.code = OH.ConsigneeKey  
                              WHERE OH.OrderKey=@c_OrderKey)  
          BEGIN  
                SET @c_LocalOrd = 'Y'  
         END  
  
       --SELECT @c_LocalOrd '@c_LocalOrd'  
         --CS11 END  
  
         IF @c_facility IN ('BULIM','WGQAP','WGQBL')   --CS06  
            BEGIN  
            INSERT INTO #TEMP_CTHTYPEDelNote23 (CartonType, SKU, QTY, TotalCtn, TotalQty, CartonNo,Palletkey,CLKUPUDF01)  
            SELECT 'SINGLE' , PD.SKU, SUM(PD.Qty)/COUNT(DISTINCT PD.CartonNo) , COUNT(DISTINCT PD.CartonNo) , SUM(PD.Qty) ,0  
               ,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END  --CS03  
            ,ISNULL(C.UDF01,'')--WL02  
             -- ,CASE WHEN C.UDF01='P' THEN COUNT(DISTINCT CD.palletkey) ELSE 0 END --CS03  
            FROM PACKHEADER PH WITH (NOLOCK)  
            JOIN PackDetail AS PD WITH (NOLOCK) ON pd.PickSlipNo = ph.PickSlipNo  
            /*CS03 Start*/  
            JOIN ORDERS ORD WITH (NOLOCK) ON ORD.OrderKey=ph.OrderKey    --CS03a  
            JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON PLTD.caseid = PD.LabelNo   AND PLTD.Sku=pd.sku --CS04b  
            LEFT JOIN Containerdetail CD WITH (NOLOCK) ON CD.PalletKey=PLTD.PalletKey                                    --CS11  
            LEFT JOIN Container CON WITH (NOLOCK) ON CON.ContainerKey = CD.ContainerKey  AND CON.MBOLKey=ord.MBOLKey     --CS03a  
            LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = 'CONTAINERT' AND C.UDF01='P' AND C.code=CON.ContainerType  
            --CS11 START   
            LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON C1.LISTNAME = 'LOGILOCAL' AND C1.code = ORD.ConsigneeKey  
            --CS11 END   
            WHERE PH.orderkey = @c_OrderKey  
            AND PLTD.STORERKEY = @c_storerkey  
            AND EXISTS(SELECT 1 FROM PackDetail AS pd2 WITH(NOLOCK)  
                        WHERE PD2.PickSlipNo = PH.PickSlipNo  
                        AND   PD2.CartonNo = PD.CartonNo  
            AND 1 = CASE WHEN @c_LocalOrd='N' AND ISNULL(CON.ContainerKey,'') <> '' THEN 1 WHEN @c_LocalOrd='Y'  THEN 1 ELSE 0 END  
              GROUP BY pd2.CartonNo  
                        HAVING COUNT(DISTINCT PD2.SKU) = 1  
                        )  
            GROUP BY PD.SKU, PD.QTY ,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END  --CS03  --MT01  
                    ,ISNULL(C.UDF01,'')--WL02  
            UNION ALL  
            --INSERT INTO #TEMP_CTHTYPEDelNote23 (CartonType, SKU, QTY, TotalCtn, TotalQty, CartonNo,Palletkey)  
            SELECT 'MULTI' , PD.SKU, SUM(PD.Qty)/COUNT(DISTINCT PD.CartonNo) , 0, SUM(PD.Qty) ,PD.CartonNo  
             ,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END  --CS03  
          ,ISNULL(C.UDF01,'')--WL02  
            --,CASE WHEN C.UDF01='P' THEN COUNT(DISTINCT CD.palletkey) ELSE 0 END                           --CS03  
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
            AND NOT EXISTS(SELECT 1 FROM PackDetail AS pd2 WITH(NOLOCK)  
                     WHERE PD2.PickSlipNo = PH.PickSlipNo  
          AND   PD2.CartonNo = PD.CartonNo  
                     GROUP BY pd2.CartonNo  
                     HAVING COUNT(DISTINCT PD2.SKU) = 1  
                     )  
            GROUP BY PD.CartonNo, PD.SKU, PD.QTY  ,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END  --CS03  --MT01  
                     ,ISNULL(C.UDF01,'')--WL02  
         END  
         ELSE IF @c_facility = 'YPCN1'  
         BEGIN  
            INSERT INTO #TEMP_CTHTYPEDelNote23 (CartonType, SKU, QTY, TotalCtn, TotalQty, CartonNo,Palletkey,CLKUPUDF01)  
            SELECT 'SINGLE' , PD.SKU, SUM(PD.Qty)/COUNT(DISTINCT PD.CartonNo) , COUNT(DISTINCT PD.CartonNo) , SUM(PD.Qty) ,0  
              ,'N/A'--CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END  --CS03  
             -- ,CASE WHEN C.UDF01='P' THEN COUNT(DISTINCT CD.palletkey) ELSE 0 END --CS03  
              ,''--WL02  
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
            GROUP BY PD.SKU, PD.QTY --,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END --MT01  
         UNION ALL  
            --INSERT INTO #TEMP_CTNTYPE37 (CartonType, SKU, QTY, TotalCtn, TotalQty, CartonNo,Palletkey)  
            SELECT 'MULTI' , PD.SKU, SUM(PD.Qty)/COUNT(DISTINCT PD.CartonNo) , 0, SUM(PD.Qty) ,PD.CartonNo  
            ,'N/A'--CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A' END  --CS03  
            --,CASE WHEN C.UDF01='P' THEN COUNT(DISTINCT CD.palletkey) ELSE 0 END                           --CS03  
            ,''--WL02  
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
            GROUP BY PD.CartonNo, PD.SKU, PD.QTY --,CASE WHEN C.UDF01='P' THEN ISNULL(REPLACE(LTRIM(REPLACE(CD.ContainerLineNumber, '0', ' ')), ' ', '0'),'') ELSE 'N/A'  END   --MT01  
         END  
  
           DECLARE CS_SinglePack CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
           SELECT CartonType, SKU, QTY, CASE WHEN cartontype='SINGLE' THEN TotalCtn ELSE Cartonno END,  
           TotalQty, palletkey,clkupudf01                      -- WL02   
           FROM #TEMP_CTHTYPEDelNote23  
           ORDER BY CartonType desc,CartonNo  
  
           OPEN CS_SinglePack  
 FETCH NEXT FROM CS_SinglePack INTO @c_CartonType, @c_SKU, @n_CtnQty, @n_CtnCount, @n_PQty,@c_GetPalletKey,@C_CLKUPUDF01 --,@n_TTLPLT --CS03  --WL02   
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
                    -- ,@c_ODUDEF05  = ISNULL(o.Userdefine05,'')  
              FROM ORDERDETAIL AS o WITH(NOLOCK)  
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
  
                -- SELECT @n_TTLPLT= CASE WHEN C.UDF01='P' THEN COUNT(DISTINCT CD.palletkey)  ELSE 0 END   --CS04a  
                   SELECT @c_UDF01 = C.UDF01                                              --CS04  
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
  
                 IF @c_facility in ('WGQAP','YPCN1','WGQBL')     --CS06  
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
              /*CS03 End*/  
  
              --CS08 START  
       SET @n_pltcbm= 0  
       SET @n_pltwgt = 0  
       SET @n_Cntvrec = 1  
       SET @n_fpltwgt = 0  
       SET @n_fpltcbm = 0  
  
       SELECT @n_Cntvrec = COUNT(1)  
       FROM  #TMP_PLTDETLOGI P --V_PalletDetail_LOGITECH P WITH (NOLOCK)  --CS10       
       WHERE P.mbolkey = @c_mbolkey  
        
      IF ISNULL(@n_Cntvrec,0) = 0  
      BEGIN  
         SET @n_Cntvrec = 1  
      END  
  
      SELECT @n_pltcbm = sum(P.cbm/@n_Cntvrec)--sum((P.Length*P.Width*P.Height)/@n_Cntvrec)/1000000  
             ,@n_pltwgt = sum(P.PLTGrosswgt/@n_Cntvrec)  
             ,@n_fpltcbm = sum(P.cbm)--sum((P.Length*P.Width*P.Height)/@n_Cntvrec)/1000000  
             ,@n_fpltwgt = sum(P.PLTGrosswgt)  
       FROM #TMP_PLTDETLOGI P --V_PalletDetail_LOGITECH P WITH (NOLOCK)    --CS10      
       WHERE P.mbolkey = @c_mbolkey  
  
     --CS08 END   
  
  
              INSERT INTO #TEMP_DelNote23SG  
              (  
               -- Rowid -- this column value is auto-generated  
               MBOLKey,  
               pmtterm,  
               ExtPOKey,  
               OHUdf05,  
               MBOLKeyBarcode,   --WL01  
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
             --   ODUDEF05,  
               CTNCOUNT,  --41  
      PieceQty,  
               TTLWGT,  
               CBM,  
               PCubeUom3,  
               PNetWgt,  
               TTLPLT              --CS03  
               ,ORDGRP             --CS04  
               ,EPWGT              --CS04  
               ,EPCBM              --CS04  
               ,CLKUPUDF01         --WL02   
               ,Orderkey           --WL02   
               ,lott11             --WL02   
               ,OrderKey_Inv       --CS05  
               ,pltwgt             --CS08  
               ,pltcbm             --CS08  
               ,Fpltwgt            --CS08  
               ,Fpltcbm            --CS08   
               ,epltwgt            --CS09a  
               ,epltcbm            --CS09a  
              )  
              VALUES  
              (  
               @c_MBOLKey,  
               @c_pmtterm,  
               @c_ExtPOKey,  
               @c_OHUdf05 ,  
               @c_MBOLKeyBarcode,   --WL01  
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
               @c_GetPalletKey,              --CS03  
              --  @c_ODUDEF05,  
               @n_NoOfCarton,  --41  
               @n_PieceQty,  
               @n_TTLWGT,  
               @n_CBM,  
               @n_PCubeUom3,  
               @c_PNetWgt  
               ,@n_TTLPLT                       --CS03  
               ,@c_OrdGrp                       --CS04  
               ,@n_EPWGT_Value,@n_EPCBM_Value   --CS04  
               ,@C_CLKUPUDF01,@c_OrderKey,''    --WL02   
               ,@c_OrderKey_Inv                 --CS05  
               ,ISNULL(@n_pltwgt,0),ISNULL(@n_pltcbm,0)             --CS08  
               ,ISNULL(@n_fpltwgt,0),ISNULL(@n_fpltcbm,0)           --CS08  
               ,ISNULL(@n_epltwgt,0),ISNULL(@n_epltcbm,0)           --CS09a  
              )  
  
               SET @c_PreOrderKey = @c_OrderKey  
               SET @n_lineNo = @n_lineNo + 1                --CS04a  
  
  
               DELETE #TEMP_CTHTYPEDelNote23  
  
           FETCH NEXT FROM CS_SinglePack INTO @c_CartonType, @c_SKU, @n_CtnQty, @n_CtnCount, @n_PQty,@c_GetPalletKey,@C_CLKUPUDF01--,@n_TTLPLT  --CS03  --WL02   
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
                                 @c_ShipMode, @c_SONo, @c_PalletKey,@c_facility,@c_OrdGrp       --CS04    --CS03a  
                                ,@c_OrderKey_Inv,@c_ohroute                                      --CS09  --CS05  
  
        END  
  
        CLOSE CS_ORDERS_INFO  
        DEALLOCATE CS_ORDERS_INFO  
  
        -- WL02 start  
        DECLARE TH_ORDERS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT DISTINCT mbolkey,orderkey,sku  
         FROM #TEMP_DelNote23SG  
         WHERE mbolkey=@c_MBOLKey  
         AND ShipTO_Country='TH'  
           
        OPEN TH_ORDERS  
          
       FETCH FROM TH_ORDERS INTO @c_Getmbolkey,@c_GetOrderKey,@c_getsku  
         
         
       WHILE @@FETCH_STATUS = 0  
       BEGIN  
            INSERT INTO #TEMP_madein23  
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
      
    IF EXISTS (SELECT 1 FROM #TEMP_madein23  WHERE MBOLKey = @c_MBOLKey)  
    BEGIN  
      SET @c_UPDATECCOM = 'Y'               --WL02  
    END  
      
    SELECT @n_CntRec = COUNT(DISTINCT lot11),@C_Lottable11 = MIN(lot11)  
          ,@c_company=MIN(C_Company)  
    FROM  #TEMP_madein23   
    WHERE MBOLKey = @c_MBOLKey  
      
    IF @n_CntRec = 1  
    BEGIN  
      SET @c_madein = @C_Lottable11  
    END  
    ELSE  
    BEGIN  
         DECLARE MadeIn_loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT DISTINCT lot11  
         FROM #TEMP_madein23  
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
       UPDATE #TEMP_DelNote23SG  
       SET lott11 = @c_madein  
       ,ShipTO_Company = @c_company  --WL02  
       WHERE MBOLKey = @c_MBOLKey   
    END  
      
    DELETE FROM #TEMP_madein23  
    -- WL02 End  
  
      
    --WL03 Start  
    SELECT @c_CLKUDF01 = CLK.UDF01  
          ,@c_CLKUDF02 = CLK.UDF02  
    FROM CODELKUP CLK (NOLOCK)  
    WHERE LISTNAME = 'LOGTHSHIP' AND Storerkey = @c_Storerkey  
    --WL03 End  
  
    --CS09a START  
    update #TEMP_DelNote23SG set   
    fpltwgt = case when CLKUPUDF01 <>'P'  then ((select sum (ttlwgt) from #TEMP_DelNote23SG) + ((select Sum (ttlplt) from #TEMP_DelNote23SG)* Epwgt) )else fpltwgt end,  
    fpltcbm = case when CLKUPUDF01 <>'P'  then ((select sum (cbm) from #TEMP_DelNote23SG)+ ((select Sum (ttlplt) from #TEMP_DelNote23SG)* Epcbm)) else fpltcbm end  
    
    update #TEMP_DelNote23SG set   
    epltwgt = case when CLKUPUDF01 <>'P'  then '0' else fpltwgt - (select sum (ttlwgt) from #TEMP_DelNote23SG) end,  
    epltcbm = case when CLKUPUDF01 <>'P'  then '0' else fpltcbm - (select sum (cbm) from #TEMP_DelNote23SG)end  
  
  
  --CS09a END  
  
      SELECT  
       Rowid  
      , MBOLKey  
      , pmtterm  
      , ExtPOKey  
      , OHUdf05  
      , MBOLKeyBarcode --WL01  
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
      --, ODUDEF05  
      , CTNCOUNT  
      , PieceQty  
      , ROUND(TTLWGT, 2) AS TTLWGT  
      , ROUND(CBM, 2) AS CBM  
      , PCubeUom3  
      , PNetWgt           
      , TTLPLT                   --CS03   
      , ORDGRP                   --CS04  
      , EPWGT,EPCBM  
      , CLKUPUDF01  
      , Lott11--WL02      
      , OrderKey_Inv               --CS05  
      , ShipType = @c_ShipType   --CS05   
      , InvoiceNo = OrderKey_Inv --CASE WHEN OrderKey_Inv = '' THEN MBOLKey ELSE 'A' + RTRIM(OrderKey_Inv) END  --CS05  --CS10  
      , CLKUDF01 = ISNULL(@c_CLKUDF01,'') --WL03  
      , CLKUDF02 = ISNULL(@c_CLKUDF02,'') --WL03  
     ,pltwgt as pltwgt,pltcbm as pltcbm                      --CS08   
      ,fpltwgt as fpltwgt,fpltcbm as fpltcbm                 --CS09   
      , epltwgt as epltwgt , epltcbm as epltcbm              --CS09a  
      FROM #TEMP_DelNote23SG  
      --ORDER BY mbolkey,ExternOrdKey, Rowid, sku, CTNCOUNT DESC   
      --ORDER BY Rowid --CS12  
      ORDER BY CASE WHEN @c_ShipType = 'L' THEN Rowid END                                            --CS12a
              , OrderKey_Inv , CASE WHEN @c_ShipType = '' THEN Rowid END                             --CS12a
              ,ShipTO_Company,ShipTO_Address1,ShipTO_Address2,ShipTO_Address3  
              --,CASE WHEN @c_ShipMode = 'L' THEN OrderKey_Inv END  
                 
  
      
  --select * from #TEMP_DelNote23SG  
  
  
END  


GO