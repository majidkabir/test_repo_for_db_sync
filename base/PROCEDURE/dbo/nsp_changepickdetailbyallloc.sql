SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_ChangePickDetailByAllLoc                       */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
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
/* 02-July-2010 TLTING        Insert into RefKeyLookup for newly added  */  
/*                            Pickdetail Record.                        */  
/*                                                                      */  
/************************************************************************/

CREATE PROC [dbo].[nsp_ChangePickDetailByAllLoc]
@c_StorerKey NVARCHAR(15)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE	@c_pickdetailkey NVARCHAR(18),
   @n_err			int,
   @n_rows 			int,
   @n_row			int,
   @c_lot		 NVARCHAR(10),
   @c_ctrl		 NVARCHAR(1),
   @c_loc		 NVARCHAR(10),
   @c_id			 NVARCHAR(18),
   @c_sku		 NVARCHAR(20),
   @n_qty			int,
   @c_newlot	 NVARCHAR(10),
   @c_newid      NVARCHAR(18),
   @c_message	 NVARCHAR(255),
   @n_LotQty               int,
   @c_NewPickDetailKey     NVARCHAR(18),
   @b_success              int,
   @c_errmsg               NVARCHAR(250),
   @c_Status               NVARCHAR(5)
   SELECT 	@n_rows = 0
   SELECT @c_ctrl = '0'

   DECLARE lot_cur CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT LOTxLOCxID.Lot,
   LOTxLOCxID.Loc,
   LOTxLOCxID.id,
   LOTxLOCxID.Sku
   FROM LOTxLOCxID (NOLOCK), SKUxLOC (NOLOCK)
   WHERE LOTxLOCxID.Sku = SKUxLOC.Sku
   AND LOTxLOCxID.Loc = SKUxLOC.Loc
   -- AND (SKUxLOC.LocationType = 'PICK' OR SKUxLOC.LocationType = 'CASE')
   AND LOTxLOCxID.Qty < LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked
   AND SKUxLOC.StorerKey = @c_StorerKey
   AND lotxlocxid.qtypicked > 0
   OPEN lot_cur
   FETCH NEXT FROM lot_cur INTO @c_lot, @c_loc, @c_id, @c_sku
   WHILE (@@FETCH_STATUS <> -1)
   BEGIN
      IF @n_rows = 200
      BEGIN
         BREAK
      END
      DECLARE pick_cur CURSOR  FAST_FORWARD READ_ONLY FOR
      SELECT PickDetailKey, Qty
      FROM PICKDETAIL (NOLOCK)
      WHERE Sku = @c_sku
      AND Loc = @c_loc
      AND Lot = @c_lot
      AND ID = @c_id
      AND Status BETWEEN '5' AND '8'
      AND storerkey = @c_storerkey
      OPEN pick_cur
      FETCH NEXT FROM pick_cur INTO @c_pickdetailkey, @n_qty
      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         SELECT @c_newlot = NULL
         SET ROWCOUNT 1
         SELECT @c_newlot = Lot,
         @n_LotQty = (Qty - QtyAllocated - QtyPicked),
         @c_newid = id
         FROM  LOTxLOCxID (NOLOCK)
         WHERE Sku = @c_sku
         AND   Loc = @c_loc
         AND   storerkey = @c_storerkey
         AND   (Qty - QtyAllocated - QtyPicked) > 0
         SET ROWCOUNT 0
         select @c_pickdetailkey, @c_newlot, @c_sku, @c_loc
         IF @c_newlot <> '' AND @c_newlot IS NOT NULL
         BEGIN
            IF @n_LotQty >= @n_Qty
            BEGIN
               BEGIN TRAN
                  UPDATE PICKDETAIL WITH (ROWLOCK)
                  SET   Lot = @c_newlot, id = @c_newid, editwho = 'wms'
                  WHERE PickDetailKey = @c_pickdetailkey
                  SELECT @n_err = @@ERROR
                  IF @n_err <> 0
                  begin
                     select @c_sku 'sku', @c_loc 'loc', @c_newlot 'new lot', @c_pickdetailkey 'pickdetailkey'
                     ROLLBACK TRAN
                  end
               ELSE
                  BEGIN
                     COMMIT TRAN
                     SELECT @n_rows = @n_rows + 1
                  END
               END
            ELSE -- Split PickDetail
               BEGIN
                  SELECT @b_success = 0
                  EXECUTE   nspg_getkey
                  "PickDetailKey"
                  , 10
                  , @c_NewPickDetailKey OUTPUT
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT
                  IF @b_success = 1
                  BEGIN
                     SELECT 'Update Pickdetail', @c_pickdetailkey "Pick Key",  @c_newlot  "LOT", @n_LotQty "Qty"
                     BEGIN TRAN
                        UPDATE PICKDETAIL WITH (ROWLOCK)
                        SET Qty = Qty - @n_LotQty
                        WHERE PickDetailKey = @c_pickdetailkey
                        IF @@ERROR = 0
                        BEGIN
                           INSERT PICKDETAIL (PickDetailKey,PickHeaderKey,OrderKey,OrderLineNumber,
                           Lot,Storerkey,Sku,Qty,Loc,Id,UOMQty,
                           UOM, CaseID, PackKey,     CartonGroup, DoReplenish, replenishzone,
                           docartonize, Trafficcop,  PickMethod,  Status,
                           PickSlipNo, AddWho, EditWho, ShipFlag)
                           SELECT @c_NewPickDetailKey, PickHeaderKey, OrderKey, OrderLineNumber,
                           @c_newlot,     Storerkey,     Sku,      @n_LotQty,
                           Loc,           @c_newid,            UOMQty,
                           UOM,           CaseID,    PackKey,  CartonGroup,
                           DoReplenish,   replenishzone, docartonize,
                           Trafficcop,    PickMethod,    '0',
                           PickSlipNo, 'wms', 'wms', 'Y'
                           FROM   PICKDETAIL (NOLOCK)
                           WHERE  PickDetailKey = @c_pickdetailkey
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
                              WHERE  PickDetailKey = @c_pickdetailkey
                              UPDATE PICKDETAIL WITH (ROWLOCK)
                              SET STATUS = @c_Status
                              WHERE  PickDetailKey = @c_NewPickDetailKey
                              AND    STATUS <> @c_Status
                              COMMIT TRAN
                              SELECT @n_rows = @n_rows + 1
                           END
                           SELECT 'Insert Pickdetail', @c_NewPickDetailKey "New Key",  @c_newlot  "LOT", @n_LotQty "Qty"
                        END
                     END
                  END
               END
               FETCH NEXT FROM  pick_cur INTO @c_pickdetailkey, @n_qty
            END
            CLOSE pick_cur
            DEALLOCATE pick_cur
            FETCH NEXT FROM lot_cur INTO @c_lot, @c_loc, @c_id, @c_sku
         END
         CLOSE lot_cur
         DEALLOCATE lot_cur
      END

GO