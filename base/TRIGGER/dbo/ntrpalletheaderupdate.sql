SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Trigger:  ntrPalletHeaderUpdate                                       */
/* Creation Date:                                                        */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose:  Trigger point upon any Update on the Container              */
/*                                                                       */
/* Return Status:  None                                                  */
/*                                                                       */
/* Usage:                                                                */
/*                                                                       */
/* Local Variables:                                                      */
/*                                                                       */
/* Called By: When records updated                                       */
/*                                                                       */
/* PVCS Version: 1.2                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author    Ver.  Purposes                                 */
/* 17-Mar-2009  TLTING    1.1   Change user_name() to SUSER_SNAME()      */
/* 02-Apr-2010  MCTang    1.2   SOS Extend Palletkey from NVARCHAR(10)   */
/*                              to NVARCHAR(30) (MC01)                   */ 
/*                              Extend @c_controlkey from NVARCHAR(60)   */
/*                              to NVARCHAR(80) (MC01)                   */
/*                              Exterd @c_summarykey from NVARCHAR(55)   */
/*                              to NVARCHAR(75) (MC01)                   */ 
/*                              Comment off unnecessary code (MC02)      */
/* 28-Oct-2013  TLTING    1.3   Review Editdate column update            */
/* 12-Dec-2018  NJOW01    1.4   WMS-7187 allow supervisor to reverse status*/
/*************************************************************************/

