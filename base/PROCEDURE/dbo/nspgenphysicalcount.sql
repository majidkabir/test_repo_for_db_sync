SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspGenPhysicalCount                                */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

/****** Object:  Stored Procedure dbo.nspGenPhysicalCount    Script Date: 09/09/1999 9:21:07 AM ******/
CREATE PROC    [dbo].[nspGenPhysicalCount]
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @b_debug          int         -- Debug: 0 - OFF, 1 - show all, 2 - map
   ,        @n_Status         int
   ,        @c_Lot            NVARCHAR(10)
   ,        @c_Loc            NVARCHAR(10)
   ,        @c_StorerKey      NVARCHAR(15)
   ,        @c_SKU            NVARCHAR(20)
   ,        @c_PackKey        NVARCHAR(10)
   ,        @c_UOM            NVARCHAR(10)
   ,        @c_ID             NVARCHAR(18)
   ,        @n_starttcnt      int         -- Holds the current transaction count
   ,        @c_preprocess     NVARCHAR(250)   -- preprocess
   ,        @c_pstprocess     NVARCHAR(250)   -- post process
   ,        @n_cnt            int
   ,        @n_err2           int         -- For Additional Error Detection
   ,        @n_err            int
   ,        @c_errmsg         NVARCHAR(250)
   ,        @b_success        int
   ,        @n_qty            int         --
   ,        @n_continue       int         --
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @n_err2=0
   DECLARE  @c_WareHouse      NVARCHAR(10),
   @c_Zone           NVARCHAR(10),
   @n_Aisle          int,
   @n_Level          int,
   @c_PreWareHouse   NVARCHAR(10),
   @c_PreZone        NVARCHAR(10),
   @n_PreAisle       int,
   @n_PreLevel       int,
   @c_SheetNo        NVARCHAR(10),
   @n_Loop           int,
   @c_Team           NVARCHAR(1)
   DECLARE cs_Lot CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT LOTxLOCxID.Lot,
   LOTxLOCxID.Loc,
   LOTxLOCxID.Id,
   LOTxLOCxID.StorerKey,
   LOTxLOCxID.Sku,
   SKU.PACKKey,
   CASE SKUxLOC.LocationType
   WHEN "OTHER" THEN
   CASE WHEN dbo.fnc_RTrim(PACK.PackUOM4) <> "" AND PACK.PackUOM4 IS NOT NULL
   THEN PACK.PackUOM4
ELSE
   CASE WHEN dbo.fnc_RTrim(PACK.PackUOM1) <> "" AND PACK.PackUOM1 IS NOT NULL
   THEN PACK.PackUOM1
ELSE
   PACK.PackUOM3
END
END
WHEN "CASE" THEN
CASE WHEN dbo.fnc_RTrim(PACK.PackUOM1) <> "" AND PACK.PackUOM1 IS NOT NULL
THEN PACK.PackUOM1
ELSE
   PACK.PackUOM3
END
ELSE
   PACK.PackUOM3
END "UOM",
LOC.Facility,
LOC.PutawayZone,
LOC.LocLevel,
LOC.LocAisle
FROM LOTxLOCxID (NOLOCK),
PhysicalParameters (NOLOCK),
SKU (NOLOCK),
SKUxLOC (NOLOCK),
PACK (NOLOCK),
LOC (NOLOCK)
WHERE ( SKU.StorerKey = LOTxLOCxID.StorerKey ) and
( SKU.Sku = LOTxLOCxID.Sku ) and
( SKUxLOC.LOC = LOTxLOCxID.LOC ) and
( SKUxLOC.SKU = LOTxLOCxID.SKU ) and
( SKU.PackKey = PACK.PackKey ) and
( LOTxLOCxID.LOC = LOC.LOC ) and
( ( LOTxLOCxID.StorerKey between PhysicalParameters.StorerKeyMin AND PhysicalParameters.StorerKeyMax ) AND
( LOTxLOCxID.Sku between PhysicalParameters.SkuMin AND PhysicalParameters.SkuMax ) )
ORDER BY LOC.Facility, LOC.PutawayZone, LOC.LOC
OPEN cs_Lot
IF @@ERROR <> 0
BEGIN
   SELECT @n_continue = 3
   SELECT @n_err = 88300
   SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Open Cursor Error (nspGenPhysicalCount)"
END
SELECT @n_Status = 0
SELECT @c_WareHouse      = "",
@c_Zone           = "",
@n_Aisle          = 0,
@n_Level          = 0,
@c_PreWareHouse   = "",
@c_PreZone        = "",
@n_PreAisle       = "",
@n_PreLevel       = ""
WHILE @n_Status <> -1
BEGIN
   FETCH NEXT FROM cs_LOT INTO @c_lot, @c_loc, @c_id, @c_storerkey, @c_sku,
   @c_Packkey, @c_uom, @c_WareHouse, @c_Zone, @n_Level, @n_Aisle
   SELECT @n_Status = @@FETCH_STATUS
   IF @n_Status = 0
   BEGIN
      IF @c_WareHouse <> @c_PreWareHouse OR @c_Zone <> @c_PreZone OR
      @n_Aisle <> @n_PreAisle OR @n_Level <> @n_PreLevel
      BEGIN
         SELECT @b_success = 0
         SELECT @c_SheetNo = ""
         EXECUTE   nspg_getkey
         "SHEETNO"
         , 7
         , @c_sheetno OUTPUT
         , @b_success OUTPUT
         , @n_err OUTPUT
         , @c_errmsg OUTPUT
      END
      SELECT @n_Loop = 1
      WHILE @n_Loop <= 2
      BEGIN
         IF @n_Loop = 1
         BEGIN
            SELECT @c_SheetNo = "PRE" + RIGHT( dbo.fnc_RTrim(@c_SheetNo), 7)
            SELECT @c_Team    = "B"
         END
      ELSE
         BEGIN
            SELECT @c_SheetNo = "FIN" + RIGHT( dbo.fnc_RTrim(@c_SheetNo), 7)
            SELECT @c_Team = "A"
         END
         EXEC nsp_JDH_PH03 @c_SheetNo, @c_storerkey, @c_lot, @c_sku, @c_id, @c_loc,
         0, @c_uom, @c_packkey, @c_team, "", @b_Success   OUTPUT,
         @n_err OUTPUT, @c_errmsg    OUTPUT
         SELECT @n_Loop = @n_Loop + 1
      END -- While n_Loop <= 2
      SELECT @c_PreWareHouse = @c_Warehouse,
      @c_PreZone      = @c_Zone,
      @n_PreLevel     = @n_Level,
      @n_PreAisle     = @n_Aisle
   END -- if n_status = 0
END -- While
CLOSE cs_Lot
DEALLOCATE cs_Lot
IF @n_continue = 3 -- Error occured - Process and return
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
   EXECUTE nsp_logerror @n_err, @c_errmsg, "nspGenPhysicalCount"
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
END
ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
   END
END


GO