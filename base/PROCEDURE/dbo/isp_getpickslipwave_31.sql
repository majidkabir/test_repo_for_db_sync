SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store Procedure:  isp_GetPickSlipWave_31                             */    
/* Creation Date: 28-Jun-2021                                           */    
/* Copyright: LFL                                                       */    
/* Written by: WLChooi                                                  */    
/*                                                                      */    
/* Purpose: WMS-17382 - [TW] New_JJCON_RCM Wave PickSlip                */    
/*          Modify from r_dw_print_wave_pickslip_31                     */    
/*                                                                      */    
/* Called By: r_dw_print_wave_pickslip_31                               */    
/*                                                                      */    
/* GitLab Version: 1.1                                                  */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date        Author   ver. Purposes                                   */    
/* 2021-08-03  WLChooi  1.1  Fix - Use MAX(ORDERS.ROUTE) (WL01)         */    
/* 2021-10-21  Mingle   1.2  Modify sorting(ML01)                       */    
/* 2021-12-02  WLChooi  1.2  DevOps Combine Script                      */    
/* 2021-12-02  WLChooi  1.2  Performance Tuning (WL02)                  */  
/* 2023-04-03  CSCHONG  1.3  WMS-22061 revised grouping (CS01)          */    
/************************************************************************/    
CREATE   PROC [dbo].[isp_GetPickSlipWave_31] (    
      @c_wavekey       NVARCHAR(10)    
    , @c_Type          NVARCHAR(5) = 'D1'    
    , @c_Orderkey      NVARCHAR(10) = ''    
    , @c_UserDefine02  NVARCHAR(18) = ''    
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE  @n_continue             INT,    
            @c_errmsg               NVARCHAR(255),    
            @b_success              INT,    
            @n_err                  INT,    
            @n_starttcnt            INT,    
            @n_pickslips_required   INT,    
            @c_PickHeaderKey        NVARCHAR(10),    
            @c_FirstTime            NVARCHAR(1),    
            @c_PrintedFlag          NVARCHAR(1),     
            @c_SKUGROUP             NVARCHAR(10),       
            @n_Qty                  INT,                
            @c_StorerKey            NVARCHAR(15),       
            @c_PickSlipNo           NVARCHAR(10),       
            @c_VASLBLValue          NVARCHAR(10),       
            @c_pickgrp              NVARCHAR(1),        
            @c_getUdf01             NVARCHAR(100),      
            @c_getUdf02             NVARCHAR(100),      
            @c_ordudf05             NVARCHAR(20),       
            @c_udf01                NVARCHAR(5),                                              
            @c_getorderkey          NVARCHAR(10),       
            @c_condition            NVARCHAR(100),      
            @c_ExecStatements       NVARCHAR(4000),     
            @c_ExecAllStatements    NVARCHAR(4000),     
            @c_ExecArguments        NVARCHAR(4000),     
            @c_CSKUUDF04            NVARCHAR(30),    
            @c_UpdPickHKey          NVARCHAR(10),   --WL02        
            @c_Short                NVARCHAR(10)    --CL01
                
   SET @c_udf01 = ''            
    
   SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''    

   -- CL01
    SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey    
    FROM PICKHEADER WITH (NOLOCK)    
    JOIN ORDERS WITH (NOLOCK) ON (PICKHEADER.OrderKey = ORDERS.OrderKey)    
    WHERE PICKHEADER.Wavekey = @c_wavekey    
    AND PICKHEADER.[Zone] = '8'    

    Select @c_Short = Isnull(Short,'N') 
    FROM Codelkup (NoLock) 
    WHERE Listname = 'REPORTCFG' 
    AND Long = 'r_dw_print_wave_pickslip_31' And Storerkey = @c_StorerKey And Code = 'SortByBUSR9'
   -- CL01


   IF @c_Type = 'D2'    
   BEGIN    
      SELECT @c_WaveKey    
            ,SKU.SKUGROUP     
            ,SUM(PICKDETAIL.Qty) Qty    
      FROM PICKDETAIL (NOLOCK)     
      JOIN ORDERS (NOLOCK) ON (ORDERS.Orderkey = Pickdetail.Orderkey)     
      JOIN SKU (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku)     
      JOIN ORDERDETAIL (NOLOCK) ON (ORDERDETAIL.OrderKey = ORDERS.OrderKey 
                                AND ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber AND ORDERDETAIL.SKU = PICKDETAIL.SKU)    
      WHERE (ORDERS.UserDefine09 = @c_WaveKey)     
      AND (ORDERS.Orderkey = @c_orderkey)    
      GROUP BY SKU.SKUGROUP     
   END    
   ELSE IF @c_Type = 'D3'    
   BEGIN    
      SELECT MAX(ORDERS.[Route]),   --WL01     
             Wave.AddDate,     
             WAVE.WaveKey,     
             PICKDETAIL.LOC,     
             PICKDETAIL.SKU,      
             SKU.DESCR,      
             PACK.CaseCnt,     
             SUM(PICKDETAIL.Qty) AS Qty,     
             LOC.LogicalLocation,    
             LOTATTRIBUTE.Lottable02,     
             CASE WHEN ISNULL(SC.Svalue,'') = '1' AND SKU.Sku <> SKU.RetailSku AND ISNULL(SKU.RetailSku,'') <> '' THEN     
                      ISNULL(SKU.RetailSku,'')    
             ELSE '' END AS RetailSku,    
             CONVERT(NVARCHAR(10),LOTATTRIBUTE.Lottable04,126)  AS Lottable04    
             ,OD.UserDefine03    
             ,ISNULL(CS1.UDF02,'') AS PalletHi    
             ,ISNULL(CS1.UDF03,'') AS PalletTi         
             ,ISNULL(OD.UserDefine02,'') AS UserDefine02    
             --,ORDERS.ORDERKEY    
             --,SKU.SKU     
             --,CASE WHEN (SELECT COUNT(SKU) FROM ORDERDETAIL (NOLOCK) WHERE Orderkey = ORDERS.OrderKey AND SKU = SKU.SKU) > 1 THEN '*' ELSE '' END AS CountUDF03Flag    
             ,CASE WHEN LEFT(OD.UserDefine02,1) = '*' THEN '*' ELSE '' END AS UDF02Flag   
             ,Case When @c_Short = 'Y' Then sku.busr9 Else '' End AS SBUSR9                     --CS01                    
      FROM ORDERS (NOLOCK)      
      JOIN PICKDETAIL (NOLOCK) ON PICKDETAIL.OrderKey = ORDERS.OrderKey     
      JOIN LOC (NOLOCK) ON LOC.LOC = PICKDETAIL.LOC     
      JOIN WAVEDETAIL (NOLOCK) ON WAVEDETAIL.OrderKey = ORDERS.OrderKey     
      JOIN WAVE (NOLOCK) ON WAVE.WaveKey = WAVEDETAIL.WaveKey     
      JOIN SKU (NOLOCK) ON SKU.StorerKey = PICKDETAIL.StorerKey AND SKU.SKU = PICKDETAIL.SKU     
      JOIN PACK (NOLOCK) ON PACK.PackKey = SKU.PackKey     
      JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot    
      LEFT JOIN CODELKUP C (NOLOCK) ON C.LISTNAME = 'LOCCASHOW' AND C.Storerkey = ORDERS.storerkey    
      LEFT JOIN CODELKUP C1 (NOLOCK) ON C1.LISTNAME = 'REPORTCFG' AND C1.Long = 'r_dw_print_wave_pickslip_31'     
                                          AND C1.Code = 'SHOWPICKLOC' AND c1.Storerkey = ORDERS.storerkey    
               AND  C1.short = ORDERS.[Stop]    
      LEFT JOIN v_storerconfig2 SC (NOLOCK) ON ORDERS.Storerkey = SC.Storerkey AND SC.Configkey = 'DELNOTE06_RSKU'      
      JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = PICKDETAIL.OrderKey AND OD.OrderLineNumber = PICKDETAIL.OrderLineNumber    
                                  AND OD.SKU = PICKDETAIL.SKU    
      LEFT OUTER JOIN CONSIGNEESKU CS1 (NOLOCK) ON (CS1.Consigneekey = ORDERS.ConsigneeKey)    
                                                    AND (CS1.Sku = OD.Sku)    
                                                    AND (CS1.StorerKey = ORDERS.StorerKey)     
      WHERE WAVE.WaveKey = @c_WaveKey       
      AND 1 = CASE WHEN ISNULL(C1.short,'') <> '' AND ISNULL(C.code,'') <> ''     
                        AND C.code=LOC.LocationCategory AND LOC.LocLevel>CONVERT(INT,C.UDF02) THEN 1    
             WHEN ISNULL(C1.short,'N') = 'N'THEN 1 ELSE 0 END    
      GROUP BY --ORDERS.[Route],   --WL01     
               Wave.AddDate,     
               WAVE.WaveKey,     
               PICKDETAIL.LOC,     
               PICKDETAIL.SKU,      
               SKU.DESCR,      
               PACK.CaseCnt,     
               LOC.LogicalLocation,    
               LOTATTRIBUTE.Lottable02,     
               CASE WHEN ISNULL(SC.Svalue,'') = '1' AND SKU.Sku <> SKU.RetailSku AND ISNULL(SKU.RetailSku,'') <> '' THEN     
                        ISNULL(SKU.RetailSku,'')    
               ELSE '' END,    
               CONVERT(NVARCHAR(10),LOTATTRIBUTE.Lottable04,126)      
               ,OD.UserDefine03    
               ,ISNULL(CS1.UDF02,'')     
               ,ISNULL(CS1.UDF03,'')          
               ,ISNULL(OD.UserDefine02,'')    
               --,ORDERS.ORDERKEY    
               --,SKU.SKU    
               ,CASE WHEN LEFT(OD.UserDefine02,1) = '*' THEN '*' ELSE '' END    
               , Case When @c_Short = 'Y' Then sku.busr9 Else '' End                        --CS01  CL01
                                   
      --ORDER BY ISNULL(OD.UserDefine02,''), OD.UserDefine03 ,PICKDETAIL.SKU, LOTATTRIBUTE.Lottable02 ,convert(nvarchar(10),LOTATTRIBUTE.Lottable04,126)     
      ORDER BY  Case When @c_Short = 'Y' Then sku.busr9 Else '' End ,   CASE WHEN LEFT(OD.UserDefine02,1) = '*' THEN '*' ELSE '' END Desc ,     --CL01                                                         --CS01 --CL01  
               ISNULL(OD.UserDefine02,''),OD.UserDefine03,PICKDETAIL.SKU,LOTATTRIBUTE.Lottable02,CONVERT(NVARCHAR(10),LOTATTRIBUTE.Lottable04,126)   --ML01   
   END    
   ELSE    
   BEGIN   --@c_Type = 'D1'    
      CREATE TABLE #TEMP_PICK    
      ( PickSlipNo        NVARCHAR(10) NULL,    
        OrderKey          NVARCHAR(10),    
        ExternOrderkey    NVARCHAR(50),     
        WaveKey           NVARCHAR(10),    
        StorerKey         NVARCHAR(15),    
        InvoiceNo         NVARCHAR(10),    
        [Route]           NVARCHAR(10) NULL,    
        RouteDescr        NVARCHAR(60) NULL,    
        ConsigneeKey      NVARCHAR(15) NULL,    
        C_Company         NVARCHAR(45) NULL,    
        C_Addr1           NVARCHAR(45) NULL,    
        C_Addr2           NVARCHAR(45) NULL,    
        C_Addr3           NVARCHAR(45) NULL,    
        C_PostCode        NVARCHAR(18) NULL,    
        C_City            NVARCHAR(45) NULL,    
        Sku               NVARCHAR(20) NULL,    
        SkuDescr          NVARCHAR(60) NULL,    
        Lot               NVARCHAR(10),    
        Lottable01        NVARCHAR(18) NULL, -- Batch No    
        Lottable04        NVARCHAR(20) NULL, -- Expiry Date    
        Qty               INT,           -- PickDetail.Qty    
        Loc               NVARCHAR(10) NULL,    
        MasterUnit        INT,    
        LowestUOM         NVARCHAR(10),    
        CaseCnt           INT,    
        InnerPack         INT,    
        Capacity          FLOAT,    
        GrossWeight       FLOAT,    
        PrintedFlag       NVARCHAR(1),    
        Notes1            NVARCHAR(60) NULL,    
        Notes2            NVARCHAR(60) NULL,    
        Lottable02        NVARCHAR(18) NULL,     
        DeliveryNote      NVARCHAR(20) NULL,     
        SKUGROUP          NVARCHAR(10) NULL,     
        SkuGroupQty       INT,                   
        DeliveryDate      NVARCHAR(20) NULL,         
        OrderGroup        NVARCHAR(20) NULL,     
        scanserial        NVARCHAR(30) NULL,     
        LogicalLoc        NVARCHAR(18) NULL,     
        Lottable03        NVARCHAR(18) NULL,     
        LabelFlag         NVARCHAR(10) NULL,     
        RetailSku         NVARCHAR(20) NULL,    
        Internalflag      NVARCHAR(10) NULL,     
        scancaseidflag    NVARCHAR(20) NULL,     
        showbarcodeflag   NVARCHAR(1) NULL,         
        UDF01             NVARCHAR(5) NULL,      
        OHUDF04           NVARCHAR(20) NULL,     
        showfield         NVARCHAR(1) NULL,         
        ODUDF05           NVARCHAR(5) NULL,      
        showbuyerpo       NVARCHAR(1) NULL,         
        CSKUUDF04         NVARCHAR(30) NULL,    
        UserDefine03      NVARCHAR(50) NULL,    
        PalletHi          NVARCHAR(60) NULL,    
        PalletTi          NVARCHAR(60) NULL,    
        ODNotes           NVARCHAR(250) NULL,    
        UserDefine02      NVARCHAR(18) NULL,    
        CountUDF03Flag    NVARCHAR(10) NULL ,  
        SBUSR9            NVARCHAR(30) NULL,    --CS01  
        UDF02Flag         NVARCHAR(10) NULL     --CS01   
   )    
          
      -- Check if wavekey existed    
      IF EXISTS(SELECT 1 FROM PICKHEADER (NOLOCK)    
                WHERE WaveKey = @c_wavekey    
                AND   [Zone] = '8')    
      BEGIN    
         SELECT @c_FirstTime = 'N'    
         SELECT @c_PrintedFlag = 'Y'    
      END    
      ELSE    
      BEGIN    
         SELECT @c_FirstTime = 'Y'    
         SELECT @c_PrintedFlag = 'N'    
      END    
          
      --WL02 S    
      DECLARE CUR_UPDATE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT DISTINCT PH.Pickheaderkey    
      FROM PICKHEADER PH (NOLOCK)    
      WHERE PH.WaveKey = @c_wavekey    
      AND [Zone] = '8'    
      AND PickType = '0'    
          
      OPEN CUR_UPDATE    
          
      FETCH NEXT FROM CUR_UPDATE INTO @c_UpdPickHKey    
          
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         BEGIN TRAN    
         -- Uses PickType as a Printed Flag    
         UPDATE PICKHEADER WITH (ROWLOCK)    
         SET PickType = '1',    
             TrafficCop = NULL    
         WHERE WaveKey = @c_wavekey    
         AND [Zone] = '8'    
         AND PickType = '0'    
         AND PickHeaderKey = @c_UpdPickHKey   --WL02    
             
         SELECT @n_err = @@ERROR    
         IF @n_err <> 0    
         BEGIN    
            SELECT @n_continue = 3    
            IF @@TRANCOUNT >= 1    
            BEGIN    
               ROLLBACK TRAN    
               GOTO FAILURE    
            END    
         END    
         ELSE    
         BEGIN    
            IF @@TRANCOUNT > 0    
            BEGIN    
               COMMIT TRAN    
            END    
            ELSE    
            BEGIN    
               SELECT @n_continue = 3    
               ROLLBACK TRAN    
               GOTO FAILURE    
            END    
         END    
          
         FETCH NEXT FROM CUR_UPDATE INTO @c_UpdPickHKey    
      END    
      CLOSE CUR_UPDATE    
      DEALLOCATE CUR_UPDATE    
      --WL02 E    
          
      SELECT TOP 1 @c_Storerkey = ORDERS.Storerkey    
      FROM PICKHEADER WITH (NOLOCK)    
      JOIN ORDERS WITH (NOLOCK) ON (PICKHEADER.OrderKey = ORDERS.OrderKey)    
      WHERE PICKHEADER.Wavekey = @c_wavekey    
      AND PICKHEADER.[Zone] = '8'    
          
      SELECT @c_VASLBLValue = SValue    
      FROM STORERCONFIG WITH (NOLOCK)    
      WHERE Storerkey = @c_Storerkey    
      AND Configkey = 'WAVEPICKSLIP31_VASLBL'    
          
      SELECT @c_pickgrp = CASE WHEN ISNULL(Code,'') <> '' THEN 'Y' ELSE 'N' END    
      FROM CODELKUP  WITH (NOLOCK)    
      WHERE Code = 'PICKPGRP'     
      AND Listname = 'REPORTCFG'     
      AND Long = 'r_dw_print_wave_pickslip_31'    
      AND ISNULL(Short,'') <> 'N'    
      AND Storerkey = @c_Storerkey    
          
      BEGIN TRAN    
          
      -- Select all records into temp table    
      INSERT INTO #TEMP_PICK    
      SELECT (SELECT PICKHEADER.PickHeaderKey FROM PICKHEADER (NOLOCK)    
               WHERE PICKHEADER.Wavekey = @c_wavekey    
               AND PICKHEADER.OrderKey = ORDERS.OrderKey    
               AND PICKHEADER.[Zone] = '8'),    
      ORDERS.Orderkey,    
      ORDERS.ExternOrderkey,    
      WAVEDETAIL.WaveKey,    
      ISNULL(ORDERS.StorerKey, ''),    
      ISNULL(ORDERS.Invoiceno, ''),    
      ISNULL(ORDERS.[Route], ''),    
      ISNULL(ROUTEMASTER.Descr, ''),    
      ISNULL(dbo.fnc_RTrim(ORDERS.ConsigneeKey), ''),    
      ISNULL(dbo.fnc_RTrim(ORDERS.C_Company), ''),    
      ISNULL(dbo.fnc_RTrim(ORDERS.C_Address1), ''),    
      ISNULL(dbo.fnc_RTrim(ORDERS.C_Address2), ''),    
      ISNULL(dbo.fnc_RTrim(ORDERS.C_Address3), ''),    
      ISNULL(dbo.fnc_RTrim(ORDERS.C_Zip), ''),    
      ISNULL(dbo.fnc_RTrim(ORDERS.C_City), ''),    
      SKU.Sku,    
        CASE WHEN ISNULL(CL4.Code,'') <> '' AND ISNULL(SKU.Notes1,'') <> '' THEN SKU.Notes1 ELSE ISNULL(SKU.Descr,'') END AS SkuDescr,       
      CASE WHEN @c_pickgrp <> 'Y' THEN PICKDETAIL.Lot ELSE '' END as Lot,    
      ISNULL(LOTATTRIBUTE.Lottable01, ''),    
      ISNULL(CONVERT(NVARCHAR(10), LOTATTRIBUTE.Lottable04, 111), '01/01/1900'),    
      SUM(PICKDETAIL.Qty) AS QTY,    
      ISNULL(PICKDETAIL.Loc, ''),    
      ISNULL(PACK.Qty, 0) AS MasterUnit,    
      ISNULL(PACK.PackUOM3, '') AS LowestUOM,    
      ISNULL(PACK.CaseCnt, 0),    
      ISNULL(PACK.InnerPack, 0),    
      ISNULL(ORDERS.Capacity, 0.00),    
      ISNULL(ORDERS.GrossWeight, 0.00),    
      @c_PrintedFlag,    
      CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, '')) AS Notes1,    
      CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')) AS Notes2,    
      ISNULL(LOTATTRIBUTE.Lottable02, '') Lottable02,      
      CASE WHEN ISNULL(CL6.Code,'') = '' OR ISNULL(CL6.Code,'') = 'N' THEN ISNULL(Orders.DeliveryNote,'')     
       ELSE ISNULL(orders.buyerpo,'') END DeliveryNote,    
      SKU.SKUGROUP,                                        
      0,                                                   
      CONVERT(NVARCHAR(10), ORDERS.DeliveryDate, 111),   --ORDERS.DeliveryDate,                                 
      ORDERS.OrderGroup,                                   
      CASE WHEN SKU.SUSR4 = 'SSCC' THEN    
                 '**Scan Serial No** '    
                ELSE    
                ''    
      END,    
      ISNULL(LOC.LogicalLocation,''),    
      CASE WHEN ISDATE(ISNULL(LOTATTRIBUTE.Lottable03, '')) = 1 THEN CONVERT(NVARCHAR(10), LOTATTRIBUTE.Lottable03, 111) ELSE ISNULL(LOTATTRIBUTE.Lottable03, '') END    
      ,CASE WHEN  @c_VASLBLValue = '1' AND CS.Sku = PICKDETAIL.Sku THEN ISNULL(RTRIM(ST.SUSR5),'')    
                                    ELSE '' END,    
      CASE WHEN ISNULL(SC.Svalue,'') = '1' AND SKU.Sku <> SKU.RetailSku AND ISNULL(SKU.RetailSku,'') <> '' THEN    
                   ISNULL(SKU.RetailSku,'')    
      ELSE '' END AS RetailSku    
      ,SKU.SKUGROUP AS Internalflag    
      ,CASE WHEN MAX(ISNULL(CL1.Code,'')) = '' AND MIN(PICKDETAIL.UOM) IN (1,2) AND MAX(ISNULL(CL3.Code,'')) <> '' THEN '*' ELSE '' END AS scancaseidflag    
      ,CASE WHEN ISNULL(CL2.Code,'') <> '' THEN 'Y' ELSE 'N' END AS showbarcodeflag    
      ,'' AS udf01                                                                     
      ,ISNULL(ORDERS.UserDefine04,'')                                                  
        ,CASE WHEN ISNULL(CL5.Code,'') <> '' THEN 'Y' ELSE 'N' END AS showfield      
      ,ISNULL(substring(OD.userdefine05,1,1),'') AS ODUDF05                        
      ,CASE WHEN ISNULL(CL6.Code,'') <> '' THEN 'Y' ELSE 'N' END AS showbuyerpo    
      ,''  AS cskuudf04    
      ,OD.UserDefine03     
      ,ISNULL(CS1.UDF02,'') AS PalletHi    
      ,ISNULL(CS1.UDF03,'') AS PalletTi    
      ,ISNULL(OD.Notes,'') AS ODNotes    
      ,ISNULL(OD.UserDefine02,'') AS UserDefine02    
      ,CASE WHEN (SELECT COUNT(SKU) FROM ORDERDETAIL (NOLOCK) WHERE Orderkey = ORDERS.OrderKey AND SKU = SKU.SKU) > 1 THEN '*' ELSE '' END AS CountUDF03Flag    
      ,Case When @c_Short = 'Y' Then sku.busr9 Else '' End  AS SBUSR9                                         --CS01  CL01
      ,CASE WHEN LEFT(OD.UserDefine02,1) = '*' THEN '*' ELSE '' END AS UDF02Flag    --CS01  
      FROM PICKDETAIL (NOLOCK)    
      JOIN ORDERS (NOLOCK) ON (PICKDETAIL.Orderkey = ORDERS.Orderkey)    
      JOIN ORDERDETAIL OD (NOLOCK) ON (OD.Orderkey = PICKDETAIL.Orderkey                                    
                                      AND OD.OrderLineNumber=PICKDETAIL.OrderLineNumber                     
                                      AND OD.Sku = PICKDETAIL.Sku AND OD.StorerKey=PICKDETAIL.Storerkey)    
      JOIN WAVEDETAIL (NOLOCK) ON (PICKDETAIL.Orderkey = WAVEDETAIL.Orderkey)    
      JOIN LOTATTRIBUTE (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)    
      JOIN SKU (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku)    
      JOIN PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)    
      JOIN LOC (NOLOCK) ON (LOC.LOC = PICKDETAIL.LOC)    
      LEFT OUTER JOIN ROUTEMASTER (NOLOCK) ON (ORDERS.Route = ROUTEMASTER.Route)    
      LEFT OUTER JOIN STORER ST WITH (NOLOCK) ON (ST.Storerkey = ORDERS.Consigneekey)    
      LEFT OUTER JOIN CONSIGNEESKU CS WITH (NOLOCK) ON (CS.Consigneekey = ST.Storerkey)    
                                                    AND(CS.Sku = PICKDETAIL.Sku)    
      LEFT OUTER JOIN v_storerconfig2 SC WITH (NOLOCK) ON ORDERS.Storerkey = SC.Storerkey AND SC.Configkey = 'DELNOTE06_RSKU'    
      LEFT OUTER JOIN CODELKUP CL1 (NOLOCK) ON (SKU.Class = CL1.Code AND CL1.Listname = 'MHCSSCAN')    
      LEFT OUTER JOIN CODELKUP CL2 (NOLOCK) ON (PICKDETAIL.Storerkey = CL2.Storerkey AND CL2.Code = 'SHOWBARCODE'     
                                             AND CL2.Listname = 'REPORTCFG' AND CL2.Long = 'r_dw_print_wave_pickslip_31' AND ISNULL(CL2.Short,'') <> 'N')    
      LEFT OUTER JOIN CODELKUP CL3 (NOLOCK) ON (PICKDETAIL.Storerkey = CL3.Storerkey AND CL3.Code = 'SHOWSCNFG'     
                                             AND CL3.Listname = 'REPORTCFG' AND CL3.Long = 'r_dw_print_wave_pickslip_31' AND ISNULL(CL3.Short,'') <> 'N')    
      LEFT OUTER JOIN CODELKUP CL4 (NOLOCK) ON (PICKDETAIL.Storerkey = CL4.Storerkey AND CL4.Code = 'PRTSKUDESC'     
                                             AND CL4.Listname = 'REPORTCFG' AND CL4.Long = 'r_dw_print_wave_pickslip_31' AND ISNULL(CL4.Short,'') <> 'N')      
      LEFT OUTER JOIN CODELKUP CL5 (NOLOCK) ON (PICKDETAIL.Storerkey = CL5.Storerkey AND CL5.Code = 'SHOWFIELD'     
                                             AND CL5.Listname = 'REPORTCFG' AND CL5.Long = 'r_dw_print_wave_pickslip_31' AND ISNULL(CL5.Short,'') <> 'N')            
      LEFT OUTER JOIN CODELKUP CL6 (NOLOCK) ON (PICKDETAIL.Storerkey = CL6.Storerkey AND CL6.Code = 'SHOWBUYERPO'     
                                             AND CL6.Listname = 'REPORTCFG' AND CL6.Long = 'r_dw_print_wave_pickslip_31' AND ISNULL(CL6.Short,'') <> 'N')         
      LEFT OUTER JOIN CONSIGNEESKU CS1 WITH (NOLOCK) ON (CS1.Consigneekey = ORDERS.ConsigneeKey)    
                                                    AND (CS1.Sku = OD.Sku)    
                                                    AND (CS1.StorerKey = ORDERS.StorerKey)                                                                                                                                                                     
 
                                                                     
      WHERE (WAVEDETAIL.Wavekey = @c_wavekey)    
      GROUP BY ORDERS.Orderkey,    
               ORDERS.ExternOrderkey,    
               WAVEDETAIL.WaveKey,    
               ISNULL(ORDERS.StorerKey, ''),    
               ISNULL(ORDERS.Invoiceno, ''),    
               ISNULL(ORDERS.[Route], ''),    
               ISNULL(ROUTEMASTER.Descr, ''),    
               ISNULL(dbo.fnc_RTrim(ORDERS.ConsigneeKey), ''),    
               ISNULL(dbo.fnc_RTrim(ORDERS.C_Company), ''),    
               ISNULL(dbo.fnc_RTrim(ORDERS.C_Address1), ''),    
               ISNULL(dbo.fnc_RTrim(ORDERS.C_Address2), ''),    
               ISNULL(dbo.fnc_RTrim(ORDERS.C_Address3), ''),    
               ISNULL(dbo.fnc_RTrim(ORDERS.C_Zip), ''),    
               ISNULL(dbo.fnc_RTrim(ORDERS.C_City), ''),    
               SKU.Sku,    
               CASE WHEN ISNULL(CL4.Code,'') <> '' AND ISNULL(SKU.Notes1,'') <> '' THEN SKU.Notes1 ELSE ISNULL(SKU.Descr,'') END,    
               PICKDETAIL.Lot,    
               ISNULL(LOTATTRIBUTE.Lottable01, ''),    
               ISNULL(Convert(NVARCHAR(10), LOTATTRIBUTE.Lottable04, 111), '01/01/1900'),    
               ISNULL(PICKDETAIL.Loc, ''),    
               ISNULL(PACK.Qty, 0),    
               ISNULL(PACK.PackUOM3, ''),    
               ISNULL(PACK.CaseCnt, 0),    
               ISNULL(PACK.InnerPack, 0),    
               ISNULL(ORDERS.Capacity, 0.00),    
               ISNULL(ORDERS.GrossWeight, 0.00),    
               CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes, '')),    
               CONVERT(NVARCHAR(60), ISNULL(ORDERS.Notes2, '')),    
               ISNULL(LOTATTRIBUTE.Lottable02, ''),             
               CASE WHEN ISNULL(CL6.Code,'') = '' OR ISNULL(CL6.Code,'') = 'N' THEN ISNULL(Orders.DeliveryNote,'')     
                ELSE ISNULL(orders.buyerpo,'') END,    
               SKU.SKUGROUP,                           
               CONVERT(NVARCHAR(10), ORDERS.DeliveryDate, 111),   --ORDERS.DeliveryDate,                    
               ORDERS.OrderGroup,                      
               CASE WHEN SKU.SUSR4 = 'SSCC' THEN       
                          '**Scan Serial No** '    
                         ELSE    
                         ''    
               END,    
               ISNULL(LOC.LogicalLocation,''),      
               CASE WHEN ISDATE(ISNULL(LOTATTRIBUTE.Lottable03, '')) = 1 THEN CONVERT(NVARCHAR(10), LOTATTRIBUTE.Lottable03, 111) ELSE ISNULL(LOTATTRIBUTE.Lottable03, '') END    
               ,CASE WHEN  @c_VASLBLValue = '1' AND CS.Sku = PICKDETAIL.Sku THEN ISNULL(RTRIM(ST.SUSR5),'')    
                                             ELSE '' END,                                                      
               CASE WHEN ISNULL(SC.Svalue,'') = '1' AND SKU.Sku <> SKU.RetailSku AND ISNULL(SKU.RetailSku,'') <> '' THEN    
                            ISNULL(SKU.RetailSku,'')    
               ELSE '' END    
               ,CASE WHEN ISNULL(CL2.Code,'') <> '' THEN 'Y' ELSE 'N' END     
               ,ISNULL(ORDERS.UserDefine04,'')    
               ,CASE WHEN ISNULL(CL5.Code,'') <> '' THEN 'Y' ELSE 'N' END     
               ,ISNULL(substring(OD.userdefine05,1,1),'')                     
               ,CASE WHEN ISNULL(CL6.Code,'') <> '' THEN 'Y' ELSE 'N' END    
               ,OD.UserDefine03     
               ,ISNULL(CS1.UDF02,'')    
               ,ISNULL(CS1.UDF03,'')    
               ,ISNULL(OD.Notes,'')    
               ,ISNULL(OD.UserDefine02,'')   
               ,Case When @c_Short = 'Y' Then sku.busr9 Else '' End                            --CS01  CL01
               ,CASE WHEN LEFT(OD.UserDefine02,1) = '*' THEN '*' ELSE '' END    --CS01  
          
      SELECT @n_err = @@ERROR    
      IF @n_err <> 0    
      BEGIN    
         SELECT @n_continue = 3    
         IF @@TRANCOUNT >= 1    
         BEGIN    
            ROLLBACK TRAN    
            GOTO FAILURE    
         END    
      END    
      ELSE    
      BEGIN    
         IF @@TRANCOUNT > 0    
         BEGIN    
            COMMIT TRAN    
         END    
         ELSE    
         BEGIN    
            SELECT @n_continue = 3    
            ROLLBACK TRAN    
            GOTO FAILURE    
         END    
      END    
          
      /* Re-calculate SKUGROUP BEGIN*/    
      DECLARE C_Pickslip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT Orderkey, SKUGROUP, SUM(Qty)    
      FROM  #TEMP_PICK    
      GROUP BY Orderkey, SKUGROUP    
          
      OPEN C_Pickslip    
      FETCH NEXT FROM C_Pickslip INTO @c_Orderkey, @c_SKUGROUP, @n_Qty    
          
      WHILE @@FETCH_STATUS <> -1    
      BEGIN    
         IF EXISTS (SELECT * FROM CODELKUP CLK WITH (NOLOCK)     
                    WHERE listname = 'REPORTCFG'     
                    AND code = 'afroutedes'    
                    AND long ='r_dw_print_wave_pickslip_31'    
                    AND storerkey = @c_StorerKey)    
         BEGIN    
            SELECT TOP 1 @c_getudf01 = C.udf01    
                        ,@c_getUdf02 = C.udf02      
            FROM Codelkup C WITH (NOLOCK)      
            WHERE C.listname='REPORTCFG'      
            AND code = 'afroutedes'    
            AND long ='r_dw_print_wave_pickslip_31'    
            AND c.Storerkey = @c_Storerkey                
                   
            SET @c_ExecStatements = ''      
            SET @c_ExecArguments = ''     
            SET @c_condition = ''    
            SET @c_ordudf05 = ''    
                 
            IF  ISNULL(@c_getUdf02,'') <> ''    
            BEGIN    
               SET @c_condition = 'AND ' + @c_getUdf02    
            END    
            ELSE     
            BEGIN    
               SET @c_condition = 'AND Orders.userdefine05=''*'''    
            END       
                
            SET @c_ExecStatements = N'SELECT @c_ordudf05 =' + @c_getudf01 + ' from Orders (nolock) where orderkey=@c_OrderKey '      
            SET @c_ExecAllStatements = @c_ExecStatements + @c_condition    
                
            SET @c_ExecArguments = N'@c_getudf01    NVARCHAR(100) '      
                                  +',@c_OrderKey    NVARCHAR(30)'      
                                  +',@c_ordudf05    NVARCHAR(20) OUTPUT'      
                
            EXEC sp_ExecuteSql @c_ExecAllStatements       
                             , @c_ExecArguments      
                             , @c_getudf01          
                             , @c_OrderKey      
                             , @c_ordudf05 OUTPUT      
         END     
                    
         SET @c_CSKUUDF04 = ''    
          
         SELECT @c_CSKUUDF04 = udf04     
         FROM ConsigneeSKU csku WITH (nolock)     
         JOIN Orders O WITH (NOLOCK) ON O.storerkey = csku.StorerKey AND o.ConsigneeKey = csku.ConsigneeKey    
         WHERE O.OrderKey =  @c_Orderkey    
         AND SKU in (SELECT TOP 1 SKU    
                     FROM ORDERDETAIL (nolock)    
                     WHERE Orderkey = @c_Orderkey)    
          
         UPDATE #TEMP_PICK    
         SET SKUGroupQty = @n_Qty    
            ,UDF01       = @c_ordudf05                    
            ,CSKUUDF04   = @c_CSKUUDF04               
         WHERE Orderkey  = @c_Orderkey    
         AND SKUGroup    = @c_SKUGROUP    
          
      FETCH NEXT FROM C_Pickslip INTO @c_Orderkey, @c_SKUGROUP, @n_Qty    
      END    
      CLOSE C_Pickslip    
      DEALLOCATE C_Pickslip    
      /* Re-calculate SKUGROUP END*/    
          
      -- Check if any pickslipno with NULL value    
      SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)    
      FROM #TEMP_PICK    
      WHERE ISNULL(RTRIM(PickSlipNo),'') = ''    
          
      IF @@ERROR <> 0    
      BEGIN    
         GOTO FAILURE    
      END    
      ELSE IF @n_pickslips_required > 0    
      BEGIN    
         EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_pickheaderkey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required    
          
         INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, WaveKey, PickType, [Zone], TrafficCop)    
         SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +    
         dbo.fnc_LTrim( dbo.fnc_RTrim(    
         STR(CAST(@c_pickheaderkey AS INT) + (SELECT COUNT(DISTINCT OrderKey)    
                                              FROM #TEMP_PICK AS Rank    
                                              WHERE Rank.OrderKey < #TEMP_PICK.OrderKey    
                                              AND ISNULL(RTRIM(Rank.PickSlipNo),'') = '' )    
             ) -- str    
             )) -- dbo.fnc_RTrim    
             , 9)    
            , OrderKey, WaveKey, '0', '8', ''    
         FROM #TEMP_PICK    
         WHERE ISNULL(RTRIM(PickSlipNo),'') = ''    
         GROUP By WaveKey, OrderKey    
          
         UPDATE #TEMP_PICK    
         SET PickSlipNo = PICKHEADER.PickHeaderKey    
         FROM PICKHEADER (NOLOCK)    
         WHERE PICKHEADER.WaveKey = #TEMP_PICK.Wavekey    
         AND   PICKHEADER.OrderKey = #TEMP_PICK.OrderKey    
         AND   PICKHEADER.[Zone] = '8'    
         AND   ISNULL(RTRIM(#TEMP_PICK.PickSlipNo),'') = ''    
      END    
          
      GOTO SUCCESS    
          
FAILURE:    
      IF OBJECT_ID('tempdb..#TEMP_PICK') IS NOT NULL    
         DROP TABLE #TEMP_PICK    
          
SUCCESS:    
      -- Do Auto Scan-in when Configkey is setup.    
      SET @c_StorerKey = ''    
      SET @c_PickSlipNo = ''    
          
      SELECT DISTINCT @c_StorerKey = StorerKey    
        FROM #TEMP_PICK (NOLOCK)    
          
      IF EXISTS (SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE CONFIGKEY = 'AUTOSCANIN'    
                    AND SValue = '1' AND StorerKey = @c_StorerKey)    
      BEGIN    
         DECLARE C_AutoScanPickSlip CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
         SELECT DISTINCT PickSlipNo    
      FROM #TEMP_PICK (NOLOCK)    
          
         OPEN C_AutoScanPickSlip    
         FETCH NEXT FROM C_AutoScanPickSlip INTO @c_PickSlipNo    
          
         WHILE @@FETCH_STATUS <> -1    
         BEGIN    
            IF NOT EXISTS (SELECT 1 FROM PICKINGINFO (NOLOCK) Where PickSlipNo = @c_PickSlipNo)    
            BEGIN    
               INSERT INTO PICKINGINFO (PickSlipNo, ScanInDate, PickerID, ScanOutDate)    
               VALUES (@c_PickSlipNo, GetDate(), sUser_sName(), NULL)    
          
               IF @@ERROR <> 0    
               BEGIN    
                  SELECT @n_continue = 3    
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 61900    
                  SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) +    
                                     ': Insert PickingInfo Failed. (isp_GetPickSlipWave_31)' + ' ( ' +    
                                     ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '    
               END    
            END -- PickSlipNo Does Not Exist    
          
            FETCH NEXT FROM C_AutoScanPickSlip INTO @c_PickSlipNo    
         END    
         CLOSE C_AutoScanPickSlip    
         DEALLOCATE C_AutoScanPickSlip    
      END -- Configkey is setup    
          
      SELECT PickSlipNo ,OrderKey ,ExternOrderkey ,WaveKey ,StorerKey  ,InvoiceNo ,[Route]  ,RouteDescr ,ConsigneeKey    
            ,C_Company ,C_Addr1 ,C_Addr2 ,C_Addr3 ,C_PostCode, C_City, Sku ,SkuDescr ,Lot ,Lottable01 ,Lottable04    
            ,SUM(Qty) AS Qty ,Loc ,MasterUnit ,LowestUOM ,CaseCnt ,InnerPack ,Capacity ,GrossWeight ,PrintedFlag ,Notes1    
            ,Notes2 ,Lottable02 ,DeliveryNote ,SKUGROUP ,SkuGroupQty ,DeliveryDate ,OrderGroup  ,scanserial, LogicalLoc, Lottable03    
            ,LabelFlag, RetailSku     
            ,Internalflag    
            ,scancaseidflag, showbarcodeflag,ISNULL(UDF01,'') AS udf01    
            ,ISNULL(OHUDF04,'') AS OHUDF04                                
            ,showfield,ODUDF05,showbuyerpo,CSKUUDF04    
            ,UserDefine03, PalletHi, PalletTi, ODNotes, UserDefine02, CountUDF03Flag,SBUSR9,UDF02Flag             --CS01      
           -- ,ROW_NUMBER() Over (PARTITION BY WaveKey,OrderKey,UserDefine02,SBUSR9 Order By WaveKey,OrderKey,UserDefine02,SBUSR9) As RowNumber                  
      FROM #TEMP_PICK     
      GROUP BY PickSlipNo ,OrderKey ,ExternOrderkey ,WaveKey ,StorerKey  ,InvoiceNo ,[Route]  ,RouteDescr ,ConsigneeKey    
            ,C_Company ,C_Addr1 ,C_Addr2 ,C_Addr3 ,C_PostCode, C_City, Sku ,SkuDescr ,Lot ,Lottable01 ,Lottable04    
            ,Loc ,MasterUnit ,LowestUOM ,CaseCnt ,InnerPack ,Capacity ,GrossWeight ,PrintedFlag ,Notes1    
            ,Notes2 ,Lottable02 ,DeliveryNote ,SKUGROUP ,SkuGroupQty ,DeliveryDate ,OrderGroup  ,scanserial, LogicalLoc, Lottable03    
            ,LabelFlag, RetailSku    
            ,Internalflag    
            ,scancaseidflag, showbarcodeflag ,UDF01,OHUDF04 ,showfield,ODUDF05    
            ,showbuyerpo,CSKUUDF04    
            ,UserDefine03, PalletHi, PalletTi, ODNotes, UserDefine02, CountUDF03Flag,SBUSR9,UDF02Flag      --CS01 CL01                                              
      --ORDER BY PickSlipNo, UserDefine02, UserDefine03, SKU    
      --ORDER BY PickSlipNo,CountUDF03Flag desc,UserDefine02,UserDefine03,SKU    --ML01       --CS01  
        ORDER BY PickSlipNo,OrderKey ,ExternOrderkey,SBUSR9,UDF02Flag Desc    --CS01  --CL01 
  
                
                                                               
      IF OBJECT_ID('tempdb..#TEMP_PICK') IS NOT NULL    
         DROP TABLE #TEMP_PICK    
   END   --@c_Type    
    
   IF @n_continue = 3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_success = 0    
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         ROLLBACK TRAN    
      END    
      ELSE    
      BEGIN    
         WHILE @@TRANCOUNT > @n_starttcnt    
         BEGIN    
            COMMIT TRAN    
         END    
      END    
    
      EXECUTE dbo.nsp_logerror @n_err, @c_errmsg, 'isp_GetPickSlipWave_31'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN    
      SELECT @b_success = 1    
      WHILE @@TRANCOUNT > @n_starttcnt    
      BEGIN    
         COMMIT TRAN    
      END    
      RETURN    
   END    
    
--WL02 S    
   IF CURSOR_STATUS('LOCAL', 'CUR_UPDATE') IN (0 , 1)    
   BEGIN    
      CLOSE CUR_UPDATE    
      DEALLOCATE CUR_UPDATE       
   END    
   --WL02 E    
END  

GO