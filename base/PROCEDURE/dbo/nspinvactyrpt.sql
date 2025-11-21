SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspInvactyRpt                                      */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

-- Leave bulk&shelves consolidation blank and recalculate net&gross variance
-- For calculating accumulative Net & Gross Variance in Grand Total Line
CREATE PROC [dbo].[nspInvactyRpt] (
@DateMin	        NVARCHAR(10),
@DateMax	        NVARCHAR(10)
) AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE	@InventoryDate		DateTime,
   @Sku		 NVARCHAR(20),
   @replenQty		Int,
   @CaseCnt		Int,
   @TotalbulkLoc		Int,
   @TotalPickLoc		Int,
   @Day		 NVARCHAR(3),
   --		@pre_bulk		int,
   @BulkFilled		Int,
   @Bulkpercent		Float,
   --		@pre_shelve		int,
   @ShelveFilled		Int,
   @Shelvepercent		float,
   @Replenishment_Cnt	Int,
   @prebalance		float,
   @skupositive		float,
   @skunegative		float,
   @locpositive		float,
   @locnegative		float,
   @Sku_CC_cnt		Int,
   @Sku_CC_NV_Percent	float,
   @Sku_CC_GV_Percent	float,
   @Loc_CC_cnt		Int,
   @Loc_CC_NV_Percent	float,
   @Loc_CC_GV_Percent	float,
   @Shelve_Loc_Consolid	Int,
   @Bulk_Loc_Consolid	Int,
   @Staff_Cnt	 NVARCHAR(5),
   @Hours_Cnt	 NVARCHAR(5),
   @Remark		 NVARCHAR(30)
   CREATE TABLE #RESULT
   (Week		 NVARCHAR(10) NULL,
   InventoryDate		DateTime,
   Day		 NVARCHAR(3) NULL,
   BulkFilled		Int NULL,
   Bulkpercent		Float NULL,
   ShelveFilled		Int NULL,
   Shelvepercent		Float NULL,
   Replenishment_Cnt	Int NULL,
   Sku_CC_cnt		Int NULL,
   Sku_CC_NV_Percent	float NULL,
   Sku_CC_GV_Percent	float NULL,
   Loc_CC_cnt		Int NULL,
   Loc_CC_NV_Percent	float NULL,
   Loc_CC_GV_Percent	float NULL,
   Shelve_Loc_Consolid NVARCHAR(10) NULL,
   Bulk_Loc_Consolid NVARCHAR(10) NULL,
   Staff_Cnt	 NVARCHAR(5) NULL,
   Hours_Cnt	 NVARCHAR(5) NULL,
   Remark		 NVARCHAR(30) NULL,
   Prebalance		float,
   SKUNegative		float,
   SKUPositive		float,
   LOCNegative		float,
   LOCPositive		float)
   INSERT INTO #RESULT (InventoryDate)
   SELECT Distinct convert(char(10), Inventorydate, 121) As Inventorydate
   FROM DailyInventory (nolock)
   WHERE InventoryDate >= @DateMin AND InventoryDate < DATEADD(dd, 1, @DateMax)
   AND StorerKey = 'NIKETH'
   ORDER BY Inventorydate
   DECLARE CUR_1 CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT InventoryDate
   FROM #RESULT
   --		select @pre_bulk = 0, @pre_shelve = 0
   OPEN CUR_1
   FETCH NEXT FROM CUR_1 INTO @InventoryDate

   WHILE (@@fetch_status <> -1)
   BEGIN
      /*  1. Get the day of week */
      SELECT @Day = case datepart(dw, @InventoryDate)
      When 1 Then 'SUN'
      When 2 Then 'MON'
      When 3 Then 'TUE'
      When 4 Then 'WED'
      When 5 Then 'THU'
      When 6 Then 'FRI'
      When 7 Then 'SAT'
   End
   SELECT @TotalbulkLoc = Count(Loc)
   FROM Locbak (nolock)
   WHERE Locbak.LocationType NOT IN ('PICK', 'CASE')
   AND Locbak.PutawayZone IN ('A01', 'A02', 'A02A', 'M1A', 'M1B', 'M1C',
   'M2A', 'M2B', 'M2C', 'M3A', 'M3C', 'RACK')
   AND Locbak.InventoryDate >= @InventoryDate AND Locbak.InventoryDate < DATEADD(dd, 1, @InventoryDate)

   IF @TotalbulkLoc > 0
   Begin
      SELECT @TotalbulkLoc = @TotalbulkLoc
   End