CREATE TRIGGER ntrPalletHeaderUpdate
ON  Pallet
FOR UPDATE
AS
BEGIN

   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END
  
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int,
           @c_issupervisor NVARCHAR(10), --NJOW01
           @c_Username NVARCHAR(18) --NJOW01
           
   SELECT @b_debug = 0

   IF @b_debug = 1
   BEGIN
      SELECT * FROM DELETED
      SELECT * FROM INSERTED
   END

   DECLARE
   @b_Success              int       -- Populated by calls to stored procedures - was the proc successful?
   ,         @n_err        int       -- Error number returned by stored procedure or this trigger
   ,         @n_err2       int              -- For Additional Error Detection
   ,         @c_errmsg     NVARCHAR(250) -- Error message returned by stored procedure or this trigger
   ,         @n_continue   int                 
   ,         @n_starttcnt  int                -- Holds the current transaction count
   ,         @c_preprocess NVARCHAR(250)         -- preprocess
   ,         @c_pstprocess NVARCHAR(250)         -- post process
   ,         @n_cnt        int   
               
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   IF UPDATE(TrafficCop)
   BEGIN
      SELECT @n_continue = 4 
   END

   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4 
   END

      /* #INCLUDE <TRPALHU1.SQL> */     
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF @b_debug = 1
      BEGIN
         PRINT 'Reject UPDATE when PALLET.Status already ''SHIPPED'''
      END
      
      IF EXISTS(SELECT * FROM DELETED WHERE Status = '9')          
      BEGIN
         --NJOW01
         SET @c_issupervisor = 'N'
         IF UPDATE(Status)
         BEGIN
            SET @c_username = SUSER_SNAME()
            EXEC isp_CheckSupervisorRole
                 @c_username  = @c_username
                ,@c_Flag     = @c_issupervisor OUTPUT
                ,@b_Success  = @b_success      OUTPUT  
                ,@n_Err      = @n_err          OUTPUT  
                ,@c_ErrMsg   = @c_errmsg       OUTPUT
         END    

      	 IF @c_issupervisor <> 'Y' --NJOW01      	
      	 BEGIN
            SELECT @n_continue=3
            SELECT @n_err=67400
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE rejected. PALLET.Status = ''SHIPPED''. (ntrPalletHeaderUpdate)'
         END
      END
   END

   -- (MC02) - S
   /*
   IF @n_continue=1 or @n_continue=2
   BEGIN
      IF EXISTS (SELECT 1 FROM PICKDETAIL WITH (nolock), PALLETDETAIL WITH (nolock), INSERTED
                 WHERE PALLETDETAIL.PalletKey = INSERTED.PalletKey
                 AND PICKDETAIL.CaseId = PALLETDETAIL.CaseId
                 AND NOT PICKDETAIL.Status = '9'
                 AND INSERTED.Status = '9' )
      BEGIN

         IF @n_continue=1 or @n_continue=2
         BEGIN
            IF @b_debug = 1
            BEGIN
               PRINT 'Update PALLETDETAIL with matching PickDetail'
            END

            UPDATE PALLETDETAIL
            SET Status = '9'
            FROM PICKDETAIL, PALLETDETAIL, INSERTED
            WHERE PALLETDETAIL.PalletKey = INSERTED.PalletKey
            AND PICKDETAIL.CaseId = PALLETDETAIL.CaseId
            AND NOT PICKDETAIL.Status = '9'
            AND INSERTED.Status = '9'

            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=67401   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table PALLETDETAIL. (ntrPalletHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         END

         IF @n_continue=1 or @n_continue=2
         BEGIN
            IF @b_debug = 1
            BEGIN
               PRINT 'Update PICKDETAIL with matching PalletDetail'
            END

            UPDATE PICKDETAIL
            SET Status = '9'
            FROM PICKDETAIL, PALLETDETAIL, INSERTED
            WHERE PALLETDETAIL.PalletKey = INSERTED.PalletKey
            AND PICKDETAIL.CaseId = PALLETDETAIL.CaseId
            AND NOT PICKDETAIL.Status = '9'
            AND INSERTED.Status = '9'

            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=67402   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table PICKDETAIL. (ntrPalletHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            END
         END
      END
   END -- Update PALLETDETAIL/PICKDETAIL

   IF @n_continue=1 or @n_continue=2
   BEGIN

      IF @b_debug = 1
      BEGIN
         PRINT 'Update ITRN (Withdrawal)'
      END

      DECLARE @c_controlkey      NVARCHAR(80),   -- (MC01)
      @c_summarykey              NVARCHAR(75),   -- (MC01)
      @c_previoussummarykey      NVARCHAR(75),   -- (MC01)
      @c_palletkey               NVARCHAR(30),   -- (MC01)
      @c_storerkey               NVARCHAR(15),
      @c_sku                     NVARCHAR(20),
      @c_loc                     NVARCHAR(10),
      @c_palletlinenumber        NVARCHAR(5),
      @n_qty                     int,
      @d_EffectiveDate           datetime,
      @n_summaryqty              int,
      @c_summarystorerkey        NVARCHAR(15),
      @c_summarysku              NVARCHAR(20),
      @c_summaryloc              NVARCHAR(10),
      @c_summarypalletkey        NVARCHAR(30),  -- (MC01)
      @d_SummaryEffectiveDate    datetime,
      @c_itrnkey                 NVARCHAR(10),
      @b_eof                     int,
      @n_pallet                  int,
      @n_casecnt                 int

      SELECT @c_controlkey = space(80),  @c_previoussummarykey = space(75),
      @b_eof = 0, @n_pallet = 1, @n_casecnt = 0

      SET ROWCOUNT 1

      SELECT @c_controlkey = PALLETDETAIL.PalletKey + PALLETDETAIL.StorerKey + PALLETDETAIL.Sku + PALLETDETAIL.Loc + PALLETDETAIL.PalletLineNumber,
      @c_summarykey = PALLETDETAIL.PalletKey + PALLETDETAIL.StorerKey + PALLETDETAIL.Sku + PALLETDETAIL.Loc,
      @c_storerkey = PALLETDETAIL.StorerKey,
      @c_sku = PALLETDETAIL.Sku,
      @c_loc = PALLETDETAIL.Loc,
      @c_palletkey = PALLETDETAIL.PalletKey,
      @n_qty = PALLETDETAIL.Qty,
      @d_EffectiveDate = INSERTED.EffectiveDate
      FROM PALLETDETAIL, INSERTED
      WHERE PALLETDETAIL.PalletKey = INSERTED.PalletKey
      AND PALLETDETAIL.PalletKey + PALLETDETAIL.StorerKey + PALLETDETAIL.Sku + PALLETDETAIL.Loc + PALLETDETAIL.PalletLineNumber > @c_controlkey
      AND NOT PALLETDETAIL.Status = '9'
      AND INSERTED.Status = '9'
      ORDER BY PALLETDETAIL.PalletKey,
      PALLETDETAIL.StorerKey,
      PALLETDETAIL.Sku,
      PALLETDETAIL.Loc,
      PALLETDETAIL.PalletLineNumber

      IF @@ROWCOUNT = 0
      BEGIN
         SELECT @b_eof = 1
      END

      WHILE (@b_eof = 0)
      BEGIN
         IF NOT @c_summarykey = @c_previoussummarykey
         BEGIN
            SELECT @c_previoussummarykey = @c_summarykey,
            @n_summaryqty = 0,
            @c_summarystorerkey = @c_storerkey,
            @c_summarysku = @c_sku,
            @c_summaryloc = @c_loc,
            @c_summarypalletkey = @c_palletkey,
            @d_SummaryEffectiveDate = @d_EffectiveDate

            IF @n_pallet = 1 and @n_casecnt = 0 and
                  exists ( SELECT 1 FROM PALLETDETAIL
                           WHERE PalletKey = @c_palletkey
                           and Status <> '9'
                           and PalletKey + StorerKey + Sku + Loc <> @c_summarykey )
            BEGIN
               SELECT @n_casecnt = 1, @n_pallet = 0
            END

            IF @b_debug = 1
            BEGIN
               PRINT 'HEADER StorerKey: ' + @c_storerkey + ', Sku:' + @c_sku + ', Loc:' + @c_loc +
                     ', PalletKey:' + @c_palletkey + ', @n_pallet:' + CONVERT(char(10),@n_pallet) + ', @n_casecnt:' + CONVERT(char(10),@n_casecnt)
            END
         END

         SELECT @n_summaryqty = @n_summaryqty + @n_qty
         IF @b_debug = 1
         BEGIN
            PRINT 'BODY @n_qty ' + CONVERT(char(10),@n_qty)
            PRINT ' @n_summaryqty ' + CONVERT(char(10),@n_summaryqty)
         END

         SELECT @c_controlkey = PALLETDETAIL.PalletKey + PALLETDETAIL.StorerKey + PALLETDETAIL.Sku + PALLETDETAIL.Loc + PALLETDETAIL.PalletLineNumber,
         @c_summarykey = PALLETDETAIL.PalletKey + PALLETDETAIL.StorerKey + PALLETDETAIL.Sku + PALLETDETAIL.Loc,
         @c_storerkey = PALLETDETAIL.StorerKey,
         @c_sku = PALLETDETAIL.Sku,
         @c_loc = PALLETDETAIL.Loc,
         @c_palletkey = PALLETDETAIL.PalletKey,
         @n_qty = PALLETDETAIL.Qty,
         @d_EffectiveDate = INSERTED.EffectiveDate
         FROM PALLETDETAIL, INSERTED
         WHERE PALLETDETAIL.PalletKey = INSERTED.PalletKey
         AND PALLETDETAIL.PalletKey + PALLETDETAIL.StorerKey + PALLETDETAIL.Sku + PALLETDETAIL.Loc + PALLETDETAIL.PalletLineNumber > @c_controlkey
         AND NOT PALLETDETAIL.Status = '9'
         AND INSERTED.Status = '9'
         ORDER BY PALLETDETAIL.PalletKey,
         PALLETDETAIL.StorerKey,
         PALLETDETAIL.Sku,
         PALLETDETAIL.Loc,
         PALLETDETAIL.PalletLineNumber

         IF @@ROWCOUNT = 0
         BEGIN
            SELECT @b_eof = 1
         END

         IF NOT @c_summarykey = @c_previoussummarykey OR @b_eof = 1
         BEGIN
            SELECT @b_success = 0
            EXECUTE nspItrnAddWithdrawal
            @n_ItrnSysId  = NULL,
            @c_StorerKey  = @c_summarystorerkey,
            @c_Sku        = @c_summarysku,
            @c_Lot        = '',
            @c_ToLoc      = @c_summaryloc,
            @c_ToID       = '',
            @c_Status     = '',
            @c_lottable01 = '',
            @c_lottable02 = '',
            @c_lottable03 = '',
            @d_lottable04 = NULL,
            @d_lottable05 = NULL,
            @n_casecnt    = @n_casecnt,
            @n_innerpack  = 0,
            @n_qty        = @n_summaryqty,
            @n_pallet     = @n_pallet,
            @f_cube       = 0,
            @f_grosswgt   = 0,
            @f_netwgt     = 0,
            @f_otherunit1 = 0,
            @f_otherunit2 = 0,
            @c_SourceKey  = @c_summarypalletkey,
            @c_SourceType = 'ntrPalletHeaderUpdate',
            @c_PackKey    = '',
            @c_UOM        = '',
            @b_UOMCalc    = 0,
            @d_EffectiveDate = @d_SummaryEffectiveDate,
            @c_itrnkey    = @c_itrnkey OUTPUT,
            @b_Success    = @b_Success OUTPUT,
            @n_err        = @n_err     OUTPUT,
            @c_errmsg     = @c_errmsg  OUTPUT

            IF NOT @b_success = 1
            BEGIN
               SELECT @n_continue = 3
               BREAK
            END

            INSERT ITRNHDR (
                  HeaderType,
                  ItrnKey,
                  HeaderKey)
            VALUES (
                  'PA',
                  @c_itrnkey,
                  @c_summarypalletkey)

            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=67403   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table ITRNHDR. (ntrPalletHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               BREAK
            END
         END
      END

      SET ROWCOUNT 0
   END
   */
   -- (MC02) - E

   IF @n_continue = 1 or @n_continue=2
   BEGIN
      IF @b_debug = 1
      BEGIN
         PRINT 'Update PALLETDETAIL.Status to ''SHIPPED'''
      END

      UPDATE PALLETDETAIL
      SET Status = '9'
          , Trafficcop = null,   --(MC02)
          EditDate = GETDATE(),   --tlting
          EditWho = SUSER_SNAME()
      FROM PALLETDETAIL, INSERTED
      WHERE PALLETDETAIL.PalletKey = INSERTED.PalletKey
      AND NOT PALLETDETAIL.Status = '9'
      AND INSERTED.Status='9'

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=67406   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table PALLETDETAIL. (ntrPalletHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

   IF ( @n_continue = 1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
   BEGIN
      IF @b_debug = 1
      BEGIN
         PRINT 'Update EditDate and EditWho'
      END

      UPDATE PALLET
      SET  EditDate = GETDATE(),
           EditWho = SUSER_SNAME()
      FROM PALLET, INSERTED
      WHERE PALLET.PalletKey = INSERTED.PalletKey

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=67404   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On Table PALLET. (ntrPalletHeaderUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
   END

      /* #INCLUDE <TRPALHU2.SQL> */

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
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

      execute nsp_logerror @n_err, @c_errmsg, 'ntrPalletHeaderUpdate'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END



GO