SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  ntrReplenishmentUpdate                                     */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  Trigger Inventory Move when Confirm Replenishment          */
/*                                                                      */
/*                                                                      */
/*                                                                      */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: Replenishment Record Update                               */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 17-Jun-2008  Shong     Change for RDT Dynamic Pick                   */
/* 22-Apr-2010  Shong     SOS#162281 RDT Dynamic Pick to Store          */
/* 04-Sep-2011  Shong     Update QtyReplen for Paper Base Dynamic       */
/*                        Replenishment (SHONG01) --SOS#224731          */
/* 02-JAN-2012  Shong     Add new Column TOID for RDT Dynamic Replen    */
/* 25 May 2012  TLTING01  DM integrity - add update editdate B4         */
/*                        TrafficCop                                    */
/* 28-Oct-2013  TLTING    Review Editdate column update                 */
/* 27-Nov-2013  SHONG     Added New StorerConfig to copy Replenihsment  */
/*                        Group to Lottable01 SOS#296373                */
/* 30-Jul-2014  CSCHONG   Add Lottable06-15 (CS01)                      */
/* 20-Sep-2016  TLTING    Change SetROWCOUNT 1 to Top 1                 */
/* 13-Nov-2016  SHONG     Update QtyReplen If Move Failed               */
/* 19-May-2017  SHONG     Include MoveRefNo when Calling Itrn Move      */
/* 07-JUL-2017  SHONG     Update QtyReplen and Double 11                */
/*                        PendingMoveIn to LotXLocXId (SWT01)           */
/* 09-NOV-2017  SWT02     Not allow to change Qty more then Avaible Qty */
/* 05-JUL-2018  Ung       WMS-5195 To support RDT                       */
/* 02-NOV-2018  Leong     INC0368977 - Allow edit Replenishment.Qty.    */
/* 20-AUG-2019  NJOW01    WMS-9826 Post confirm replenishment call custom*/
/*                        stored proc                                   */
/* 12-Sep-2019  SHONG     Fixing QtyReplen Not Tally Issues (SWT02)     */ 
/* 18-Aug-2022  WLChooi   WMS-20526 - ReplenUpdateUCC (WL01)            */
/* 18-Aug-2022  WLChooi   DevOps Combine Script                         */
/************************************************************************/

