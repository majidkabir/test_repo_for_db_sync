SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/* 03-Dec-2018  GTGOH     1.4   Missing nolock                          */
CREATE PROC [dbo].[ispPnp_PurgeDummyCtn]
         @c_PickSlipNo	 NVARCHAR(20),
         @n_CartonNo       int, 
         @b_Success			int       OUTPUT,
         @n_err				int       OUTPUT,
         @c_errmsg		 NVARCHAR(255) OUTPUT
AS
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @n_count int /* next key */
DECLARE @n_ncnt int
DECLARE @n_starttcnt int /* Holds the current transaction count */
DECLARE @n_continue int /* Continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip furthur processing */
DECLARE @n_cnt int /* Variable to record if @@ROWCOUNT=0 after UPDATE */
SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''


BEGIN TRANSACTION 

IF NOT EXISTS(SELECT 1 FROM PICKHEADER (NOLOCK) WHERE PICKHEADERKEY = @c_PickSlipNo)
BEGIN
   SELECT @n_continue = 3 
   SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
   SELECT @c_errmsg='Invalid Pick Slip No. (ispPnp_PurgeDummyCtn)' 
END

IF @n_continue = 1 OR @n_continue = 2
BEGIN
-- tlting
   IF EXISTS(SELECT 1 FROM PackDetail (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo AND CartonNo = @n_CartonNo
             AND SKU = '')
   BEGIN
      DELETE FROM PackDetail 
      WHERE PickSlipNo = @c_PickSlipNo 
        AND CartonNo = @n_CartonNo
        AND SKU = ''
      IF @@ERROR <> 0 
      BEGIN
          SELECT @n_continue = 3 
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete PackDetail Failed. (ispPnp_PurgeDummyCtn)' 
      END
   END 
END -- IF @n_continue = 1 OR @n_continue = 2

IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
   SELECT @b_success = 0     
   IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt 
   BEGIN
       ROLLBACK TRAN
   END
   ELSE BEGIN
       WHILE @@TRANCOUNT > @n_starttcnt 
       BEGIN
           COMMIT TRAN
       END          
   END
   EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPnp_PurgeDummyCtn'
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
-- procedure

GO