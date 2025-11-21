SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispRVPSDS01                                        */  
/* Creation Date: 21-Sep-2020                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-15201 - Reverse update ncounter                         */  
/*                                                                      */  
/* Called By: isp_ReversePrintShipmentDocs_Wrapper                      */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/   

CREATE PROCEDURE [dbo].[ispRVPSDS01]
   @c_Orderkey       NVARCHAR(10),
   @c_StorerKey      NVARCHAR(15),  
   @n_RecCnt         INT,
   @c_Printer        NVARCHAR(100)      OUTPUT,
   @c_DataWindow     NVARCHAR(100)      OUTPUT,
   @c_UsrDef01       NVARCHAR(500) = '' OUTPUT,
   @c_UsrDef02       NVARCHAR(500) = '' OUTPUT,
   @c_UsrDef03       NVARCHAR(500) = '' OUTPUT,
   @c_UsrDef04       NVARCHAR(500) = '' OUTPUT,
   @c_UsrDef05       NVARCHAR(500) = '' OUTPUT,
   @b_Success        INT                OUTPUT,  
   @n_err            INT                OUTPUT,  
   @c_errmsg         NVARCHAR(255)      OUTPUT     
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue      INT = 1,
           @n_StartTCnt     INT,
           @n_PrevCount     INT
   
   SELECT @n_StartTCnt = @@TRANCOUNT
   
   INSERT INTO TraceInfo
   (
      TraceName,
   	TimeIn,
   	[TimeOut],
   	Step1,
   	Step2,
   	Step3,
   	Col1,
   	Col2,
   	Col3
   )
   VALUES
   (
   	'ispRVPSDS01',
   	GETDATE(),
   	GETDATE(),
   	'Orderkey',
   	'UsrDef01',
   	'UsrDef02',
   	@c_Orderkey,
   	@c_UsrDef01,
      @c_UsrDef02
   )
   
   SET @n_PrevCount = CAST(@c_UsrDef02 AS INT)
   
   BEGIN TRAN
   
   UPDATE NCOUNTER WITH (ROWLOCK)
   SET keycount = @n_PrevCount
   WHERE KeyName = 'NCCI_InvoiceNo'
   
   IF @@ERROR <> 0
   BEGIN
   	SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 76005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Fail to Update NCOUNTER. (ispRVPSDS01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      GOTO QUIT_SP 
   END

   --UPDATE ORDERS WITH (ROWLOCK)
   --SET PrintFlag = ''
   --WHERE OrderKey = @c_Orderkey

   --IF @@ERROR <> 0
   --BEGIN
   --   SELECT @n_continue = 3
   --   SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 76006   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
   --   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Orders Table Failed . (ispRVPSDS01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
   --   GOTO QUIT_SP  
   --END
   
   --UPDATE PACKHEADER WITH (ROWLOCK)
   --SET ManifestPrinted = 'N'
   --WHERE OrderKey = @c_Orderkey

   --IF @@ERROR <> 0
   --BEGIN
   --   SELECT @n_continue = 3
   --   SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 76007   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
   --   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Packheader Table Failed . (ispRVPSDS01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
   --   GOTO QUIT_SP  
   --END
   
QUIT_SP:
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      execute nsp_logerror @n_err, @c_errmsg, 'ispRVPSDS01'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END 
   
END -- End Procedure

GO