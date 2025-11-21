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
/* 02-Jun-2014  TKLIM   1.1   Added Lottables 06-15                     */
/************************************************************************/

CREATE PROC [dbo].[nsp_ChangePickDetailByPickface]  
AS 
BEGIN 
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_pickdetailkey     NVARCHAR(18), 
            @n_err               int, 
            @n_rows              int, 
            @n_row               int, 
            @c_lot               NVARCHAR(10),
            @c_ctrl              NVARCHAR(1), 
            @c_loc               NVARCHAR(10), 
            @c_id                NVARCHAR(18), 
            @c_sku               NVARCHAR(20), 
            @n_qty               int, 
            @c_NewLot            NVARCHAR(10), 
            @c_message           NVARCHAR(255), 
            @n_LotQty            int, 
            @c_NewPickDetailKey  NVARCHAR(18), 
            @c_newid             NVARCHAR(18), 
            @b_success           int, 
            @c_errmsg            NVARCHAR(250), 
            @c_Status            NVARCHAR(5) 
 
   -- Added By SHONG on 11-Mar-2003 
   -- Look for Lottables 
   DECLARE  @c_CursorStatement   NVARCHAR(512), 
            @c_Lottables         NVARCHAR(256), 
            @c_Lottable01        NVARCHAR(18), 
            @c_Lottable02        NVARCHAR(18), 
            @c_Lottable03        NVARCHAR(18), 
            @d_Lottable04        DATETIME, 
            @d_Lottable05        DATETIME, 
            @c_Lottable06        NVARCHAR(30),
            @c_Lottable07        NVARCHAR(30),
            @c_Lottable08        NVARCHAR(30),
            @c_Lottable09        NVARCHAR(30),
            @c_Lottable10        NVARCHAR(30),
            @c_Lottable11        NVARCHAR(30),
            @c_Lottable12        NVARCHAR(30),
            @d_Lottable13        DATETIME,
            @d_Lottable14        DATETIME,
            @d_Lottable15        DATETIME,
            @c_StorerKey         NVARCHAR(15)  
 
   SELECT  @n_rows = 0 
   SELECT  @c_ctrl = '0' 

   DECLARE lot_cur CURSOR  FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT LOTxLOCxID.StorerKey, LOTxLOCxID.Lot, LOTxLOCxID.Loc, LOTxLOCxID.id, LOTxLOCxID.Sku 
   FROM LOTxLOCxID (NOLOCK) 
   JOIN SKUxLOC (NOLOCK) ON (LOTxLOCxID.StorerKey = SKUxLOC.StorerKey  
                              AND LOTxLOCxID.Sku = SKUxLOC.Sku 
                              AND LOTxLOCxID.Loc = SKUxLOC.Loc 
                              AND SKUxLOC.LocationType IN ('PICK', 'CASE')) 
   WHERE LOTxLOCxID.Qty < LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked 

   OPEN lot_cur 

   FETCH NEXT FROM lot_cur INTO @c_StorerKey, @c_lot, @c_loc, @c_id, @c_sku  
   WHILE (@@FETCH_STATUS <> -1) 
   BEGIN         
      IF @n_rows = 200 
      BEGIN 
         BREAK 
      END 
 
      SELECT @c_Lottables = '' 
 
      SELECT @c_Lottable01    = od.Lottable01, 
             @c_Lottable02    = od.Lottable02, 
             @c_Lottable03    = od.Lottable03, 
             @d_Lottable04    = od.Lottable04, 
             @d_Lottable05    = od.Lottable05, 
             @c_Lottable06    = od.Lottable06,
             @c_Lottable07    = od.Lottable07,
             @c_Lottable08    = od.Lottable08,
             @c_Lottable09    = od.Lottable09,
             @c_Lottable10    = od.Lottable10,
             @c_Lottable11    = od.Lottable11,
             @c_Lottable12    = od.Lottable12,
             @d_Lottable13    = od.Lottable13,
             @d_Lottable14    = od.Lottable14,
             @d_Lottable15    = od.Lottable15,
             @c_pickdetailkey = p.PickdetailKey, 
             @n_Qty           = p.Qty   
      FROM PICKDETAIL p (NOLOCK)  
      JOIN orderdetail od (nolock) on p.orderkey = od.orderkey 
                                    and p.orderlinenumber = od.orderlinenumber 
      WHERE p.Sku = @c_sku  
      AND p.Loc = @c_loc 
      AND p.Lot = @c_lot 
      AND p.ID  = @c_id 
      AND p.Status <> '9'    
 
      --IF dbo.fnc_RTrim(@c_Lottable01) IS NOT NULL AND dbo.fnc_RTrim(@c_Lottable01) <> '' 
      --BEGIN 
      --   SELECT @c_Lottables = dbo.fnc_RTrim(@c_Lottables) + "AND LotAttribute.Lottable01 = N'" + dbo.fnc_RTrim(@c_Lottable01) + "' "  
      --END 
      --IF dbo.fnc_RTrim(@c_Lottable02) IS NOT NULL AND dbo.fnc_RTrim(@c_Lottable02) <> '' 
      --BEGIN 
      --   SELECT @c_Lottables = dbo.fnc_RTrim(@c_Lottables) + "AND LotAttribute.Lottable02 = N'" + dbo.fnc_RTrim(@c_Lottable02) + "' "  
      --END 
      --IF dbo.fnc_RTrim(@c_Lottable03) IS NOT NULL AND dbo.fnc_RTrim(@c_Lottable03) <> '' 
      --BEGIN 
      --   SELECT @c_Lottables = dbo.fnc_RTrim(@c_Lottables) + "AND LotAttribute.Lottable03 = N'" + dbo.fnc_RTrim(@c_Lottable03) + "' "  
      --END 
      --IF @d_Lottable04 IS NOT NULL  
      --BEGIN 
      --   SELECT @c_Lottables = dbo.fnc_RTrim(@c_Lottables) + "AND LotAttribute.Lottable04 = N'" + CONVERT(char(20), @d_Lottable04, 106) + "' "  
      --END 
      --IF @d_Lottable05 IS NOT NULL  
      --BEGIN 
      --   SELECT @c_Lottables = dbo.fnc_RTrim(@c_Lottables) + "AND LotAttribute.Lottable05 = N'" + CONVERT(char(20), @d_Lottable05, 106) + "' "  
      --END 
 

      IF dbo.fnc_RTRIM(ISNULL(@c_Lottable01,'')) <> ''
         SELECT @c_Lottables = dbo.fnc_RTRIM(@c_Lottables) + "AND LotAttribute.Lottable01 = N'" + dbo.fnc_RTrim(@c_Lottable01) + "' "  
      IF dbo.fnc_RTRIM(ISNULL(@c_Lottable02,'')) <> ''
         SELECT @c_Lottables = dbo.fnc_RTRIM(@c_Lottables) + "AND LotAttribute.Lottable02 = N'" + dbo.fnc_RTrim(@c_Lottable02) + "' "  
      IF dbo.fnc_RTRIM(ISNULL(@c_Lottable03,'')) <> ''
         SELECT @c_Lottables = dbo.fnc_RTRIM(@c_Lottables) + "AND LotAttribute.Lottable03 = N'" + dbo.fnc_RTrim(@c_Lottable03) + "' "  
      IF @d_Lottable05 IS NOT NULL  
         SELECT @c_Lottables = dbo.fnc_RTrim(@c_Lottables) + "AND LotAttribute.Lottable04 = N'" + CONVERT(char(20), @d_Lottable04, 106) + "' "  
      IF @d_Lottable04 IS NOT NULL  
         SELECT @c_Lottables = dbo.fnc_RTrim(@c_Lottables) + "AND LotAttribute.Lottable05 = N'" + CONVERT(char(20), @d_Lottable05, 106) + "' "  

      IF dbo.fnc_RTRIM(ISNULL(@c_Lottable06,'')) <> ''
         SELECT @c_Lottables = dbo.fnc_RTRIM(@c_Lottables) + "AND LotAttribute.Lottable06 = N'" + dbo.fnc_RTrim(@c_Lottable06) + "' "  
      IF dbo.fnc_RTRIM(ISNULL(@c_Lottable07,'')) <> ''
         SELECT @c_Lottables = dbo.fnc_RTRIM(@c_Lottables) + "AND LotAttribute.Lottable07 = N'" + dbo.fnc_RTrim(@c_Lottable07) + "' "  
      IF dbo.fnc_RTRIM(ISNULL(@c_Lottable08,'')) <> ''
         SELECT @c_Lottables = dbo.fnc_RTRIM(@c_Lottables) + "AND LotAttribute.Lottable08 = N'" + dbo.fnc_RTrim(@c_Lottable08) + "' "  
      IF dbo.fnc_RTRIM(ISNULL(@c_Lottable09,'')) <> ''
         SELECT @c_Lottables = dbo.fnc_RTRIM(@c_Lottables) + "AND LotAttribute.Lottable09 = N'" + dbo.fnc_RTrim(@c_Lottable09) + "' "  
      IF dbo.fnc_RTRIM(ISNULL(@c_Lottable10,'')) <> ''
         SELECT @c_Lottables = dbo.fnc_RTRIM(@c_Lottables) + "AND LotAttribute.Lottable10 = N'" + dbo.fnc_RTrim(@c_Lottable10) + "' "  
      IF dbo.fnc_RTRIM(ISNULL(@c_Lottable11,'')) <> ''
         SELECT @c_Lottables = dbo.fnc_RTRIM(@c_Lottables) + "AND LotAttribute.Lottable11 = N'" + dbo.fnc_RTrim(@c_Lottable11) + "' "  
      IF dbo.fnc_RTRIM(ISNULL(@c_Lottable12,'')) <> ''
         SELECT @c_Lottables = dbo.fnc_RTRIM(@c_Lottables) + "AND LotAttribute.Lottable12 = N'" + dbo.fnc_RTrim(@c_Lottable12) + "' "  
      IF @d_Lottable13 IS NOT NULL  
         SELECT @c_Lottables = dbo.fnc_RTrim(@c_Lottables) + "AND LotAttribute.Lottable13 = N'" + CONVERT(char(20), @d_Lottable13, 106) + "' "  
      IF @d_Lottable14 IS NOT NULL  
         SELECT @c_Lottables = dbo.fnc_RTrim(@c_Lottables) + "AND LotAttribute.Lottable14 = N'" + CONVERT(char(20), @d_Lottable14, 106) + "' "  
      IF @d_Lottable15 IS NOT NULL  
         SELECT @c_Lottables = dbo.fnc_RTrim(@c_Lottables) + "AND LotAttribute.Lottable15 = N'" + CONVERT(char(20), @d_Lottable15, 106) + "' "  


      SELECT @c_CursorStatement = " DECLARE LotChange_cur CURSOR  FAST_FORWARD READ_ONLY FOR " + 
                                 " SELECT LOTxLOCxID.LOT, ID, (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) as QtyAvailable " + 
                                 " FROM  LOTxLOCxID (NOLOCK) " +  
                                 " JOIN  LOTAttribute (NOLOCK) On (LOTxLOCxID.LOT = LotAttribute.LOT) " + 
                                 " WHERE LOTxLOCxID.Sku = N'" + dbo.fnc_RTrim(@c_sku) + "' " +  
                                 " AND   LOTxLOCxID.Loc = N'" + dbo.fnc_RTrim(@c_loc) + "' " + 
                                 " AND   LOTxLOCxID.LOT <> N'" + dbo.fnc_RTrim(@c_lot) + "' " + 
                                 " AND   LOTxLOCxID.StorerKey = N'" + dbo.fnc_RTrim(@c_StorerKey) + "' " + 
                                 " AND   (LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked) > 0 " + 
                                 dbo.fnc_RTrim(@c_Lottables)  
 
      EXEC (@c_CursorStatement) 
      OPEN LotChange_cur 
 
      FETCH NEXT FROM LotChange_cur INTO @c_NewLot, @c_NewID , @n_LotQty
      WHILE (@@FETCH_STATUS <> -1) 
      BEGIN       
      SELECT @c_pickdetailkey "Pick Key",  @c_lot "Old Lot", @c_NewLot  "New LOT", @c_Loc "LOC", @n_LotQty "Lot Qty", @n_Qty "PickDetail Qty" --        SELECT @c_NewLot = NULL    
 
         IF dbo.fnc_RTrim(@c_NewLot) <> '' AND dbo.fnc_RTrim(@c_NewLot) IS NOT NULL 
         BEGIN 
            IF @n_LotQty >= @n_Qty 
            BEGIN 
               SELECT 'Update Pickdetail 1', @c_pickdetailkey "Pick Key",  @c_NewLot  "LOT", @n_LotQty "Qty" 
 
               BEGIN TRAN        
               UPDATE PICKDETAIL WITH (ROWLOCK)
               SET   Lot = @c_NewLot, id = @c_NewID  
               WHERE PickDetailKey = @c_pickdetailkey 
 
               SELECT @n_err = @@ERROR 
               IF @n_err <> 0 
                  ROLLBACK TRAN 
               ELSE 
               BEGIN 
                  COMMIT TRAN 
                  SELECT @n_rows = @n_rows + 1    
               END 
            END 
            ELSE -- Split PickDetail 
            BEGIN 
               SELECT @b_success = 0 
               EXECUTE  nspg_getkey 
                        "PickDetailKey" 
                        , 10 
                        , @c_NewPickDetailKey OUTPUT 
                        , @b_success OUTPUT 
                        , @n_err OUTPUT 
                        , @c_errmsg OUTPUT 
               IF @b_success = 1 
               BEGIN 
               SELECT 'UPDATE Pickdetail 2', @c_pickdetailkey "Pick Key",  @c_NewLot  "LOT", @n_LotQty "Qty" 
               BEGIN TRAN  

               UPDATE PICKDETAIL 
               SET Qty = Qty - @n_LotQty, UOMQty = Qty - @n_LotQty
               WHERE PickDetailKey = @c_pickdetailkey 

               IF @@ERROR <> -1 
               BEGIN 
                  SELECT 'INSERT New Pickdetail', @c_NewPickDetailKey "Pick Key",  @c_NewLot  "LOT", @c_NewID "ID", 
                            @n_Qty -  @n_LotQty "Qty"

                  INSERT PICKDETAIL (
                           PickDetailKey,  PickHeaderKey,    OrderKey,    OrderLineNumber, 
                           Lot,            Storerkey,        Sku,         Qty,
                           Loc,            Id,               UOMQty,      UOM, 
                           CaseID,         PackKey,          CartonGroup, DoReplenish, 
                           replenishzone,  docartonize,      Trafficcop,  PickMethod,  
                           Status,         PickSlipNo,       AddWho,      EditWho) 
                  SELECT @c_NewPickDetailKey, PickHeaderKey, OrderKey, OrderLineNumber, 
                           @c_NewLot,      Storerkey,        Sku,         @n_LotQty,  
                           Loc,            @c_NewID ,        @n_LotQty, 
                           UOM,            CaseID,           PackKey,  CartonGroup,  
                           DoReplenish,    replenishzone,    docartonize, 
                           Trafficcop,     PickMethod,       '0', 
                           PickSlipNo,     'wms',            'wms' 
                  FROM   PICKDETAIL (NOLOCK)
                  WHERE  PickDetailKey = @c_pickdetailkey 

                  IF @n_err <> 0 
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
                  SELECT 'Insert Pickdetail', @c_NewPickDetailKey "New Key",  @c_NewLot  "LOT", @n_LotQty "Qty" 
                  END 
               END 
            END 
         END 
 
         UPDATE LOTxLOCxID WITH (ROWLOCK)
            SET QtyExpected = 0 
         WHERE (QtyAllocated+QtyPicked) <= Qty  
         AND  QtyExpected > 0  
         AND  Lot = @c_Lot  
 
         FETCH NEXT FROM LotChange_cur INTO @c_NewLot, @c_NewID , @n_LotQty
      END 
      CLOSE LotChange_cur 
      DEALLOCATE LotChange_cur  
      FETCH NEXT FROM lot_cur INTO @c_StorerKey, @c_lot, @c_loc, @c_id, @c_sku 
   END 
   CLOSE lot_cur 
   DEALLOCATE lot_cur  
END 

GO