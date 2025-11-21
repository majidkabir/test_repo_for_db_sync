SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: nsp_GetPickSlipOrders12                             */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Generate PickSlip by WaveKey                                */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 06-Aug-2003  SHONG         Interface Manual Order- (SOS#12791).      */
/* 03-Dec-2003  SHONG         - (SOS#16003).                            */
/* 03-May-2004  Ong           NSC Project Change Request                */
/*                            - (SOS#34665).                            */
/* 13-Apr-2006  SHONG         Add StorerKey into PickHeader             */
/* 13-Feb-2014  Leong         SOS# 303176 - Performance tune.           */
/*                            Prevent Pickslip number not tally with    */
/*                            nCounter table. (Leong01)                 */
/* 4-April-2014 TLTING        Bug fix - mess update on Pickheader       */
/* 30-Aug-2017  TLTING  1.1   Dynamic SQL review, impact SQL cache log  */ 
/* 28-Jan-2019  TLTING_ext 1.2 enlarge externorderkey field length      */ 
/************************************************************************/

CREATE PROC [dbo].[nsp_GetPickSlipOrders12] (@c_WaveKey_start NVARCHAR(10), @c_WaveKey_end NVARCHAR(10),
                                     @c_StorerKey_start NVARCHAR(10), @c_StorerKey_end NVARCHAR(10),
                                     @c_pickslipno_start NVARCHAR(10), @c_pickslipno_end NVARCHAR(10),
                                     @c_ExternOrderKey_start NVARCHAR(50), @c_ExternOrderKey_end NVARCHAR(50))  --tlting_ext
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
           @c_ExternOrderKey     NVARCHAR(50),  --tlting_ext
           @c_PickSlipNo         NVARCHAR(10),
           @c_size               NVARCHAR(5),
           @c_qty                NVARCHAR(5),
           @c_PrintedFlag        NVARCHAR(1),
           @n_cnt                INT,
           @c_loc                NVARCHAR(10),
           @c_Busr6              NVARCHAR(30),
           @c_SQLParm            NVARCHAR(2000) = '',
           @n_PDQty              INT = 0

   SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT, @theSQLStmt = ''
   SELECT @n_pickslips_required = 0 -- (Leong01)

   WHILE @@TRANCOUNT > 0 -- SOS# 303176
   BEGIN
      COMMIT TRAN
   END

   SELECT @n_cnt = COUNT(*)
   FROM PickHeader (NOLOCK)
   WHERE (WaveKey BETWEEN @c_WaveKey_start AND @c_WaveKey_end)

   CREATE TABLE #TEMP_PICK
       ( PickSlipNo       NVARCHAR(10) NULL,
         OrderKey         NVARCHAR(10),
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
         Sku              NVARCHAR(20) NULL,
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
         Busr7  NVARCHAR(30) NULL,   -- change request 16July2003
         Notes2 NVARCHAR(255) NULL DEFAULT '', -- Added By SHong ON 3-12-2003, SOS16003
         Lottable02 NVARCHAR(20) NULL,
         UOM3 NVARCHAR(10) NULL,
         PackQtyIndicator INT NULL,
         StorerKey NVARCHAR(15) NULL
       )

	 Create index IDX_TEMP_PICK_01 on #TEMP_PICK ( PickSlipNo )

   IF @n_cnt = 0
   BEGIN
      INSERT INTO #TEMP_PICK (PickSlipNo, OrderKey, ExternOrderKey, DeliveryDate, WaveKey, InvoiceNo,
                             Route, Facility, BuyerPO, B_Company, B_Addr1, B_Addr2, B_Addr3, B_Addr4,
                             B_Country, C_Company, C_Addr1, C_Addr2, C_Addr3, C_Addr4, C_City, C_Country, LOC,
                             Sku, SkuDesc, Qty, Remarks, LogicalLocation, PrintFlag, BUSR7, Notes2,
                             lottable02, UOM3, PackQtyIndicator, StorerKey)      -- added by Ong 3/5/05
      SELECT (SELECT PickHeader.PickHeaderKey FROM PickHeader (NOLOCK)
               WHERE ( PickHeader.WaveKey BETWEEN @c_WaveKey_start AND @c_WaveKey_end )
               AND PickHeader.OrderKey = ORDERS.OrderKey
               AND PickHeader.ZONE = '8') ,
            ORDERS.OrderKey,
            ORDERS.ExternOrderKey,
            CONVERT(NVARCHAR(10), ORDERS.DeliveryDate, 103) AS DeliveryDate,
            ISNULL(ORDERS.UserDefine09,'') AS WaveKey,
            ORDERS.Invoiceno,
            ORDERS.Route,
            ORDERS.Facility,
            ORDERS.BuyerPO,
            ISNULL(ORDERS.B_Company, '') AS B_Company,
            ISNULL(ORDERS.B_Address1, '')AS B_Addr1,
            ISNULL(ORDERS.B_Address2,'') AS B_Addr2,
            ISNULL(ORDERS.B_Address3,'') AS B_Addr3,
            ISNULL(ORDERS.B_Address4,'') AS B_Addr4,
            ISNULL(ORDERS.B_Country,'')  AS B_Country,
            ISNULL(ORDERS.C_Company, '') AS C_Company,
            ISNULL(ORDERS.C_Address1, '')AS C_Addr1,
            ISNULL(ORDERS.C_Address2,'') AS C_Addr2,
            ISNULL(ORDERS.C_Address3,'') AS C_Addr3,
            ISNULL(ORDERS.C_Address4,'') AS C_Addr4,
            ISNULL(ORDERS.C_City,'')  AS C_City,            -- added by Ong 3/5/05
            ISNULL(ORDERS.C_Country,'')  AS C_Country,
            PickDetail.Loc,
            SUBSTRING(Sku.Sku,1,9) AS Sku,       -- modified by Ong sos34665 6/6/05
            ISNULL(Sku.Descr,'') AS SkuDescr,
            SUM(PickDetail.Qty) AS Qty,
            dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(255),ORDERS.Notes))) AS Remarks,  -- change request 16July2003
            LOC.LogicalLocation,
            'N' AS PrintFlag,
            Sku.BUSR7,  -- change request 16July2003
            dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(255),ORDERS.Notes2))) AS Notes2,   -- Added By SHong ON 3-12-2003, SOS16003
            dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(20), LOTATTRIBUTE.lottable02))) AS lottable02,  -- added by Ong 3/5/05
            dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(10), pack.PackUOM3))) AS UOM3,                   -- added by Ong 3/5/05
            Sku.PackQtyIndicator AS PackQtyIndicator                              -- added by Ong 3/5/05
          , ORDERS.StorerKey
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
      LEFT OUTER JOIN STORER (NOLOCK) ON (ORDERS.ConsigneeKey = STORER.StorerKey AND STORER.Type = '2')
      WHERE PickDetail.Status < '5'
      AND (PickDetail.PickMethod = '8' OR PickDetail.PickMethod = '')
      AND (WAVEDETAIL.WaveKey >= @c_WaveKey_start AND WAVEDETAIL.WaveKey <= @c_WaveKey_end )
      AND (ORDERS.StorerKey >= @c_StorerKey_start AND ORDERS.StorerKey <= @c_StorerKey_end )
      AND (ORDERS.ExternOrderKey >= @c_ExternOrderKey_start AND ORDERS.ExternOrderKey <= @c_ExternOrderKey_end )
      GROUP BY ORDERS.OrderKey,
               ORDERS.ExternOrderKey,
               CONVERT(NVARCHAR(10), ORDERS.DeliveryDate, 103),
               ISNULL(ORDERS.UserDefine09,''),
               ORDERS.Invoiceno,
               ORDERS.Route,
               ORDERS.Facility,
               ORDERS.BuyerPO,
               ISNULL(ORDERS.B_Company, '') ,
               ISNULL(ORDERS.B_Address1, ''),
               ISNULL(ORDERS.B_Address2,'') ,
               ISNULL(ORDERS.B_Address3,'') ,
               ISNULL(ORDERS.B_Address4,''),
               ISNULL(ORDERS.B_Country,''),
               ISNULL(ORDERS.C_Company, '') ,
               ISNULL(ORDERS.C_Address1, ''),
               ISNULL(ORDERS.C_Address2,''),
               ISNULL(ORDERS.C_Address3,''),
               ISNULL(ORDERS.C_Address4,''),
               ISNULL(ORDERS.C_City,''),        -- added by Ong 3/5/05
               ISNULL(ORDERS.C_Country,''),
               PickDetail.Loc,
               SUBSTRING(Sku.Sku,1,9),   -- modified by Ong 6/6/05 sos34665
               ISNULL(Sku.Descr,'') ,
               LOC.LogicalLocation,
               dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(255),ORDERS.Notes))),  -- change request 16July2003
               Sku.BUSR7,  -- change request 16July2003
               dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(255),ORDERS.Notes2))), -- SOS16003
               dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(20), lotattribute.lottable02))),  -- added by Ong 3/5/05   sos34665
               dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(10), pack.PackUOM3))),                   -- added by Ong 3/5/05   sos34665
               PackQtyIndicator                              -- added by Ong 3/5/05
             , ORDERS.StorerKey
   END
   ELSE
   BEGIN
      INSERT INTO #TEMP_PICK (PickSlipNo, OrderKey, ExternOrderKey, DeliveryDate, WaveKey, InvoiceNo,
                             Route, Facility, BuyerPO, B_Company, B_Addr1, B_Addr2, B_Addr3, B_Addr4,
                             B_Country, C_Company, C_Addr1, C_Addr2, C_Addr3, C_Addr4, C_City, C_Country, LOC,
                             Sku, SkuDesc, Qty, Remarks, LogicalLocation, PrintFlag, BUSR7, Notes2,  -- change request 16July2003
                             lottable02, UOM3, PackQtyIndicator, StorerKey)      -- added by Ong 3/5/05
      SELECT PickHeader.PickHeaderKey,
             ORDERS.OrderKey,
             ORDERS.ExternOrderKey,
             CONVERT(NVARCHAR(10), ORDERS.DeliveryDate, 103) AS DeliveryDate,
             ISNULL(ORDERS.UserDefine09,'') AS WaveKey,
             ORDERS.Invoiceno,
             ORDERS.Route,
             ORDERS.Facility,
             ORDERS.BuyerPO,
             ISNULL(ORDERS.B_Company, '') AS B_Company,
             ISNULL(ORDERS.B_Address1, '')AS B_Addr1,
             ISNULL(ORDERS.B_Address2,'') AS B_Addr2,
             ISNULL(ORDERS.B_Address3,'') AS B_Addr3,
             ISNULL(ORDERS.B_Address4,'') AS B_Addr4,
             ISNULL(ORDERS.B_Country,'')  AS B_Country,
             ISNULL(ORDERS.C_Company, '') AS C_Company,
             ISNULL(ORDERS.C_Address1, '')AS C_Addr1,
             ISNULL(ORDERS.C_Address2,'') AS C_Addr2,
             ISNULL(ORDERS.C_Address3,'') AS C_Addr3,
             ISNULL(ORDERS.C_Address4,'') AS C_Addr4,
             ISNULL(ORDERS.C_City,'')  AS C_City,         -- added by Ong 3/5/05
             ISNULL(ORDERS.C_Country,'')  AS C_Country,
             PickDetail.Loc,
             SUBSTRING(Sku.Sku,1,9) AS Sku,    -- modified by Ong 6/6/05 sos34665
             ISNULL(Sku.Descr,'') AS SkuDescr,
             SUM(PickDetail.Qty) AS Qty,
             dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(255),ORDERS.Notes))) AS Remarks,  -- change request 16July2003
             LOC.LogicalLocation,
             'Y' AS PrintFlag ,
             Sku.BUSR7,  -- change request 16July2003
             dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(255),ORDERS.Notes2))) AS Notes2,
             dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(20), lotattribute.lottable02))) AS lottable02,  -- added by Ong 3/5/05
             dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(10), pack.PackUOM3))) AS UOM3,                   -- added by Ong 3/5/05
             Sku.PackQtyIndicator AS PackQtyIndicator                              -- added by Ong 3/5/05
           , ORDERS.StorerKey
      FROM PickDetail (NOLOCK)
      JOIN ORDERS (NOLOCK) ON (PickDetail.OrderKey = ORDERS.OrderKey AND ORDERS.UserDefine08 = 'Y')
      JOIN WAVEDETAIL (NOLOCK) ON (PickDetail.OrderKey = WAVEDETAIL.OrderKey)
      JOIN LOTATTRIBUTE (NOLOCK) ON (PickDetail.Lot = LOTATTRIBUTE.Lot)
      JOIN Sku (NOLOCK) ON (PickDetail.StorerKey = Sku.StorerKey AND PickDetail.Sku = Sku.Sku)
      JOIN Pack (NOLOCK) ON (Pack.packKey = Sku.packKey)         -- added by Ong 3/5/05
      JOIN SkuxLOC (NOLOCK) ON (PickDetail.Loc = SkuxLOC.Loc AND PickDetail.StorerKey = SkuxLOC.StorerKey
                                AND PickDetail.Sku = SkuxLOC.Sku)
      JOIN LOC (NOLOCK) ON (PickDetail.Loc = LOC.Loc)
      LEFT OUTER JOIN STORER (NOLOCK) ON (ORDERS.ConsigneeKey = STORER.StorerKey AND STORER.Type = '2')
      JOIN PickHeader (NOLOCK) ON (PickHeader.OrderKey = ORDERS.OrderKey AND PickHeader.WaveKey = WAVEDETAIL.WaveKey )
      WHERE
      --   PickDetail.Status < '5' AND (PickDetail.PickMethod = '8' OR PickDetail.PickMethod = '') AND
      (WAVEDETAIL.WaveKey >= @c_WaveKey_start AND WAVEDETAIL.WaveKey <= @c_WaveKey_end )
      AND (ORDERS.StorerKey >= @c_StorerKey_start AND ORDERS.StorerKey <= @c_StorerKey_end )
      AND (PickHeader.PickHeaderKey >= @c_pickslipno_start AND PickHeader.PickHeaderKey <= @c_pickslipno_end )
      AND (ORDERS.ExternOrderKey >= @c_ExternOrderKey_start AND ORDERS.ExternOrderKey <= @c_ExternOrderKey_end )
      GROUP BY PickHeader.PickHeaderKey,
               ORDERS.OrderKey,
               ORDERS.ExternOrderKey,
               CONVERT(NVARCHAR(10), ORDERS.DeliveryDate, 103),
               ISNULL(ORDERS.UserDefine09,''),
               ORDERS.Invoiceno,
               ORDERS.Route,
               ORDERS.Facility,
               ORDERS.BuyerPO,
               ISNULL(ORDERS.B_Company, '') ,
               ISNULL(ORDERS.B_Address1, ''),
               ISNULL(ORDERS.B_Address2,'') ,
               ISNULL(ORDERS.B_Address3,'') ,
               ISNULL(ORDERS.B_Address4,''),
               ISNULL(ORDERS.B_Country,''),
               ISNULL(ORDERS.C_Company, '') ,
               ISNULL(ORDERS.C_Address1, ''),
               ISNULL(ORDERS.C_Address2,''),
               ISNULL(ORDERS.C_Address3,''),
               ISNULL(ORDERS.C_Address4,''),
               ISNULL(ORDERS.C_City,''),        -- added by Ong 3/5/05
               ISNULL(ORDERS.C_Country,''),
               PickDetail.Loc,
               SUBSTRING(Sku.Sku,1,9),   -- modified by Ong 6/6/05 sos34665
               ISNULL(Sku.Descr,'') ,
               LOC.LogicalLocation,
               dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(255),ORDERS.Notes))),  -- change request 16July2003
               Sku.BUSR7,  -- change request 16July2003
               dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(255),ORDERS.Notes2))),
               dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(20), lotattribute.lottable02))),  -- added by Ong 3/5/05
               dbo.fnc_RTrim(dbo.fnc_LTrim(CONVERT(NVARCHAR(10), pack.PackUOM3))),                   -- added by Ong 3/5/05
               Sku.PackQtyIndicator                             -- added by Ong 3/5/05
             , ORDERS.StorerKey
   END -- END @n_cnt

   SELECT @n_pickslips_required = COUNT(DISTINCT OrderKey)
   FROM #TEMP_PICK
   WHERE ISNULL(RTRIM(PickSlipNo),'') = '' -- (Leong01)

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
      INSERT INTO PickHeader (PickHeaderKey, OrderKey, WaveKey, PickType, Zone, TrafficCop, StorerKey)
      SELECT 'P' + RIGHT ( REPLICATE ('0', 9) +
                   dbo.fnc_LTrim( dbo.fnc_RTrim(
                   STR(CAST(@c_PickHeaderKey AS INT) + (SELECT COUNT(DISTINCT orderKey)
                                                        FROM #TEMP_PICK AS Rank
                                                        WHERE Rank.OrderKey < #TEMP_PICK.OrderKey
                                                        AND ISNULL(RTRIM(Rank.PickSlipNo),'') = '' ) -- (Leong01)
                   ) -- str
                   )) -- dbo.fnc_RTrim
                   , 9)
            , OrderKey, WaveKey, '0', '8', '', StorerKey
      FROM #TEMP_PICK WHERE ISNULL(RTRIM(PickSlipNo),'') = '' -- (Leong01)
      GROUP By WaveKey, OrderKey, StorerKey

      UPDATE #TEMP_PICK
      SET PickSlipNo = PickHeader.PickHeaderKey
      FROM PickHeader (NOLOCK)
      WHERE PickHeader.WaveKey = #TEMP_PICK.WaveKey
        AND PickHeader.OrderKey = #TEMP_PICK.OrderKey
        AND PickHeader.Zone = '8'
        AND ISNULL(RTRIM(#TEMP_PICK.PickSlipNo),'') = '' -- (Leong01)

      WHILE @@TRANCOUNT > 0 -- SOS# 303176
      BEGIN
         COMMIT TRAN
      END
   END


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
      SELECT Sku, ExternOrderKey
      FROM #Temp_Pick

   OPEN pick_cur
   FETCH NEXT FROM pick_cur INTO @c_Sku, @c_ExternOrderKey

   WHILE @@FETCH_STATUS = 0
   BEGIN
      DECLARE picksize_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT SUBSTRING(PD.Sku,10,5) SIZE, --       change from SUBSTRING(PD.Sku,16,5),   BY Ong sos34665 27/5/2005
               SUM(PD.Qty) AS Qty,
               PD.loc AS Loc,
               S.Busr6 AS Busr6      -- SOS#34665 add Busr6 to solve size order
         FROM OrderDetail OD (NOLOCK)
         JOIN PickDetail PD (NOLOCK) ON (OD.orderKey = PD.orderKey AND OD.StorerKey = PD.StorerKey
                                         AND OD.Orderlinenumber = PD.Orderlinenumber AND SUBSTRING(OD.Sku,1,9) = SUBSTRING(PD.Sku,1,9))
         JOIN Sku s (NOLOCK) ON (OD.Sku = S.Sku AND S.StorerKey = PD.StorerKey)
         WHERE           -- modified by Ong sos34665 7/6/05
         OD.ExternOrderKey = @c_ExternOrderKey
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
         SELECT @theSQLStmt = @theSQLStmt+' WHERE SUBSTRING(Sku,1,9) = SUBSTRING(@c_Sku,1,9) AND ExternOrderKey = @c_ExternOrderKey '   -- modified by Ong sos34665 7/6/05
         SELECT @theSQLStmt = @theSQLStmt+' AND Loc = @c_loc '

         SET @c_SQLParm =  N'@c_ExternOrderKey   NVARCHAR(30),  @c_SKU        NVARCHAR(20), ' +    
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
      SELECT @cOrdKey = MIN(OrderKey)
      FROM #TEMP_PICK
      WHERE  OrderKey > @cOrdKey

      IF dbo.fnc_RTrim(@cOrdKey) IS NULL OR dbo.fnc_RTrim(@cOrdKey) = ''
         BREAK

      SELECT @cStorerKey = StorerKey
      FROM   ORDERS (NOLOCK)
      WHERE  OrderKey = @cOrdKey

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
               SELECT @c_errMsg = 'Error Found When Generating TransmitLogKey (nsp_GetPickSlipOrders12)'
            END
            ELSE
            BEGIN
               INSERT TransmitLog (transmitlogKey,tablename,Key1,Key2, Key3)
               VALUES (@cTransmitlogKey, 'NIKEHKMORD', @cOrdKey, '', '' )
               IF @@ERROR <> 0
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @n_err = @@ERROR
                  SELECT @c_errMsg = 'Insert into TransmitLog Failed (nsp_GetPickSlipOrders12)'
               END
            END
         END
      END
   END -- END while

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_GetPickSlipOrders12'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END

   SELECT * FROM #TEMP_PICK ORDER BY PickSlipNo, LogicalLocation, Loc, Sku
   DROP Table #TEMP_PICK

   WHILE @@TRANCOUNT < @n_starttcnt -- SOS# 303176
   BEGIN
      BEGIN TRAN
   END
END -- Procedure

GO