Else
   Begin
      SELECT @TotalbulkLoc = 1
   End
   SELECT @BulkFilled = Count(Distinct Loc.Loc)
   FROM DailyInventory DI (nolock), Locbak Loc (nolock)
   WHERE DI.Loc = Loc.Loc
   AND DI.InventoryDate >= @InventoryDate AND DI.InventoryDate < DATEADD(dd, 1, @InventoryDate)
   AND DI.Qty > 0
   AND DI.Storerkey = 'NIKETH'
   AND Loc.LocationType NOT IN ('PICK', 'CASE')
   AND Loc.PutawayZone IN ('A01', 'A02', 'A02A', 'M1A', 'M1B', 'M1C',
   'M2A', 'M2B', 'M2C', 'M3A', 'M3C', 'RACK')
   IF @BulkFilled > 0
   Begin
      SELECT @BulkFilled = @BulkFilled
   End
Else
   Begin
      SELECT @BulkFilled = 0
   End

   SELECT @Bulkpercent = (convert(float,@BulkFilled)/convert(float,@TotalbulkLoc)) * 100
   /*			if @pre_bulk = 0
   begin
   select @bulk_loc_consolid = 0
   end
   else
   begin
   select @bulk_loc_consolid = @pre_bulk - @bulkfilled
   end
   */
   SELECT @TotalpickLoc = Count(Loc)
   FROM Locbak (nolock)
   WHERE Locbak.LocationType IN ('PICK', 'CASE')
   AND Locbak.PutawayZone IN ('A01', 'A02', 'A02A', 'M1A', 'M1B', 'M1C',
   'M2A', 'M2B', 'M2C', 'M3A', 'M3C', 'RACK')
   AND Locbak.InventoryDate >= @InventoryDate AND Locbak.InventoryDate < DATEADD(dd, 1, @InventoryDate)

   IF @TotalpickLoc > 0
   Begin
      SELECT @TotalpickLoc = @TotalpickLoc
   End
Else
   Begin
      SELECT @TotalpickLoc = 1
   End
   SELECT @ShelveFilled = Count(Distinct Loc.Loc)
   FROM DailyInventory DI (nolock), Locbak Loc (nolock)
   WHERE DI.Loc = Loc.Loc
   AND DI.InventoryDate >= @InventoryDate AND DI.InventoryDate < DATEADD(dd, 1, @InventoryDate)
   AND DI.Qty > 0
   AND DI.Storerkey = 'NIKETH'
   AND Loc.LocationType IN ('PICK', 'CASE')
   AND Loc.PutawayZone IN ('A01', 'A02', 'A02A', 'M1A', 'M1B', 'M1C',
   'M2A', 'M2B', 'M2C', 'M3A', 'M3C', 'RACK')
   IF @ShelveFilled > 0
   Begin
      SELECT @ShelveFilled = @ShelveFilled
   End
