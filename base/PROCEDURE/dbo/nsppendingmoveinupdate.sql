SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspPendingMoveInUpdate                             */
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
/* Date         Ver.  Author     Purposes                               */
/* 28-09-2009   1.1   Vicky      RDT Compatible Error Message (Vicky01) */
/* 05-01-2010   1.2   Vicky      Cater for Multi records for one ID     */
/*                               (Vicky02)                              */
/* 05-07-2010   1.3   ChewKP     SKIP Update PendingMovein when ID = '' */  
/*                               (ChewKP01)                             */  
/* 26-08-2010   1.3   NJOW01     Fix pending move in qty for multi lot  */
/*                               per ID                                 */
/************************************************************************/

/*******************************************************************
* Modification History:
*
* 06/11/2002 Leo Ng  Program rewrite for IDS version 5
* *****************************************************************/

CREATE PROC    [dbo].[nspPendingMoveInUpdate]
               @c_storerkey    NVARCHAR(15)
,              @c_sku          NVARCHAR(20)
,              @c_lot          NVARCHAR(10)
,              @c_Loc          NVARCHAR(10)
,              @c_ID           NVARCHAR(18)
,              @c_fromloc      NVARCHAR(10)
,              @c_fromid       NVARCHAR(18)
,              @n_qty          int
,              @c_action       NVARCHAR(1) -- S/B 'R'educe, 'I'ncrease
,              @b_Success      int        OUTPUT
,              @n_err          int        OUTPUT
,              @c_errmsg       NVARCHAR(250)  OUTPUT
,              @c_tasktype     NVARCHAR(10) = '' -- (Vicky02)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_continue   int,
           @n_starttcnt  int, -- Holds the current transaction count
           @c_preprocess NVARCHAR(250) , -- preprocess
           @c_pstprocess NVARCHAR(250) , -- post process
           @n_cnt        int,
           @n_err2       int         -- For Additional Error Detection
   
   -- (Vicky02) - Start
   DECLARE @n_LLIQty           int,
           @n_LLIAllocQty      int,
           @n_factor           int,
           @n_PendingMoveInQty int,
           @c_LLISKU           NVARCHAR(20),
           @n_LLILOT           NVARCHAR(10), 
           @cStorerkey         NVARCHAR(15)
   -- (Vicky02) - End

   SELECT @n_starttcnt = @@TRANCOUNT, 
          @n_continue = 1, 
          @b_success = 0,
          @n_err = 0,
          @c_errmsg = '',
          @n_err2 = 0

   /* #INCLUDE <SPPMIU1.SQL> */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF ISNULL(RTRIM(@c_id), '') = ''
      BEGIN
         IF ISNULL(RTRIM(@c_sku), '') = '' OR ISNULL(RTRIM(@c_storerkey), '') = ''
         OR ISNULL(RTRIM(@c_lot), '') = '' OR ISNULL(RTRIM(@c_loc), '') = ''
         OR @n_qty = 0
         BEGIN
            SELECT @n_continue = 3 
            SELECT @n_err = 67779--84101
            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': ID is blank therefore LOT/LOC/ID/QTY/STORERKEY/SKU must be filled in. (nspPendingMoveInUpdate)'
         END
      END
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF ISNULL(RTRIM(@c_id), '') <> ''
      BEGIN
         IF ISNULL(RTRIM(@c_lot), '') <> ''
         BEGIN
            SELECT @n_continue = 3 
            SELECT @n_err = 67780--84102
            SELECT @c_errmsg ='NSQL'+CONVERT(char(5),@n_err)+': ID has been filled in therefore LOT should be blank. (nspPendingMoveInUpdate)'
         END
      END
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF ISNULL(RTRIM(@c_id), '') <> ''
      BEGIN
         IF ISNULL(RTRIM(@c_loc), '') = ''
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 67781 --84103
            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': ID has been filled in therefore LOC must be filled in. (nspPendingMoveInUpdate)'
         END
      END
   END

