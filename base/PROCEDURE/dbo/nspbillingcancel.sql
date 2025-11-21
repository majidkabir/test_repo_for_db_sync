SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspBillingCancel                                   */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: PowerBuider Bill Screen (Cancel Billing)                  */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 15-Jul-2010  KHLim     Replace SUSER_NAME to sUSER_sName              */ 
/************************************************************************/

CREATE PROC  [dbo].[nspBillingCancel] 
                @b_Success      int        OUTPUT
 ,              @n_err          int        OUTPUT
 ,              @c_errmsg       NVARCHAR(250)  OUTPUT
AS
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @b_debug     int, 
        @n_cnt       int, 
        @n_continue  int, 
        @n_starttcnt int 

SELECT  @b_debug = 0
SELECT  @n_starttcnt = @@TRANCOUNT 

BEGIN TRAN

DECLARE @t_LockWho TABLE (LockWho NVARCHAR(18))

INSERT INTO @t_LockWho (LockWho)
SELECT DISTINCT LockWho FROM StorerBilling WITH (NOLOCK) 
WHERE LockWho > '' OR LockWho IS NOT NULL
SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
IF @n_err <> 0
BEGIN
   SELECT @n_continue = 3
   SELECT @n_err = 61912 --61301   
   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert @t_LockWho Failed. (nspBillingCancel) ' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_RTrim(@c_errmsg), '') + ' ) '
   GOTO QUIT 
END                         

DELETE BILL_ACCUMULATEDCHARGES 
FROM BILL_ACCUMULATEDCHARGES 
LEFT OUTER JOIN @t_LockWho as LockStorer 
     ON LockStorer.LockWho = BILL_ACCUMULATEDCHARGES.AddWho 
Where BILL_ACCUMULATEDCHARGES.AddWho = sUser_sName() 
AND   LockStorer.LockWho IS NULL 
SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
IF @n_err <> 0
BEGIN
   SELECT @n_continue = 3
   SELECT @n_err = 61912 --61301   
   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': DELETE BILL_ACCUMULATEDCHARGES Failed. (nspBillingCancel) ' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_RTrim(@c_errmsg), '') + ' ) '
   GOTO QUIT 
END  

DELETE BILL_StockMovement 
FROM BILL_StockMovement 
LEFT OUTER JOIN @t_LockWho as LockStorer 
     ON LockStorer.LockWho = BILL_StockMovement.AddWho 
Where BILL_StockMovement.AddWho = sUser_sName() 
AND   LockStorer.LockWho IS NULL 
SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT 
IF @n_err <> 0
BEGIN
   SELECT @n_continue = 3
   SELECT @n_err = 61912 --61301   
   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': DELETE BILL_StockMovement Failed. (nspBillingCancel) ' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_RTrim(@c_errmsg), '') + ' ) '
   GOTO QUIT 
END  

DELETE BILLING_Summary_Cut 
FROM BILLING_Summary_Cut 
LEFT OUTER JOIN @t_LockWho as LockStorer 
     ON LockStorer.LockWho = BILLING_Summary_Cut.AddWho 
Where BILLING_Summary_Cut.AddWho = sUser_sName() 
AND   LockStorer.LockWho IS NULL 
SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
IF @n_err <> 0
BEGIN
   SELECT @n_continue = 3
   SELECT @n_err = 61912 --61301   
   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': DELETE BILLING_Summary_Cut Failed. (nspBillingCancel) ' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_RTrim(@c_errmsg), '') + ' ) '
   GOTO QUIT 
END  

DELETE ACCUMULATEDCHARGES
FROM ACCUMULATEDCHARGES 
WHERE ACCUMULATEDCHARGES.Status = '5' 
 AND (ChargeType IN ('RS','MI','MR','MO','MH','DI','DO','MT') OR LineType = 'T' OR LineType = 'TA' )
 AND (EditWho = sUser_sName() OR EditWho not in (select LockWho from @t_LockWho))
SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
IF @n_err <> 0
BEGIN
   SELECT @n_continue = 3
   SELECT @n_err = 61912 --61301   
   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': DELETE ACCUMULATEDCHARGES Failed. (nspBillingCancel) ' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_RTrim(@c_errmsg), '') + ' ) '
   GOTO QUIT 
END 

UPDATE ACCUMULATEDCHARGES
SET Status = '0', InvoiceKey = '', InvoiceDate = Null
WHERE Status = '5' and ( EditWho = sUser_sName() OR 
                         EditWho is NULL OR 
                         EditWho not in (select LockWho from @t_LockWho) ) 

UPDATE STORERBILLING SET LockBatch = ' ', LockWho = ' ' 
WHERE LockWho = sUser_sName()
SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
IF @n_err <> 0
BEGIN
   SELECT @n_continue = 3
   SELECT @n_err = 61912 --61301   
   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE ACCUMULATEDCHARGES Failed. (nspBillingCancel) ' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(dbo.fnc_RTrim(@c_errmsg), '') + ' ) '
   GOTO QUIT 
END 

QUIT:

IF @n_continue = 3  -- Error Occured - Process And Return
BEGIN
   ROLLBACK TRAN 
   EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspBillingCancel'
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   RETURN
END         
ELSE
BEGIN
   SELECT @b_success = 1
   WHILE @@TRANCOUNT > @n_starttcnt
      COMMIT TRAN 

   RETURN
END         

GO