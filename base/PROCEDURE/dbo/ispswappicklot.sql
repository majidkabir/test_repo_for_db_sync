SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: ispSwapPickLot                                          */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: To solve the Integrity for qty expected between the         */  
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
/* 03-Jun-2014  TKLIM   1.1   Added Lottables 06-15                     */
/************************************************************************/  

CREATE PROC [dbo].[ispSwapPickLot] 
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_pickdetailkey        NVARCHAR(18),
            @n_err                  int,
            @n_rows                 int,
            @n_row                  int,
            @c_lot                  NVARCHAR(10),
            @c_ctrl                 NVARCHAR(1),
            @c_loc                  NVARCHAR(10),
            @c_id                   NVARCHAR(18),
            @c_sku                  NVARCHAR(20),
            @n_qty                  int,
            @c_NewLot               NVARCHAR(10),
            @c_message              NVARCHAR(255),
            @n_LotQty               int,
            @c_NewPickDetailKey     NVARCHAR(18),
            @b_success              int,
            @c_errmsg               NVARCHAR(250),
            @c_Status               NVARCHAR(5),
            @c_StorerKey            NVARCHAR(15) 

   DECLARE  @c_MatchLot01           NVARCHAR(1),  
            @c_MatchLot02           NVARCHAR(1),
            @c_MatchLot03           NVARCHAR(1),
            @c_MatchLot04           NVARCHAR(1),
            @c_MatchLot05           NVARCHAR(1),
            @c_MatchLot06           NVARCHAR(1),
            @c_MatchLot07           NVARCHAR(1),
            @c_MatchLot08           NVARCHAR(1),
            @c_MatchLot09           NVARCHAR(1),
            @c_MatchLot10           NVARCHAR(1),
            @c_MatchLot11           NVARCHAR(1),
            @c_MatchLot12           NVARCHAR(1),
            @c_MatchLot13           NVARCHAR(1),
            @c_MatchLot14           NVARCHAR(1),
            @c_MatchLot15           NVARCHAR(1),
            @c_Lottable01           NVARCHAR(18),
            @c_Lottable02           NVARCHAR(18),
            @c_Lottable03           NVARCHAR(18),
            @c_Lottable04           NVARCHAR(18),
            @c_Lottable05           NVARCHAR(18),
            @c_Lottable06           NVARCHAR(30),
            @c_Lottable07           NVARCHAR(30),
            @c_Lottable08           NVARCHAR(30),
            @c_Lottable09           NVARCHAR(30),
            @c_Lottable10           NVARCHAR(30),
            @c_Lottable11           NVARCHAR(30),
            @c_Lottable12           NVARCHAR(30),
            @c_Lottable13           NVARCHAR(18),
            @c_Lottable14           NVARCHAR(18),
            @c_Lottable15           NVARCHAR(18),
            @c_SQL                  NVARCHAR(2000)

   SELECT   @n_rows = 0
   SELECT   @c_ctrl = '0'

   DECLARE LOT_CUR CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT LOTxLOCxID.StorerKey, LOTxLOCxID.Lot, LOTxLOCxID.Loc, 
                  LOTxLOCxID.id, LOTxLOCxID.Sku
   FROM  LOTxLOCxID (NOLOCK), SKUxLOC (NOLOCK)
   WHERE LOTxLOCxID.Sku = SKUxLOC.Sku
   AND LOTxLOCxID.Loc = SKUxLOC.Loc
   AND SKUxLOC.LocationType IN ('PICK', 'CASE')
   AND LOTxLOCxID.Qty < LOTxLOCxID.QtyAllocated + LOTxLOCxID.QtyPicked

   OPEN LOT_CUR

   FETCH NEXT FROM LOT_CUR INTO @c_StorerKey, @c_lot, @c_loc, @c_id, @c_sku

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN     
      IF @n_rows = 200
      BEGIN
         BREAK
      END


      SELECT @c_MatchLot01 = '0',
            @c_MatchLot02 = '0',
            @c_MatchLot03 = '0',
            @c_MatchLot04 = '0',
            @c_MatchLot05 = '0',
            @c_MatchLot06 = '0',
            @c_MatchLot07 = '0',
            @c_MatchLot08 = '0',
            @c_MatchLot09 = '0',
            @c_MatchLot10 = '0',
            @c_MatchLot11 = '0',
            @c_MatchLot12 = '0',
            @c_MatchLot13 = '0',
            @c_MatchLot14 = '0',
            @c_MatchLot15 = '0'

      IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE StorerKey = @c_StorerKey AND ConfigKey = 'SwapLotWithMatchLottabble01' AND sValue = '1') 
         SELECT @c_MatchLot01 = '1' 
      IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE StorerKey = @c_StorerKey AND ConfigKey = 'SwapLotWithMatchLottabble02' AND sValue = '1') 
         SELECT @c_MatchLot02 = '1'                                                
      IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE StorerKey = @c_StorerKey AND ConfigKey = 'SwapLotWithMatchLottabble03' AND sValue = '1') 
         SELECT @c_MatchLot03 = '1'                                                
      IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE StorerKey = @c_StorerKey AND ConfigKey = 'SwapLotWithMatchLottabble04' AND sValue = '1') 
         SELECT @c_MatchLot04 = '1'                                                
      IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE StorerKey = @c_StorerKey AND ConfigKey = 'SwapLotWithMatchLottabble05' AND sValue = '1') 
         SELECT @c_MatchLot05 = '1' 

      IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE StorerKey = @c_StorerKey AND ConfigKey = 'SwapLotWithMatchLottabble06' AND sValue = '1') 
         SELECT @c_MatchLot06 = '1' 
      IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE StorerKey = @c_StorerKey AND ConfigKey = 'SwapLotWithMatchLottabble07' AND sValue = '1') 
         SELECT @c_MatchLot07 = '1' 
      IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE StorerKey = @c_StorerKey AND ConfigKey = 'SwapLotWithMatchLottabble08' AND sValue = '1') 
         SELECT @c_MatchLot08 = '1' 
      IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE StorerKey = @c_StorerKey AND ConfigKey = 'SwapLotWithMatchLottabble09' AND sValue = '1') 
         SELECT @c_MatchLot09 = '1' 
      IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE StorerKey = @c_StorerKey AND ConfigKey = 'SwapLotWithMatchLottabble10' AND sValue = '1') 
         SELECT @c_MatchLot10 = '1' 
      IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE StorerKey = @c_StorerKey AND ConfigKey = 'SwapLotWithMatchLottabble11' AND sValue = '1') 
         SELECT @c_MatchLot11 = '1' 
      IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE StorerKey = @c_StorerKey AND ConfigKey = 'SwapLotWithMatchLottabble12' AND sValue = '1') 
         SELECT @c_MatchLot12 = '1' 
      IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE StorerKey = @c_StorerKey AND ConfigKey = 'SwapLotWithMatchLottabble13' AND sValue = '1') 
         SELECT @c_MatchLot13 = '1' 
      IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE StorerKey = @c_StorerKey AND ConfigKey = 'SwapLotWithMatchLottabble14' AND sValue = '1') 
         SELECT @c_MatchLot14 = '1' 
      IF EXISTS(SELECT 1 FROM STORERCONFIG (NOLOCK) WHERE StorerKey = @c_StorerKey AND ConfigKey = 'SwapLotWithMatchLottabble15' AND sValue = '1') 
         SELECT @c_MatchLot15 = '1' 


      DECLARE pick_cur CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT PickDetailKey, Qty
         FROM PICKDETAIL (NOLOCK)
         WHERE Sku = @c_sku 
         AND Loc = @c_loc
         AND Lot = @c_lot
         AND ID = @c_id
         AND Status < '9'

      OPEN pick_cur

      FETCH NEXT FROM pick_cur INTO @c_pickdetailkey, @n_qty
      WHILE (@@FETCH_STATUS <> -1)
      BEGIN      
         SELECT @c_NewLot = NULL   

         IF @c_MatchLot01 = '0' AND  @c_MatchLot02 = '0' AND @c_MatchLot03 = '0' AND @c_MatchLot04 = '0' AND @c_MatchLot05 = '0' AND 
            @c_MatchLot06 = '0' AND  @c_MatchLot07 = '0' AND @c_MatchLot08 = '0' AND @c_MatchLot09 = '0' AND @c_MatchLot10 = '0' AND 
            @c_MatchLot11 = '0' AND  @c_MatchLot12 = '0' AND @c_MatchLot13 = '0' AND @c_MatchLot14 = '0' AND @c_MatchLot15 = '0' 
         BEGIN
            SET ROWCOUNT 1

            SELECT @c_NewLot = Lot,
                  @n_LotQty = (Qty - QtyAllocated - QtyPicked)
            FROM  LOTxLOCxID (NOLOCK)
            WHERE Sku = @c_sku
            AND   Loc = @c_loc
            AND   (Qty - QtyAllocated - QtyPicked) > 0
         END
         ELSE
         BEGIN
            SELECT @c_Lottable01 = ISNULL(Lottable01, ''), 
                  @c_Lottable02 = ISNULL(Lottable02, ''),
                  @c_Lottable03 = ISNULL(Lottable03, ''),
                  @c_Lottable04 = ISNULL(CONVERT(char(10), Lottable04, 112), ''),
                  @c_Lottable05 = ISNULL(CONVERT(char(10), Lottable05, 112), ''),
                  @c_Lottable06 = ISNULL(Lottable06, ''),
                  @c_Lottable07 = ISNULL(Lottable07, ''),
                  @c_Lottable08 = ISNULL(Lottable08, ''),
                  @c_Lottable09 = ISNULL(Lottable09, ''),
                  @c_Lottable10 = ISNULL(Lottable10, ''),
                  @c_Lottable11 = ISNULL(Lottable11, ''),
                  @c_Lottable12 = ISNULL(Lottable12, ''),
                  @c_Lottable13 = ISNULL(CONVERT(char(10), Lottable13, 112), ''),
                  @c_Lottable14 = ISNULL(CONVERT(char(10), Lottable14, 112), ''),
                  @c_Lottable15 = ISNULL(CONVERT(char(10), Lottable15, 112), '')

            FROM LOTATTRIBUTE (NOLOCK)
            WHERE LOT = @c_LOT 

            SELECT @c_SQL = 
                     ' SELECT @c_NewLot = L.Lot, ' + 
                     ' @n_LotQty = (L.Qty - L.QtyAllocated - L.QtyPicked) ' + 
                     ' FROM  LOTxLOCxID L (NOLOCK) ' + 
                     ' JOIN  LOTATTRIBUTE LA (NOLOCK) ON (L.LOT = LA.LOT) ' + 
                     ' WHERE SKU = N''' + dbo.fnc_RTrim(@c_sku) + ''' ' + 
                     ' AND   STORERKEY = N''' + dbo.fnc_RTrim(@c_StorerKey) + ''' ' + 
                     ' AND   LOC = N''' + dbo.fnc_RTrim(@c_loc) + ''' ' + 
                     ' AND   (Qty - QtyAllocated - QtyPicked) > 0 ' 

            IF @c_MatchLot01 = '1' AND dbo.fnc_RTrim(ISNULL(@c_Lottable01,'')) <> '' 
            BEGIN
               SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ' AND LA.Lottable01 = N''' + dbo.fnc_RTrim(@c_Lottable01) + ''' ' 
            END 
            IF @c_MatchLot02 = '1' AND dbo.fnc_RTrim(ISNULL(@c_Lottable02,'')) <> '' 
            BEGIN
               SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ' AND LA.Lottable02 = N''' + dbo.fnc_RTrim(@c_Lottable02) + ''' ' 
            END 
            IF @c_MatchLot03 = '1' AND dbo.fnc_RTrim(ISNULL(@c_Lottable03,'')) <> '' 
            BEGIN
               SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ' AND LA.Lottable03 = N''' + dbo.fnc_RTrim(@c_Lottable03) + ''' ' 
            END 
            IF @c_MatchLot04 = '1' AND dbo.fnc_RTrim(ISNULL(@c_Lottable04,'')) <> '' 
            BEGIN
               SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ' AND LA.Lottable04 = N''' + dbo.fnc_RTrim(@c_Lottable04) + ''' ' 
            END 
            IF @c_MatchLot05 = '1' AND dbo.fnc_RTrim(ISNULL(@c_Lottable05,'')) <> '' 
            BEGIN
               SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ' AND LA.Lottable05 = N''' + dbo.fnc_RTrim(@c_Lottable05) + ''' ' 
            END 


            IF @c_MatchLot06 = '1' AND dbo.fnc_RTrim(ISNULL(@c_Lottable06,'')) <> '' 
               SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ' AND LA.Lottable06 = N''' + dbo.fnc_RTrim(@c_Lottable06) + ''' ' 
            IF @c_MatchLot07 = '1' AND dbo.fnc_RTrim(ISNULL(@c_Lottable07,'')) <> '' 
               SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ' AND LA.Lottable07 = N''' + dbo.fnc_RTrim(@c_Lottable07) + ''' ' 
            IF @c_MatchLot08 = '1' AND dbo.fnc_RTrim(ISNULL(@c_Lottable08,'')) <> '' 
               SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ' AND LA.Lottable08 = N''' + dbo.fnc_RTrim(@c_Lottable08) + ''' ' 
            IF @c_MatchLot09 = '1' AND dbo.fnc_RTrim(ISNULL(@c_Lottable09,'')) <> '' 
               SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ' AND LA.Lottable09 = N''' + dbo.fnc_RTrim(@c_Lottable09) + ''' ' 
            IF @c_MatchLot10 = '1' AND dbo.fnc_RTrim(ISNULL(@c_Lottable10,'')) <> '' 
               SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ' AND LA.Lottable10 = N''' + dbo.fnc_RTrim(@c_Lottable10) + ''' ' 
            IF @c_MatchLot11 = '1' AND dbo.fnc_RTrim(ISNULL(@c_Lottable11,'')) <> '' 
               SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ' AND LA.Lottable11 = N''' + dbo.fnc_RTrim(@c_Lottable11) + ''' ' 
            IF @c_MatchLot12 = '1' AND dbo.fnc_RTrim(ISNULL(@c_Lottable12,'')) <> '' 
               SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ' AND LA.Lottable12 = N''' + dbo.fnc_RTrim(@c_Lottable12) + ''' ' 
            IF @c_MatchLot13 = '1' AND dbo.fnc_RTrim(ISNULL(@c_Lottable13,'')) <> '' 
               SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ' AND LA.Lottable13 = N''' + dbo.fnc_RTrim(@c_Lottable13) + ''' ' 
            IF @c_MatchLot14 = '1' AND dbo.fnc_RTrim(ISNULL(@c_Lottable14,'')) <> '' 
               SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ' AND LA.Lottable14 = N''' + dbo.fnc_RTrim(@c_Lottable14) + ''' ' 
            IF @c_MatchLot15 = '1' AND dbo.fnc_RTrim(ISNULL(@c_Lottable15,'')) <> '' 
               SELECT @c_SQL = dbo.fnc_RTrim(@c_SQL) + ' AND LA.Lottable15 = N''' + dbo.fnc_RTrim(@c_Lottable15) + ''' ' 


            EXEC sp_executesql @c_SQL, N'@c_NewLot NVARCHAR(10) output, @n_LotQty int output', @c_NewLot output, @n_LotQty output
         END 


         SET ROWCOUNT 0
         select @c_pickdetailkey 'PickDetailKey', @c_NewLot 'New Lot', @c_sku 'SKU', @c_loc 'Loc'

         IF @c_NewLot <> '' AND @c_NewLot IS NOT NULL
         BEGIN
            IF @n_LotQty >= @n_Qty
            BEGIN
               BEGIN TRAN

               UPDATE PICKDETAIL WITH (ROWLOCK)
               SET   Lot = @c_NewLot, id = ''
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

               EXECUTE   nspg_getkey
                     'PickDetailKey'
                     , 10
                     , @c_NewPickDetailKey OUTPUT
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT

               IF @b_success = 1
               BEGIN
                  SELECT 'Update Pickdetail', @c_pickdetailkey 'Pick Key',  @c_NewLot  'LOT', @n_LotQty 'Qty'

                  BEGIN TRAN
                  UPDATE PICKDETAIL
                  SET Qty = Qty - @n_LotQty
                  WHERE PickDetailKey = @c_pickdetailkey

                  IF @@ERROR <> -1
                  BEGIN
                     INSERT PICKDETAIL (PickDetailKey,PickHeaderKey,OrderKey,OrderLineNumber,
                              Lot,Storerkey,Sku,Qty,Loc,Id,UOMQty,
                              UOM, CaseID, PackKey,     CartonGroup, DoReplenish, replenishzone,
                              docartonize, Trafficcop,  PickMethod,  Status,
                              PickSlipNo, AddWho, EditWho)
                     SELECT @c_NewPickDetailKey, PickHeaderKey, OrderKey, OrderLineNumber,
                              @c_NewLot,     Storerkey,     Sku,      @n_LotQty,
                              Loc,           '',            UOMQty,
                              UOM,           CaseID,        PackKey,  CartonGroup, 
                              DoReplenish,   replenishzone, docartonize,
                              Trafficcop,    PickMethod,    '0',
                              PickSlipNo, 'wms', 'wms'
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
                   
                        SELECT @n_err = @@ERROR
                        IF @n_err <> 0
                           ROLLBACK TRAN
                        ELSE
                        BEGIN
                           COMMIT TRAN
                           SELECT @n_rows = @n_rows + 1   
                        END
                     END
                     SELECT 'Insert Pickdetail', @c_NewPickDetailKey 'New Key',  @c_NewLot  'LOT', @n_LotQty 'Qty'
                  END
               END
            END
         END
         FETCH NEXT FROM  pick_cur INTO @c_pickdetailkey, @n_qty
      END
      CLOSE pick_cur
      DEALLOCATE pick_cur

      FETCH NEXT FROM LOT_CUR INTO @c_StorerKey, @c_lot, @c_loc, @c_id, @c_sku
   END
   CLOSE LOT_CUR
   DEALLOCATE LOT_CUR
END

GO