Else
   Begin
      SELECT @ShelveFilled = 0
   End

   SELECT @Shelvepercent = (convert(float,@ShelveFilled)/convert(float,@TotalpickLoc)) * 100
   /*			if @pre_shelve = 0
   begin
   select @shelve_loc_consolid = 0
   end
   else
   begin
   select @shelve_loc_consolid = @pre_shelve - @shelvefilled
   end
   */
   SELECT @Replenishment_Cnt = 0
   DECLARE Replen_Cur CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT Sku, sum(qty)
   FROM ITRN (nolock)
   WHERE AddDate >= @InventoryDate AND AddDate < DATEADD(dd, 1, @InventoryDate)
   AND Storerkey = 'NIKETH'
   AND Sourcetype = 'nsp_replenishment'
   AND TranType = 'MV'
   GROUP BY SKU

   OPEN Replen_Cur
   FETCH NEXT FROM Replen_Cur INTO @Sku, @replenQty

   WHILE (@@fetch_status <> -1)
   BEGIN
      IF @replenQty > 0
      Begin
         Select @replenQty = @replenQty
      End
   Else
      Begin
         Select @replenQty = 0
      End

      SELECT @CaseCnt = Casecnt
      FROM SKU (nolock), Pack (Nolock)
      WHERE Pack.Packkey = SKU.packkey
      AND SKU.Storerkey = 'NIKETH'
      AND SKU.Sku = @Sku
      IF @Casecnt > 0
      Begin
         SELECT @Replenishment_Cnt = @Replenishment_Cnt + Floor(@replenQty/@Casecnt)
      End
   else
      begin
         SELECT @Replenishment_Cnt = @Replenishment_Cnt + @replenQty
      end

      FETCH NEXT FROM Replen_Cur INTO @Sku, @replenQty
   END  /* cursor loop */

   CLOSE      Replen_Cur
   DEALLOCATE Replen_Cur
   /*			select sku, netvar = sum(qty )
   ,	grossvar = abs(sum(qty))
   ,	netsum = sum(case when sourcekey = 'nsp_CCWithdrawstock' then abs(qty) else 0 end)
   into #tnCCsku from itrn (nolock)
   where adddate >= @inventorydate and adddate < DATEADD(dd, 1, @inventorydate)
   and Storerkey = 'NIKETH'
   and Sourcekey in ('nsp_CCWithdrawStock','nsp_InsertStock')
   and Sourcetype in ('CC Withdrawal','CC Deposit','NIKE-DP-0208')
   and trantype in ('DP','WD')
   group by sku
   select @sku_cc_cnt = count(sku)
   ,	@sku_cc_nv_percent = (convert(float,sum(netvar))/convert(float,sum(netsum)))*100
   ,	@sku_cc_gv_percent = (convert(float,sum(grossvar))/convert(float,sum(netsum)))*100
   from #tnCCsku
   */
   select @skupositive = 0, @skunegative = 0, @prebalance = 0
   select sku, netvar = sum(qty)
,	prebalance = sum(case when trantype = 'WD' then abs(qty) else 0 end)
   into #tnCCsku from itrn (nolock)
   where adddate >= @inventorydate and adddate < DATEADD(dd, 1, @inventorydate)
   and Storerkey = 'NIKETH'
   and Sourcetype like 'CC%'
   and Toloc <> 'NIKELOSS'
   and trantype in ('DP','WD')
   group by sku
   select @sku_cc_cnt = count(sku)
,	@skupositive = sum(case when netvar > 0 then netvar else 0 end)
,	@skunegative = sum(case when netvar < 0 then netvar else 0 end)
   ,	@prebalance = sum(prebalance)
   from #tnCCsku
   if @prebalance = 0
   begin
      select @sku_cc_nv_percent = 0, @sku_cc_gv_percent = 0
   end
else
   begin
      select @sku_cc_nv_percent = (convert(float,@skunegative+@skupositive)/convert(float,@prebalance))*100
      ,      @sku_cc_gv_percent = (convert(float,@skupositive-@skunegative)/convert(float,@prebalance))*100
   end
   drop table #tnCCsku
   /*			select loc = toloc, netvar = sum(qty)
   ,	grossvar = abs(sum(qty))
   ,	netsum = sum(case when sourcekey = 'nsp_CCWithdrawStock' then abs(qty) else 0 end)
   into #tnCCloc from itrn (nolock)
   where adddate >= @inventorydate and adddate < DATEADD(dd, 1, @inventorydate)
   and Storerkey = 'NIKETH'
   and Sourcekey in ('nsp_CCWithdrawStock','nsp_InsertStock')
   and Sourcetype in ('CC Withdrawal','CC Deposit','NIKE-DP-0208')
   and trantype in ('DP','WD')
   group by toloc
   select @loc_cc_cnt = count(loc)
   ,	@loc_cc_nv_percent = (convert(float,sum(netvar))/convert(float,sum(netsum)))*100
   ,	@loc_cc_gv_percent = (convert(float,sum(grossvar))/convert(float,sum(netsum)))*100
   from #tnCCloc
   drop table #tnCCloc
   */
   select @locpositive = 0, @locnegative = 0, @prebalance = 0
   select loc = toloc, netvar = sum(qty)
