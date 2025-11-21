SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispPMCU01                                          */  
/* Creation Date: 08-Sep-2020                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-14786 - PMI Insert into SerialNo table                  */  
/*                                                                      */  
/* Called By: isp_PackWithMultiCodeUpdate_Wrapper                       */  
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

CREATE PROCEDURE [dbo].[ispPMCU01]
   @c_PickSlipNo     NVARCHAR(10),  
   @n_CartonNo       INT,  
   @c_SKU            NVARCHAR(20),  
   @n_Qty            INT,  
   @c_Code01         NVARCHAR(60) = '',   --SerialNo
   @c_Code02         NVARCHAR(60) = '',
   @c_Code03         NVARCHAR(60) = '',
   @b_Success        INT           OUTPUT,  
   @n_err            INT           OUTPUT,  
   @c_errmsg         NVARCHAR(255) OUTPUT  
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @c_Orderkey      NVARCHAR(10) = '',
           @c_Storerkey     NVARCHAR(15) = '',
           @n_Continue      INT          = 1,
           @c_SerialNoKey   NVARCHAR(10)
   
   SELECT @c_Orderkey  = OrderKey,
          @c_Storerkey = StorerKey
   FROM PACKHEADER (NOLOCK)
   WHERE PickSlipNo = @c_PickSlipNo
   
   EXECUTE nspg_getkey
         'SERIALNO'
         , 10
         , @c_SerialNoKey OUTPUT
         , @b_success     OUTPUT
         , @n_err         OUTPUT
         , @c_errmsg      OUTPUT
         
   IF NOT @b_success = 1
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 72100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain SerialNoKey. (ispPMCU01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      GOTO QUIT_SP  
   END
   
   INSERT INTO SerialNo (SerialNoKey, SerialNo, Orderkey, OrderLineNumber, StorerKey, SKU, Qty)
   SELECT @c_SerialNoKey, @c_Code01, @c_Orderkey, @n_CartonNo, @c_Storerkey, @c_SKU, @n_Qty
   
   SELECT @n_err = @@ERROR
   
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 72105   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Inserting Record into SerialNo Table. (ispPMCU01)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      GOTO QUIT_SP  
   END
   
QUIT_SP:
END -- End Procedure

GO