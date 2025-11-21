SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_UpdateInvoiceNo                                */  
/* Creation Date: 21-Sep-2020                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-15201 - Update Orders.InvoiceNo and UploadInvData table */  
/*                                                                      */  
/* Called By: PB                                                        */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 2021-04-21   WLChooi  1.1  Enhance ErrorMSG to show InvoiceNo (WL01) */
/************************************************************************/   

CREATE PROCEDURE [dbo].[isp_UpdateInvoiceNo]
   @c_Orderkey       NVARCHAR(10),
   @c_StorerKey      NVARCHAR(15),  
   @c_InvoiceNo      NVARCHAR(10),
   @n_PrintStatus    INT = 1,
   @b_Success        INT                OUTPUT,  
   @n_err            INT                OUTPUT,  
   @c_errmsg         NVARCHAR(255)      OUTPUT     
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue        INT = 1,
           @n_StartTCnt       INT,
           @c_ExternOrderkey  NVARCHAR(50)
   
   SELECT @n_StartTCnt = @@TRANCOUNT
   
   --SELECT @c_ExternOrderkey = Externorderkey
   --FROM ORDERS (NOLOCK)
   --WHERE OrderKey = @c_Orderkey
   
   BEGIN TRAN
   
   --@n_PrintStatus = 1  -> Print Success
   --@n_PrintStatus = -1 -> Print Failed
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @n_PrintStatus = 1
      BEGIN
         IF EXISTS (SELECT 1 FROM UploadInvData (NOLOCK) WHERE Invoice_Number = @c_InvoiceNo AND Storerkey = @c_StorerKey)
         BEGIN 
   	      SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 77000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invoice # ' + LTRIM(RTRIM(@c_InvoiceNo)) + ' already exists. (isp_UpdateInvoiceNo)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '   --WL01
            GOTO QUIT_SP 
         END
         ELSE
         BEGIN
   	      INSERT INTO UploadInvData (Storerkey, ExternOrderkey, Invoice_Number, Invoice_Date, Invoice_Amount, [Status], Remarks)
   	      SELECT OH.Storerkey, ISNULL(OH.ExternOrderkey,''), @c_InvoiceNo, GETDATE(), 0.00, '9', ''
   	      FROM ORDERS OH (NOLOCK)
   	      WHERE OH.OrderKey = @c_Orderkey
   	   
   	      IF @@ERROR <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 77005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT INTO UploadInvData Failed. (isp_UpdateInvoiceNo)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               GOTO QUIT_SP 
            END
         
            UPDATE ORDERS WITH (ROWLOCK)
            SET InvoiceNo = @c_InvoiceNo
   	      WHERE OrderKey = @c_Orderkey
   	   
   	      IF @@ERROR <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 77010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT INTO UploadInvData Failed. (isp_UpdateInvoiceNo)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               GOTO QUIT_SP 
            END
         END
      END
      ELSE IF @n_PrintStatus = -1
      BEGIN
         --IF NOT EXISTS (SELECT 1 FROM UploadInvData (NOLOCK) WHERE Storerkey = @c_StorerKey AND Externorderkey = @c_ExternOrderkey)
         --BEGIN
         INSERT INTO UploadInvData (Storerkey, ExternOrderkey, Invoice_Number, Invoice_Date, Invoice_Amount, [Status], Remarks)
         SELECT OH.Storerkey, ISNULL(OH.ExternOrderkey,''), @c_InvoiceNo, GETDATE(), 0.00, 'X', ''
         FROM ORDERS OH (NOLOCK)
         WHERE OH.OrderKey = @c_Orderkey
         
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 77015   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': INSERT INTO UploadInvData Failed. (isp_UpdateInvoiceNo)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
            GOTO QUIT_SP 
         END
         --END
      END
   END
   /*
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
   	UPDATE ORDERS WITH (ROWLOCK)
   	SET PrintFlag = 'Y'
   	WHERE OrderKey = @c_Orderkey
   	
   	IF @@ERROR <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 77020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Orders Failed. (isp_UpdateInvoiceNo)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         GOTO QUIT_SP 
      END
   END*/
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_UpdateInvoiceNo'
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