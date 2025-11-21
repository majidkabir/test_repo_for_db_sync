SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_StorerStatusUpdate                             */
/* Creation Date: 13-Feb-2014                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 303057- Storer Status Update By SQL Job                     */
/*                                                                      */
/* Called By: SQL Job                                                   */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0	                                                */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp_StorerStatusUpdate]
(  
    @n_Inactive_days  INT = 90
)      
AS
BEGIN 
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF   
     
   DECLARE @n_continue INT,
           @n_starttcnt INT,
           @b_success INT,
           @n_err INT,
           @c_errmsg NVARCHAR(250)

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0 
   
   SELECT DISTINCT STORER.Storerkey
   INTO #TEMP_ACTIVESTORER
   FROM STORER (NOLOCK) 
   JOIN ITRN (NOLOCK) ON STORER.Storerkey = ITRN.Storerkey     
   WHERE DATEDIFF(Day, ITRN.Adddate, GetDate()) <= @n_inactive_days
   UNION
   SELECT Storerkey
   FROM SKUXLOC (NOLOCK) 
   GROUP BY Storerkey
   HAVING SUM(Qty) > 0
   UNION 
   SELECT DISTINCT STORER.Storerkey
   FROM STORER (NOLOCK) 
   JOIN ORDERS (NOLOCK) ON STORER.Storerkey = ORDERS.Storerkey     
   WHERE DATEDIFF(Day, ORDERS.Adddate, GetDate()) <= @n_inactive_days
   AND ORDERS.Status < '9'
   UNION
   SELECT DISTINCT STORER.Storerkey
   FROM STORER (NOLOCK) 
   JOIN RECEIPT (NOLOCK) ON STORER.Storerkey = RECEIPT.Storerkey 
   JOIN RECEIPTDETAIL (NOLOCK) ON RECEIPT.Receiptkey = RECEIPTDETAIL.Receiptkey     
   WHERE DATEDIFF(Day, RECEIPTDETAIL.Adddate, GetDate()) <= @n_inactive_days
   AND RECEIPT.Status < '9'
   
   BEGIN TRAN
   	
   UPDATE STORER WITH (ROWLOCK)
   SET STORER.Status = CASE WHEN ACTSTORER.Storerkey IS NULL THEN 'INACTIVE' ELSE 'ACTIVE' END,
       TrafficCop = NULL,
       EditDate = GetDate(),
       EditWho = CASE WHEN LEFT(LTRIM(Editwho),1)='_' THEN '' ELSE '_' END + LTRIM(RTRIM(EditWho))
   FROM STORER 
   LEFT JOIN #TEMP_ACTIVESTORER ACTSTORER ON STORER.Storerkey = ACTSTORER.Storerkey
   WHERE STORER.Type = '1'   
   AND ISNULL(STORER.Status,'') <> CASE WHEN ACTSTORER.Storerkey IS NULL THEN 'INACTIVE' ELSE 'ACTIVE' END
   
   SELECT @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
	    SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60113   
	    SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update STORER Table. (isp_StorerStatusUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
	 END
                        
   IF @n_continue=3  -- Error Occured - Process And Return
	 BEGIN
	    SELECT @b_success = 0
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
  	  execute nsp_logerror @n_err, @c_errmsg, 'isp_StorerStatusUpdate'
	    RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
	    RETURN
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
	   
END -- End PROC

GO