-- Commented By (Vicky02) - allow multi records
--   IF @n_continue = 1 or @n_continue = 2
--   BEGIN
--      IF ISNULL(RTRIM(@c_fromid), '') <> '' and @n_qty > 0
--      BEGIN
--         DECLARE @n_checkcount int
--         SELECT @n_checkcount = COUNT(*) FROM LOTxLOCxID WITH (NOLOCK)
--         WHERE ID = @c_fromid AND LOC = @c_loc

--         IF @n_checkcount > 1
--         BEGIN
--            SELECT @n_continue = 3
--            SELECT @n_err = 67782--84104
--            SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': ID has been filled in and QTY has been provided but there is MORE than one LOTxLOCxID record for this ID. (nspPendingMoveInUpdate)'
--         END
--      END
--   END

   -- (Vicky05) - Start
   -- Get the Qty of SKU that belongs to the ID + LOC
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
 		IF ISNULL(RTRIM(@c_lot), '') <> '' AND ISNULL(RTRIM(@c_ID), '') <> '' AND ISNULL(RTRIM(@c_loc), '') <> ''
 		BEGIN  
        IF NOT EXISTS (SELECT 1 FROM LOTxLOCxID WITH (NOLOCK)
                       WHERE LOC = @c_fromloc
                       AND   ID = @c_fromid
                       AND   LOT = @c_lot
                       AND   QTY > 0)
         BEGIN
              DECLARE CUR_QTY CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
              SELECT SKU, QTY, LOT, Storerkey, QtyAllocated
              FROM LOTxLOCxID WITH (NOLOCK)
              WHERE ID = @c_fromid
         END
         ELSE
         BEGIN
              DECLARE CUR_QTY CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
              SELECT SKU, QTY, LOT, Storerkey, QtyAllocated
              FROM LOTxLOCxID WITH (NOLOCK)
              WHERE LOC = @c_fromloc
              AND   ID = @c_fromid
              AND   LOT = @c_lot
         END
      END    
 		ELSE IF ISNULL(RTRIM(@c_lot), '') <> '' AND ISNULL(RTRIM(@c_ID), '') <> '' AND ISNULL(RTRIM(@c_loc), '') <> '' 
              AND ISNULL(RTRIM(@c_sku), '') <> '' AND ISNULL(RTRIM(@c_storerkey), '') <> ''
 		BEGIN  
        IF NOT EXISTS (SELECT 1 FROM LOTxLOCxID WITH (NOLOCK)
                       WHERE LOC = @c_fromloc
                       AND   ID = @c_fromid
                       AND   LOT = @c_lot
                       AND   SKU = @c_sku
                       AND   Storerkey = @c_storerkey
                       AND   QTY > 0)
         BEGIN
              DECLARE CUR_QTY CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
              SELECT SKU, SUM(QTY), LOT, Storerkey, SUM(QtyAllocated)
              FROM LOTxLOCxID WITH (NOLOCK)
              WHERE ID = @c_fromid
              GROUP BY SKU, Storerkey, LOT
         END
         ELSE
         BEGIN
              DECLARE CUR_QTY CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
SELECT SKU, SUM(QTY), LOT, Storerkey, SUM(QtyAllocated)
              FROM LOTxLOCxID WITH (NOLOCK)
              WHERE LOC = @c_fromloc
              AND   ID = @c_fromid
              AND   LOT = @c_lot
              AND   SKU = @c_sku
              AND   Storerkey = @c_storerkey
              GROUP BY SKU, Storerkey, LOT
         END
      END   
 		ELSE IF ISNULL(RTRIM(@c_lot), '') <> '' AND ISNULL(RTRIM(@c_ID), '') = '' AND ISNULL(RTRIM(@c_loc), '') <> '' 
              AND ISNULL(RTRIM(@c_sku), '') <> '' AND ISNULL(RTRIM(@c_storerkey), '') <> ''
 		BEGIN  
