SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_BTB_Shipment_ITF                                    */
/* Creation Date: 07-AUG-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-2613 - Logitech - Back to Back Declaration Transmission */
/*        : To Tradenet                                                 */
/* Called By: BTBShipment RCM                                           */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2020-06-16  Wan01    1.1   WMS-13409 - SG - Logitech - Back to Back  */
/*                            Declaration for Form DE                   */
/************************************************************************/
CREATE PROC [dbo].[isp_BTB_Shipment_ITF]
           @c_BTB_ShipmentKey    NVARCHAR(10)
         , @b_Success            INT            OUTPUT
         , @n_Err                INT            OUTPUT
         , @c_ErrMsg             NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt          INT
         , @n_Continue           INT 

         , @c_Storerkey          NVARCHAR(15)
         , @c_ITFConfigKey       NVARCHAR(30)
         , @c_BTB_Shipment_ITF   NVARCHAR(30)


   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_Storerkey = ''
   SELECT @c_Storerkey = Storerkey
   FROM BTB_SHIPMENT WITH (NOLOCK)
   WHERE BTB_ShipmentKey = @c_BTB_ShipmentKey

   IF @c_Storerkey = ''
   BEGIN
      GOTO QUIT_SP
   END

   SET @c_ITFConfigKey = 'BTBSHPRCM'
   SET @c_BTB_Shipment_ITF = ''
   EXECUTE dbo.nspGetRight  NULL
            ,  @c_StorerKey        -- Storer
            ,  ''                  -- Sku
            ,  @c_ITFConfigKey     -- ConfigKey
            ,  @b_success           OUTPUT
            ,  @c_BTB_Shipment_ITF  OUTPUT
            ,  @n_err               OUTPUT
            ,  @c_errmsg            OUTPUT

   IF @b_success <> 1
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 60010
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error executing nspGetRight. (isp_BTB_Shipment_ITF)'
      GOTO QUIT_SP
   END

   IF @c_BTB_Shipment_ITF = '1'
   BEGIN
      IF EXISTS ( SELECT 1 FROM TransmitLog3 (NOLOCK) WHERE TableName = @c_ITFConfigKey
                  AND Key1 = @c_BTB_ShipmentKey AND Key2 = '' AND Key3 = @c_StorerKey)
      BEGIN
         SET @c_ErrMsg = 'BTB ShipmentKey exists in Transmitlog3.'
         GOTO QUIT_SP
      END

      EXEC dbo.ispGenTransmitLog3 
              @c_TableName = @c_ITFConfigKey
            , @c_Key1 = @c_BTB_ShipmentKey
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
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Generating Transmitlog3 Interface record. (isp_BTB_Shipment_ITF)'
         GOTO QUIT_SP
      END

      --(Wan01) - START
      UPDATE BTB_SHIPMENT
         SET [Status] = '9'
         ,  EditWho = SUSER_SNAME()
         ,  EditDate= GETDATE()
         ,  Trafficcop = NULL
      WHERE BTB_ShipmentKey = @c_BTB_ShipmentKey

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 60035
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Update BTB_SHIPMENT Status. (isp_BTB_Shipment_ITF)'
         GOTO QUIT_SP
      END
      --(Wan01) - END
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

      --EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_BTB_Shipment_ITF'
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