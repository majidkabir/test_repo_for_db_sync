SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store Procedure:  ntrRFPutawayUpdate                                       */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Modification log:                                                          */
/* Date         Author     Ver   Purposes                                     */
/* 24-Mar-2022  YeeKung    1.0   Created                                      */
/* 03-Mar-2023  Ung        1.1   Add RFPutaway_EDITLOG for troubleshoot       */
/******************************************************************************/

CREATE   TRIGGER [dbo].[ntrRFPutawayUpdate]
ON  [dbo].[RFPUTAWAY]
FOR UPDATE
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   SELECT @b_debug = 0

   DECLARE
      @b_Success            int           -- Populated by calls to stored procedures - was the proc successful?
     ,@n_err                int           -- Error number returned by stored procedure or this trigger
     ,@n_err2               int           -- For Additional Error Detection
     ,@c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
     ,@n_continue           int
     ,@n_starttcnt          int           -- Holds the current transaction count
     ,@c_preprocess         NVARCHAR(250) -- preprocess
     ,@c_pstprocess         NVARCHAR(250) -- post process
     ,@profiler             NVARCHAR(80)

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   IF @n_continue = 1 OR @n_continue=2
   BEGIN
      UPDATE RFPUTAWAY WITH (ROWLOCK) 
      SET   EditDate = GETDATE(), 
            EditWho=SUSER_SNAME()                          
      FROM RFPUTAWAY  
      JOIN INSERTED ON INSERTED.rowref = RFPUTAWAY.rowref  

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 61620
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On RFPUTAWAY. (ntrPickDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
         ROLLBACK TRAN 
      END
   END
   
   INSERT INTO RFPutaway_EDITLOG 
      (StorerKey, SKU, LOT, FromLOC, SuggestedLOC, ID, ptcid, QTY, AddDate, AddWho, TrafficCop, ArchiveCop, 
      CaseID, FromID, RowRef, TaskDetailKey, Func, PABookingKey, QTYPrinted, EditDate, EditWho,
      Receiptkey, ReceiptLineNumber, UDF01, UDF02, UDF03)
   SELECT 
      StorerKey, SKU, LOT, FromLOC, SuggestedLOC, ID, ptcid, QTY, AddDate, AddWho, TrafficCop, ArchiveCop, 
      CaseID, FromID, RowRef, TaskDetailKey, Func, PABookingKey, QTYPrinted, EditDate, EditWho,
      Receiptkey, ReceiptLineNumber, UDF01, UDF02, UDF03
   FROM DELETED
   
   GOTO QUIT

QUIT:
   WHILE @@TRANCOUNT > @n_starttcnt  
   BEGIN  
      COMMIT TRAN  
   END  

END


GO