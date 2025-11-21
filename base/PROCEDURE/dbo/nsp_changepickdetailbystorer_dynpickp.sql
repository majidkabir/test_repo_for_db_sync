SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* S Proc: nsp_ChangePickDetailByStorer_DynPickP                        */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: To solve the integrity for qty expected between the         */
/*          LOTxLOCxID and SKUxLOC                                      */
/* Input Parameters: Storer Key                                         */
/*                                                                      */
/* OUTPUT Parameters: None                                              */
/*                                                                      */
/* Return Status: None                                                  */
/*                                                                      */
/* Usage: For Backend Schedule job                                      */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: SQL Schedule Job                                          */
/*                                                                      */
/* PVCS Version: 1.11                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 15-Feb-2005  Shong         Patch the qty expected for lotxlocxid     */
/*                                                                      */
/* 01-Apr-2005  Shong         Bug Fixed and Performance Tuning          */
/*                                                                      */
/* 21-07-2005   Shong         Include those records was previously over */
/*                            Allocated and Now LocationType change to  */
/*                            OTHER                                     */
/* 04-04-2007   Shong         SOS72093 Not Allow to swap HELD Lot and ID*/
/* 24-08-2008   Shong         Include DropID when duplicate PickDetail  */
/* 13-01-2010   Shong         SOS158944 - Include StorerConfigKey       */
/*                                        'ForceAllocLottable'          */
/* 23-06-2010   Shong         Insert into RefKeyLookup for newly added  */
/*                            Pickdetail Record.                        */
/* 11-10-2010   Shong         Include others Column when insert PD      */
/* 16-10-2010   TLTING        Get Larger qty for swap lot tlting01      */
/* 29-10-2010   TLTING        Check QtyPreAllocated to get lot          */
/* 17-12-2012   Leong         SOS# 264916 - Exclude ShipFlag = 'Y'      */
/* 24-05-2012   Shong01       System skip lot when selected lot qty     */
/*                            already taken by other pickdetail record  */
/* 01-Nov-2021  Shong         Insert Channel_ID into Pickdetail Table   */  
/*                            (SWT01)                                   */  
/************************************************************************/
CREATE PROC [dbo].[nsp_ChangePickDetailByStorer_DynPickP]
   @c_StorerKey NVARCHAR(15)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @c_PickDetailKey      NVARCHAR(18),
      @b_Err                INT,
      @n_Rows               INT,
      @n_RowCount           INT,
      @c_LOT                NVARCHAR(10),
      @c_Ctrl               NVARCHAR(1),
      @c_LOC                NVARCHAR(10),
      @c_ID                 NVARCHAR(18),
      @c_SKU                NVARCHAR(20),
      @n_Qty                INT,
      @c_NewLOT             NVARCHAR(10),
      @c_NewID              NVARCHAR(18),
      @n_LotQty             INT,
      @c_NewPickDetailKey   NVARCHAR(18),
      @b_Success            INT,
      @c_ErrMsg             NVARCHAR(250),
      @c_Status             NVARCHAR(5),
      @c_ShipFlag           NVARCHAR(1),
      @n_LOTQty2            INT,
      @c_Lottable01         NVARCHAR(18), --SOS158944
      @c_Lottable02         NVARCHAR(18),
      @c_Lottable03         NVARCHAR(18),
      @d_Lottable04         Datetime,
      @c_ForceAllocLottable NVARCHAR(1),
      @c_SQLSelect          NVARCHAR(4000), 
      @n_ExchangeQty        INT, -- Shong01
      @c_ExchgPickDetailKey NVARCHAR(10), 
      @n_ExchgPickDetQty    INT, 
      @c_ExchgPDStatus      NVARCHAR(10), 
      @c_ExchgID            NVARCHAR(18),
      @c_ExchgLOC           NVARCHAR(10) 

   SELECT @n_Rows = 0
   SELECT @c_Ctrl = '0'

   DECLARE @n_Continue int

   SELECT @n_Continue = 1

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      DECLARE @c_Authority NVARCHAR(1)

      SELECT @b_Success = 0
      EXECUTE nspGetRight '',
         @c_StorerKey,   -- Storer
         '',             -- Sku
         'OWITF',        -- ConfigKey
         @b_Success   OUTPUT,
         @c_Authority OUTPUT,
         @b_Err       OUTPUT,
         @c_ErrMsg    OUTPUT

      IF @c_Authority = '1'
         SELECT @n_Continue = 3
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      IF NOT EXISTS(SELECT 1 FROM LOTxLOCxID WITH (NOLOCK)
                    JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.SKU = LOTxLOCxID.SKU AND
                                              SKUxLOC.StorerKey = LOTxLOCxID.StorerKey)
                    JOIN LOC WITH (NOLOCK) ON LOC.Loc = SKUxLOC.Loc
                    WHERE LOTxLOCxID.QtyExpected > 0
                    AND LOTxLOCxID.StorerKey = @c_StorerKey
                    AND ( SKUxLOC.LocationType IN ('PICK', 'CASE') OR
                          (LOTxLOCxID.QtyExpected > 0 AND SKUxLOC.QtyExpected = 0 ) OR
                          (LOC.LocationType IN ('DYNPICKP', 'DYNPICKR') )))
      BEGIN
         SELECT @n_Continue = 4
      END
   END

   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      DECLARE LOT_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT LOTxLOCxID.Lot, LOTxLOCxID.Loc, LOTxLOCxID.id, LOTxLOCxID.Sku
      FROM LOTxLOCxID WITH (NOLOCK)
      JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.SKU = LOTxLOCxID.SKU AND
                                SKUxLOC.StorerKey = LOTxLOCxID.StorerKey)
      JOIN LOC WITH (NOLOCK) ON LOC.Loc = SKUxLOC.Loc
      WHERE LOTxLOCxID.QtyExpected > 0
      AND LOTxLOCxID.StorerKey = @c_StorerKey
      AND ( SKUxLOC.LocationType IN ('PICK', 'CASE') OR
            (LOTxLOCxID.QtyExpected > 0 AND SKUxLOC.QtyExpected = 0 ) OR
            (LOC.LocationType IN ('DYNPICKP', 'DYNPICKR') ))

      OPEN LOT_CUR
      FETCH NEXT FROM LOT_CUR INTO @c_LOT, @c_LOC, @c_ID, @c_SKU

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN

         DECLARE PICK_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PD.PickDetailKey, PD.Qty, PD.Shipflag --Added by Vicky 04 Dec 2002
               ,OD.Lottable01, OD.Lottable02, OD.Lottable03, OD.Lottable04, 
                PD.[Status] 
         FROM PICKDETAIL PD WITH (NOLOCK)
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON PD.OrderKey = OD.OrderKey --SOS158944
              AND PD.OrderLineNumber = OD.OrderLineNumber
         WHERE PD.SKU       = @c_SKU
           AND PD.StorerKey = @c_StorerKey
           AND PD.LOC       = @c_LOC
           AND PD.LOT       = @c_LOT
           AND PD.ID        = @c_ID
           AND PD.Status BETWEEN '5' AND '8'
           AND PD.ShipFlag <> 'Y' -- SOS# 264916

         OPEN PICK_CUR
         FETCH NEXT FROM PICK_CUR IntO @c_PickDetailKey, @n_Qty, @c_shipflag, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @c_Status

         WHILE (@@FETCH_STATUS <> -1)
         BEGIN

            SELECT @c_NewLOT = ''

            -- Find is any Qty Availale for Same LOT# or not
            SELECT TOP 1
                   @c_NewLOT = LOTxLOCxID.Lot,
                   @n_LotQty = (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked),
                   @c_NewID = LOTxLOCxID.ID
            FROM  LOTxLOCxID WITH (NOLOCK)
            JOIN  ID WITH (NOLOCK) ON LOTxLOCxID.ID = ID.ID
            JOIN  LOT WITH (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT
            WHERE LOTxLOCxID.Sku = @c_SKU
            AND   LOTxLOCxID.StorerKey = @c_StorerKey
            AND   LOTxLOCxID.Loc = @c_LOC
            AND   LOTxLOCxID.LOT = @c_LOT
            AND   LOTxLOCxID.ID <> @c_ID
            AND   (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) > 0
            AND   ID.Status <> 'HOLD'
            AND   LOT.Status <> 'HOLD'
            ORDER BY LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked DESC

            SELECT @n_RowCount = @@ROWCOUNT

            -- If Cannot find same LOT#, find Different LOT#
            IF @n_RowCount = 0
            BEGIN

               SET @c_ForceAllocLottable = '0' -- SOS158944
               SELECT @c_ForceAllocLottable = sValue FROM StorerConfig WITH (NOLOCK)
               WHERE  StorerKey = @c_StorerKey
               AND    ConfigKey = 'ForceAllocLottable'

               -- SOS72093 Not Allow to swap HELD Lot and ID
               GET_NEXT_LOT:
               
               SET @n_LotQty = 0
               SET @c_NewLOT = ''
               SET @n_RowCount = 0

               IF ISNULL(RTRIM(@c_ForceAllocLottable),'0') = '1'
               BEGIN

                  -- SOS72093 Not Allow to swap HELD Lot and ID
                  SELECT @c_SQLSelect =
                  N'SELECT TOP 1 
                           @c_NewLOT = LOTxLOCxID.Lot,
                           @n_LotQty = (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked),
                           @c_NewID  = LOTxLOCxID.ID
                    FROM  LOTxLOCxID WITH (NOLOCK)
                    JOIN  ID WITH (NOLOCK) ON LOTxLOCxID.ID = ID.ID
                    JOIN  LOT WITH (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT
                    JOIN  LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.LOT = LOT.LOT
                    WHERE LOTxLOCxID.Sku       = @c_SKU
                    AND   LOTxLOCxID.StorerKey = @c_StorerKey
                    AND   LOTxLOCxID.Loc       = @c_LOC
                    AND   (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) > 0
                    AND   ID.Status <> ''HOLD''
                    AND   LOT.Status <> ''HOLD''
                    AND   LOT.LOT > @c_NewLOT ' +
                    CASE WHEN ISNULL(RTRIM(@c_Lottable01),'') <> '' THEN 'AND LOTATTRIBUTE.Lottable01 = @c_Lottable01 ' END +
                    CASE WHEN ISNULL(RTRIM(@c_Lottable02),'') <> '' THEN 'AND LOTATTRIBUTE.Lottable02 = @c_Lottable02 ' END +
                    CASE WHEN ISNULL(RTRIM(@c_Lottable03),'') <> '' THEN 'AND LOTATTRIBUTE.Lottable03 = @c_Lottable03 ' END + 
                    ' ORDER BY LOT.LOT '
                    -- + CASE WHEN @d_Lottable04 IS NOT NULL THEN ' AND LOTATTRIBUTE.Lottable04 = @d_Lottable04 ' END
               END
               ELSE
               BEGIN

                  SELECT @c_SQLSelect =
                  N'SELECT TOP 1 
                           @c_NewLOT = LOTxLOCxID.Lot,
                           @n_LotQty = (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked),
                           @c_NewID  = LOTxLOCxID.ID
                    FROM  LOTxLOCxID WITH (NOLOCK)
                    JOIN  ID WITH (NOLOCK) ON LOTxLOCxID.ID = ID.ID
                    JOIN  LOT WITH (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT
                    JOIN  LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.LOT = LOT.LOT
                    WHERE LOTxLOCxID.Sku       = @c_SKU
                    AND   LOTxLOCxID.StorerKey = @c_StorerKey
                    AND   LOTxLOCxID.Loc       = @c_LOC
                    AND   (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) > 0
                    AND   ID.Status <> ''HOLD''
                    AND   LOT.Status <> ''HOLD''
                    AND   LOT.LOT > @c_NewLOT 
                    ORDER BY LOT.LOT '
               END

               EXEC sp_executesql @c_SQLSelect, N'@c_StorerKey  NVARCHAR(15)
                                                , @c_LOC        NVARCHAR(10)
                                                , @c_SKU        NVARCHAR(20)
                                                , @c_NewLOT     NVARCHAR(10) OUTPUT
                                                , @n_LotQty     Int      OUTPUT
                                                , @c_NewID      NVARCHAR(18) OUTPUT
                                                , @c_Lottable01 NVARCHAR(18)
                                                , @c_Lottable02 NVARCHAR(18)
                                                , @c_Lottable03 NVARCHAR(18)
                                                , @d_Lottable04 Datetime '
                                                , @c_StorerKey
                                                , @c_LOC
                                                , @c_SKU
                                                , @c_NewLOT OUTPUT
                                                , @n_LotQty OUTPUT
                                                , @c_NewID  OUTPUT
                                                , @c_Lottable01
                                                , @c_Lottable02
                                                , @c_Lottable03
                                                , @d_Lottable04
               SELECT @n_RowCount = @@ROWCOUNT

               IF @n_RowCount = 0
               BEGIN
                  CLOSE PICK_CUR
                  DEALLOCATE PICK_CUR
                  GOTO READ_NEXT_RECORD
               END

               SET @n_LOTQty2 = 0
               SELECT @n_LOTQty2 = LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated  -- tlting01
               FROM LOT WITH (NOLOCK)        -- tlting01
               WHERE LOT = @c_NewLOT
               AND LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated > 0

               -- When the Lot selected already allocated by other Pickdetail in other location
               -- We need exchange the current pickdetail lot with the other pickdetail lot
               IF @n_LOTQty2 < @n_LotQty 
               BEGIN
                  IF @n_LOTQty2 = 0 
                  BEGIN
                     -- Shong01
                     -- Go to find another Location PickDetail with suggested LOT To Swap
                     SET @n_ExchangeQty = 0
                     
                     DECLARE CUR_ExchangePickDetailLot CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT p.PickDetailKey, p.Qty, p.STATUS, p.ID, p.LOC  
                     FROM PICKDETAIL p WITH (NOLOCK) 
                     JOIN LOTxLOCxID lli WITH (NOLOCK) ON lli.Loc = p.Loc AND lli.Id = p.ID AND lli.Lot = p.Lot 
                     JOIN SKUxLOC sl WITH (NOLOCK) ON sl.StorerKey = lli.StorerKey AND sl.Sku = lli.Sku AND sl.Loc = lli.Loc 
                     JOIN LOC l WITH (NOLOCK) ON l.Loc = lli.Loc  
                     WHERE p.Lot = @c_NewLOT 
                     AND   p.Loc <> @c_LOC 
                     AND  (lli.QtyAllocated + lli.QtyPicked) > lli.Qty    
                     AND  ((sl.LocationType  IN ('PICK', 'CASE')) OR
                           (l.LocationType   IN ('DYNPICKP', 'DYNPICKR'))) 
                     AND  p.[Status] BETWEEN '0' AND '8' 
                     AND  p.ShipFlag <> 'Y'                                     
                     ORDER BY p.[Status] 
                     
                     OPEN CUR_ExchangePickDetailLot 
                     FETCH NEXT FROM CUR_ExchangePickDetailLot INTO @c_ExchgPickDetailKey, @n_ExchgPickDetQty, @c_ExchgPDStatus, @c_ExchgID, @c_ExchgLOC 
                      
                     WHILE @@FETCH_STATUS <> -1 AND @n_Qty > 0 
                     BEGIN
                        IF @n_ExchgPickDetQty <= @n_Qty 
                        BEGIN

                           SET @n_ExchangeQty = @n_ExchangeQty + @n_ExchgPickDetQty

                           IF @c_Status <> @c_ExchgPDStatus
                           BEGIN
                              UPDATE PICKDETAIL WITH (ROWLOCK)
                              SET STATUS=@c_Status 
                              WHERE PickDetailKey = @c_ExchgPickDetailKey
                           END

                           IF @n_Qty  = @n_ExchgPickDetQty
                           BEGIN

                              -- UnAllocate the Source Pick Detail
                              UPDATE PICKDETAIL WITH (ROWLOCK)
                                 SET Qty = 0, QtyMoved = Qty 
                                 WHERE PickDetailKey = @c_ExchgPickDetailKey
                                                       
                              -- Create LOTxLOCxID if this LOT, LOC, ID not exists
                              IF NOT EXISTS(SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE LOT = @c_NewLOT AND LOC = @c_LOC AND ID = @c_ID)
                              BEGIN
                                 INSERT INTO LOTxLOCxID (Lot, Loc, Id, StorerKey,Sku,
                                             Qty) VALUES (@c_NewLOT, @c_LOC, @c_ID, @c_StorerKey, @c_SKU, 0)
                              END
                              -- Allocate New LOT to Current Pick Detail                               
                              UPDATE PICKDETAIL WITH (ROWLOCK)
                                 SET LOT=@c_NewLOT 
                                 WHERE PickDetailKey = @c_PickDetailKey
                                   
                              IF NOT EXISTS(SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE LOT = @c_LOT AND LOC = @c_ExchgLOC AND ID = @c_ExchgID)
                              BEGIN
                                 INSERT INTO LOTxLOCxID (Lot, Loc, Id, StorerKey,Sku,
                                             Qty) VALUES (@c_LOT, @c_ExchgLOC, @c_ExchgID, @c_StorerKey, @c_SKU, 0)
                                 
                              END
                              -- Allocate the Exchg Pick Detail
                              UPDATE PICKDETAIL WITH (ROWLOCK)
                                 SET LOT=@c_LOT, ID=@c_ExchgID, STATUS = @c_ExchgPDStatus, Qty=PICKDETAIL.QtyMoved, QtyMoved=0 
                                 WHERE PickDetailKey = @c_ExchgPickDetailKey

                              SET @n_Qty = 0
                           END -- IF @n_Qty = @n_ExchgPickDetQty
                           ELSE
                           BEGIN -- @n_Qty > @n_ExchgPickDetQty 
                              -- Split current pickdetail
                              --select 'here12'
                              SELECT @b_Success = 0

                              EXECUTE nspg_getkey
                                    'PickDetailKey'
                                    , 10
                                    , @c_NewPickDetailKey OUTPUT
                                    , @b_Success OUTPUT
                                    , @b_Err OUTPUT
                                    , @c_ErrMsg OUTPUT

                              IF @b_Success = 1
                              BEGIN
                                 BEGIN TRAN

                                 -- Reduce Qty for for current pickdetail, old lot 
                                 UPDATE PICKDETAIL WITH (ROWLOCK)
                                    SET Qty = Qty - @n_ExchgPickDetQty
                                 WHERE PickDetailKey = @c_PickDetailKey

                                 SET @n_Qty = @n_Qty -  @n_ExchgPickDetQty
                                 
                                 -- Give Reduce Qty To Exchange PickDetail
                                 IF NOT EXISTS(SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE LOT = @c_LOT AND LOC = @c_ExchgLOC AND ID = @c_ExchgID)
                                 BEGIN
                                    INSERT INTO LOTxLOCxID (Lot, Loc, Id, StorerKey,Sku,
                                                Qty) VALUES (@c_LOT, @c_ExchgLOC, @c_ExchgID, @c_StorerKey, @c_SKU, 0)
                                    
                                 END                               
                                   
                                 UPDATE PICKDETAIL WITH (ROWLOCK)
                                    SET LOT = @c_LOT, STATUS = @c_ExchgPDStatus
                                    WHERE PickDetailKey = @c_ExchgPickDetailKey
                                 
                                 IF @@ERROR = 0
                                 BEGIN
                                    -- Make sure the inserted PD has entry in LLI (jamesxxx)
                                    IF NOT EXISTS(SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE LOT = @c_NewLOT AND LOC = @c_LOC AND ID = @c_NewID)
                                    BEGIN
                                       INSERT INTO LOTxLOCxID (Lot, Loc, Id, StorerKey,Sku, Qty) VALUES 
                                       (@c_NewLOT, @c_LOC, @c_NewID, @c_StorerKey, @c_SKU, 0)
                                    END                               

                                    -- Allocate again with new lot
                                    INSERT PICKDETAIL
                                       (PickDetailKey, PickHeaderKey, OrderKey,      OrderLineNumber,
                                        Lot,           StorerKey,     Sku,           Qty,
                                        Loc,           Id,            UOMQty,        UOM,
                                        CaseID,        PackKey,       CartonGroup,   DoReplenish,
                                        Replenishzone, docartonize,   Trafficcop,    PickMethod,
                                        Status,        PickSlipNo,    AddWho,        EditWho,
                                        ShipFlag,      DropID,        TaskDetailKey, AltSKU,
                                        ToLoc,         Channel_ID -- SWT01                                        
                                       )
                                    SELECT @c_NewPickDetailKey,    PickHeaderKey,    OrderKey,     OrderLineNumber,
                                           @c_NewLOT,              StorerKey,        Sku,          @n_ExchgPickDetQty,
                                           Loc,                    @c_NewID,         UOMQty,       UOM,
                                           CaseID,                 PackKey,          CartonGroup,  DoReplenish,
                                           replenishzone,          docartonize,      Trafficcop,   PickMethod,
                                           '0',                    PickSlipNo,       'wms',        'wms',
                                           ShipFlag,               DropID,           TaskDetailKey, AltSku,
                                           ToLoc,                  Channel_ID -- SWT01 
                                    FROM   PICKDETAIL WITH (NOLOCK)
                                    WHERE  PickDetailKey = @c_PickDetailKey

                                    IF @@ERROR <> 0
                                       ROLLBACK TRAN
                                    ELSE
                                    BEGIN
                                       -- 23-06-2010 (Shong) Insert into RefKeyLookup for newly added Pickdetail Record.
                                       IF EXISTS(SELECT 1 FROM RefKeyLookup rkl WITH (NOLOCK) WHERE rkl.PickDetailkey = @c_PickDetailKey)
                                       BEGIN
                                          INSERT INTO RefKeyLookup
                                          (
                                             PickDetailkey,
                                             Pickslipno,
                                             OrderKey,
                                             OrderLineNumber,
                                             Loadkey
                                          )
                                          SELECT @c_NewPickDetailKey,
                                                 rkl.Pickslipno,
                                                 rkl.OrderKey,
                                                 rkl.OrderLineNumber,
                                                 rkl.Loadkey
                                            FROM RefKeyLookup rkl
                                          WHERE rkl.PickDetailkey = @c_PickDetailKey
                                       END

                                       IF @c_Status <> '0'
                                       BEGIN
                                          UPDATE PICKDETAIL WITH (ROWLOCK)
                                          SET STATUS = @c_Status
                                          WHERE  PickDetailKey = @c_NewPickDetailKey
                                          AND    STATUS <> @c_Status                              
                                       END

                                       COMMIT TRAN
                                    END
                                 END
                              END -- IF @b_Success = 1 (GetKey)                              
                           END
                                                            
                           
                        END -- IF @n_ExchgPickDetQty < @n_Qty
                        ELSE 
                        BEGIN -- Split PickDetail 

                           SET @n_ExchangeQty = @n_ExchangeQty + @n_Qty
                           SELECT @b_Success = 0

                           EXECUTE nspg_getkey
                                 'PickDetailKey'
                                 , 10
                                 , @c_NewPickDetailKey OUTPUT
                                 , @b_Success OUTPUT
                                 , @b_Err OUTPUT
                                 , @c_ErrMsg OUTPUT

                           IF @b_Success = 1
                           BEGIN
                              BEGIN TRAN

                              -- Reduce Qty for Exchange pickdetail, new lot 
                              UPDATE PICKDETAIL WITH (ROWLOCK) 
                                 SET Qty = Qty - @n_Qty 
                              WHERE PickDetailKey = @c_ExchgPickDetailKey 

                              -- Give Reduce Qty To Current PickDetail
                              IF NOT EXISTS(SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE LOT = @c_NewLOT AND LOC = @c_LOC AND ID = @c_ID)
                              BEGIN
                                 INSERT INTO LOTxLOCxID (Lot, Loc, Id, StorerKey,Sku,
                                             Qty) VALUES (@c_NewLOT, @c_LOC, @c_ID, @c_StorerKey, @c_SKU, 0)
                                 
                              END                               
                             
                              UPDATE PICKDETAIL WITH (ROWLOCK)
                                 SET LOT = @c_NewLOT 
                                 WHERE PickDetailKey = @c_PickDetailKey
                                 
                              IF @@ERROR = 0
                              BEGIN
                                 -- Make sure the inserted PD has entry in LLI (jamesxxx)
                                 IF NOT EXISTS(SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE LOT = @c_LOT AND LOC = @c_ExchgLOC AND ID = @c_ExchgID)
                                 BEGIN
                                    INSERT INTO LOTxLOCxID (Lot, Loc, Id, StorerKey,Sku, Qty) VALUES 
                                    (@c_LOT, @c_ExchgLOC, @c_ExchgID, @c_StorerKey, @c_SKU, 0)
                                 END                               

                                 -- Allocate again with new lot lot
                                 INSERT PICKDETAIL
                                    (PickDetailKey, PickHeaderKey, OrderKey,      OrderLineNumber,
                                     Lot,           StorerKey,     Sku,           Qty,
                                     Loc,           Id,            UOMQty,        UOM,
                                     CaseID,        PackKey,       CartonGroup,   DoReplenish,
                                     Replenishzone, docartonize,   Trafficcop,    PickMethod,
                                     Status,        PickSlipNo,    AddWho,        EditWho,
                                     ShipFlag,      DropID,        TaskDetailKey, AltSKU,
                                     ToLoc,         Channel_ID -- SWT01 
                                     ) 
                                 SELECT @c_NewPickDetailKey,    PickHeaderKey,    OrderKey,     OrderLineNumber,
                                        @c_LOT,                 StorerKey,        Sku,          @n_Qty,
                                        LOC,                    ID,               @n_LotQty,    '6',
                                        CaseID,                 PackKey,          CartonGroup,  DoReplenish,
                                        replenishzone,          docartonize,      Trafficcop,   PickMethod,
                                        '0',                    PickSlipNo,       'wms',        'wms',
                                         ShipFlag,              DropID,           TaskDetailKey, AltSku,
                                        ToLoc,                  Channel_ID -- SWT01  
                                 FROM   PICKDETAIL WITH (NOLOCK)
                                 WHERE  PickDetailKey = @c_ExchgPickDetailKey

                                 IF @@ERROR <> 0
                                    ROLLBACK TRAN
                                 ELSE
                                 BEGIN
                                    -- 23-06-2010 (Shong) Insert into RefKeyLookup for newly added Pickdetail Record.
                                    IF EXISTS(SELECT 1 FROM RefKeyLookup rkl WITH (NOLOCK) WHERE rkl.PickDetailkey = @c_ExchgPickDetailKey)
                                    BEGIN
                                       INSERT INTO RefKeyLookup
                                       (
                                          PickDetailkey,
                                          Pickslipno,
                                          OrderKey,
                                          OrderLineNumber,
                                          Loadkey
                                       )
                                       SELECT @c_NewPickDetailKey,
                                              rkl.Pickslipno,
                                              rkl.OrderKey,
                                              rkl.OrderLineNumber,
                                              rkl.Loadkey
                                         FROM RefKeyLookup rkl
                                       WHERE rkl.PickDetailkey = @c_ExchgPickDetailKey
                                    END

                                    IF @c_ExchgPDStatus <> '0'
                                    BEGIN
                                       UPDATE PICKDETAIL WITH (ROWLOCK)
                                       SET STATUS = @c_ExchgPDStatus
                                       WHERE  PickDetailKey = @c_NewPickDetailKey                           
                                    END

                                    COMMIT TRAN
                                 END
                                 SET @n_Qty = 0
                              END
                           END -- IF @b_Success = 1 (GetKey)                           
                        END
                        
                        IF @n_Qty = 0 
                           BREAK
                           
                        FETCH NEXT FROM CUR_ExchangePickDetailLot INTO @c_ExchgPickDetailKey, @n_ExchgPickDetQty, @c_ExchgPDStatus, @c_ExchgID, @c_ExchgLOC
                     END
                     CLOSE CUR_ExchangePickDetailLot
                     DEALLOCATE CUR_ExchangePickDetailLot

                  END
                  ELSE
                  BEGIN
                     SET @n_LotQty = @n_LOTQty2                     
                  END                  
               END
                  
               IF @n_LotQty = 0
                  GOTO GET_NEXT_LOT
            END

            SET ROWCOUNT 0

            IF ISNULL(RTRIM(@c_NewLOT),'') <> '' AND @n_RowCount > 0  AND @n_LotQty > 0
            BEGIN

               IF @n_LotQty >= @n_Qty
               BEGIN

                  BEGIN TRAN

                  UPDATE PICKDETAIL WITH (ROWLOCK)
                  SET Lot = @c_NewLOT,
                      Id  = @c_NewID,
                      EditWho = 'wms'
                  WHERE PickDetailKey = @c_PickDetailKey

                  SELECT @b_Err = @@ERROR

                  IF @b_Err <> 0
                  BEGIN
                     ROLLBACK TRAN
                  END
                  ELSE
                  BEGIN
                     COMMIT TRAN
                     SELECT @n_rows = @n_rows + 1
                  END
                  -- Added By SHONG on 15-Feb-2005
                  IF EXISTS(SELECT 1 FROM LOTxLOCxID WITH (NOLOCK) WHERE LOC = @c_LOC AND LOT = @c_LOT
                            AND ID = @c_ID AND ( Qty > QtyPicked + QtyAllocated) )
                  BEGIN
                     BEGIN TRAN

                     UPDATE LOTxLOCxID WITH (ROWLOCK)
                        SET QtyExpected = 0
                     WHERE LOT = @c_LOT
                     AND   LOC = @c_LOC
                     AND   ID = @c_ID
                     AND ( Qty >= QtyPicked + QtyAllocated )

                     IF @@ERROR <> 0
                     BEGIN
                        ROLLBACK TRAN
                     END
                     ELSE
                     BEGIN
                        COMMIT TRAN
                     END
                  END
               END -- If lot qty > pick qty
               ELSE -- Split PickDetail
               BEGIN

                  SELECT @b_Success = 0

                  EXECUTE nspg_getkey
                        'PickDetailKey'
                        , 10
                        , @c_NewPickDetailKey OUTPUT
                        , @b_Success OUTPUT
                        , @b_Err OUTPUT
                        , @c_ErrMsg OUTPUT

                  IF @b_Success = 1
                  BEGIN
                     BEGIN TRAN

                     -- Reduce Qty for for current pickdetail, old lot 
                     UPDATE PICKDETAIL WITH (ROWLOCK)
                        SET Qty = Qty - @n_LotQty
                     WHERE PickDetailKey = @c_PickDetailKey

                     IF @@ERROR = 0
                     BEGIN
                        -- Allocate again with new lot lot
                        INSERT PICKDETAIL
                           (PickDetailKey, PickHeaderKey, OrderKey,      OrderLineNumber,
                            Lot,           StorerKey,     Sku,           Qty,
                            Loc,           Id,            UOMQty,        UOM,
                            CaseID,        PackKey,       CartonGroup,   DoReplenish,
                            Replenishzone, docartonize,   Trafficcop,    PickMethod,
                            Status,        PickSlipNo,    AddWho,        EditWho,
                            ShipFlag,      DropID,        TaskDetailKey, AltSKU,
                            ToLoc,         Channel_ID -- SWT01 
                            )
                        SELECT @c_NewPickDetailKey,    PickHeaderKey,    OrderKey,     OrderLineNumber,
                               @c_NewLOT,              StorerKey,        Sku,          @n_LotQty,
                               Loc,                    @c_NewID,         UOMQty,       UOM,
                               CaseID,                 PackKey,          CartonGroup,  DoReplenish,
                               replenishzone,          docartonize,      Trafficcop,   PickMethod,
                               '0',                    PickSlipNo,       'wms',        'wms',
                               @c_ShipFlag,            DropID,           TaskDetailKey, AltSku,
                               ToLoc,                  Channel_ID -- SWT01 
                        FROM   PICKDETAIL WITH (NOLOCK)
                        WHERE  PickDetailKey = @c_PickDetailKey

                        IF @@ERROR <> 0
                           ROLLBACK TRAN
                        ELSE
                        BEGIN
                           -- 23-06-2010 (Shong) Insert into RefKeyLookup for newly added Pickdetail Record.
                           IF EXISTS(SELECT 1 FROM RefKeyLookup rkl WITH (NOLOCK) WHERE rkl.PickDetailkey = @c_PickDetailKey)
                           BEGIN
                              INSERT INTO RefKeyLookup
                              (
                                 PickDetailkey,
                                 Pickslipno,
                                 OrderKey,
                                 OrderLineNumber,
                                 Loadkey
                              )
                              SELECT @c_NewPickDetailKey,
                                     rkl.Pickslipno,
                                     rkl.OrderKey,
                                     rkl.OrderLineNumber,
                                     rkl.Loadkey
                                FROM RefKeyLookup rkl
                              WHERE rkl.PickDetailkey = @c_PickDetailKey
                           END

                           IF @c_Status <> '0'
                           BEGIN
                              UPDATE PICKDETAIL WITH (ROWLOCK)
                              SET STATUS = @c_Status
                              WHERE  PickDetailKey = @c_NewPickDetailKey
                              AND    STATUS <> @c_Status                              
                           END

                           COMMIT TRAN
                           SELECT @n_rows = @n_rows + 1
                        END
                     END
                  END -- IF @b_Success = 1 (GetKey)
               END
            END
            SKIP_NEXT:
            FETCH NEXT FROM PICK_CUR IntO @c_PickDetailKey, @n_Qty, @c_shipflag, @c_Lottable01, @c_Lottable02, @c_Lottable03, @d_Lottable04, @c_Status
         END
         CLOSE PICK_CUR
         DEALLOCATE PICK_CUR

         READ_NEXT_RECORD:
         FETCH NEXT FROM LOT_CUR INTO @c_LOT, @c_LOC, @c_ID, @c_SKU


      END
      CLOSE LOT_CUR
      DEALLOCATE LOT_CUR
   END -- @n_Continue = 1

   QUIT:
END

GO