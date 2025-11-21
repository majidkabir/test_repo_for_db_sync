SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_ORDRCM_ITF_541                                      */
/* Creation Date: 15-AUG-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-2662 - MHAP RCM to trigger Interface                    */
/*        :                                                             */
/* Called By: Custom RCM Menu                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_ORDRCM_ITF_541]
           @c_Orderkey  NVARCHAR(10)
         , @b_Success   INT            OUTPUT
         , @n_Err       INT            OUTPUT
         , @c_ErrMsg    NVARCHAR(255)  OUTPUT
         , @c_Code      NVARCHAR(30)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_Storerkey       NVARCHAR(15)
         , @c_OrderType       NVARCHAR(10)

         , @c_ITFConfigKey    NVARCHAR(30)
         , @c_Orders_ITF      NVARCHAR(30)


   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_Storerkey = ''
   SET @c_OrderType = ''
   SELECT @c_Storerkey = Storerkey
      ,  @c_OrderType = Type
   FROM ORDERS WITH (NOLOCK)
   WHERE Orderkey = @c_OrderKey

   IF @c_Storerkey = ''
   BEGIN
      GOTO QUIT_SP
   END

   IF @c_OrderType <> 'MH541'
   BEGIN
      GOTO QUIT_SP
   END

   SET @c_ITFConfigKey = 'MHAPALLOCLOG'
   SET @c_Orders_ITF = ''

   EXECUTE dbo.nspGetRight  NULL
            ,  @c_StorerKey        -- Storer
            ,  ''                  -- Sku
            ,  @c_ITFConfigKey     -- ConfigKey
            ,  @b_success           OUTPUT
            ,  @c_Orders_ITF        OUTPUT
            ,  @n_err               OUTPUT
            ,  @c_errmsg            OUTPUT

   IF @b_success <> 1
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 60010
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error executing nspGetRight. (isp_ORDRCM_ITF_541)'
      GOTO QUIT_SP
   END

   IF @c_Orders_ITF = '1'
   BEGIN
      IF EXISTS ( SELECT 1 FROM TransmitLog3 (NOLOCK) WHERE TableName = @c_ITFConfigKey
                  AND Key1 = @c_OrderKey AND Key2 = '' AND Key3 = @c_StorerKey)
      BEGIN
         SET @c_ErrMsg = 'OrderKey exists in Transmitlog3.'
         GOTO QUIT_SP
      END

      EXEC dbo.ispGenTransmitLog3 
              @c_TableName = @c_ITFConfigKey
            , @c_Key1 = @c_OrderKey
            , @c_Key2 = ''
            , @c_Key3 = @c_StorerKey
            , @c_TransmitBatch = ''
            , @b_success = @b_success   OUTPUT
            , @n_err     = @n_err       OUTPUT
            , @c_errmsg  = @c_errmsg    OUTPUT

      IF @b_success <> 1
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 60030
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Generating Transmitlog3 Interface record. (isp_ORDRCM_ITF_541)'
         GOTO QUIT_SP
      END
      SET @c_errmsg = 'Orders inserted to trasmitlog3'
   END

QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      --EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ORDRCM_ITF_541'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO