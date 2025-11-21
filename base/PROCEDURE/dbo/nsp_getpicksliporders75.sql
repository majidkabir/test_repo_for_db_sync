SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/      
/* Store Procedure: nsp_GetPickSlipOrders75                              */      
/* Creation Date: 24-OCT-2017                                            */      
/* Copyright: IDS                                                        */      
/* Written by:CSCHONG                                                    */      
/*                                                                       */      
/* Purpose: WMS-3254  - [HK] Nike consolidated pick slip in wave plan    */      
/*                                                                       */      
/* Called By:r_dw_print_pickorder75                                      */      
/*                                                                       */      
/* PVCS Version: 1.1                                                     */      
/*                                                                       */      
/* Version: 5.4                                                          */      
/*                                                                       */      
/* Data Modifications:                                                   */      
/*                                                                       */      
/* Updates:                                                              */      
/* Date         Author        Purposes                                   */      
/* 2018-03-08   CSCHONG       WMS-4159-insert loadkey to pickheader(CS01)*/      
/* 28-Jan-2019  TLTING_ext 1.1 enlarge externorderkey field length       */      
/* 26-JUL-2022  CSCHONG    1.2  Devops Scripts Combine & WMS-20120 (CS02)*/      
/* 13-OCT-2022  CSCHONG    1.3  WMS-20874 Fix some loadkey cannot        */  
/*                              generate Pickslipno (CS03)               */  
/* 23-FEB-2023  NJOW01     1.4  WMS-21843 add pickmethod='C' filter      */
/* 23-FEB-2023  NJOW01     1.4  DEVOPS Combine Script                    */
/*************************************************************************/      
      
CREATE    PROC [dbo].[nsp_GetPickSlipOrders75]     
                  (@c_WaveKey_start         NVARCHAR(10),      
                   @c_WaveKey_end           NVARCHAR(10)='',      
                   @c_StorerKey_start       NVARCHAR(10)='',      
                   @c_StorerKey_end         NVARCHAR(10)='',      
                   @c_pickslipno_start      NVARCHAR(10)='',      
                   @c_pickslipno_end        NVARCHAR(10)='',      
                   @c_ExternOrderKey_start  NVARCHAR(50)= '',    --tlting_ext      
                   @c_ExternOrderKey_end    NVARCHAR(50)= '')      