CREATE   TRIGGER [dbo].[ntrReplenishmentUpdate]
ON  [dbo].[REPLENISHMENT]
FOR UPDATE AS
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
        @b_Success    INT       -- Populated by calls to stored procedures - was the proc successful?
      , @n_Err        INT       -- Error number returned by stored procedure OR this trigger
      , @n_Err2       INT       -- For Additional Error Detection
      , @c_ErrMsg     NVARCHAR(250) -- Error message returned by stored procedure OR this trigger
      , @n_Continue   INT
      , @n_StartTCnt  INT       -- Holds the current transaction count
      , @c_Preprocess NVARCHAR(250) -- preprocess
      , @c_Pstprocess NVARCHAR(250) -- post process
      , @n_Cnt        INT
      , @n_PendingMoveIn        INT --SWT01
      , @n_deletedPendingMoveIn INT --SWT01
      , @n_QtyReplen            INT --SWT01
      , @n_deletedQtyReplen     INT --SWT01
      , @n_deletedQty           INT --SWT01

   --WL01 S
   DECLARE @c_ReplenUpdateUCC   NVARCHAR(20)  
          ,@c_Option1           NVARCHAR(50)  
          ,@c_Option2           NVARCHAR(50)  
          ,@c_Option3           NVARCHAR(50)  
          ,@c_Option4           NVARCHAR(50)  
          ,@c_Option5           NVARCHAR(4000)
          ,@c_UCCNoField        NVARCHAR(30)  
   --WL01 E

   -- To support RDT
   DECLARE @n_IsRDT INT
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

   SELECT @n_Continue = 1, @n_StartTCnt=@@TRANCOUNT

   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_Continue = 4
   END

   -- TLTING01
   IF ( @n_Continue = 1 OR @n_Continue = 2 ) AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE Replenishment
      SET ArchiveCop = NULL
         ,EditDate = GetDate()
         ,EditWho = SUSER_SNAME()
      FROM Replenishment, INSERTED (NOLOCK)
      WHERE Replenishment.ReplenishmentKey = INSERTED.ReplenishmentKey

      IF @@ERROR <> 0
      BEGIN
         SELECT @n_Continue = 3
         SELECT @n_Err = 63501
         SELECT @c_ErrMsg='NSQL'+CONVERT(VARCHAR(5),@n_Err)+': UPDATE Replenishment Failed (ntrReplenishmentUpdate)'
      END
   END

   /* #INCLUDE <TRMBOA1.SQL> */
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      DECLARE
         @c_StorerKey           NVARCHAR(15),
         @c_SKU                 NVARCHAR(20),
         @c_LOT                 NVARCHAR(10),
         @c_ID                  NVARCHAR(18),
         @c_LOC                 NVARCHAR(10),
         @c_ToLoc               NVARCHAR(10),
         @n_Qty                 INT,
         @c_PackKey             NVARCHAR(10),
         @c_UOM                 NVARCHAR(10),
         @c_ReplenishmentKey    NVARCHAR(10),
         @n_InvQty              INT,
         @c_ReplenType          NVARCHAR(1),
         @c_UCCNo               NVARCHAR(20),
         @c_DropID              NVARCHAR(20),
         @c_ReplenishmentGroup  NVARCHAR(10), -- SHONG01
         @c_TOID                NVARCHAR(18),
         @c_CopyRplenGrptoLot01 NVARCHAR(1),  -- SHONG02
         @c_LOTtable01          NVARCHAR(18), -- SHONG02
         @c_MoveRefKey          NVARCHAR(10),
         @n_MoveAllocQty        INT,
         @c_AllowMove           CHAR(1),
         @c_Confirmed           NVARCHAR(1)

      SELECT @c_ReplenishmentKey = SPACE(10)
      WHILE 1=1
      BEGIN
         SELECT TOP 1
               @c_ReplenishmentKey = INSERTED.ReplenishmentKey,
               @c_StorerKey = INSERTED.StorerKey,
               @c_SKU       = INSERTED.Sku,
               @c_LOT       = INSERTED.Lot,
               @c_ID        = INSERTED.Id,
               @c_LOC       = INSERTED.FromLoc,
               @c_ToLoc     = INSERTED.ToLoc,
               @n_Qty       = INSERTED.Qty,
               @c_PackKey   = INSERTED.Packkey,
               @c_UOM       = INSERTED.Uom,
               @c_ReplenType = CASE WHEN INSERTED.ReplenishmentGroup = 'DYNAMIC'
                               THEN DELETED.Confirmed
                               ELSE INSERTED.Confirmed
                               END, --SHONG01
               @c_UCCNo      = INSERTED.RefNo,
               @c_DropID     = INSERTED.DropId,
               @c_ReplenishmentGroup = INSERTED.ReplenishmentGroup,  -- SHONG01
               @c_TOID        = INSERTED.TOID,
               @c_MoveRefKey  = ISNULL(INSERTED.[MoveRefKey], ''),
               @n_QtyReplen    = ISNULL(INSERTED.QtyReplen,0),      --SWT01
               @n_PendingMoveIn = ISNULL(INSERTED.PendingMoveIn,0), --SWT01
               @n_deletedQtyReplen = ISNULL(DELETED.QtyReplen,0),   --SWT01
               @n_deletedPendingMoveIn = ISNULL(DELETED.PendingMoveIn,0),  --SWT01
               @c_Confirmed = ISNULL(INSERTED.Confirmed,'N'), --SWT01
               @n_deletedQty = DELETED.Qty --SWT01
         FROM DELETED, INSERTED
         WHERE DELETED.ReplenishmentKey = INSERTED.ReplenishmentKey
         AND ( DELETED.Confirmed IS NULL OR
               DELETED.Confirmed = 'N' OR
               DELETED.Confirmed = 'S' OR
               DELETED.Confirmed = 'L' )
         -- AND INSERTED.Confirmed  = 'Y' --SWT01
         AND INSERTED.ReplenishmentKey > @c_ReplenishmentKey
         AND INSERTED.Qty >= 0 -- INC0368977
         ORDER BY INSERTED.ReplenishmentKey

         IF @@ROWCOUNT = 0
         BEGIN
            BREAK
         END

         IF @c_Confirmed = 'Y' AND @n_Qty > 0 -- INC0368977
         BEGIN
            SELECT @b_Success = 0

            -- for ucc tracking
            IF EXISTS (
                        SELECT 1
                        FROM   StorerConfig(NOLOCK)
                        WHERE  StorerKey = @c_StorerKey
                        AND    ConfigKey = 'UCCTracking'
                        AND    SValue = '1' )
            BEGIN
               UPDATE Replenishment WITH (ROWLOCK)
               SET Remark = 'Success - UCC Replen!'
                 , ArchiveCop = NULL
                 , EditDate = GETDATE()
                 , EditWho = SUSER_SNAME()
               WHERE  ReplenishmentKey = @c_ReplenishmentKey

               IF @@ERROR <> 0
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @n_Err = 63502
                  SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5) ,@n_Err) + ': UPDATE Replenishment Failed (ntrReplenishmentUpdate)'
                  GOTO EXIT_SP -- SHONG01
               END
               ELSE
                  CONTINUE
            END

            SET @n_InvQty = 0

            SELECT @n_InvQty = SUM(Qty - QtyPicked - QtyAllocated)
            FROM   LOTxLOCxID (NOLOCK)
            WHERE  LOT = @c_LOT
            AND    LOC = @c_LOC
            AND    ID  = @c_ID

            -- If Qty Available to move less than Replenishment Qty
            IF @n_InvQty < @n_Qty
            BEGIN
               SET @c_AllowMove = 'N'

               -- Getting allocated qty by move reference key
               SET @n_MoveAllocQty = 0

               SELECT @n_MoveAllocQty = SUM(p.Qty)
               FROM PICKDETAIL AS p WITH(NOLOCK)
               WHERE p.Lot = @c_LOT
               AND   p.Loc = @c_LOC
               AND   p.ID = @c_ID
               AND   p.MoveRefKey = @c_MoveRefKey
               AND   p.[Status] = '0'

               -- System allow to move allocated qty if MoveRefKey link to replenishment
               IF @n_InvQty + @n_MoveAllocQty >= @n_Qty
               BEGIN
                  SET @c_AllowMove = 'Y'
               END
            END
            ELSE
            BEGIN
               SET @c_AllowMove = 'Y'
            END

            IF @c_AllowMove = 'Y'
            BEGIN
               IF NOT EXISTS(SELECT 1 FROM StorerConfig sc WITH (NOLOCK) WHERE sc.StorerKey = @c_StorerKey
                             AND sc.ConfigKey = 'DynReplenToStore' AND sc.SValue = '1')
               BEGIN
                  SET @c_DropID = ''
               END

               -- SHONG02
               SET @c_CopyRplenGrptoLot01 = '0'
               SET @c_LOTtable01 = ''

               SELECT @c_CopyRplenGrptoLot01 = ISNULL(sc.SValue,'0')
               FROM StorerConfig sc WITH (NOLOCK) WHERE sc.StorerKey = @c_StorerKey
               AND sc.ConfigKey = 'CopyRplenGrptoLot01'

               IF @c_CopyRplenGrptoLot01 = '1'
                  SET @c_LOTtable01 = @c_ReplenishmentGroup

               -- 02-JAN-2012  Shong
               IF ISNULL(RTRIM(@c_TOID),'') <> ''
                  SET @c_DropID = @c_TOID

               EXECUTE nspItrnAddMove
                  @n_ItrnSysId  = null,
                  @c_StorerKey  = @c_StorerKey,
                  @c_SKU        = @c_SKU,
                  @c_LOT        = @c_LOT,
                  @c_FromLoc    = @c_LOC,
                  @c_FromID     = @c_ID,
                  @c_ToLoc      = @c_ToLoc,
                  @c_ToID       = @c_DropID,
                  @c_Status     = '',
                  @c_LOTtable01 = @c_LOTtable01, -- SHONG02
                  @c_LOTtable02 = '',
                  @c_LOTtable03 = '',
                  @d_lottable04 = null,
                  @d_lottable05 = null,
                  @c_LOTtable06 = '',             --CS01
                  @c_LOTtable07 = '',             --CS01
                  @c_LOTtable08 = '',             --CS01
                  @c_LOTtable09 = '',             --CS01
                  @c_LOTtable10 = '',             --CS01
                  @c_LOTtable11 = '',             --CS01
                  @c_LOTtable12 = '',             --CS01
                  @d_lottable13 = null,           --CS01
                  @d_lottable14 = null,           --CS01
                  @d_lottable15 = null,           --CS01
                  @n_casecnt    = 0,
                  @n_innerpack  = 0,
                  @n_Qty        = @n_Qty,
                  @n_pallet     = 0,
                  @f_cube       = 0,
                  @f_grosswgt   = 0,
                  @f_netwgt     = 0,
                  @f_otherunit1 = 0,
                  @f_otherunit2 = 0,
                  @c_SourceKey  = @c_ReplenishmentKey,
                  @c_SourceType = 'ntrReplenishmentUpdate',
                  @c_PackKey    = @c_PackKey,
                  @c_UOM        = @c_UOM,
                  @b_UOMCalc    = 1,
                  @d_EffectiveDate = NULL,
                  @c_itrnkey = '',
                  @b_Success = @b_Success OUTPUT,
                  @n_Err = @n_Err OUTPUT,
                  @c_ErrMsg = @c_ErrMsg OUTPUT,
                  @c_MoveRefKey = @c_MoveRefKey

               IF @b_Success = 1
               BEGIN
                  -- SHONG01
                  IF @c_ReplenishmentGroup = 'DYNAMIC' AND @c_ReplenType = 'N'
                  BEGIN
                     UPDATE dbo.LOTxLOCxID WITH (ROWLOCK)
                     SET QtyReplen = CASE WHEN QtyReplen > @n_Qty THEN QtyReplen - @n_Qty
                                          ELSE 0
                                     END,
                         EditDate = GETDATE(),   --tlting
                         EditWho = SUSER_SNAME()
                     WHERE  LOT = @c_LOT
                     AND  LOC = @c_LOC
                     AND  ID  = @c_ID

                     IF @@ERROR <> 0
                     BEGIN
                        SELECT @n_Continue = 3
                        SELECT @n_Err = 63503
                        SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': UPDATE LOTxLOCxID Failed (ntrReplenishmentUpdate)'
                        GOTO EXIT_SP
                     END
                  END

                  IF @n_QtyReplen > 0
                  BEGIN
                     -- Comment by Shong, If Confirm = Y. Should clean up the QtyReplen for this record (SWT02)  
                     --IF UPDATE(Qty) AND @n_Qty <> @n_QtyReplen  
                     --   SET @n_QtyReplen = @n_Qty

                     UPDATE LOTxLOCxID WITH (ROWLOCK)
                         SET QtyReplen = CASE WHEN (QtyReplen - @n_QtyReplen) < 0 THEN 0 ELSE QtyReplen - @n_QtyReplen END,
                             EditDate = GETDATE(),
                             EditWho = SUSER_SNAME()
                     WHERE Lot = @c_LOT
                       AND LOC = @c_LOC
                       AND ID  = @c_ID
                     IF @@ERROR <> 0
                     BEGIN
                        SELECT @n_Continue = 3
                        SELECT @n_Err = 63504
                        SELECT @c_ErrMsg='NSQL'+CONVERT(varchar(5),@n_Err)+': UPDATE LOTxLOCxID Failed (ntrReplenishmentUpdate)'
                     END
                  END

                  -- Comment by Shong, If Confirm = Y. Should clean up the PendingMoveIn for this record (SWT02)  
                  --IF UPDATE(Qty) AND @n_Qty <> @n_PendingMoveIn  
                  --   SET @n_PendingMoveIn = @n_Qty 

                  IF @n_PendingMoveIn > 0
                  BEGIN
                     UPDATE LOTxLOCxID WITH (ROWLOCK)
                         SET PendingMoveIn = CASE WHEN (PendingMoveIn - @n_PendingMoveIn) < 0 THEN 0
                                                  ELSE PendingMoveIn - @n_PendingMoveIn
                                             END,
                             EditDate = GETDATE(),
                             EditWho = SUSER_SNAME()
                     WHERE Lot = @c_LOT
                       AND LOC = @c_ToLoc
                       AND ID  = @c_DropID
                     IF @@ERROR <> 0
                     BEGIN
                        SELECT @n_Continue = 3
                        SELECT @n_Err = 63505
                        SELECT @c_ErrMsg='NSQL'+CONVERT(varchar(5),@n_Err)+': UPDATE LOTxLOCxID Failed (ntrReplenishmentUpdate)'
                     END
                  END

                  UPDATE Replenishment WITH (ROWLOCK)
                  SET Remark = 'Perfect ! '
                     ,ArchiveCop = NULL
                     ,EditDate  = GetDate()
                     ,EditWho   = SUSER_SNAME()
                     ,DropID    = CASE WHEN @c_ReplenType = 'L' THEN @c_ReplenType ELSE DropID END
                     ,QtyReplen = 0
                  WHERE ReplenishmentKey = @c_ReplenishmentKey

                  IF @@ERROR <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @n_Err = 63506
                     SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': UPDATE Replenishment Failed (ntrReplenishmentUpdate)'
                     GOTO EXIT_SP -- SHONG01
                  END
                  
                  --NJOW01
                  IF @n_continue IN(1,2)
                  BEGIN
                  	 EXEC isp_PostReplenishment_Wrapper 
                  	      @c_Replenishmentkey = @c_Replenishmentkey,
                          @b_Success = @b_Success OUTPUT,
                          @n_Err = @n_Err OUTPUT, 
                          @c_ErrMsg = @c_ErrMsg OUTPUT
                     
                     IF @b_Success <> 1
                     BEGIN
                        SELECT @n_continue = 3
                     END     
                  END                  
               END -- IF @b_Success = 1
               ELSE
               BEGIN
                  IF @n_IsRDT = 1
                  BEGIN
                     SET @n_Continue = 3
                     GOTO EXIT_SP
                  END

                  UPDATE Replenishment WITH (ROWLOCK)
                  SET Remark = 'Failed ! '
                     ,ArchiveCop = NULL
                     ,EditDate = GetDate()
                     ,EditWho = SUSER_SNAME()
                     ,DropID    = CASE WHEN @c_ReplenType = 'L' THEN @c_ReplenType ELSE DropID END
                  WHERE ReplenishmentKey = @c_ReplenishmentKey

                  IF @@ERROR <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @n_Err = 63507
                     SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': UPDATE Replenishment Failed (ntrReplenishmentUpdate)'
                     GOTO EXIT_SP -- SHONG01
                  END

                  IF @c_ReplenishmentGroup = 'DYNAMIC' AND @c_ReplenType = 'N'
                  BEGIN
                     UPDATE dbo.LOTxLOCxID WITH (ROWLOCK)
                     SET QtyReplen = CASE WHEN QtyReplen > @n_Qty THEN QtyReplen - @n_Qty
                                          ELSE 0
                                       END,
                           EditDate = GETDATE(),   --tlting
                           EditWho = SUSER_SNAME()
                     WHERE  LOT = @c_LOT
                        AND  LOC = @c_LOC
                        AND  ID  = @c_ID
                     IF @@ERROR <> 0
                     BEGIN
                        SELECT @n_Continue = 3
                        SELECT @n_Err = 63508
                        SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': UPDATE LOTxLOCxID Failed (ntrReplenishmentUpdate)'
                        GOTO EXIT_SP
                     END
                  END
               END
            END -- IF @c_AllowMove = 'Y'
            ELSE
            BEGIN
               UPDATE Replenishment WITH (ROWLOCK)
                     SET Remark = 'Failed ! Quantity - (Qty Picked + Qty Allocated) < Qty to Move'
                        ,ArchiveCop = NULL
                        ,EditDate   = GetDate()
                        ,EditWho    = SUSER_SNAME()
                        ,DropID    = CASE WHEN @c_ReplenType = 'L' THEN 'Y' ELSE DropID END
                     WHERE ReplenishmentKey = @c_ReplenishmentKey

               IF @@ERROR <> 0
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @n_Err = 63509
                  SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': UPDATE Replenishment Failed (ntrReplenishmentUpdate)'
                  GOTO EXIT_SP -- SHONG01
               END

               IF @c_ReplenishmentGroup = 'DYNAMIC' AND @c_ReplenType = 'N'
               BEGIN
                  UPDATE dbo.LOTxLOCxID WITH (ROWLOCK)
                  SET QtyReplen = CASE WHEN QtyReplen > @n_Qty THEN QtyReplen - @n_Qty
                                       ELSE 0
                                    END,
                        EditDate = GETDATE(),   --tlting
                        EditWho = SUSER_SNAME()
                  WHERE  LOT = @c_LOT
                     AND  LOC = @c_LOC
                     AND  ID  = @c_ID
                  IF @@ERROR <> 0
                  BEGIN
                     SELECT @n_Continue = 3
                     SELECT @n_Err = 63510
                     SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': UPDATE LOTxLOCxID Failed (ntrReplenishmentUpdate)'
                     GOTO EXIT_SP
                  END
               END

               IF @c_ReplenType = 'L'
               BEGIN
                  UPDATE UCC
                     SET STATUS = '1', EditDate = GETDATE(), EditWho = SUSER_SNAME()
                  WHERE Storerkey = @c_StorerKey
                  AND UCCNo = @c_UCCNo

                  IF @@ERROR <> 0
                  BEGIN
                  SELECT @n_Continue = 3
                     SELECT @n_Err = 63511
                     SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': UPDATE UCC Failed (ntrReplenishmentUpdate)'
                     GOTO EXIT_SP -- SHONG01
                  END
               END
            END  -- IF @c_AllowMove <> 'Y'
         END -- IF @c_Confirmed = 'Y'
         ELSE -- (SWT01)
         BEGIN
            -- (SWT02)
            IF UPDATE(Qty) AND @n_Qty > 0
            BEGIN
               SET @n_InvQty = 0

               SELECT @n_InvQty = SUM(Qty - QtyPicked - QtyAllocated)
               FROM   LOTxLOCxID (NOLOCK)
               WHERE  LOT = @c_LOT
               AND    LOC = @c_LOC
               AND    ID  = @c_ID

               -- If Qty Available to move less than Replenishment Qty
               IF @n_InvQty < @n_Qty
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @n_Err = 63518
                  SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': UPDATE Replenishment Failed, Qty > Qty Available (ntrReplenishmentUpdate)'
                  GOTO EXIT_SP
               END
            END

            IF UPDATE(QtyReplen) AND (@n_deletedQtyReplen <> @n_QtyReplen)
            BEGIN
               UPDATE LOTxLOCxID WITH (ROWLOCK)
                  SET QtyReplen = QtyReplen - @n_deletedQtyReplen + @n_QtyReplen,
                      EditDate = GETDATE(),
                      EditWho = SUSER_SNAME()
               WHERE Lot = @c_LOT
                 AND LOC = @c_LOC
                 AND ID  = @c_ID

               IF @@ERROR <> 0
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @n_Err = 63512
                  SELECT @c_ErrMsg='NSQL'+CONVERT(varchar(5),@n_Err)+': UPDATE LOTxLOCxID Failed (ntrReplenishmentUpdate)'
               END
            END

            IF UPDATE(PendingMoveIN) AND (@n_deletedPendingMoveIn <> @n_PendingMoveIn)
            BEGIN
               UPDATE LOTxLOCxID WITH (ROWLOCK)
                  SET PendingMoveIN = PendingMoveIN - @n_deletedPendingMoveIn + @n_PendingMoveIn,
                      EditDate = GETDATE(),
                      EditWho = SUSER_SNAME()
                WHERE Lot = @c_LOT
                  AND LOC = @c_ToLOC
                  AND ID  = @c_ToID
               IF @@ERROR <> 0
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @n_Err = 63513
                  SELECT @c_ErrMsg='NSQL'+CONVERT(varchar(5),@n_Err)+': UPDATE LOTxLOCxID Failed (ntrReplenishmentUpdate)'
               END
            END

            IF UPDATE(Qty)
               AND NOT UPDATE(QtyReplen)
               AND @n_Qty <> @n_deletedQty
               AND @n_QtyReplen > 0
            BEGIN
               UPDATE LOTxLOCxID  WITH (ROWLOCK)
               SET QtyReplen = QtyReplen - @n_deletedQty  + @n_Qty,
                   EditDate = GETDATE(),
                   EditWho = SUSER_SNAME()
               WHERE Lot = @c_LOT
                 AND LOC = @c_LOC
                 AND ID  = @c_ID

               IF @@ERROR <> 0
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @n_Err = 63514
                  SELECT @c_ErrMsg='NSQL'+CONVERT(varchar(5),@n_Err)+': UPDATE LOTxLOCxID Failed (ntrReplenishmentUpdate)'
               END

               UPDATE Replenishment  WITH (ROWLOCK)
                  SET QtyReplen = QtyReplen - @n_deletedQty  + @n_Qty,
                      ArchiveCop = NULL,
                      EditDate = GETDATE(),
                      EditWho = SUSER_SNAME()
                WHERE ReplenishmentKey = @c_ReplenishmentKey

               IF @@ERROR <> 0
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @n_Err = 63515
                  SELECT @c_ErrMsg='NSQL'+CONVERT(varchar(5),@n_Err)+': UPDATE Replenishment Failed (ntrReplenishmentUpdate)'
               END
            END

            IF UPDATE(Qty)
               AND NOT UPDATE(PendingMoveIN)
               AND @n_Qty <> @n_deletedQty
               AND @n_PendingMoveIN > 0
            BEGIN
               UPDATE LOTxLOCxID WITH (ROWLOCK)
                  SET PendingMoveIN = PendingMoveIN - @n_deletedQty + @n_Qty,
                      EditDate = GETDATE(),
                      EditWho = SUSER_SNAME()
               WHERE Lot = @c_LOT
                 AND LOC = @c_ToLOC
                 AND ID  = @c_ToID

               IF @@ERROR <> 0
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @n_Err = 63516
                  SELECT @c_ErrMsg='NSQL'+CONVERT(varchar(5),@n_Err)+': UPDATE LOTxLOCxID Failed (ntrReplenishmentUpdate)'
               END

               UPDATE Replenishment WITH (ROWLOCK)
               SET PendingMoveIN = PendingMoveIN - @n_deletedQty  + @n_Qty,
                   ArchiveCop = NULL,
                   EditDate = GETDATE(),
                   EditWho = SUSER_SNAME()
               WHERE ReplenishmentKey = @c_ReplenishmentKey

               IF @@ERROR <> 0
               BEGIN
                  SELECT @n_Continue = 3
                  SELECT @n_Err = 63517
                  SELECT @c_ErrMsg='NSQL'+CONVERT(varchar(5),@n_Err)+': UPDATE Replenishment Failed (ntrReplenishmentUpdate)'
               END
            END
         END

         --WL01 S
         IF @n_Continue = 1 OR @n_Continue = 2
         BEGIN
            SET @c_ReplenUpdateUCC = '0'

            SELECT @b_success = 0

            EXECUTE nspGetRight                                
               @c_Facility        = '',                     
               @c_StorerKey       = @c_StorerKey,                    
               @c_sku             = '',
               @c_ConfigKey       = 'ReplenUpdateUCC',
               @b_Success         = @b_success           OUTPUT,             
               @c_Authority       = @c_ReplenUpdateUCC   OUTPUT,             
               @n_err             = @n_err               OUTPUT,             
               @c_errmsg          = @c_errmsg            OUTPUT,             
               @c_Option1         = @c_Option1           OUTPUT,               
               @c_Option2         = @c_Option2           OUTPUT,               
               @c_Option3         = @c_Option3           OUTPUT,               
               @c_Option4         = @c_Option4           OUTPUT,               
               @c_Option5         = @c_Option5           OUTPUT 

            IF ISNULL(@c_UCCNoField,'') = ''
               SELECT @c_UCCNoField = dbo.fnc_GetParamValueFromString('@c_UCCNoField', @c_Option5, @c_UCCNoField)  

            IF ISNULL(@c_UCCNoField,'') = ''
               SET @c_UCCNoField = 'DropID'

            IF @c_ReplenUpdateUCC = '1' AND @c_UCCNoField IN ('DropID', 'RefNo')
            BEGIN
               UPDATE UCC WITH (ROWLOCK)
               SET [Status] = CASE WHEN @c_Confirmed = 'Y' THEN '6' WHEN @c_Confirmed = 'N' THEN '4' ELSE [Status] END
               WHERE UCCNo = CASE WHEN @c_UCCNoField = 'DropID' THEN @c_DropID ELSE @c_UCCNo END
               AND [Status] <= '4'
            END
         END
         --WL01 E
      END -- While
   END

EXIT_SP:
   /* #INCLUDE <TRMBOHA2.SQL> */
   IF @n_Continue = 3  -- Error Occured - Process And Return
   BEGIN
      IF @n_IsRDT = 1
      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit and raise an error back to parent, let the parent decide

         -- Commit until the level we begin with
         WHILE @@TRANCOUNT > @n_starttcnt
            COMMIT TRAN

         -- Raise error with severity = 10, instead of the default severity 16.
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_err, 10, 1) WITH SETERROR

         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
         IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
         BEGIN
            ROLLBACK TRAN
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT > @n_StartTCnt
            BEGIN
               COMMIT TRAN
            END
         END
         EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ntrReplenishmentUpdate'
         RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012
         RETURN
      END
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO