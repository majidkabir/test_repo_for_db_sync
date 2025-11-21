SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*********************************************************************************/  
/* Store Procedure:  ntrrdtPreReceiveSortDelete                                  */  
/* Copyright: LF Logistics                                                       */  
/*                                                                               */  
/* Modification log:                                                             */  
/* Date         Author     Ver   Purposes                                        */  
/* 26-08-2020   kocy       1.0    https://jiralfl.atlassian.net/browse/WMS-14833 */
/*********************************************************************************/ 

CREATE     TRIGGER [RDT].[ntrrdtPreReceiveSortDelete]  
ON  [RDT].[rdtPreReceiveSort]  
FOR DELETE  
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
     ,@n_cnt                INT
     ,@c_authority          NVARCHAR(1)
  
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT  
  
   IF (SELECT COUNT(*) FROM DELETED) = (SELECT COUNT(*) FROM DELETED WHERE DELETED.ArchiveCop = '9')  
   BEGIN  
    SELECT @n_continue = 4  
   END  
      
   IF @n_continue = 1 OR @n_continue=2    
   BEGIN  
      SELECT @b_success = 0         --    Start
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
               ,@c_errmsg = 'ntrrdtPreReceiveSortDelete' + RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'       
      BEGIN
         INSERT INTO RDT.rdtPreReceiveSort_DELLOG ( [RowRefSource], [Mobile], [Func], [Facility], [StorerKey], [ReceiptKey], [UCCNo], [SKU], [Qty], [Loc],
         [ID], [Status], [Position],[Lottable01], [Lottable02], [Lottable03], [Lottable04], [Lottable05], [Lottable06], [Lottable07], [Lottable08], [Lottable09],
         [Lottable10], [Lottable11], [Lottable12], [Lottable13], [Lottable14], [Lottable15], [SourceType], [UDF01], [UDF02], [UDF03], [UDF04], [UDF05], [ArchiveCop] )
         SELECT RowRef, [Mobile], [Func], [Facility], [StorerKey], [ReceiptKey], [UCCNo], [SKU], [Qty], [Loc],
         [ID], [Status], [Position],[Lottable01], [Lottable02], [Lottable03], [Lottable04], [Lottable05], [Lottable06], [Lottable07], [Lottable08], [Lottable09],
         [Lottable10], [Lottable11], [Lottable12], [Lottable13], [Lottable14], [Lottable15], [SourceType], [UDF01], [UDF02], [UDF03], [UDF04], [UDF05], [ArchiveCop]
         FROM DELETED

         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table rdtPreReceiveSort Failed. (ntrrdtPreReceiveSortDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END                  
      END
   END  
  
QUIT:  
     /* #INCLUDE <TRCOND2.SQL> */
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrrdtPreReceiveSortDelete'
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