--              DECLARE CUR_QTY CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
--              SELECT SKU, SUM(QTY), LOT, Storerkey, SUM(QtyAllocated)
--              FROM LOTxLOCxID WITH (NOLOCK)
--              WHERE LOC = @c_fromloc
--              AND   LOT = @c_lot
--              AND   SKU = @c_sku
--              AND   Storerkey = @c_storerkey
--              GROUP BY SKU, Storerkey, LOT
                GOTO SKIPPENDINGMOVEIN -- (ChewKP01)  
      END
 		ELSE IF ISNULL(RTRIM(@c_lot), '') <> '' AND ISNULL(RTRIM(@c_ID), '') <> '' AND ISNULL(RTRIM(@c_loc), '') = '' 
              AND ISNULL(RTRIM(@c_sku), '') <> '' AND ISNULL(RTRIM(@c_storerkey), '') <> ''
 		BEGIN  
              DECLARE CUR_QTY CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
              SELECT SKU, SUM(QTY), LOT, Storerkey, SUM(QtyAllocated)
              FROM LOTxLOCxID WITH (NOLOCK)
              WHERE ID = @c_fromid
              AND   LOT = @c_lot
              AND   SKU = @c_sku
              AND   Storerkey = @c_storerkey
              GROUP BY SKU, Storerkey, LOT
      END  
 		ELSE IF ISNULL(RTRIM(@c_lot), '') = '' AND ISNULL(RTRIM(@c_ID), '') <> '' AND ISNULL(RTRIM(@c_loc), '') <> '' 
              AND ISNULL(RTRIM(@c_sku), '') <> '' AND ISNULL(RTRIM(@c_storerkey), '') <> ''
 		BEGIN  
        IF NOT EXISTS (SELECT 1 FROM LOTxLOCxID WITH (NOLOCK)
                       WHERE LOC = @c_fromloc
                       AND   ID = @c_fromid
                       AND   SKU = @c_sku
                       AND   Storerkey = @c_storerkey
                       AND   QTY > 0)
         BEGIN
              DECLARE CUR_QTY CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
              SELECT SKU, SUM(QTY), LOT, Storerkey, SUM(QtyAllocated)
              FROM LOTxLOCxID WITH (NOLOCK)
              WHERE ID = @c_fromid
              GROUP BY SKU, Storerkey, LOT
         END
         ELSE
         BEGIN
              DECLARE CUR_QTY CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
              SELECT SKU, SUM(QTY), LOT, Storerkey, SUM(QtyAllocated)
              FROM LOTxLOCxID WITH (NOLOCK)
              WHERE LOC = @c_fromloc
              AND   ID = @c_fromid
              AND   SKU = @c_sku
              AND   Storerkey = @c_storerkey
              GROUP BY SKU, Storerkey, LOT
         END
      END   
 		ELSE IF ISNULL(RTRIM(@c_lot), '') = '' AND ISNULL(RTRIM(@c_ID), '') = '' AND ISNULL(RTRIM(@c_loc), '') <> '' 
              AND ISNULL(RTRIM(@c_sku), '') <> '' AND ISNULL(RTRIM(@c_storerkey), '') <> ''
 		BEGIN  
