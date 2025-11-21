SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: nsp_ChangePickDetail_OW_Storer                                   */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: To solve the integrity for qty expected between the         */
/*          LOTxLOCxID and SKUxLOC (For OW Storer Only)                 */
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
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 02-July-2010 TLTING        Insert into RefKeyLookup for newly added  */  
/*                            Pickdetail Record.                        */  
/* 17-July-2012 NJOW          250583-Merge fixes and enhancements from  */  
/*                            nsp_ChangePickDetailByStorer              */
/* 17-Apr-2017  TLTING        Performance Tune                          */  
/************************************************************************/

CREATE PROC [dbo].[nsp_ChangePickDetail_OW_Storer]
@c_StorerKey NVARCHAR(15)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_PickDetailKey  NVARCHAR(18),
   @n_err         int,
   @n_rows        int,
   @n_RowCount    int,
   @c_LOT         NVARCHAR(10),
   @c_ctrl        NVARCHAR(1),
   @c_LOC         NVARCHAR(10),
   @c_id          NVARCHAR(18),
   @c_SKU         NVARCHAR(20),
   @n_Qty         int,
   @c_NewLOT      NVARCHAR(10),
   @c_NewID       NVARCHAR(18),
   @c_message     NVARCHAR(255),
   @n_LotQty               int,
   @c_NewPickDetailKey     NVARCHAR(18),
   @b_success              int,
   @c_errmsg               NVARCHAR(250),
   @c_Status               NVARCHAR(5),
   @c_shipflag             NVARCHAR(1),
   @c_Lottable02           NVARCHAR(18),
   @d_Lottable04           datetime

   SELECT @n_rows = 0
   SELECT @c_ctrl = '0'

   DECLARE @n_continue int

   SELECT @n_continue = 1

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      
      IF NOT EXISTS ( SELECT  1 FROM SKUxLOC  WITH (NOLOCK)
                    JOIN LOTxLOCxID WITH (NOLOCK) ON ( SKUxLOC.StorerKey = LOTxLOCxID.StorerKey 
                                          AND SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC  )
                    WHERE LOTxLOCxID.QtyExpected > 0
                    AND SKUxLOC.StorerKey = @c_StorerKey 
                    AND SKUxLOC.LocationType IN ('PICK', 'CASE') ) AND
         NOT EXISTS ( 
                     SELECT  1 FROM SKUxLOC  WITH (NOLOCK)
                    JOIN LOTxLOCxID WITH (NOLOCK) ON ( SKUxLOC.StorerKey = LOTxLOCxID.StorerKey 
                                          AND SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC ) 
                    WHERE LOTxLOCxID.QtyExpected > 0
                    AND SKUxLOC.StorerKey = @c_StorerKey 
                    AND  SKUxLOC.QtyExpected = 0  ) AND
         NOT EXISTS ( SELECT  1 FROM SKUxLOC WITH (NOLOCK)
                    JOIN LOTxLOCxID  WITH (NOLOCK) ON ( SKUxLOC.StorerKey = LOTxLOCxID.StorerKey 
                                          AND SKUxLOC.SKU = LOTxLOCxID.SKU AND SKUxLOC.LOC = LOTxLOCxID.LOC )
                    JOIN LOC WITH (NOLOCK) ON LOC.Loc = SKUxLOC.Loc
                    WHERE LOTxLOCxID.QtyExpected > 0
                    AND SKUxLOC.StorerKey = @c_StorerKey 
                    AND LOC.LocationType IN ('DYNPICKP', 'DYNPICKR', 'DYNPPICK') ) 
                          
 --     IF NOT EXISTS(SELECT 1 FROM LOTxLOCxID WITH (NOLOCK)        
 --                   JOIN SKUxLOC WITH (NOLOCK) ON (SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.SKU = LOTxLOCxID.SKU AND        
 --                                             SKUxLOC.StorerKey = LOTxLOCxID.StorerKey)      
 --                   JOIN LOC WITH (NOLOCK) ON LOC.Loc = SKUxLOC.Loc     
 --                   WHERE LOTxLOCxID.QtyExpected > 0        
 --                   AND SKUxLOC.StorerKey = @c_StorerKey         -- tlting
 --                   AND ( SKUxLOC.LocationType IN ('PICK', 'CASE') OR     
 --                         (LOTxLOCxID.QtyExpected > 0 AND SKUxLOC.QtyExpected = 0 ) OR      
 --                         (LOC.LocationType IN ('DYNPICKP', 'DYNPICKR') )))        
      BEGIN                   
         SELECT @n_Continue = 4        
      END        
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE LOT_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT LOTxLOCxID.Lot, LOTxLOCxID.Loc, 
                      LOTxLOCxID.id,  LOTxLOCxID.Sku,
                      LOTAttribute.Lottable02,
                      LOTAttribute.Lottable04
      FROM LOTxLOCxID (NOLOCK)
      JOIN  LOTAttribute (NOLOCK) ON (LOTxLOCxID.LOT = LOTAttribute.LOT)
      JOIN SKUxLOC (NOLOCK) ON (SKUxLOC.LOC = LOTxLOCxID.LOC AND SKUxLOC.SKU = LOTxLOCxID.SKU AND
                                SKUxLOC.StorerKey = LOTxLOCxID.StorerKey)
      JOIN LOC (NOLOCK) ON SKUXLOC.LOC = LOC.LOC
      WHERE LOTxLOCxID.QtyExpected > 0
      AND SKUxLOC.StorerKey = @c_StorerKey      -- tlting
      AND ( SKUxLOC.LocationType IN ('PICK', 'CASE') OR     
            (LOTxLOCxID.QtyExpected > 0 AND SKUxLOC.QtyExpected = 0 ) OR      
            (LOC.LocationType IN ('DYNPICKP', 'DYNPICKR') ))      

      OPEN LOT_CUR
      
      FETCH NEXT FROM LOT_CUR INTO @c_LOT, @c_LOC, @c_ID, @c_SKU, @c_Lottable02, @d_Lottable04
      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         --IF @n_rows = 200
         --BEGIN
         --   BREAK
         --END

         DECLARE PICK_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PickDetailKey, Qty, Shipflag  --Added by Vicky 04 Dec 2002
         FROM  PICKDETAIL (NOLOCK)
         WHERE PICKDETAIL.SKU = @c_SKU
         AND PICKDETAIL.StorerKey = @c_StorerKey
         AND PICKDETAIL.LOC = @c_LOC
         AND PICKDETAIL.LOT = @c_LOT
         AND PICKDETAIL.ID = @c_id
         AND PICKDETAIL.Status BETWEEN '5' AND '8'

         OPEN PICK_CUR

         FETCH NEXT FROM PICK_CUR INTO @c_PickDetailKey, @n_Qty, @c_ShipFlag

         WHILE (@@FETCH_STATUS <> -1)
         BEGIN
            SELECT @c_NewLOT = ''

            SET ROWCOUNT 1

            -- Consider Same Lot # and Different ID
            SELECT TOP 1   
                   @c_NewLOT = LOTxLOCxID.Lot,        
                   @n_LotQty = (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked),        
                   @c_NewID = LOTxLOCxID.ID     
            FROM  LOTxLOCxID WITH (NOLOCK)         
            JOIN  ID (NOLOCK) ON LOTxLOCxID.ID = ID.ID         
            JOIN  LOT (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT         
            WHERE 
            --LOTxLOCxID.Sku = @c_SKU        
            --AND   LOTxLOCxID.StorerKey = @c_StorerKey        
                LOTxLOCxID.Loc = @c_LOC        
            AND   LOTxLOCxID.LOT = @c_LOT         
            AND   LOTxLOCxID.ID <> @c_ID         
            AND   (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) > 0         
            AND   ID.Status <> 'HOLD'         
            AND   LOT.Status <> 'HOLD'        
            ORDER BY LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked desc  
            
            SELECT @n_RowCount = @@ROWCOUNT
            
            IF @n_RowCount = 0
            BEGIN
               SELECT @c_NewLOT = LOTxLOCxID.Lot,
                      @n_LotQty = (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked),
                      @c_NewID = LOTxLOCxID.ID
               FROM  LOTxLOCxID WITH (NOLOCK)
               JOIN  ID WITH (NOLOCK) ON LOTxLOCxID.ID = ID.ID
               JOIN  LOT WITH (NOLOCK) ON LOTxLOCxID.LOT = LOT.LOT
               JOIN  LOTATTRIBUTE WITH (NOLOCK) ON LOTATTRIBUTE.LOT = LOT.LOT
               WHERE LOT.Sku = @c_SKU
               AND   LOT.StorerKey = @c_StorerKey
               AND   LOTxLOCxID.Loc = @c_LOC
               AND   (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) > 0
               AND   ISNULL(LOTAttribute.Lottable02,'') = ISNULL(@c_Lottable02,'')
               AND   LOTAttribute.Lottable04 = @d_Lottable04
               AND   ID.Status <> 'HOLD'
               AND   LOT.Status <> 'HOLD' 
                                                  
					     SELECT @n_RowCount = @@ROWCOUNT
            END --IF @@ROWCOUNT = 0 
            
            SET ROWCOUNT 0

            IF ISNULL(RTrim(@c_NewLOT),'') <> ''  AND @n_RowCount > 0
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
                     SELECT @c_SKU 'sku', @c_LOC 'loc', @c_NewLOT 'new lot', @c_PickDetailKey 'pickdetailkey'
                     ROLLBACK TRAN
                  END
                  ELSE
                  BEGIN
                     COMMIT TRAN
                     SELECT @n_rows = @n_rows + 1
                  END
                  -- Added By SHONG on 15-Feb-2005
                  IF EXISTS(SELECT 1 FROM LOTxLOCxID (NOLOCK) WHERE LOC = @c_LOC  AND   LOT = @c_LOT
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
                        (PickDetailKey, PickHeaderKey, OrderKey,     OrderLineNumber,
                        Lot,           StorerKey,     Sku,           Qty,
                        Loc,           Id,            UOMQty,        UOM,
                        CaseID,        PackKey,       CartonGroup,   DoReplenish,
                        Replenishzone, docartonize,   Trafficcop,    PickMethod,
                        Status,        PickSlipNo,    AddWho,        EditWho,
                        ShipFlag,      DropID,        TaskDetailKey, AltSKU,      
                        ToLoc)
                        SELECT @c_NewPickDetailKey,   PickHeaderKey,    OrderKey,       OrderLineNumber,
                               @c_NewLOT,              StorerKey,        Sku,           @n_LotQty,
                               Loc,                    @c_NewID,         UOMQty,        UOM,
                               CaseID,                 PackKey,          CartonGroup,   DoReplenish,
                               replenishzone,          docartonize,      Trafficcop,    PickMethod,
                               '0',                    PickSlipNo,       'wms',         'wms',
                               @c_shipflag,						 DropID,           TaskDetailKey, AltSku,      
                               ToLoc           
                        FROM   PICKDETAIL (NOLOCK)
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
                           
                           SELECT @c_Status = STATUS
                           FROM   PICKDETAIL (NOLOCK)
                           WHERE  PickDetailKey = @c_PickDetailKey

                           UPDATE PICKDETAIL WITH (ROWLOCK) 
                           SET STATUS = @c_Status
                           WHERE  PickDetailKey = @c_NewPickDetailKey
                           AND    STATUS <> @c_Status

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

         FETCH NEXT FROM LOT_CUR INTO @c_LOT, @c_LOC, @c_id, @c_SKU, @c_Lottable02, @d_Lottable04
      END
      CLOSE LOT_CUR
      DEALLOCATE LOT_CUR
   END -- @n_continue = 1
END

GO