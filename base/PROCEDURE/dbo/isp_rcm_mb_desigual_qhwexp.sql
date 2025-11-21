SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RCM_MB_DESIGUAL_QHWExp                         */
/* Creation Date: 06-JUL-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-23009 - CN Desigual - QHW Exp interface                 */
/*                                                                      */
/* Called By: MBOL Dymaic RCM configure at listname 'RCMConfig'         */
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE   PROCEDURE [dbo].[isp_RCM_MB_DESIGUAL_QHWExp]
   @c_Mbolkey NVARCHAR(10),
   @b_success  int OUTPUT,
   @n_err      int OUTPUT,
   @c_errmsg   NVARCHAR(225) OUTPUT,
   @c_code     NVARCHAR(30)=''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,
           @n_cnt int,
           @n_starttcnt int

   DECLARE @c_Facility NVARCHAR(5),
           @c_storerkey NVARCHAR(15),
           @c_Status NVARCHAR(10)

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt=@@TRANCOUNT, @c_errmsg='', @n_err=0
     
   SELECT TOP 1 @c_Storerkey = ORD.Storerkey,
                @c_Status = M.Status
   FROM MBOL M (NOLOCK)
   JOIN MBOLDETAIL MD (NOLOCK) ON M.Mbolkey = MD.Mbolkey
   JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey=MD.Orderkey
   WHERE M.Mbolkey = @c_Mbolkey
   
   IF @c_Status = '9'
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 60090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': MBOL has been shipped. Re-Send EXP interface Is Not Allowed. (isp_RCM_MB_DESIGUAL_QHWExp)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
      GOTO ENDPROC
   END
   
   IF EXISTS (SELECT 1 FROM TransmitLog3 (NOLOCK) WHERE TableName = 'PICKCFM2LG'
                      AND Key1 = @c_Mbolkey AND Key2 = '' AND Key3 = @c_Storerkey)
   BEGIN
   	  UPDATE TRANSMITLOG3 WITH (ROWLOCK)
   	  SET transmitflag = '0'
   	  WHERE TableName = 'PICKCFM2LG'
      AND Key1 = @c_Mbolkey 
      AND Key2 = '' 
      AND Key3 = @c_Storerkey
   END                   
   ELSE
   BEGIN                      
      EXEC dbo.ispGenTransmitLog3 'PICKCFM2LG', @c_Mbolkey, '', @c_StorerKey, ''
           , @b_success OUTPUT
           , @n_err OUTPUT
           , @c_errmsg OUTPUT
      
      IF @b_success = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 60091   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate transmintlog3 failed. (isp_RCM_MB_DESIGUAL_QHWExp)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_ErrMsg), '') + ' ) '
      END
   END

ENDPROC:

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
     execute nsp_logerror @n_err, @c_errmsg, 'isp_RCM_MB_DESIGUAL_QHWExp'
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