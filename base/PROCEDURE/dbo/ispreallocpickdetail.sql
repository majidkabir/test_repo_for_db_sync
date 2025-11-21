SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: ispReAllocPickDetail                                    */  
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
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author        Purposes                                  */  
/* 02-June-2010 TLTING        Insert into RefKeyLookup for newly added  */  
/*                            Pickdetail Record.                        */  
/* 02-Jun-2014  TKLIM   1.1   Added Lottables 06-15                     */
/************************************************************************/  

CREATE PROC [dbo].[ispReAllocPickDetail]
           @c_StorerKey    NVARCHAR(15)
         , @c_Sku          NVARCHAR(20)
         , @c_Lot          NVARCHAR(10)
         , @c_Loc          NVARCHAR(10)
         , @c_ID           NVARCHAR(18)
         , @n_Qty          int 
         , @c_Lottable01   NVARCHAR(18)
         , @c_Lottable02   NVARCHAR(18)
         , @c_Lottable03   NVARCHAR(18)
         , @d_Lottable04   DATETIME
         , @d_Lottable05   DATETIME
         , @c_Lottable06   NVARCHAR(30)   = ''  
         , @c_Lottable07   NVARCHAR(30)   = ''  
         , @c_Lottable08   NVARCHAR(30)   = ''  
         , @c_Lottable09   NVARCHAR(30)   = ''  
         , @c_Lottable10   NVARCHAR(30)   = ''  
         , @c_Lottable11   NVARCHAR(30)   = ''  
         , @c_Lottable12   NVARCHAR(30)   = ''  
         , @dt_Lottable13  DATETIME       = NULL
         , @dt_Lottable14  DATETIME       = NULL
         , @dt_Lottable15  DATETIME       = NULL
         , @b_Success      int            OUTPUT
         , @n_err          int            OUTPUT
         , @c_errmsg       NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_PickDetailKey     NVARCHAR(18),
            @n_row               int,
            @c_ctrl              NVARCHAR(1),
            @n_PickQty           int,
            @c_OldLot            NVARCHAR(10),
            @c_OldID             NVARCHAR(18),
            @c_message           NVARCHAR(255),
            @n_LotQty            int,
            @c_NewPickDetailKey  NVARCHAR(18),
            @c_PickStatus        NVARCHAR(5),
            @c_Shipflag          NVARCHAR(1),
            @n_StartTCnt         int,
            @n_QtyRemain         int,
            @n_QtyExpected       int  

   SELECT @c_ctrl = '0'

   DECLARE @n_continue int

   SELECT @n_continue = 1

   SELECT @n_QtyRemain = @n_Qty 

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE LOTCUR CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT DISTINCT LOTxLOCxID.Lot, LOTxLOCxID.id , QtyExpected 
      FROM LOTxLOCxID (NOLOCK)
      WHERE LOTxLOCxID.QtyExpected > 0
      AND LOTxLOCxID.StorerKey = @c_StorerKey
      AND LOTxLOCxID.SKU = @c_SKU
      AND LOTxLOCxID.LOC = @c_Loc 
      AND LOTxLOCxID.LOT <> @c_LOT 

      OPEN LOTCUR
      FETCH NEXT FROM LOTCUR INTO @c_OldLOT, @c_OldID, @n_QtyExpected  
      WHILE (@@FETCH_STATUS <> -1) AND @n_QtyRemain > 0 
      BEGIN           
         DECLARE PickCur CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT PickDetailKey, Qty, Shipflag, Status 
           FROM PICKDETAIL (NOLOCK)
         WHERE Sku = @c_sku
         AND StorerKey = @c_StorerKey 
         AND Loc = @c_Loc 
         AND Lot = @c_OldLOT 
         AND ID  = @c_OldID 
         -- AND Status < '9' 
         AND Status BETWEEN '5' AND '8'

         OPEN PickCur
         FETCH NEXT FROM PickCur INTO @c_PickDetailKey, @n_PickQty, @c_Shipflag, @c_PickStatus 
         WHILE (@@FETCH_STATUS <> -1) and @n_QtyExpected > 0 and @n_QtyRemain > 0  
         BEGIN
            IF @n_QtyExpected >= @n_PickQty and @n_QtyRemain >= @n_QtyExpected
            BEGIN
               BEGIN TRAN
               -- print 'updating pickdetail key: ' + dbo.fnc_RTrim(@c_PickDetailKey) + ' qty ' + cast( @n_QtyRemain as NVARCHAR(5))
               UPDATE PICKDETAIL WITH (ROWLOCK)
                  SET Lot = @c_LOT, ID = @c_ID, EditWho = 'wms'
               WHERE PickDetailKey = @c_PickDetailKey

               SELECT @n_err = @@ERROR                  

               IF @n_err <> 0
               BEGIN
                  ROLLBACK TRAN
               END
               ELSE
               BEGIN
                  SELECT @n_QtyRemain = @n_QtyRemain - @n_PickQty 
                  SELECT @n_QtyExpected = @n_QtyExpected - @n_PickQty 
                  COMMIT TRAN
               END
            END
            ELSE -- Split PickDetail
            BEGIN
               IF @n_QtyRemain < @n_QtyExpected
               BEGIN
                  SELECT @n_QtyExpected = @n_QtyRemain
               END 

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
                  SELECT @n_StartTCnt = @@TRANCOUNT

                  BEGIN TRAN

                  -- print 'updating pickdetail key: ' + dbo.fnc_RTrim(@c_PickDetailKey) + ' qty ' + cast( @n_QtyRemain as NVARCHAR(5))
                  UPDATE PICKDETAIL
                  SET Qty = Qty - @n_QtyExpected, UOMQty = Qty - @n_QtyExpected, UOM = '6'
                  WHERE PickDetailKey = @c_PickDetailKey

                  IF @@ERROR = 0
                  BEGIN
                     INSERT PICKDETAIL (PickDetailKey, PickHeaderKey,  OrderKey,      OrderLineNumber,
                                        Lot,           StorerKey,      Sku,           Qty,
                                        Loc,           Id,             UOMQty,
                                        UOM,           CaseID,         PackKey,       CartonGroup, 
                                        DoReplenish,   replenishzone,  docartonize,   Trafficcop,     
                                        PickMethod,    Status,         PickSlipNo,    AddWho, 
                                        EditWho,       Shipflag)
                     SELECT @c_NewPickDetailKey,       PickHeaderKey,  OrderKey,      OrderLineNumber,
                            @c_LOT,        StorerKey,     Sku,         @n_QtyExpected,
                            Loc,           @c_ID,         @n_QtyExpected,
                            '6',           CaseID,        PackKey,     CartonGroup,
                            DoReplenish, replenishzone, docartonize,
                            Trafficcop,    PickMethod,    '0',
                            PickSlipNo,    'wms',         'wms',       @c_Shipflag
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
                                                 
                        UPDATE PICKDETAIL WITH (ROWLOCK)
                        SET STATUS = @c_PickStatus
                        WHERE  PickDetailKey = @c_NewPickDetailKey

                        IF @@ERROR <> 0
                           ROLLBACK TRAN
                        ELSE                                 
                        BEGIN
                           WHILE @@TRANCOUNT > @n_starttcnt
                           BEGIN
                              COMMIT TRAN
                              SELECT @n_QtyRemain = @n_QtyRemain - @n_QtyExpected
                              SELECT @n_QtyExpected = 0
                           END
                        END 
                     END
                  END
               END
            END
            FETCH NEXT FROM  PickCur INTO @c_PickDetailKey, @n_PickQty, @c_Shipflag, @c_PickStatus 
         END
         CLOSE PickCur
         DEALLOCATE PickCur
         FETCH NEXT FROM LOTCUR INTO @c_OldLOT, @c_OldID, @n_QtyExpected 
      END
      CLOSE LOTCUR
      DEALLOCATE LOTCUR
   END -- @n_continue = 1
END

GO