AS      
BEGIN      
   SET NOCOUNT ON      
   Set ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE @c_PickHeaderKey      NVARCHAR(10),      
           @n_continue           INT,      
           @c_errmsg             NVARCHAR(255),      
           @b_success            INT,      
           @n_err                INT,      
           @n_starttcnt          INT,      
           @n_pickslips_required INT,      
           @c_loopcnt            INT,      
           @theSQLStmt           NVARCHAR(255),      
           @c_Sku                NVARCHAR(50),      
           @c_ExternOrderKey     NVARCHAR(50),   --tlting_ext      
           @c_PickSlipNo         NVARCHAR(10),      
           @c_size               NVARCHAR(5),      
           @c_qty                NVARCHAR(5),      
           @c_PrintedFlag        NVARCHAR(1),      
           @n_cnt                INT,      
           @c_loc                NVARCHAR(10),      
           @c_Busr6              NVARCHAR(30),      
           @c_SQLParm            NVARCHAR(2000) = '',      
           @n_PDQty              INT = 0,      
           @c_AutoScaninPickslip NVARCHAR(10) ='N',  --CS02      
           @c_GetStorerkey       NVARCHAR(20) = '',  --CS02        
           @c_GetPickslipno      NVARCHAR(20) = ''   --CS02      
      
   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT, @theSQLStmt = ''      
   SELECT @n_pickslips_required = 0 -- (Leong01)      
      
 WHILE @@TRANCOUNT > 0 -- SOS# 303176      
   BEGIN      
      COMMIT TRAN      
   END      
      
   IF @c_WaveKey_end = '' OR @c_WaveKey_end='0'      
   BEGIN      
    SET @c_WaveKey_end = @c_WaveKey_start      
   END      
      
   IF @c_StorerKey_start = '' OR @c_StorerKey_start = 'ZZZZZZZZZZ'      
  BEGIN      
    SET @c_StorerKey_start = '0'      
   END      
      
   IF @c_StorerKey_end = '' OR @c_StorerKey_end = '0'      
   BEGIN      
    SET @c_StorerKey_end = 'ZZZZZZZZZZ'      
   END      
      
   IF ISNULL(@c_pickslipno_start,'') = '' OR @c_pickslipno_start = 'ZZZZZZZZZZ'      
   BEGIN      
    SET @c_pickslipno_start = '0'      
   END      
      
   IF ISNULL(@c_pickslipno_end,'') = '' --OR @c_pickslipno_end = 'ZZZZZZZZZZ'      
   BEGIN      
    SET @c_pickslipno_end = 'ZZZZZZZZZZ'      
   END      
      
   IF ISNULL(@c_ExternOrderKey_start,'') = '' --OR @c_pickslipno_end = 'ZZZZZZZZZZ'      
   BEGIN      
    SET @c_ExternOrderKey_start = '0'      
   END      
     
   IF ISNULL(@c_ExternOrderKey_end,'') = '' --OR @c_pickslipno_end = 'ZZZZZZZZZZ'      
   BEGIN      
    SET @c_ExternOrderKey_end = 'ZZZZZZZZZZ'      
   END      
  
   --CS03 S  
   CREATE TABLE #TEMP_PICKLoad (  
     Storerkey      NVARCHAR(20),   
     Wavekey        NVARCHAR(10),  
     Loadkey        NVARCHAR(10)  
       )    
   
      
   --IF @c_ExternOrderKey_start = '0'                          --remove  
   --BEGIN      
   -- SELECT @c_ExternOrderKey_start = MIN(OH.loadkey)      
   --       ,@c_ExternOrderKey_end = MAX(OH.loadkey)      
   -- FROM  WAVE a (nolock)      
   --   JOIN orders OH (nolock) on a.wavekey=OH.userdefine09      
   -- WHERE A.WaveKey BETWEEN @c_WaveKey_start AND @c_WaveKey_end      
   --END      
  
    IF @c_WaveKey_start = @c_WaveKey_end  
    BEGIN  
        INSERT INTO #TEMP_PICKLoad  
        (  
            Storerkey,  
            Wavekey,  
            Loadkey  
        )  
        SELECT DISTINCT OH.StorerKey,OH.UserDefine09,OH.LoadKey  
        FROM  WAVE a (nolock)      
        JOIN orders OH (nolock) on a.wavekey=OH.userdefine09      
        WHERE A.WaveKey= @c_WaveKey_start    
              
    END  
    ELSE  
    BEGIN  
        INSERT INTO #TEMP_PICKLoad  
        (  
            Storerkey,  
            Wavekey,  
            Loadkey  
        )  
        SELECT DISTINCT OH.StorerKey,OH.UserDefine09,OH.LoadKey  
        FROM  WAVE a (nolock)      
        JOIN orders OH (nolock) on a.wavekey=OH.userdefine09      
        WHERE A.WaveKey BETWEEN @c_WaveKey_start AND @c_WaveKey_end     
    END  
      
   SELECT @n_cnt = COUNT(*)      
   FROM PickHeader PH (NOLOCK)      
   --WHERE (externorderkey BETWEEN @c_ExternOrderKey_start AND @c_ExternOrderKey_end)     
   JOIN #TEMP_PICKLoad TPL ON TPL.Storerkey = PH.StorerKey AND TPL.Loadkey = PH.ExternOrderKey  
  
   --CS01 E   
      
  -- SELECT @c_ExternOrderKey_start '@c_ExternOrderKey_start',@c_ExternOrderKey_end '@c_ExternOrderKey_end',@n_cnt '@n_cnt'      
      
   CREATE TABLE #TEMP_PICK      
       ( PickSlipNo       NVARCHAR(10) NULL,      
         loadKey         NVARCHAR(10),      
         ExternOrderKey   NVARCHAR(50),   --tlting_ext      
         DeliveryDate     NVARCHAR(10) NULL,      
         WaveKey          NVARCHAR(10),      
         InvoiceNo        NVARCHAR(10),      
         Route            NVARCHAR(10) NULL,      
         Facility         NVARCHAR(5) ,      
         BuyerPO          NVARCHAR(20) NULL,      
         B_Company        NVARCHAR(45),      
         B_Addr1          NVARCHAR(45) NULL,      
         B_Addr2          NVARCHAR(45) NULL,      
         B_Addr3          NVARCHAR(45) NULL,      
         B_Addr4          NVARCHAR(45) NULL,      
         B_Country        NVARCHAR(30) NULL,      
         C_Company        NVARCHAR(45),      
         C_Addr1          NVARCHAR(45) NULL,      
         C_Addr2          NVARCHAR(45) NULL,      
         C_Addr3          NVARCHAR(45) NULL,      
         C_Addr4          NVARCHAR(45) NULL,      
         C_City           NVARCHAR(45) NULL, -- added by Ong 3/5/05   sos34665      
         C_Country        NVARCHAR(30) NULL,      
         Loc              NVARCHAR(10) NULL,      
         Sku              NVARCHAR(50) NULL,      
         SkuDesc          NVARCHAR(60) NULL,      
         Qty              INT,      
         Remarks          NVARCHAR(255) NULL,      
         LogicalLocation  NVARCHAR(10) NULL,      
         PrintFlag        NVARCHAR(1) NULL,      
         SizeCOL1 NVARCHAR(5) NULL DEFAULT '', QtyCOL1 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL2 NVARCHAR(5) NULL DEFAULT '', QtyCOL2 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL3 NVARCHAR(5) NULL DEFAULT '', QtyCOL3 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL4 NVARCHAR(5) NULL DEFAULT '', QtyCOL4 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL5 NVARCHAR(5) NULL DEFAULT '', QtyCOL5 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL6 NVARCHAR(5) NULL DEFAULT '', QtyCOL6 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL7 NVARCHAR(5) NULL DEFAULT '', QtyCOL7 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL8 NVARCHAR(5) NULL DEFAULT '', QtyCOL8 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL9 NVARCHAR(5) NULL DEFAULT '', QtyCOL9 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL10 NVARCHAR(5) NULL DEFAULT '', QtyCOL10 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL11 NVARCHAR(5) NULL DEFAULT '', QtyCOL11 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL12 NVARCHAR(5) NULL DEFAULT '', QtyCOL12 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL13 NVARCHAR(5) NULL DEFAULT '', QtyCOL13 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL14 NVARCHAR(5) NULL DEFAULT '', QtyCOL14 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL15 NVARCHAR(5) NULL DEFAULT '', QtyCOL15 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL16 NVARCHAR(5) NULL DEFAULT '', QtyCOL16 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL17 NVARCHAR(5) NULL DEFAULT '', QtyCOL17 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL18 NVARCHAR(5) NULL DEFAULT '', QtyCOL18 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL19 NVARCHAR(5) NULL DEFAULT '', QtyCOL19 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL20 NVARCHAR(5) NULL DEFAULT '', QtyCOL20 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL21 NVARCHAR(5) NULL DEFAULT '', QtyCOL21 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL22 NVARCHAR(5) NULL DEFAULT '', QtyCOL22 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL23 NVARCHAR(5) NULL DEFAULT '', QtyCOL23 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL24 NVARCHAR(5) NULL DEFAULT '', QtyCOL24 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL25 NVARCHAR(5) NULL DEFAULT '', QtyCOL25 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL26 NVARCHAR(5) NULL DEFAULT '', QtyCOL26 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL27 NVARCHAR(5) NULL DEFAULT '', QtyCOL27 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL28 NVARCHAR(5) NULL DEFAULT '', QtyCOL28 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL29 NVARCHAR(5) NULL DEFAULT '', QtyCOL29 NVARCHAR(5) NULL DEFAULT '',      
         SizeCOL30 NVARCHAR(5) NULL DEFAULT '', QtyCOL30 NVARCHAR(5) NULL DEFAULT '' ,      
         Busr7     NVARCHAR(30) NULL,   -- change request 16July2003      
         Notes2     NVARCHAR(255) NULL DEFAULT '', -- Added By SHong ON 3-12-2003, SOS16003      
         Lottable02 NVARCHAR(20) NULL,      
         UOM3       NVARCHAR(10) NULL,      
         PackQtyIndicator INT NULL,      
         StorerKey NVARCHAR(15) NULL,      
         SCOMPANY  NVARCHAR(45) NULL      
       )      
      
  Create index IDX_TEMP_PICK_01 on #TEMP_PICK ( PickSlipNo )      
      
   IF @n_cnt = 0      
   BEGIN      
      INSERT INTO #TEMP_PICK (PickSlipNo, loadKey, ExternOrderKey, DeliveryDate, WaveKey, InvoiceNo,      
                             Route, Facility, BuyerPO, B_Company, B_Addr1, B_Addr2, B_Addr3, B_Addr4,      
                             B_Country, C_Company, C_Addr1, C_Addr2, C_Addr3, C_Addr4, C_City, C_Country, LOC,      
      Sku, SkuDesc, Qty, Remarks, LogicalLocation, PrintFlag, BUSR7, Notes2,      
                             lottable02, UOM3, PackQtyIndicator, StorerKey,SCOMPANY)      -- added by Ong 3/5/05      
      SELECT (SELECT PickHeader.PickHeaderKey FROM PickHeader (NOLOCK)      
               WHERE ( PickHeader.WaveKey BETWEEN @c_WaveKey_start AND @c_WaveKey_end )      
               AND PickHeader.externorderkey = ORDERS.loadkey      
               AND PickHeader.ZONE = '7') ,      
            MIN(ORDERS.loadKey) AS loadkey,      
            MIN(ORDERS.ExternOrderKey) AS ExternOrderkey,      
            MIN(CONVERT(NVARCHAR(10), ORDERS.DeliveryDate, 103)) AS DeliveryDate,      
            ISNULL(WAVEDETAIL.wavekey,'') AS WaveKey,      
            MIN(ORDERS.Invoiceno) AS InvoiceNo,      
            MIN(ORDERS.Route) AS route,      
            MIN(ORDERS.Facility) AS Facility,      
            '' AS buyerpo,      
            MIN(ISNULL(ORDERS.B_Company, '')) AS B_Company,      
            MIN(ISNULL(ORDERS.B_Address1, '')) AS B_Addr1,      
            MIN(ISNULL(ORDERS.B_Address2,'')) AS B_Addr2,      
            MIN(ISNULL(ORDERS.B_Address3,'')) AS B_Addr3,      
            MIN(ISNULL(ORDERS.B_Address4,'')) AS B_Addr4,      
            MIN(ISNULL(ORDERS.B_Country,''))  AS B_Country,      
            MIN(ISNULL(ORDERS.C_Company, '')) AS C_Company,      
            MIN(ISNULL(ORDERS.C_Address1, '')) AS C_Addr1,      
            MIN(ISNULL(ORDERS.C_Address2,'')) AS C_Addr2,      
            MIN(ISNULL(ORDERS.C_Address3,'')) AS C_Addr3,      
            MIN(ISNULL(ORDERS.C_Address4,'')) AS C_Addr4,      
            MIN(ISNULL(ORDERS.C_City,''))  AS C_City,            -- added by Ong 3/5/05      
            MIN(ISNULL(ORDERS.C_Country,''))  AS C_Country,      
            PickDetail.Loc,      
            SUBSTRING(Sku.Sku,1,9) AS Sku,       -- modified by Ong sos34665 6/6/05      
            ISNULL(Sku.Descr,'') AS SkuDescr,      
            SUM(PickDetail.Qty) AS Qty,      
            '' AS remarks,--MIN(dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(255),ORDERS.Notes)))) AS Remarks,  -- change request 16July2003      
            '' AS logicallocation,--LOC.LogicalLocation,      
            'N' AS PrintFlag,      
            Sku.BUSR7,  -- change request 16July2003      
            '' AS notes2,--MIN(dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(255),ORDERS.Notes2)))) AS Notes2,   -- Added By SHong ON 3-12-2003, SOS16003      
            dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(20), LOTATTRIBUTE.lottable02))) AS lottable02,  -- added by Ong 3/5/05      
            dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(10), pack.PackUOM3))) AS UOM3,                   -- added by Ong 3/5/05      
            Sku.PackQtyIndicator AS PackQtyIndicator                              -- added by Ong 3/5/05      
          , MIN(ORDERS.StorerKey) AS storerkey,ISNULL(STORER.Company,'')      
      FROM PickDetail (NOLOCK)      
      JOIN ORDERS (NOLOCK) ON (PickDetail.OrderKey = ORDERS.OrderKey AND ORDERS.UserDefine08 = 'Y')      
      JOIN WAVEDETAIL (NOLOCK) ON (PickDetail.OrderKey = WAVEDETAIL.OrderKey)      
      JOIN LOTATTRIBUTE (NOLOCK) ON (PickDetail.Lot = LOTATTRIBUTE.Lot)      
      -- modified by Ong sos 34665      
      JOIN Sku (NOLOCK) ON (PickDetail.StorerKey = Sku.StorerKey AND PickDetail.Sku = Sku.Sku)      
      JOIN Pack (NOLOCK) ON (Pack.packKey = Sku.packKey)         -- added by Ong 3/5/05      
      JOIN SkuxLOC (NOLOCK) ON (PickDetail.Loc = SkuxLOC.Loc AND PickDetail.StorerKey = SkuxLOC.StorerKey      
                                AND PickDetail.Sku = SkuxLOC.Sku)      
      JOIN LOC (NOLOCK) ON (PickDetail.Loc = LOC.Loc)      
      LEFT OUTER JOIN STORER (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)-- AND STORER.Type = '2')      
      JOIN #TEMP_PICKLoad TPL ON TPL.Loadkey= ORDERS.loadkey                                                   --CS03  
      WHERE PickDetail.Status < '5'      
      AND (PickDetail.PickMethod = '8' OR PickDetail.PickMethod = ''  OR PickDetail.PickMethod = 'C')  --NJOW01    
      AND (WAVEDETAIL.WaveKey >= @c_WaveKey_start AND WAVEDETAIL.WaveKey <= @c_WaveKey_end )      
      AND (ORDERS.StorerKey >= @c_StorerKey_start AND ORDERS.StorerKey <= @c_StorerKey_end )      
     -- AND (ORDERS.loadKey >= @c_ExternOrderKey_start AND ORDERS.loadKey <= @c_ExternOrderKey_end )      --CS03  
      GROUP BY ORDERS.loadKey,      
               --ORDERS.ExternOrderKey,      
              -- CONVERT(NVARCHAR(10), ORDERS.DeliveryDate, 103),      
               ISNULL(WAVEDETAIL.wavekey,''),      
               --ORDERS.Invoiceno,      
               --ORDERS.Route,      
               --ORDERS.Facility,      
               --ORDERS.BuyerPO,      
               --ISNULL(ORDERS.B_Company, '') ,      
               --ISNULL(ORDERS.B_Address1, ''),      
               --ISNULL(ORDERS.B_Address2,'') ,      
               --ISNULL(ORDERS.B_Address3,'') ,      
               --ISNULL(ORDERS.B_Address4,''),      
               --ISNULL(ORDERS.B_Country,''),      
               --ISNULL(ORDERS.C_Company, '') ,      
               --ISNULL(ORDERS.C_Address1, ''),      
               --ISNULL(ORDERS.C_Address2,''),      
               --ISNULL(ORDERS.C_Address3,''),      
               --ISNULL(ORDERS.C_Address4,''),      
               --ISNULL(ORDERS.C_City,''),        -- added by Ong 3/5/05      
               --ISNULL(ORDERS.C_Country,''),      
               PickDetail.Loc,      
               SUBSTRING(Sku.Sku,1,9),   -- modified by Ong 6/6/05 sos34665      
               ISNULL(Sku.Descr,'') ,      
              -- LOC.LogicalLocation,      
             --  dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(255),ORDERS.Notes))),  -- change request 16July2003      
               Sku.BUSR7,  -- change request 16July2003      
             --  dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(255),ORDERS.Notes2))), -- SOS16003      
               dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(20), lotattribute.lottable02))),  -- added by Ong 3/5/05   sos34665      
               dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(10), pack.PackUOM3))),                   -- added by Ong 3/5/05   sos34665      
               PackQtyIndicator                              -- added by Ong 3/5/05      
            -- , ORDERS.StorerKey      
             ,ISNULL(STORER.Company,'')      
             --ORDER BY ISNULL(WAVEDETAIL.wavekey,''),ORDERS.DeliveryDate,ORDERS.Route,ORDERS.loadKey      
   END      
   ELSE      
   BEGIN      
      INSERT INTO #TEMP_PICK (PickSlipNo, loadKey, ExternOrderKey, DeliveryDate, WaveKey, InvoiceNo,      
                             Route, Facility, BuyerPO, B_Company, B_Addr1, B_Addr2, B_Addr3, B_Addr4,      
                             B_Country, C_Company, C_Addr1, C_Addr2, C_Addr3, C_Addr4, C_City, C_Country, LOC,      
                             Sku, SkuDesc, Qty, Remarks, LogicalLocation, PrintFlag, BUSR7, Notes2,  -- change request 16July2003      
                             lottable02, UOM3, PackQtyIndicator, StorerKey,SCOMPANY)      -- added by Ong 3/5/05      
      SELECT DISTINCT PickHeader.PickHeaderKey,      
             MIN(ORDERS.loadKey) AS loadkey,      
             MIN(ORDERS.ExternOrderKey) AS ExternOrderkey,      
             MIN(CONVERT(NVARCHAR(10), ORDERS.DeliveryDate, 103)) AS DeliveryDate,      
             ISNULL(WAVEDETAIL.wavekey,'') AS WaveKey,      
             MIN(ORDERS.Invoiceno) AS Invoiceno,      
             MIN(ORDERS.Route) AS Route,      
             MIN(ORDERS.Facility) AS Facility,      
             '' AS Buyerpo,      
             MIN(ISNULL(ORDERS.B_Company, '')) AS B_Company,      
             MIN(ISNULL(ORDERS.B_Address1, '')) AS B_Addr1,      
             MIN(ISNULL(ORDERS.B_Address2,'')) AS B_Addr2,      
             MIN(ISNULL(ORDERS.B_Address3,'')) AS B_Addr3,      
             MIN(ISNULL(ORDERS.B_Address4,'')) AS B_Addr4,      
             MIN(ISNULL(ORDERS.B_Country,''))  AS B_Country,      
             MIN(ISNULL(ORDERS.C_Company, '')) AS C_Company,      
             MIN(ISNULL(ORDERS.C_Address1, '')) AS C_Addr1,      
             MIN(ISNULL(ORDERS.C_Address2,'')) AS C_Addr2,      
             MIN(ISNULL(ORDERS.C_Address3,'')) AS C_Addr3,      
             MIN(ISNULL(ORDERS.C_Address4,'')) AS C_Addr4,      
             MIN(ISNULL(ORDERS.C_City,''))  AS C_City,         -- added by Ong 3/5/05      
             MIN(ISNULL(ORDERS.C_Country,''))  AS C_Country,      
             PickDetail.Loc,      
             SUBSTRING(Sku.Sku,1,9) AS Sku,    -- modified by Ong 6/6/05 sos34665      
             ISNULL(Sku.Descr,'') AS SkuDescr,      
             SUM(PickDetail.Qty) AS Qty,      
             '' AS remarks,--MIN(dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(255),ORDERS.Notes)))) AS Remarks,  -- change request 16July2003      
             '' AS logicallocation,--LOC.LogicalLocation,      
             'Y' AS PrintFlag ,      
             Sku.BUSR7,  -- change request 16July2003      
             '' AS notes2,--MIN(dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(255),ORDERS.Notes2)))) AS Notes2,      
             dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(20), lotattribute.lottable02))) AS lottable02,  -- added by Ong 3/5/05      
             dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(10), pack.PackUOM3))) AS UOM3,                   -- added by Ong 3/5/05      
             Sku.PackQtyIndicator AS PackQtyIndicator                              -- added by Ong 3/5/05      
           , MIN(ORDERS.StorerKey) AS storerkey,ISNULL(STORER.Company,'')      
     FROM PickDetail (NOLOCK)      
      JOIN ORDERS (NOLOCK) ON (PickDetail.OrderKey = ORDERS.OrderKey AND ORDERS.UserDefine08 = 'Y')      
      JOIN WAVEDETAIL (NOLOCK) ON (PickDetail.OrderKey = WAVEDETAIL.OrderKey)      
      JOIN LOTATTRIBUTE (NOLOCK) ON (PickDetail.Lot = LOTATTRIBUTE.Lot)      
      JOIN Sku (NOLOCK) ON (PickDetail.StorerKey = Sku.StorerKey AND PickDetail.Sku = Sku.Sku)      
      JOIN Pack (NOLOCK) ON (Pack.packKey = Sku.packKey)         -- added by Ong 3/5/05      
      JOIN SkuxLOC (NOLOCK) ON (PickDetail.Loc = SkuxLOC.Loc AND PickDetail.StorerKey = SkuxLOC.StorerKey      
                                AND PickDetail.Sku = SkuxLOC.Sku)      
      JOIN LOC (NOLOCK) ON (PickDetail.Loc = LOC.Loc)      
      LEFT OUTER JOIN STORER (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)-- AND STORER.Type = '2')      
      JOIN PickHeader (NOLOCK) ON (PickHeader.externorderkey = ORDERS.loadkey)-- AND PickHeader.WaveKey = WAVEDETAIL.WaveKey )      
      WHERE      
      --   PickDetail.Status < '5' AND (PickDetail.PickMethod = '8' OR PickDetail.PickMethod = '') AND      
      (WAVEDETAIL.WaveKey >= @c_WaveKey_start AND WAVEDETAIL.WaveKey <= @c_WaveKey_end )      
      AND (ORDERS.StorerKey >= @c_StorerKey_start AND ORDERS.StorerKey <= @c_StorerKey_end )      
      AND (PickHeader.PickHeaderKey >= @c_pickslipno_start AND PickHeader.PickHeaderKey <= @c_pickslipno_end )      
      AND (ORDERS.loadKey >= @c_ExternOrderKey_start AND ORDERS.loadKey <= @c_ExternOrderKey_end )      
      GROUP BY PickHeader.PickHeaderKey,      
             --  ORDERS.loadKey,      
              -- ORDERS.ExternOrderKey,      
               --CONVERT(NVARCHAR(10), ORDERS.DeliveryDate, 103),      
               ISNULL(WAVEDETAIL.wavekey,''),      
               --ORDERS.Invoiceno,      
               --ORDERS.Route,      
               --ORDERS.Facility,      
               --ORDERS.BuyerPO,      
               --ISNULL(ORDERS.B_Company, '') ,      
               --ISNULL(ORDERS.B_Address1, ''),      
               --ISNULL(ORDERS.B_Address2,'') ,      
               --ISNULL(ORDERS.B_Address3,'') ,      
               --ISNULL(ORDERS.B_Address4,''),      
               --ISNULL(ORDERS.B_Country,''),      
               --ISNULL(ORDERS.C_Company, '') ,      
               --ISNULL(ORDERS.C_Address1, ''),      
               --ISNULL(ORDERS.C_Address2,''),      
               --ISNULL(ORDERS.C_Address3,''),      
               --ISNULL(ORDERS.C_Address4,''),      
               --ISNULL(ORDERS.C_City,''),        -- added by Ong 3/5/05      
               --ISNULL(ORDERS.C_Country,''),      
               PickDetail.Loc,      
               SUBSTRING(Sku.Sku,1,9),   -- modified by Ong 6/6/05 sos34665      
               ISNULL(Sku.Descr,'') ,      
              -- LOC.LogicalLocation,      
             --  dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(255),ORDERS.Notes))),  -- change request 16July2003      
               Sku.BUSR7,  -- change request 16July2003      
              -- dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(255),ORDERS.Notes2))),      
               dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(20), lotattribute.lottable02))),  -- added by Ong 3/5/05      
               dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(10), pack.PackUOM3))),                   -- added by Ong 3/5/05      
               Sku.PackQtyIndicator                             -- added by Ong 3/5/05      
             --, ORDERS.StorerKey      
             ,ISNULL(STORER.Company,'')      
             --ORDER BY ISNULL(WAVEDETAIL.wavekey,''),ORDERS.DeliveryDate,ORDERS.Route,ORDERS.loadKey      
   END -- END @n_cnt      
      
      
      
   --SELECT * FROM #TEMP_PICK      
      
   SELECT @n_pickslips_required = COUNT(DISTINCT loadkey)      
   FROM #TEMP_PICK      
   WHERE ISNULL(RTRIM(PickSlipNo),'') = '' -- (Leong01)      
      
   --CS02 S      
   SET @c_AutoScaninPickslip = 'N'      
   SET @c_GetStorerkey = ''      
         
      
   SELECT TOP 1 @c_GetStorerkey = StorerKey      
   FROM #TEMP_PICK       
      
  IF @c_GetStorerkey <> ''      
  BEGIN      
      
   SELECT @c_AutoScaninPickslip = ISNULL(CL.Short,'')      
   FROM CODELKUP CL WITH (NOLOCK)      
   WHERE CL.ListName = 'REPORTCFG'      
   AND   CL.Code = 'AutoScanInPickslip'      
   AND   CL.Storerkey = @c_GetStorerkey      
   AND   CL.Long = 'r_dw_print_pickorder75'      
   END      
   --CS02 E      
      
   IF @@ERROR <> 0      
   BEGIN      
      GOTO FAILURE      
   END      
   ELSE IF @n_pickslips_required > 0 AND @n_cnt = 0      
   BEGIN      
      BEGIN TRAN -- SOS# 303176      
      EXECUTE nspg_GetKey 'PICKSLIP', 9, @c_PickHeaderKey OUTPUT, @b_success OUTPUT, @n_err  OUTPUT, @c_errmsg OUTPUT, 0, @n_pickslips_required      
      COMMIT TRAN      
      
      BEGIN TRAN      
      INSERT INTO PickHeader (PickHeaderKey, orderkey,externorderkey, WaveKey, PickType, Zone, TrafficCop, StorerKey,loadkey)  --(CS01)      
      SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +      
                   dbo.fnc_LTrim( dbo.fnc_RTrim(      
                   STR(CAST(@c_PickHeaderKey AS INT) + (SELECT COUNT(DISTINCT loadkey)      
                                                        FROM #TEMP_PICK AS Rank      
                                                        WHERE Rank.loadkey < #TEMP_PICK.loadkey      
                                                        AND ISNULL(RTRIM(Rank.PickSlipNo),'') = '' ) -- (Leong01)      
                   ) -- str      
                   )) -- dbo.fnc_RTrim      
                   , 9)      
            , '', loadkey,'', '0', '7', '', StorerKey,loadkey                       --(CS01)      
      FROM #TEMP_PICK WHERE ISNULL(RTRIM(PickSlipNo),'') = '' -- (Leong01)      
      GROUP By WaveKey, loadkey, StorerKey      
      
      UPDATE #TEMP_PICK      
      SET PickSlipNo = PickHeader.PickHeaderKey      
      FROM PickHeader (NOLOCK)      
      JOIN #TEMP_PICK ON PickHeader.externorderkey = #TEMP_PICK.loadkey      
      WHERE PickHeader.Zone = '7'      
        AND ISNULL(RTRIM(#TEMP_PICK.PickSlipNo),'') = '' -- (Leong01)      
      
      WHILE @@TRANCOUNT > 0 -- SOS# 303176      
      BEGIN      
         COMMIT TRAN      
      END      
      
   END      
      
      
    --CS02 S      
      IF @c_AutoScaninPickslip='Y'       
      BEGIN      
      
              DECLARE @c_UserName NVARCHAR( 18)      
              SET @c_UserName = 'GetPickSlipOrders75'      
      
             DECLARE autoscaninps_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
               SELECT DISTINCT PickSlipNo      
               FROM #Temp_Pick      
               ORDER BY PickSlipNo      
      
               OPEN autoscaninps_cur      
               FETCH NEXT FROM autoscaninps_cur INTO @c_GetPickslipno      
      
               WHILE @@FETCH_STATUS = 0      
               BEGIN      
      
                 IF NOT EXISTS( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @c_GetPickslipno )      
                 BEGIN              
                        -- Scan in pickslip      
                        EXEC dbo.isp_ScanInPickslip      
                           @c_PickSlipNo  = @c_GetPickslipno,      
                           @c_PickerID    = @c_UserName,      
                           @n_err         = @n_err        OUTPUT,      
                           @c_errmsg      = @c_errmsg     OUTPUT      
      
                        IF @n_err <> 0      
                        BEGIN      
                              SELECT @n_continue=3      
                              Select @c_errmsg= CONVERT(char(250), @n_err), @n_err=22807      
                              Select @c_errmsg= 'NSQL'+CONVERT(char(5), @n_err)+':Auto Scan in Fail. (nsp_GetPickSlipOrders75)'+'('+'SQLSvr MESSAGE='+dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg))+')'      
                              ROLLBACK TRAN      
                              --GOTO QUIT      
                        END      
      
                 END         
      
               FETCH NEXT FROM autoscaninps_cur INTO @c_GetPickslipno      
               END -- autoscaninps_cur WHILE loop      
               CLOSE autoscaninps_cur      
               DEALLOCATE autoscaninps_cur      
      
      END      
    --CS02 E      
      
   BEGIN TRAN      
   UPDATE PickHeader      
   SET PickType = '1', TrafficCop = NULL, editdate = getdate()      
   FROM PickHeader      
   WHERE  Zone = '8'      
   AND Exists ( Select 1 from #TEMP_PICK where PickSlipNo = PickHeader.PickHeaderKey )      
      
   SELECT @n_err = @@ERROR      
   IF @n_err <> 0      
   BEGIN      
      IF @@TRANCOUNT >= 1      
      BEGIN      
         ROLLBACK TRAN      
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
         ROLLBACK TRAN      
      END      
   END      
      
   DECLARE @prevloc NVARCHAR(10)      
   DECLARE @nQty INT      
   SELECT @prevloc = ''      
      
   DECLARE pick_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT DISTINCT Sku, loadkey      
      FROM #Temp_Pick      
      ORDER BY loadkey,sku      
      
   OPEN pick_cur      
   FETCH NEXT FROM pick_cur INTO @c_Sku, @c_ExternOrderKey      
      
   WHILE @@FETCH_STATUS = 0      
   BEGIN      
      DECLARE picksize_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
         SELECT SUBSTRING(PD.Sku,10,5) SIZE, --       change from SUBSTRING(PD.Sku,16,5),   BY Ong sos34665 27/5/2005      
               SUM(PD.Qty) AS Qty,      
               PD.loc AS Loc,      
               S.Busr6 AS Busr6      -- SOS#34665 add Busr6 to solve size order      
         FROM Orders OH (NOLOCK)      
         JOIN OrderDetail OD (NOLOCK) ON OD.orderkey = OH.orderkey      
         JOIN PickDetail PD (NOLOCK) ON (OD.orderKey = PD.orderKey AND OD.StorerKey = PD.StorerKey      
                                         AND OD.Orderlinenumber = PD.Orderlinenumber AND SUBSTRING(OD.Sku,1,9) = SUBSTRING(PD.Sku,1,9))      
         JOIN Sku s (NOLOCK) ON (OD.Sku = S.Sku AND S.StorerKey = PD.StorerKey)      
         WHERE           -- modified by Ong sos34665 7/6/05      
         OH.loadKey = @c_ExternOrderKey      
         AND SUBSTRING(OD.Sku,1,9) = SUBSTRING(@c_Sku,1,9)   -- modified by Ong sos34665 7/6/05      
         GROUP BY SUBSTRING(PD.Sku,10,5), OD.Userdefine01, PD.loc, S.Busr6   ---BY Ong sos34665 27/5/2005      
         --      ORDER BY OD.Userdefine01--SUBSTRING(Sku,16,5)      
         ORDER BY PD.loc, OD.Userdefine01, S.Busr6 -- SOS#34665 add Busr6 to solve size order      
      
      OPEN picksize_cur      
      SELECT @c_loopcnt = 1      
      FETCH NEXT FROM picksize_cur INTO @c_size, @n_PDQty, @c_loc, @c_Busr6      
      
      WHILE @@FETCH_STATUS = 0      
      BEGIN      
         IF  @prevloc <> @c_loc      
         BEGIN      
            SELECT @c_loopcnt = 1      
         END      
         -- re-calculate Qty      
         IF @c_loopcnt = 1      
         BEGIN      
            SELECT @nQty = 0      
         END      
      
         SELECT @nQty = CAST(@nQty AS INT) + @n_PDQty      
      
         SELECT @theSQLStmt = 'UPDATE #Temp_Pick SET SizeCOL'+dbo.fnc_RTrim(CAST(@c_loopcnt AS char))+'= RTrim(@c_size) '      
         SELECT @theSQLStmt = @theSQLStmt+', QtyCOL'+dbo.fnc_RTrim(CAST(@c_loopcnt AS char))+'= @n_PDQty '      
         SELECT @theSQLStmt = @theSQLStmt+' WHERE SUBSTRING(Sku,1,9) = SUBSTRING(@c_Sku,1,9) AND loadkey = @c_ExternOrderKey '   -- modified by Ong sos34665 7/6/05      
         SELECT @theSQLStmt = @theSQLStmt+' AND Loc = @c_loc '      
      
         SET @c_SQLParm =  N'@c_ExternOrderKey   NVARCHAR(50),  @c_SKU        NVARCHAR(20), ' +      --tlting_ext      
                            '@c_loc NVARCHAR(10), @c_size NVARCHAR(18), @n_PDQty  INT '      
      
         EXEC sp_ExecuteSQL @theSQLStmt, @c_SQLParm, @c_ExternOrderKey, @c_SKU, @c_loc, @c_size, @n_PDQty      
      
         SELECT @c_loopcnt = @c_loopcnt + 1      
         SELECT @prevloc = @c_loc      
      
      FETCH NEXT FROM picksize_cur INTO @c_size, @n_PDQty, @c_loc, @c_Busr6      
      END -- size_cur WHILE loop      
      CLOSE picksize_cur      
      DEALLOCATE picksize_cur      
      FETCH NEXT FROM pick_cur INTO @c_Sku, @c_ExternOrderKey      
   END -- pick_cur WHILE loop      
   CLOSE pick_cur      
   DEALLOCATE pick_cur      
      
   GOTO SUCCESS      
      
   FAILURE:      
   DELETE FROM #TEMP_PICK      
      
   SUCCESS:      
   -- Added By SHONG ON 6th Aug 2003      
   -- SOS# 12791 - Interface Manual Order      
   DECLARE @cOrdKey         NVARCHAR(10),      
           @cStorerKey      NVARCHAR(15),      
           @cTransmitlogKey NVARCHAR(10)      
      
   SELECT @cOrdKey = ''      
      
   WHILE 1=1      
   BEGIN      
      SELECT @cOrdKey = MIN(loadkey)      
      FROM #TEMP_PICK      
      WHERE  loadkey > @cOrdKey      
      
      IF dbo.fnc_RTrim(@cOrdKey) IS NULL OR dbo.fnc_RTrim(@cOrdKey) = ''      
         BREAK      
      
      SELECT TOP 1 @cStorerKey = StorerKey      
      FROM   ORDERS (NOLOCK)      
      WHERE  loadkey = @cOrdKey      
      
      IF EXISTS(SELECT 1 FROM StorerConfig (NOLOCK) WHERE ConfigKey = 'NIKEHK_MANUALORD' And sValue = '1'      
                AND StorerKey = @cStorerKey)      
      BEGIN      
         IF NOT EXISTS (SELECT 1 FROM Transmitlog (NOLOCK) WHERE TableName = 'NIKEHKMORD' AND Key1 = @cOrdKey)      
         BEGIN      
            SELECT @cTransmitlogKey = ''      
            SELECT @b_success = 1      
      
            EXECUTE nspg_getKey      
            'TransmitlogKey'      
            ,10      
            , @cTransmitlogKey OUTPUT      
            , @b_success OUTPUT      
            , @n_err OUTPUT      
            , @c_errmsg OUTPUT      
      
            IF NOT @b_success = 1      
            BEGIN      
               SELECT @n_continue = 3      
               SELECT @n_err = @@ERROR      
               SELECT @c_errMsg = 'Error Found When Generating TransmitLogKey (nsp_GetPickSlipOrders75)'      
            END      
            ELSE      
            BEGIN      
               INSERT TransmitLog (transmitlogKey,tablename,Key1,Key2, Key3)      
               VALUES (@cTransmitlogKey, 'NIKEHKMORD', @cOrdKey, '', '' )      
               IF @@ERROR <> 0      
               BEGIN      
                  SELECT @n_continue = 3      
                  SELECT @n_err = @@ERROR      
                  SELECT @c_errMsg = 'Insert into TransmitLog Failed (nsp_GetPickSlipOrders75)'      
               END      
            END      
     END      
      END      
   END -- END while      
      
   IF @n_continue = 3  -- Error Occured - Process And Return      
   BEGIN      
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_GetPickSlipOrders75'      
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
      RETURN      
   END      
      
   SELECT *  FROM #TEMP_PICK      
   ORDER BY wavekey,convert(datetime, deliverydate, 103),[Route],loadkey, Loc, Sku      
      
   DROP Table #TEMP_PICK      
  
    DROP TABLE #TEMP_PICKLoad             --CS03  
      
   WHILE @@TRANCOUNT < @n_starttcnt -- SOS# 303176      
   BEGIN      
      BEGIN TRAN      
   END      
END -- Procedure   

GO