--              DECLARE CUR_QTY CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
--              SELECT SKU, SUM(QTY), LOT, Storerkey, SUM(QtyAllocated)
--              FROM LOTxLOCxID WITH (NOLOCK)
--              WHERE LOC = @c_fromloc
--              AND   SKU = @c_sku
--              AND   Storerkey = @c_storerkey
--              GROUP BY SKU, Storerkey, LOT
                GOTO SKIPPENDINGMOVEIN -- (ChewKP01)  
      END
 		ELSE IF ISNULL(RTRIM(@c_lot), '') = '' AND ISNULL(RTRIM(@c_ID), '') <> '' AND ISNULL(RTRIM(@c_loc), '') = '' 
              AND ISNULL(RTRIM(@c_sku), '') <> '' AND ISNULL(RTRIM(@c_storerkey), '') <> ''
 		BEGIN  
              DECLARE CUR_QTY CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
              SELECT SKU, SUM(QTY), LOT, Storerkey, SUM(QtyAllocated)
              FROM LOTxLOCxID WITH (NOLOCK)
              WHERE ID = @c_fromid
              AND   SKU = @c_sku
              AND   Storerkey = @c_storerkey
              GROUP BY SKU, Storerkey, LOT
      END    
 		ELSE IF ISNULL(RTRIM(@c_ID), '') <> '' AND ISNULL(RTRIM(@c_loc), '') <> ''
 		BEGIN  
        IF NOT EXISTS (SELECT 1 FROM LOTxLOCxID WITH (NOLOCK)
                       WHERE LOC = @c_fromloc
                       AND   ID = @c_fromid
                       AND   QTY > 0)
         BEGIN
              DECLARE CUR_QTY CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
              SELECT SKU, SUM(QTY), LOT, Storerkey, SUM(QtyAllocated)
              FROM LOTxLOCxID WITH (NOLOCK)
              WHERE ID = @c_fromid
              GROUP BY SKU, Storerkey, LOT
         END
         ELSE
         BEGIN
              DECLARE CUR_QTY CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
              SELECT SKU, SUM(QTY), LOT, Storerkey, SUM(QtyAllocated)
              FROM LOTxLOCxID WITH (NOLOCK)
              WHERE LOC = @c_fromloc
              AND   ID = @c_fromid
              GROUP BY SKU, Storerkey, LOT
         END
      END
 		ELSE IF ISNULL(RTRIM(@c_ID), '') = '' AND ISNULL(RTRIM(@c_loc), '') <> ''
 		BEGIN  
          DECLARE CUR_QTY CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
          SELECT SKU, SUM(QTY), LOT, Storerkey, SUM(QtyAllocated)
          FROM LOTxLOCxID WITH (NOLOCK)
          WHERE LOC = @c_fromloc
          GROUP BY SKU, Storerkey, LOT
      END
 		ELSE IF ISNULL(RTRIM(@c_ID), '') <> '' AND ISNULL(RTRIM(@c_loc), '') = ''
 		BEGIN  
          DECLARE CUR_QTY CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
          SELECT SKU, SUM(QTY), LOT, Storerkey, SUM(QtyAllocated)
          FROM LOTxLOCxID WITH (NOLOCK)
          WHERE ID = @c_fromid
          GROUP BY SKU, Storerkey, LOT
      END

          OPEN CUR_QTY
          FETCH NEXT FROM CUR_QTY INTO @c_LLISKU, @n_LLIQTY, @n_LLILOT, @cStorerkey, @n_LLIAllocQty
          WHILE @@FETCH_STATUS <> -1
          BEGIN