,	prebalance = sum(case when trantype = 'WD' then abs(qty) else 0 end)
   into #tnCCloc from itrn (nolock)
   where adddate >= @inventorydate and adddate < DATEADD(dd, 1, @inventorydate)
   and Storerkey = 'NIKETH'
   and Sourcetype like 'CC%'
   and Toloc <> 'NIKELOSS'
   and trantype in ('DP','WD')
   group by toloc
   select @loc_cc_cnt = count(loc)
,	@locpositive = sum(case when netvar > 0 then netvar else 0 end)
,	@locnegative = sum(case when netvar < 0 then netvar else 0 end)
   ,	@prebalance = sum(prebalance)
   from #tnCCloc
   if @prebalance = 0
   begin
      select @loc_cc_nv_percent = 0, @loc_cc_gv_percent = 0
   end
else
   begin
      select @loc_cc_nv_percent = (convert(float,@locnegative+@locpositive)/convert(float,@prebalance))*100
      ,      @loc_cc_gv_percent = (convert(float,@locpositive-@locnegative)/convert(float,@prebalance))*100
   end
   drop table #tnCCloc
   /* Select count(Distinct Sku) From CC */
   /* Select Sum(ABS(Qty)) From CC where Sku in (Select Distinct Sku From CC) */
   /* Select count(Distinct Loc) From CC */
   /* Select Sum(Qty) From CC where loc in (Select Distinct Loc From CC) */
   /* Select Sum(ABS(Qty)) From CC where loc in (Select Distinct Loc From CC) */
   UPDATE #Result
   SET Day = @Day, BulkFilled = @Bulkfilled, Bulkpercent = @Bulkpercent, ShelveFilled = @ShelveFilled,
   Shelvepercent = @Shelvepercent, Replenishment_Cnt = @Replenishment_Cnt, Sku_CC_cnt = @Sku_CC_cnt,
   Sku_CC_NV_Percent = @Sku_CC_NV_Percent, Sku_CC_GV_Percent = @Sku_CC_GV_Percent, Loc_CC_cnt = @Loc_CC_cnt,
   Loc_CC_NV_Percent = @Loc_CC_NV_Percent, Loc_CC_GV_Percent = @Loc_CC_GV_Percent,
   Shelve_Loc_Consolid = @Shelve_Loc_Consolid, Bulk_Loc_Consolid = @Bulk_Loc_Consolid,
   Staff_Cnt = @Staff_Cnt, Hours_Cnt = @Hours_Cnt, Remark = @Remark,
   Prebalance = @prebalance, SkuNegative = @skunegative, SkuPositive = @skupositive,
   LocNegative = @locnegative, LocPositive = @locpositive
   WHERE InventoryDate = @InventoryDate
   SELECT @Replenishment_Cnt = 0
   --			,	@pre_shelve = @shelvefilled, @pre_bulk = @bulkfilled

   FETCH NEXT FROM CUR_1 INTO @InventoryDate

END  /* cursor loop */

CLOSE      CUR_1
DEALLOCATE CUR_1
SELECT Week, InventoryDate, Day, BulkFilled, Bulkpercent, ShelveFilled, Shelvepercent, Replenishment_Cnt,
Sku_CC_cnt, Sku_CC_NV_Percent, Sku_CC_GV_Percent, Loc_CC_cnt, Loc_CC_NV_Percent, Loc_CC_GV_Percent,
Shelve_Loc_Consolid, Bulk_Loc_Consolid, Staff_Cnt, Hours_Cnt, Remark,
Prebalance, SkuNegative, SkuPositive, LocNegative, LocPositive
FROM #RESULT
END

GO