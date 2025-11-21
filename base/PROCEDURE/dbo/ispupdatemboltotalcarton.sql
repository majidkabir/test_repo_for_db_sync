SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  ispUpdateMBOLTotalCarton                           */
/* Creation Date: 22-Feb-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: IDS                                                      */
/*                                                                      */
/* Purpose:  - Update MBOLDetail.TotalCartons when print VICSBOL report */
/*             in MBOL module                                           */
/*                                                                      */
/* Input Parameters:  @c_MBOLKey       - MBOLKey                        */
/*                                                                      */
/* Output Parameters: @b_Success       - Success Flag  = 0              */
/*                    @n_Err           - Error Code    = 0              */
/*                    @c_ErrMsg        - Error Message = ''             */
/*                                                                      */
/*                                                                      */
/* Called By: ue_print_vics_bol                                         */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver  Purposes                                   */
/* 22-Feb-2012  Leong   1.0  SOS# 237180 - Created.                     */
/************************************************************************/

CREATE PROC [dbo].[ispUpdateMBOLTotalCarton] (
     @c_MBOLKey NVARCHAR(10)
   , @b_Success Int       = 1  OUTPUT
   , @n_Err     Int       = 0  OUTPUT
   , @c_ErrMsg  NVARCHAR(250) = '' OUTPUT
   )
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_ConfigKey      NVARCHAR(30)
         , @c_Authority      NVARCHAR(10)
         , @c_OrderKey       NVARCHAR(10)
         , @c_ConsoOrderKey  NVARCHAR(30)
         , @c_ExecStatements NVarChar(Max)
         , @c_PickSlipNo     NVARCHAR(10)
         , @c_TotalCartons   Int
         , @c_Cartons        Int
         , @n_Continue       Int
         , @n_StartTCnt      Int
         , @b_debug          Int

   SET @c_ConfigKey = 'GenUCCLabelNoConfig'
   SET @c_Authority = '0'
   SET @b_debug = 1

   SELECT @n_StartTCnt = @@TRANCOUNT, @n_Continue = 1, @n_Err = 0, @c_ErrMsg = '', @b_Success = 0

   SELECT TOP 1 @c_Authority = ISNULL(RTRIM(SValue),'')
   FROM   ORDERS O WITH (NOLOCK)
   JOIN   STORERCONFIG SC WITH (NOLOCK) ON (O.StorerKey = SC.StorerKey)
   WHERE  O.MBOLKey = @c_MBOLKey
   AND    SC.ConfigKey = @c_ConfigKey

   IF @c_Authority = '1'
   BEGIN
      DECLARE CUR_MBOL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT OrderKey
         FROM   MBOLDetail WITH (NOLOCK)
         WHERE  MBOLKey = @c_MBOLKey
         ORDER BY OrderKey

      OPEN CUR_MBOL
      FETCH NEXT FROM CUR_MBOL INTO @c_OrderKey
      WHILE @@FETCH_STATUS <> -1
      BEGIN

         SET @c_ConsoOrderKey = ''
         SELECT TOP 1 @c_ConsoOrderKey = ISNULL(RTRIM(ConsoOrderKey),'')
         FROM OrderDetail WITH (NOLOCK)
         WHERE OrderKey = @c_OrderKey

         SET @c_ExecStatements = ''
         SET @c_ExecStatements = 'DECLARE Cur_PackDetail CURSOR FAST_FORWARD READ_ONLY FOR '
                               + 'SELECT PickslipNo FROM PackHeader WITH (NOLOCK) '

         IF ISNULL(RTRIM(@c_ConsoOrderKey),'') = ''
         BEGIN
            SET @c_ExecStatements = @c_ExecStatements
                                  + 'WHERE Orderkey = N''' + ISNULL(RTRIM(@c_OrderKey),'') + ''' '
         END
         ELSE
         BEGIN
            SET @c_ExecStatements = @c_ExecStatements
                                  + 'WHERE ConsoOrderKey = N''' + ISNULL(RTRIM(@c_ConsoOrderKey),'') + ''' '
         END

         IF @b_debug = 1
         BEGIN
            SELECT @c_OrderKey '@c_OrderKey', @c_ConsoOrderKey '@c_ConsoOrderKey'
                 , @c_ExecStatements '@c_ExecStatements'
         END

         SET @c_TotalCartons = 0
         ------------------------------------------------------------------------------
         EXEC sp_ExecuteSql @c_ExecStatements

         OPEN Cur_PackDetail
         FETCH NEXT FROM Cur_PackDetail INTO @c_PickSlipNo
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SELECT @c_Cartons = 0
            SELECT @c_Cartons = COUNT(DISTINCT PD.LabelNo)
            FROM PackHeader PH WITH (NOLOCK)
            JOIN PackDetail PD WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
            WHERE PH.PickSlipNo = ISNULL(RTRIM(@c_PickSlipNo),'')

            SELECT @c_TotalCartons = @c_TotalCartons + @c_Cartons

            FETCH NEXT FROM Cur_PackDetail INTO @c_PickSlipNo
         END
         CLOSE Cur_PackDetail
         DEALLOCATE Cur_PackDetail
         ------------------------------------------------------------------------------
         IF @b_debug = 1
         BEGIN
            SELECT @c_OrderKey '@c_OrderKey', @c_TotalCartons '@c_TotalCartons'
         END

         -- BEGIN TRAN
         -- UPDATE MBOLDETAIL WITH (ROWLOCK)
         -- SET TotalCartons = @c_TotalCartons
         --   , TrafficCop = NULL
         -- WHERE Orderkey = @c_OrderKey
         -- AND MBOLKey = @c_MBOLKey
         --
         -- IF @@ERROR = 0
         -- BEGIN
         --    WHILE @@TRANCOUNT > 0
         --       COMMIT TRAN
         -- END
         -- ELSE
         -- BEGIN
         --    ROLLBACK TRAN
         --    SET @n_Continue = 3
         --    SET @n_Err = 89900
         --    SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0)) +
         --                    ': Update MBOLDetail failed. (ispUpdateMBOLTotalCarton)'
         --    GOTO QUIT
         -- END

         FETCH NEXT FROM CUR_MBOL INTO @c_OrderKey
      END
      CLOSE CUR_MBOL
      DEALLOCATE CUR_MBOL
   END -- IF @c_Authority = '1'

   QUIT:
   IF CURSOR_STATUS('GLOBAL', 'Cur_PackDetail') IN (0, 1)
   BEGIN
      CLOSE Cur_PackDetail
      DEALLOCATE Cur_PackDetail
   END

   IF CURSOR_STATUS('GLOBAL', 'CUR_MBOL') IN (0, 1)
   BEGIN
      CLOSE CUR_MBOL
      DEALLOCATE CUR_MBOL
   END

   IF @n_Continue = 3  -- Error Occured
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispUpdateMBOLTotalCarton'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END -- End Procedure

GO