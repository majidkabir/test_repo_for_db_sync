SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
/* Trigger: ntrPickHeaderDelete                                                        */
/* Creation Date:                                                                      */
/* Copyright: IDS                                                                      */
/* Written by:                                                                         */
/*                                                                                     */
/* Purpose: SOS# 39810 Picklist for KCPI (Philippine)                                  */
/*                                                                                     */
/* Called By:                                                                          */
/*                                                                                     */
/* PVCS Version: 1.2                                                                   */
/*                                                                                     */
/* Version: 5.4.2                                                                      */
/*                                                                                     */
/* Data Modifications:                                                                 */
/*                                                                                     */
/* Updates:                                                                            */
/* Date         Author        Purposes                                                 */
/* 39856        SHONG         Delete REFKEYLOOKUP Records when PickHeader was deleted  */
/* 12-May-2011  KHLim01       Insert Delete log                                        */
/* 14-Jul-2011  KHLim02       GetRight for Delete log                                  */
/* 14-Nov-2016  TLTING        Perfromance tune - delete pickdetail                     */
/***************************************************************************************/
CREATE TRIGGER [dbo].[ntrPickHeaderDelete]
ON [dbo].[PICKHEADER]
FOR DELETE
AS
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END
   DECLARE @b_Success  int,       -- Populated by calls to stored procedures - was the proc successful?
   @n_err              int,       -- Error number returned by stored procedure or this trigger
   @c_errmsg           NVARCHAR(250), -- Error message returned by stored procedure or this trigger
   @n_continue         int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing
   @n_starttcnt        int,       -- Holds the current transaction count
   @n_cnt              int        -- Holds the number of rows affected by the DELETE statement that fired this trigger.
  ,@c_authority        NVARCHAR(1)  -- KHLim02

   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
      
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
   IF (SELECT COUNT(*) from DELETED) = (select count(*) from DELETED where DELETED.ArchiveCop = '9')
   BEGIN
      SELECT @n_continue = 4
   END
   /* #INCLUDE <TRPHD1.SQL> */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      -- Added By SHONG 26-Jul-2002
      -- Check before update, Reduce Table Blocking
      IF EXISTS(SELECT 1 FROM PickDetail (NOLOCK), Deleted
      WHERE PickDetail.PickHeaderKey=Deleted.PickHeaderKey
      AND PickDetail.PickHeaderKey <> '' )
      BEGIN
         DELETE PickDetail
         FROM PickDetail, Deleted
         WHERE PickDetail.PickHeaderKey=Deleted.PickHeaderKey
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63200   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Trigger On PickHeader Failed. (ntrPickHeaderDelete)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
         END
      END
   END

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      -- SOS 6774
      -- Bug fixes for Performance Tuning
      -- Added By SHONG 26-Jul-2002
      -- Check before update, Reduce Table Blocking
      IF EXISTS(SELECT 1 FROM PickingInfo (NOLOCK), Deleted WHERE PickingInfo.PickSlipNo=Deleted.PickHeaderKey)
      BEGIN
         DELETE PickingInfo
         FROM PickingInfo, Deleted
         WHERE PickingInfo.PickSlipNo=Deleted.PickHeaderKey
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63200   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Trigger On PickHeader Failed. (ntrPickHeaderDelete)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
         END
      END
   END

   -- to re-initialize PickSlipNo no in pickdetail table
   -- WALLY 11.06.00
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      -- Added By SHONG 26-Jul-2002
      -- Check before update, Reduce Table Blocking
      IF EXISTS( SELECT 1 FROM PICKDETAIL (NOLOCK), DELETED WHERE PICKDETAIL.PickSlipNo = DELETED.PickHeaderKey)
      BEGIN
         UPDATE PICKDETAIL
            SET trafficcop = NULL, PickSlipNo = ''
         FROM PICKDETAIL, DELETED
         WHERE PICKDETAIL.PickSlipNo = DELETED.PickHeaderKey
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63200   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Trigger On PickHeader Failed. (ntrPickHeaderDelete)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
         END
      END
   END


   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE @cPickDetailkey NVARCHAR(10)

      -- Added By SHONG 26-Jul-2002
      -- Check before update, Reduce Table Blocking
      DECLARE C_DeleteRefKeyLkup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT PickDetailKey 
      FROM REFKEYLOOKUP (NOLOCK), DELETED
      WHERE REFKEYLOOKUP.PickSlipNo = DELETED.PickHeaderKey
      ORDER BY PickDetailKey
         
      OPEN C_DeleteRefKeyLkup 
      
      FETCH NEXT FROM C_DeleteRefKeyLkup INTO @cPickDetailkey 
      
      WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2)
      BEGIN

         DELETE REFKEYLOOKUP
         WHERE PickDetailKey = @cPickDetailkey 
         
         SELECT @n_err = @@ERROR 

         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 63200   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete Trigger On PickHeader Failed. (ntrPickHeaderDelete)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
         END
         
         FETCH NEXT FROM C_DeleteRefKeyLkup INTO @cPickDetailkey 
      END
   END

   -- Start (KHLim01) 
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 0         --    Start (KHLim02)
      EXECUTE nspGetRight  NULL,             -- facility  
                           NULL,             -- Storerkey  
                           NULL,             -- Sku  
                           'DataMartDELLOG', -- Configkey  
                           @b_success     OUTPUT, 
                           @c_authority   OUTPUT, 
                           @n_err         OUTPUT, 
                           @c_errmsg      OUTPUT  
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
               ,@c_errmsg = 'ntrPICKHEADERDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'         --    End   (KHLim02)
      BEGIN
         INSERT INTO dbo.PICKHEADER_DELLOG ( PickHeaderKey )
         SELECT PickHeaderKey FROM DELETED

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table PICKHEADER Failed. (ntrPICKHEADERDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END
   -- End (KHLim01) 

   
   /* #INCLUDE <TRPHD2.SQL> */
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrPickHeaderDelete'
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