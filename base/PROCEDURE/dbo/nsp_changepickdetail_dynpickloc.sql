SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* S Proc: nsp_ChangePickDetail_DynPickLoc                              */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: To solve the integrity for qty expected between the         */
/*          LOTxLOCxID and SKUxLOC                                      */
/* Input Parameters: Storer Key                                         */
/*                                                                      */
/* Output Parameters: None                                              */
/*                                                                      */
/* Return Status: None                                                  */
/*                                                                      */
/* Usage: For Backend Schedule job                                      */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: SQL Schedule Job                                          */
/*                                                                      */
/* PVCS Version: 1.6                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[nsp_ChangePickDetail_DynPickLoc]
@c_StorerKey NVARCHAR(15)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF 

   DECLARE  
   @c_PickDetailKey        NVARCHAR(18),
   @n_err                  int,
   @n_rows                 int,
   @n_RowCount             int,
   @c_LOT                  NVARCHAR(10),
   @c_ctrl                 NVARCHAR(1),
   @c_LOC                  NVARCHAR(10),
   @c_id                   NVARCHAR(18),
   @c_SKU                  NVARCHAR(20),
   @n_Qty                  int,
   @c_NewLOT               NVARCHAR(10),
   @c_NewID                NVARCHAR(18),
   @c_message              NVARCHAR(255),
   @n_LotQty               int,
   @c_NewPickDetailKey     NVARCHAR(18),
   @b_success              int,
   @c_errmsg               NVARCHAR(250),
   @c_Status               NVARCHAR(5),
   @c_shipflag             NVARCHAR(1)

   SELECT @n_rows = 0
   SELECT @c_ctrl = '0'

   DECLARE @n_continue int

   SELECT @n_continue = 1

   IF @n_continue=1 or @n_continue=2
   BEGIN
      DECLARE @c_authority NVARCHAR(1)

      Select @b_success = 0
      Execute nspGetRight '',
      @c_StorerKey,   -- Storer
      '',             -- Sku
      'OWITF',        -- ConfigKey
      @b_success          output,
      @c_authority        output,
      @n_err              output,
      @c_errmsg           output

      IF @c_authority = '1'
         select @n_continue = 3
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF NOT EXISTS(SELECT 1 FROM LOTxLOCxID (NOLOCK)
                    JOIN LOC WITH (NOLOCK) ON LOC.Loc = LOTxLOCxID.Loc 
                    JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.SKU = LOTxLOCxID.SKU AND
                                              SKUxLOC.StorerKey = LOTxLOCxID.StorerKey)
                    WHERE LOTxLOCxID.QtyExpected > 0
                    AND LOTxLOCxID.StorerKey = @c_StorerKey
                    AND ( LOC.LocationCategory IN ('DYNPICKP', 'DYNPICKR') 
                    AND (LOTxLOCxID.QtyExpected > 0 AND SKUxLOC.QtyExpected = 0 ) ) )
      BEGIN
         SELECT @n_continue = 4
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE LOT_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT DISTINCT LOTxLOCxID.Lot, LOTxLOCxID.Loc, LOTxLOCxID.id, LOTxLOCxID.Sku
      FROM LOTxLOCxID (NOLOCK)
      JOIN LOC WITH (NOLOCK) ON LOC.Loc = LOTxLOCxID.Loc
      JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.SKU = LOTxLOCxID.SKU AND
                                SKUxLOC.StorerKey = LOTxLOCxID.StorerKey)
      WHERE LOTxLOCxID.QtyExpected > 0
      AND LOTxLOCxID.StorerKey = @c_StorerKey
      AND ( LOC.LocationCategory IN ('DYNPICKP', 'DYNPICKR') 
      AND (LOTxLOCxID.QtyExpected > 0 AND SKUxLOC.QtyExpected = 0 ) )

      OPEN LOT_CUR

-- Commented by SHONG, THis checking is not valid when define cursor as Fast_Forward      
--       IF @@CURSOR_ROWS = 0 
--          RETURN 

      FETCH NEXT FROM LOT_CUR INTO @c_LOT, @c_LOC, @c_ID, @c_SKU
      WHILE (@@FETCH_STATUS <> -1)
      BEGIN           
         IF @n_rows = 200
         BEGIN
            BREAK
         END
   
         DECLARE PICK_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT PickDetailKey, Qty, Shipflag --Added by Vicky 04 Dec 2002
         FROM PICKDETAIL (NOLOCK)
         WHERE SKU = @c_SKU
           AND StorerKey = @c_StorerKey
           AND LOC = @c_LOC
           AND LOT = @c_LOT
           AND ID = @c_id
           AND Status BETWEEN '5' AND '8'

         OPEN PICK_CUR

         IF @@CURSOR_ROWS = 0 
         BEGIN
            GOTO SKIP_NEXT 
         END

         FETCH NEXT FROM PICK_CUR INTO @c_PickDetailKey, @n_Qty, @c_shipflag

         WHILE (@@FETCH_STATUS <> -1)
         BEGIN
            SELECT @c_NewLOT = NULL

            SET ROWCOUNT 1

            -- Consider Same Lot # and Different ID 
            -- SOS72093 Not Allow to swap HELD Lot and ID
            SELECT @c_NewLOT = LOTxLOCxID.Lot,
                   @n_LotQty = (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked),
                   @c_NewID = LOTxLOCxID.ID
            FROM  LOTxLOCxID (NOLOCK) 
            JOIN  ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID 
            JOIN  LOT (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT 
            WHERE LOTxLOCxID.Sku = @c_SKU
            AND   LOTxLOCxID.StorerKey = @c_StorerKey
            AND   LOTxLOCxID.Loc = @c_LOC
            AND   LOTxLOCxID.LOT = @c_LOT 
            AND   LOTxLOCxID.ID <> @c_ID 
            AND   (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) > 0 
            AND   ID.Status <> 'HOLD' 
            AND   LOT.Status <> 'HOLD'

            SELECT @n_RowCount = @@ROWCOUNT 

            IF @n_RowCount = 0 
            BEGIN
               -- SOS72093 Not Allow to swap HELD Lot and ID 
               SELECT @c_NewLOT = LOTxLOCxID.Lot,
                      @n_LotQty = (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked),
                      @c_NewID = LOTxLOCxID.ID
               FROM  LOTxLOCxID (NOLOCK) 
               JOIN  ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID 
               JOIN  LOT (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT 
               WHERE LOTxLOCxID.Sku = @c_SKU
               AND   LOTxLOCxID.StorerKey = @c_StorerKey
               AND   LOTxLOCxID.Loc = @c_LOC
               AND   (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) > 0 
               AND   ID.Status <> 'HOLD' 
               AND   LOT.Status <> 'HOLD'
            
               SELECT @n_RowCount = @@ROWCOUNT
           END 
           
            SET ROWCOUNT 0

            IF ISNULL(RTRIM(@c_NewLOT),'') <> '' AND @n_RowCount > 0  
            BEGIN
               IF @n_LotQty >= @n_Qty
               BEGIN
                  BEGIN TRAN

                  UPDATE PICKDETAIL WITH (ROWLOCK)
                  SET Lot = @c_NewLOT, 
                      id  = @c_NewID, 
                      editwho = 'wms'
                  WHERE PickDetailKey = @c_PickDetailKey 
   
                  SELECT @n_err = @@ERROR
   
                  IF @n_err <> 0
                  BEGIN
                     select @c_SKU 'sku', @c_LOC 'loc', @c_NewLOT 'new lot', @c_PickDetailKey 'pickdetailkey'
                     ROLLBACK TRAN
                  END
                  ELSE
                  BEGIN
                     COMMIT TRAN
                     SELECT @n_rows = @n_rows + 1
                  END
                  -- Added By SHONG on 15-Feb-2005
                  IF EXISTS(SELECT 1 FROM LOTxLOCxID (NOLOCK) WHERE LOC = @c_LOC  AND   LOT = @c_LOT 
                                                              AND   ID = @c_ID AND ( Qty > QtyPicked + QtyAllocated) )
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
                  
               END
               ELSE -- Split PickDetail
               BEGIN
                  SELECT @b_success = 0

                  EXECUTE   nspg_getkey
                        'PickDetailKey'
                        , 10
                        , @c_NewPickDetailKey OUTPUT
                        , @b_success OUTPUT
                        , @n_err OUTPUT
                        , @c_errmsg OUTPUT
   
                  IF @b_success = 1
                  BEGIN
                     SELECT 'Update Pickdetail', @c_PickDetailKey "Pick Key",  @c_NewLOT  "LOT", @n_LotQty "Qty"

                     BEGIN TRAN

                     UPDATE PICKDETAIL WITH (ROWLOCK)
                        SET Qty = Qty - @n_LotQty
                     WHERE PickDetailKey = @c_PickDetailKey

                     IF @@ERROR = 0
                     BEGIN
                        INSERT PICKDETAIL 
                           (PickDetailKey, PickHeaderKey, OrderKey,    OrderLineNumber,
                            Lot,           StorerKey,     Sku,         Qty,
                            Loc,           Id,            UOMQty,      UOM, 
                            CaseID,        PackKey,       CartonGroup, DoReplenish, 
                            Replenishzone, docartonize,   Trafficcop,  PickMethod,  
                            Status,        PickSlipNo,    AddWho,      EditWho, 
                            ShipFlag)
                        SELECT @c_NewPickDetailKey,    PickHeaderKey,    OrderKey,    OrderLineNumber,
                               @c_NewLOT,              StorerKey,        Sku,         @n_LotQty,
                               Loc,                    @c_NewID,         UOMQty,      UOM,           
                               CaseID,                 PackKey,          CartonGroup, DoReplenish,   
                               replenishzone,          docartonize,      Trafficcop,  PickMethod,    
                               '0',                    PickSlipNo,       'wms',       'wms', 
                               @c_shipflag
                        FROM   PICKDETAIL (NOLOCK)
                        WHERE  PickDetailKey = @c_PickDetailKey
   
                        IF @@ERROR <> 0
                           ROLLBACK TRAN
                        ELSE
                        BEGIN
                           SELECT @c_Status = STATUS
                           FROM   PICKDETAIL (NOLOCK)
                           WHERE  PickDetailKey = @c_PickDetailKey
   
                           UPDATE PICKDETAIL WITH (ROWLOCK)
                           SET STATUS = @c_Status
                           WHERE  PickDetailKey = @c_NewPickDetailKey
                           AND    STATUS <> @c_Status

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
                              
                           COMMIT TRAN
                           SELECT @n_rows = @n_rows + 1
                        END
                        SELECT 'Insert Pickdetail', @c_NewPickDetailKey "New Key",  @c_NewLOT  "LOT", @n_LotQty "Qty"
                     END
                  END
               END
            END
            SKIP_NEXT:
   
            FETCH NEXT FROM  PICK_CUR INTO @c_PickDetailKey, @n_Qty, @c_shipflag
         END

         CLOSE PICK_CUR
         DEALLOCATE PICK_CUR

         FETCH NEXT FROM LOT_CUR INTO @c_LOT, @c_LOC, @c_id, @c_SKU
      END
      CLOSE LOT_CUR
      DEALLOCATE LOT_CUR
   END -- @n_continue = 1
END

GO