--               IF NOT EXISTS(SELECT 1 FROM LOTxLOCxID WITH (NOLOCK)
--                             WHERE LOT = @c_lot AND LOC = @c_loc and ID = @c_id)
--               BEGIN
--                    INSERT LOTxLOCxID (STORERKEY, SKU, LOT, LOC, ID)
--                    VALUES (@cStorerkey, @c_LLISKU, @n_LLILOT, @c_loc, @c_id)
--                    
--
--                    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
--                    IF @n_err <> 0
--                    BEGIN
--                       SELECT @n_continue = 3
--                       SELECT @n_err = 67783--84105   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
--                       SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update Failed To LOTxLOCxID. (nspPendingMoveInUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
--                    END
--                END

                IF @c_action = 'R'
                BEGIN
                  SELECT @n_factor = -1
                END
                ELSE
                BEGIN
                  SELECT @n_factor = 1
                END

                IF @c_tasktype = 'PK'
                BEGIN
                    IF @n_LLIAllocQty > 0 --@n_qty > 0
                    BEGIN
                      IF ((SELECT COUNT(*)
                          FROM LOTxLOCxID WITH (NOLOCK)
                          WHERE LOC = @c_fromloc
                          AND   ID = @c_fromid
                          AND   QtyAllocated > 0) > 1
                          AND ISNULL(RTRIM(@c_lot), '') = ''
                          AND ISNULL(RTRIM(@c_Sku), '') = ''
                          AND ISNULL(RTRIM(@c_ID), '') <> '' 
                          AND ISNULL(RTRIM(@c_loc), '') <> '') --NJOW01
                      BEGIN
                         UPDATE LOTxLOCxID WITH (ROWLOCK)
--                            SET PENDINGMOVEIN = CASE WHEN PENDINGMOVEIN + (@n_qty * @n_factor) < 0
--                                       THEN 0
--                                                     ELSE PENDINGMOVEIN + (@n_qty * @n_factor)
--                                                END
                            SET PENDINGMOVEIN = CASE WHEN PENDINGMOVEIN + (@n_LLIAllocQty * @n_factor) < 0
                                                     THEN 0
                                                     ELSE PENDINGMOVEIN + (@n_LLIAllocQty * @n_factor)
                                                END
                         WHERE LOC = @c_loc 
                         AND   ID = @c_id
                         AND   LOT = @n_LLILOT
                         AND   SKU = @c_LLISKU
                         AND   Storerkey = @cStorerkey
                      END
                      ELSE
                      BEGIN
                         UPDATE LOTxLOCxID WITH (ROWLOCK)
                            SET PENDINGMOVEIN = CASE WHEN PENDINGMOVEIN + (@n_qty * @n_factor) < 0
                                                     THEN 0
                                                     ELSE PENDINGMOVEIN + (@n_qty * @n_factor)
                                                END
--                            SET PENDINGMOVEIN = CASE WHEN PENDINGMOVEIN + (@n_LLIAllocQty * @n_factor) < 0
--                                                     THEN 0
--                                                     ELSE PENDINGMOVEIN + (@n_LLIAllocQty * @n_factor)
--                                                END
                         WHERE LOC = @c_loc 
                         AND   ID = @c_id
                         AND   LOT = @n_LLILOT
                         AND   SKU = @c_LLISKU
                         AND   Storerkey = @cStorerkey
                      END
                                         
                      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                      IF @n_err <> 0
                      BEGIN
                         SELECT @n_continue = 3
                         SELECT @n_err = 67785--84106   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed To LOTxLOCxID. (nspPendingMoveInUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
                      END
                    END -- (@n_continue = 1 or @n_continue = 2) and @n_qty > 0
                END
                ELSE
                BEGIN
                    IF @n_LLIQTY > 0 --@n_qty > 0
                    BEGIN
                      UPDATE LOTxLOCxID WITH (ROWLOCK)
        --                 SET PENDINGMOVEIN = CASE WHEN PENDINGMOVEIN + (@n_qty * @n_factor) < 0
        --                                          THEN 0
        --                                          ELSE PENDINGMOVEIN + (@n_qty * @n_factor)
        --                                     END
                         SET PENDINGMOVEIN = CASE WHEN PENDINGMOVEIN + (@n_LLIQTY * @n_factor) < 0
                                                  THEN 0
                                                  ELSE PENDINGMOVEIN + (@n_LLIQTY * @n_factor)
                                             END
                      WHERE LOC = @c_loc 
                      AND   ID = @c_id
                      AND   LOT = @n_LLILOT
                      AND   SKU = @c_LLISKU
                      AND   Storerkey = @cStorerkey
                      
                   
                      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                      IF @n_err <> 0
                      BEGIN
                         SELECT @n_continue = 3
                         SELECT @n_err = 67785--84106   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed To LOTxLOCxID. (nspPendingMoveInUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg), '') + ' ) '
                      END
                    END -- (@n_continue = 1 or @n_continue = 2) and @n_qty > 0
                END

         FETCH NEXT FROM CUR_QTY INTO @c_LLISKU, @n_LLIQTY, @n_LLILOT, @cStorerkey, @n_LLIAllocQty
      END
      CLOSE CUR_QTY
      DEALLOCATE CUR_QTY
  END --(@n_continue = 1 or @n_continue = 2)

-- (ChewKP01)  
SKIPPENDINGMOVEIN:  
 /* #INCLUDE <SPPMIU2.SQL> */
 IF @n_continue=3  -- Error Occured - Process And Return
 BEGIN
      SELECT @b_success = 0
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

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
        execute nsp_logerror @n_err, @c_errmsg, 'nspPendingMoveInUpdate'
        RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
        RETURN
     END
 END
 ELSE
 BEGIN
   SELECT @b_success = 1
   WHILE @@TRANCOUNT > @n_starttcnt
   BEGIN
      COMMIT TRAN
   END
      RETURN
 END
END -- End PRoc

GO