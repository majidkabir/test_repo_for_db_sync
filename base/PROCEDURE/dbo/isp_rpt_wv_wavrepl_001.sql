SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: isp_RPT_WV_WAVREPL_001                              */
/* Creation Date: 03-Jul-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-22840 - [TW] PMA Wave Replenishment Report              */
/*                                                                      */
/* Called By: RPT_WV_WAVREPL_001                                        */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver. Purposes                                  */
/* 03-Jul-2023  WLChooi  1.0  DevOps Combine Script                     */
/************************************************************************/
CREATE   PROC [dbo].[isp_RPT_WV_WAVREPL_001]
   @c_Wavekey          NVARCHAR(10)
 , @c_FromPAZone       NVARCHAR(10) = ''
 , @c_ToLoc            NVARCHAR(10) = ''
 , @c_cOrderPercentage NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF

   DECLARE @c_UOM              NVARCHAR(10)
         , @c_Facility         NVARCHAR(5)
         , @c_Storerkey        NVARCHAR(15)
         , @c_Sku              NVARCHAR(20)
         , @c_Style            NVARCHAR(20)
         , @c_Color            NVARCHAR(10)
         , @c_FromLot          NVARCHAR(10)
         , @c_FromLoc          NVARCHAR(10)
         , @c_FromID           NVARCHAR(18)
         , @n_FromQty          INT
         , @c_GetToLoc         NVARCHAR(10)
         , @c_Priority         NVARCHAR(5)
         , @c_ReplenishmentKey NVARCHAR(10)
         , @c_Packkey          NVARCHAR(10)
         , @b_success          INT
         , @n_err              INT
         , @c_errmsg           NVARCHAR(250)
         , @n_continue         INT
         , @n_starttcnt        INT
         , @n_OrderQty         INT 
         , @n_AvailableQty     FLOAT 
         , @n_OrderPercentage  FLOAT 

   DECLARE @n_Load01_Qty       INT
         , @n_Load02_Qty       INT
         , @n_Load03_Qty       INT
         , @n_Load04_Qty       INT
         , @n_Load05_Qty       INT
         , @n_Load06_Qty       INT
         , @c_Loadkey          NVARCHAR(10)
         , @n_Qty              INT
         , @n_PDQty            INT
         , @n_Count            INT
         , @c_SQL              NVARCHAR(MAX)
         , @c_SDESCR           NVARCHAR(250)

   DECLARE @REPLENISHMENT TABLE
   (
      StorerKey    NVARCHAR(15)
    , SKU          NVARCHAR(20)
    , FromLOC      NVARCHAR(10)
    , ToLOC        NVARCHAR(10)
    , Lot          NVARCHAR(10)
    , Id           NVARCHAR(18)
    , Qty          INT
    , QtyMoved     INT
    , QtyInPickLOC INT
    , Priority     NVARCHAR(5)
    , UOM          NVARCHAR(5)
    , PackKey      NVARCHAR(10)
   )

   SELECT @n_continue = 1
        , @n_starttcnt = @@TRANCOUNT
        , @n_err = 0
        , @c_errmsg = N''
        , @b_success = 1

   DECLARE @T_TEMP TABLE
   (
      SKU          NVARCHAR(20) NULL
    , FromLOC      NVARCHAR(10) NULL
    , LLIQty       INT NULL
    , Load01_Qty   INT NULL
    , Load02_Qty   INT NULL
    , Load03_Qty   INT NULL
    , Load04_Qty   INT NULL
    , Load05_Qty   INT NULL
    , Load06_Qty   INT NULL
    , TotalQty     INT NULL
    , RemainingQty INT NULL
    , SDESCR       NVARCHAR(250) NULL
   )
   --PMA1101	A1FAST	60
   
   IF ISNUMERIC(@c_cOrderPercentage) = 1
      SELECT @n_OrderPercentage = CAST(@c_cOrderPercentage AS FLOAT)
   ELSE
      SELECT @n_OrderPercentage = 0

   SELECT TOP 1 @c_Facility = ORDERS.Facility
   FROM WAVEDETAIL (NOLOCK)
   JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey
   WHERE Wavekey = @c_Wavekey

   IF NOT EXISTS (  SELECT 1
                    FROM LOC (NOLOCK)
                    WHERE Facility = @c_Facility AND Loc = @c_ToLoc)
   BEGIN
      GOTO EXIT_SP
   END

   IF NOT EXISTS (  SELECT 1
                    FROM LOC (NOLOCK)
                    WHERE Facility = @c_Facility AND PutawayZone = @c_FromPAZone)
   BEGIN
      GOTO EXIT_SP
   END

   DECLARE CUR_ColorStyle CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT SKU.StorerKey
        , SKU.Style
        , SKU.Color
        , ORDERS.Facility
        , SUM(ORDERDETAIL.OpenQty) AS OrderQty 
   FROM WAVEDETAIL (NOLOCK)
   JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey
   JOIN ORDERDETAIL (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey
   JOIN SKU (NOLOCK) ON ORDERDETAIL.StorerKey = SKU.StorerKey AND ORDERDETAIL.Sku = SKU.Sku
   WHERE WAVEDETAIL.Wavekey = @c_Wavekey
   GROUP BY SKU.StorerKey
          , SKU.Style
          , SKU.Color
          , ORDERS.Facility 
   ORDER BY ORDERS.Facility
          , SKU.StorerKey
          , SKU.Style
          , SKU.Color

   OPEN CUR_ColorStyle
   FETCH NEXT FROM CUR_ColorStyle
   INTO @c_Storerkey
      , @c_Style
      , @c_Color
      , @c_Facility
      , @n_OrderQty

   WHILE @@FETCH_STATUS = 0
   BEGIN
      SELECT @n_AvailableQty = SUM(LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated)
      FROM LOTxLOCxID LLI (NOLOCK)
      JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
      JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
      JOIN ID (NOLOCK) ON LLI.Id = ID.Id
      JOIN SKUxLOC SL (NOLOCK) ON LLI.StorerKey = SL.StorerKey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
      JOIN SKU (NOLOCK) ON SL.StorerKey = SKU.StorerKey AND SL.Sku = SKU.Sku
      JOIN PACK (NOLOCK) ON SKU.PACKKey = PACK.PackKey
      WHERE LLI.StorerKey = @c_Storerkey
      AND   SKU.Style = @c_Style
      AND   SKU.Color = @c_Color
      AND   LOC.Facility = @c_Facility
      AND   LOT.Status <> 'HOLD'
      AND   LOC.LocationFlag <> 'DAMAGE'
      AND   LOC.LocationFlag <> 'HOLD'
      AND   LOC.Status <> 'HOLD'
      AND   ID.Status <> 'HOLD'
      AND   LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated > 0
      AND   (SL.LocationType = 'OTHER' OR ISNULL(SL.LocationType, '') = '')
      AND   LLI.QtyExpected = 0 -- make sure we aren't going to try to pull from a Location that needs stuff to satisfy existing demAND
      AND   LLI.Loc <> @c_ToLoc
      AND   LOC.PutawayZone = @c_FromPAZone

      IF @n_AvailableQty = 0
         SET @n_AvailableQty = 1.00

      IF ((@n_OrderQty / @n_AvailableQty) * 100.00) >= @n_OrderPercentage
      BEGIN
         DECLARE CUR_Replen_Inv CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT LLI.Sku
              , LLI.Lot
              , LLI.Loc
              , LLI.Id
              , LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated
              , PACK.PackKey
              , PACK.PackUOM3
         FROM LOTxLOCxID LLI (NOLOCK)
         JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
         JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
         JOIN ID (NOLOCK) ON LLI.Id = ID.Id
         JOIN SKUxLOC SL (NOLOCK) ON LLI.StorerKey = SL.StorerKey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
         JOIN SKU (NOLOCK) ON SL.StorerKey = SKU.StorerKey AND SL.Sku = SKU.Sku
         JOIN PACK (NOLOCK) ON SKU.PACKKey = PACK.PackKey
         WHERE LLI.StorerKey = @c_Storerkey
         AND   SKU.Style = @c_Style
         AND   SKU.Color = @c_Color
         AND   LOC.Facility = @c_Facility
         AND   LOT.Status <> 'HOLD'
         AND   LOC.LocationFlag <> 'DAMAGE'
         AND   LOC.LocationFlag <> 'HOLD'
         AND   LOC.Status <> 'HOLD'
         AND   ID.Status <> 'HOLD'
         AND   LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated > 0
         AND   (SL.LocationType = 'OTHER' OR ISNULL(SL.LocationType, '') = '')
         AND   LLI.QtyExpected = 0 -- make sure we aren't going to try to pull from a Location that needs stuff to satisfy existing demAND
         AND   LLI.Loc <> @c_ToLoc
         AND   LOC.PutawayZone = @c_FromPAZone
         ORDER BY LOC.LogicalLocation
                , LOC.Loc
                , LLI.Id
                , LLI.Sku
                , LLI.Lot

         OPEN CUR_Replen_Inv
         FETCH NEXT FROM CUR_Replen_Inv
         INTO @c_Sku
            , @c_FromLot
            , @c_FromLoc
            , @c_FromID
            , @n_FromQty
            , @c_Packkey
            , @c_UOM

         WHILE @@FETCH_STATUS = 0
         BEGIN
            INSERT @REPLENISHMENT (StorerKey, SKU, FromLOC, ToLOC, Lot, Id, Qty, UOM, PackKey, Priority, QtyMoved
                                 , QtyInPickLOC)
            VALUES (@c_Storerkey, @c_Sku, @c_FromLoc, @c_ToLoc, @c_FromLot, @c_FromID, @n_FromQty, @c_UOM, @c_Packkey
                  , '99999', 0, 0)
            FETCH NEXT FROM CUR_Replen_Inv
            INTO @c_Sku
               , @c_FromLot
               , @c_FromLoc
               , @c_FromID
               , @n_FromQty
               , @c_Packkey
               , @c_UOM
         END
         CLOSE CUR_Replen_Inv
         DEALLOCATE CUR_Replen_Inv
      END
      ELSE
      BEGIN
         DECLARE CUR_SKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT SKU.Sku
              , SUM(ORDERDETAIL.OpenQty) AS OrderQty
         FROM WAVEDETAIL (NOLOCK)
         JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey
         JOIN ORDERDETAIL (NOLOCK) ON ORDERS.OrderKey = ORDERDETAIL.OrderKey
         JOIN SKU (NOLOCK) ON ORDERDETAIL.StorerKey = SKU.StorerKey AND ORDERDETAIL.Sku = SKU.Sku
         WHERE WAVEDETAIL.Wavekey = @c_Wavekey
         AND   ORDERS.Facility = @c_Facility
         AND   ORDERS.StorerKey = @c_Storerkey
         AND   SKU.Style = @c_Style
         AND   SKU.Color = @c_Color
         GROUP BY SKU.Sku
         ORDER BY SKU.Sku

         OPEN CUR_SKU

         FETCH NEXT FROM CUR_SKU
         INTO @c_Sku
            , @n_OrderQty

         WHILE @@FETCH_STATUS <> -1
         BEGIN
            DECLARE CUR_Replen_Inv2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LLI.Lot
                 , LLI.Loc
                 , LLI.Id
                 , LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated
                 , PACK.PackKey
                 , PACK.PackUOM3
            FROM LOTxLOCxID LLI (NOLOCK)
            JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
            JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
            JOIN ID (NOLOCK) ON LLI.Id = ID.Id
            JOIN SKUxLOC SL (NOLOCK) ON LLI.StorerKey = SL.StorerKey AND LLI.Sku = SL.Sku AND LLI.Loc = SL.Loc
            JOIN SKU (NOLOCK) ON SL.StorerKey = SKU.StorerKey AND SL.Sku = SKU.Sku
            JOIN PACK (NOLOCK) ON SKU.PACKKey = PACK.PackKey
            WHERE LLI.StorerKey = @c_Storerkey
            AND   SKU.Sku = @c_Sku
            AND   LOC.Facility = @c_Facility
            AND   LOT.Status <> 'HOLD'
            AND   LOC.LocationFlag <> 'DAMAGE'
            AND   LOC.LocationFlag <> 'HOLD'
            AND   LOC.Status <> 'HOLD'
            AND   ID.Status <> 'HOLD'
            AND   LLI.Qty - LLI.QtyPicked - LLI.QtyAllocated > 0
            AND   (SL.LocationType = 'OTHER' OR ISNULL(SL.LocationType, '') = '')
            AND   LLI.QtyExpected = 0 -- make sure we aren't going to try to pull from a Location that needs stuff to satisfy existing demAND
            AND   LLI.Loc <> @c_ToLoc
            AND   LOC.PutawayZone = @c_FromPAZone
            ORDER BY LOC.LogicalLocation
                   , LOC.Loc
                   , LLI.Id
                   , LLI.Sku
                   , LLI.Lot

            OPEN CUR_Replen_Inv2
            FETCH NEXT FROM CUR_Replen_Inv2
            INTO @c_FromLot
               , @c_FromLoc
               , @c_FromID
               , @n_FromQty
               , @c_Packkey
               , @c_UOM

            WHILE @@FETCH_STATUS <> -1 AND @n_OrderQty > 0
            BEGIN

               IF @n_FromQty <= @n_OrderQty
               BEGIN
                  SELECT @n_OrderQty = @n_OrderQty - @n_FromQty
               END
               ELSE
               BEGIN
                  SELECT @n_FromQty = @n_OrderQty
                  SELECT @n_OrderQty = 0
               END

               INSERT @REPLENISHMENT (StorerKey, SKU, FromLOC, ToLOC, Lot, Id, Qty, UOM, PackKey, Priority, QtyMoved
                                    , QtyInPickLOC)
               VALUES (@c_Storerkey, @c_Sku, @c_FromLoc, @c_ToLoc, @c_FromLot, @c_FromID, @n_FromQty, @c_UOM, @c_Packkey
                     , '99999', 0, 0)
               FETCH NEXT FROM CUR_Replen_Inv2
               INTO @c_FromLot
                  , @c_FromLoc
                  , @c_FromID
                  , @n_FromQty
                  , @c_Packkey
                  , @c_UOM
            END --Loop inventory of current sku 
            CLOSE CUR_Replen_Inv2
            DEALLOCATE CUR_Replen_Inv2

            FETCH NEXT FROM CUR_SKU
            INTO @c_Sku
               , @n_OrderQty
         END --Loop sku of current sytle and color    	      	 
         CLOSE CUR_SKU
         DEALLOCATE CUR_SKU
      END

      FETCH NEXT FROM CUR_ColorStyle
      INTO @c_Storerkey
         , @c_Style
         , @c_Color
         , @c_Facility
         , @n_OrderQty
   END
   CLOSE CUR_ColorStyle
   DEALLOCATE CUR_ColorStyle

   UPDATE @REPLENISHMENT
   SET QtyInPickLOC = SKUxLOC.Qty - SKUxLOC.QtyPicked
   FROM @REPLENISHMENT RP
   JOIN SKUxLOC (NOLOCK) ON (RP.StorerKey = SKUxLOC.StorerKey AND RP.SKU = SKUxLOC.Sku AND RP.ToLOC = SKUxLOC.Loc)

   IF (  SELECT COUNT(*)
         FROM @REPLENISHMENT) > 0
   BEGIN
      DELETE REPLENISHMENT
      WHERE Wavekey = @c_Wavekey
   END

   DECLARE CUR_Replen CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT R.FromLOC
        , R.Id
        , R.ToLOC
        , R.SKU
        , R.Qty
        , R.StorerKey
        , R.Lot
        , R.PackKey
        , R.Priority
        , R.UOM
   FROM @REPLENISHMENT R
   OPEN CUR_Replen

   FETCH NEXT FROM CUR_Replen
   INTO @c_FromLoc
      , @c_FromID
      , @c_GetToLoc
      , @c_Sku
      , @n_FromQty
      , @c_Storerkey
      , @c_FromLot
      , @c_Packkey
      , @c_Priority
      , @c_UOM
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXECUTE nspg_GetKey 'REPLENISHKEY'
                        , 10
                        , @c_ReplenishmentKey OUTPUT
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT

      IF NOT @b_success = 1
      BEGIN
         BREAK
      END

      IF @b_success = 1
      BEGIN
         INSERT REPLENISHMENT (ReplenishmentGroup, ReplenishmentKey, Storerkey, Sku, FromLoc, ToLoc, Lot, Id, Qty, UOM
                             , PackKey, Confirmed, Wavekey)
         VALUES (@c_Wavekey, @c_ReplenishmentKey, @c_Storerkey, @c_Sku, @c_FromLoc, @c_GetToLoc, @c_FromLot, @c_FromID
               , @n_FromQty, @c_UOM, @c_Packkey, 'N', @c_Wavekey)

         SELECT @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250), @n_err)
                 , @n_err = 63524 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg = N'NSQL' + CONVERT(CHAR(5), @n_err)
                               + N': Insert into replenishment table failed. (isp_RPT_WV_WAVREPL_001)' + N' ( '
                               + N' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + N' ) '
         END
      END -- IF @b_success = 1
      FETCH NEXT FROM CUR_Replen
      INTO @c_FromLoc
         , @c_FromID
         , @c_GetToLoc
         , @c_Sku
         , @n_FromQty
         , @c_Storerkey
         , @c_FromLot
         , @c_Packkey
         , @c_Priority
         , @c_UOM
   END -- While

   CLOSE CUR_Replen
   DEALLOCATE CUR_Replen

   RESULT:
   DECLARE CUR_REPL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT R.Storerkey, R.SKU, R.FROMLoc, S.DESCR
   FROM dbo.REPLENISHMENT R (NOLOCK) 
   JOIN SKU S (NOLOCK) ON S.StorerKey = R.StorerKey AND S.SKU = R.SKU
   WHERE R.Wavekey = @c_Wavekey
   ORDER BY R.SKU, R.FromLoc

   OPEN CUR_REPL

   FETCH NEXT FROM CUR_REPL INTO @c_Storerkey, @c_SKU, @c_FromLoc, @c_SDESCR

   WHILE @@FETCH_STATUS <> -1
   BEGIN

      SET @n_Load01_Qty = 0
      SET @n_Load02_Qty = 0
      SET @n_Load03_Qty = 0
      SET @n_Load04_Qty = 0
      SET @n_Load05_Qty = 0
      SET @n_Load06_Qty = 0
      SET @n_Count = 1

      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT TOP 6 OH.Loadkey
      FROM WAVEDETAIL WD (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = WD.OrderKey
      WHERE WD.Wavekey = @c_Wavekey
      ORDER BY OH.LoadKey

      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_Loadkey

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @n_PDQty = 0
         SET @n_Qty = 0

         SELECT @n_Qty = SUM(LTLCI.Qty)
         FROM dbo.LOTxLOCxID LTLCI
         WHERE LTLCI.Storerkey = @c_Storerkey
         AND LTLCI.SKU = @c_Sku
         AND LTLCI.Loc = @c_FromLoc
         
         SELECT @n_PDQty = SUM(OD.OriginalQty) 
         FROM LOADPLANDETAIL LPD (NOLOCK)
         JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
         JOIN ORDERDETAIL OD (NOLOCK) ON OH.OrderKey = OD.OrderKey
         WHERE LPD.LoadKey = @c_Loadkey
         AND OD.Storerkey = @c_Storerkey
         AND OD.SKU = @c_SKU

         SET @c_SQL = N' SET @n_Load0' + CAST(@n_Count AS NVARCHAR) + '_Qty = ISNULL(@n_PDQty,0) '

         EXEC sp_executesql @c_SQL
                          , N' @n_Load01_Qty INT OUTPUT, @n_Load02_Qty INT OUTPUT, @n_Load03_Qty INT OUTPUT, @n_Load04_Qty INT OUTPUT, @n_Load05_Qty INT OUTPUT, @n_Load06_Qty INT OUTPUT, @n_PDQty INT '
                          , @n_Load01_Qty OUTPUT
                          , @n_Load02_Qty OUTPUT
                          , @n_Load03_Qty OUTPUT
                          , @n_Load04_Qty OUTPUT
                          , @n_Load05_Qty OUTPUT
                          , @n_Load06_Qty OUTPUT
                          , @n_PDQty

         SET @n_Count = @n_Count + 1

         FETCH NEXT FROM CUR_LOOP INTO @c_Loadkey
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP

      IF (@n_Load01_Qty + @n_Load02_Qty + @n_Load03_Qty + @n_Load04_Qty + @n_Load05_Qty + @n_Load06_Qty) > 0
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM @T_TEMP TT WHERE TT.SKU = @c_Sku)
         BEGIN
            INSERT INTO @T_TEMP (SKU, FromLOC, LLIQty, Load01_Qty, Load02_Qty, Load03_Qty, Load04_Qty, Load05_Qty, Load06_Qty
                                  , TotalQty, RemainingQty, SDESCR)
            VALUES (@c_SKU -- SKU - nvarchar(20)
                  , @c_FromLoc -- FromLOC - nvarchar(10)
                  , @n_Qty -- LLIQty - int
                  , @n_Load01_Qty -- Load01_Qty - int
                  , @n_Load02_Qty -- Load02_Qty - int
                  , @n_Load03_Qty -- Load03_Qty - int
                  , @n_Load04_Qty -- Load04_Qty - int
                  , @n_Load05_Qty -- Load05_Qty - int
                  , @n_Load06_Qty -- Load06_Qty - int
                  , (@n_Load01_Qty + @n_Load02_Qty + @n_Load03_Qty + @n_Load04_Qty + @n_Load05_Qty + @n_Load06_Qty) -- TotalQty - int
                  , @n_Qty - (@n_Load01_Qty + @n_Load02_Qty + @n_Load03_Qty + @n_Load04_Qty + @n_Load05_Qty + @n_Load06_Qty) -- RemainingQty - int
                  , @c_SDESCR -- SDESCR - nvarchar(250)
               )
         END
         ELSE
         BEGIN
            INSERT INTO @T_TEMP (SKU, FromLOC, LLIQty, Load01_Qty, Load02_Qty, Load03_Qty, Load04_Qty, Load05_Qty, Load06_Qty
                                  , TotalQty, RemainingQty, SDESCR)
            VALUES (@c_SKU -- SKU - nvarchar(20)
                  , @c_FromLoc -- FromLOC - nvarchar(10)
                  , @n_Qty -- LLIQty - int
                  , NULL -- Load01_Qty - int
                  , NULL -- Load02_Qty - int
                  , NULL -- Load03_Qty - int
                  , NULL -- Load04_Qty - int
                  , NULL -- Load05_Qty - int
                  , NULL -- Load06_Qty - int
                  , NULL -- TotalQty - int
                  , NULL -- RemainingQty - int
                  , @c_SDESCR -- SDESCR - nvarchar(250)
               )
         END
      END

      NEXT:

      FETCH NEXT FROM CUR_REPL INTO @c_Storerkey, @c_SKU, @c_FromLoc, @c_SDESCR
   END
   CLOSE CUR_REPL
   DEALLOCATE CUR_REPL

   ;WITH CTE AS (
   SELECT TT.SKU, SUM(TT.LLIQty) AS Qty
   FROM @T_TEMP TT
   GROUP BY TT.SKU
   )
   UPDATE @T_TEMP
   SET RemainingQty = CTE.Qty - [@T_TEMP].TotalQty
   FROM CTE
   WHERE [@T_TEMP].SKU = CTE.SKU

   EXIT_SP:

   SELECT T.SKU
        , T.FromLOC
        , T.LLIQty
        , T.Load01_Qty
        , T.Load02_Qty
        , T.Load03_Qty
        , T.Load04_Qty
        , T.Load05_Qty
        , T.Load06_Qty
        , T.TotalQty
        , T.RemainingQty
        , T.SDESCR
        , @c_Wavekey AS Wavekey
   FROM @T_TEMP T
   ORDER BY T.SKU
          , T.FromLOC

   IF CURSOR_STATUS('LOCAL', 'CUR_Replen') IN (0 , 1)
   BEGIN
      CLOSE CUR_Replen
      DEALLOCATE CUR_Replen   
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_REPL') IN (0 , 1)
   BEGIN
      CLOSE CUR_REPL
      DEALLOCATE CUR_REPL   
   END

   IF @n_continue = 3 -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RPT_WV_WAVREPL_001'
      RAISERROR(@c_errmsg, 16, 1) WITH SETERROR -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
   -- RETURN
   END
END

GO