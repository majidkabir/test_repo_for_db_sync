SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispPnP_ResetCarton                                 */
/* Creation Date: 30-Apr-2014                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 309234-Scan and Pack screen reset carton                    */
/*                                                                      */
/* Called By: w_scannpack                                               */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0	                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date       Author  Ver.  Purposes                                    */
/************************************************************************/

CREATE PROC [dbo].[ispPnP_ResetCarton]
         @c_PickSlipNo	 NVARCHAR(20),
			   @n_CartonNo		 INT,
         @b_Success			 INT OUTPUT,
         @n_err				   INT OUTPUT,
         @c_errmsg		   NVARCHAR(255) OUTPUT
AS
   
SET NOCOUNT ON 
SET QUOTED_IDENTIFIER OFF 
SET CONCAT_NULL_YIELDS_NULL OFF
   
DECLARE @n_starttcnt int /* Holds the current transaction count */
DECLARE @n_continue int /* Continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip furthur processing */
SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''

BEGIN TRANSACTION 

IF EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE Pickslipno = @c_PickSlipNo AND Status = '9')
BEGIN
   SELECT @n_continue = 3 
   SELECT @n_err = 62000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
   SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+ ': Pickslip# ' + RTRIM(@c_Pickslipno) + ' already pack confirmed. Not allow to reset carton. (ispPnP_ResetCarton)' 
END

IF @n_continue = 1 OR @n_continue = 2
BEGIN
	 DELETE FROM PACKDETAIL WITH (ROWLOCK)
	 WHERE Pickslipno = @c_PickslipNo
	 AND CartonNo = @n_CartonNo
	 
	 SELECT @n_Err = @@ERROR
	 
   IF @n_Err <> 0 
   BEGIN
   	   SELECT @n_continue = 3 
       SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=61900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete PACKDETAIL Failed. (ispPnP_ResetCarton)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
   END	 
END

EXIT_SP:

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
   EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPnP_ResetCarton'
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