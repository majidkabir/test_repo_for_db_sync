SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_TP_GenLabelNo_Wrapper                          */
/*                                                                      */
/* Purpose: SOS#255883 - Custom label no                                */
/*          Storerconfig GenLabelNo_SP={isp_GLBLxx} to call customize SP*/
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Ver   Purposes                               */
/* 10-04-2020  CHERMAINE   1.1   dulicate isp_GenLabelNo_Wrapper        */
/************************************************************************/
CREATE   PROCEDURE [API].[isp_TP_GenLabelNo_Wrapper]
      @c_PickSlipNo     NVARCHAR(10)
   ,  @n_CartonNo       INT
   ,  @c_LabelNo        NVARCHAR(20) OUTPUT
   ,  @c_DropID         NVARCHAR(20) = '' --NJOW01
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue     INT
         , @b_Success      INT
         , @n_Err          INT
         , @c_ErrMsg       NVARCHAR(255)
         , @c_SPCode       NVARCHAR(50)
         , @c_StorerKey    NVARCHAR(15)
         , @c_SQL          NVARCHAR(MAX)

         , @c_SQLParms        NVARCHAR(MAX)
         , @c_CTNTrackNo      NVARCHAR(40)
         , @c_authority       NVARCHAR(30)
         , @c_CTNTrackNo_SP   NVARCHAR(30)

         , @c_OrderKey        NVARCHAR(10) = ''
         , @c_LoadKey         NVARCHAR(10) = ''

   SET @n_err        = 0
   SET @b_Success    = 1
   SET @c_errmsg     = ''

   SET @n_Continue   = 1
   SET @c_SPCode     = ''
   SET @c_StorerKey  = ''
   SET @c_SQL        = ''

   SET @c_OrderKey = '' -- SWT01
   SET @c_LoadKey  = '' -- SWT01

   -- SWT01
   SELECT @c_OrderKey = PH.OrderKey,
          @c_LoadKey  = PH.ExternOrderKey
   FROM PICKHEADER PH WITH (NOLOCK)
   WHERE PH.PickHeaderKey = @c_PickSlipNo

   -- SWT01
   SELECT @c_StorerKey = ISNULL(RTRIM(OH.Storerkey),'')
   FROM ORDERS OH WITH (NOLOCK)
   WHERE OH.Orderkey = @c_OrderKey

   IF RTRIM(@c_StorerKey) = ''
   BEGIN
   	-- SWT01
      SELECT TOP 1
            @c_StorerKey = ISNULL(RTRIM(OH.Storerkey),'')
      FROM LoadPlanDetail AS LPD WITH(NOLOCK)
      JOIN ORDERS OH WITH (NOLOCK) ON (LPD.Orderkey = OH.Orderkey)
      WHERE LPD.LoadKey = @c_LoadKey
   END

    --(Wan01) - START
   IF ISNULL(@c_StorerKey,'') = ''
   BEGIN
      SELECT TOP 1 @c_StorerKey = PACKHEADER.Storerkey
      FROM PACKHEADER (NOLOCK)
      WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo
   END
   --(Wan01) - END

   SELECT @c_SPCode = sVALUE
   FROM   StorerConfig WITH (NOLOCK)
   WHERE  StorerKey = @c_StorerKey
   AND    ConfigKey = 'GenLabelNo_SP'

   IF ISNULL(RTRIM(@c_SPCode),'') = ''
   BEGIN
      GOTO QUIT_SP
   END

   --(Wan02) - START
   IF @c_SPCode = 'EPACKCTNTrackNo_SP'
   BEGIN
      SET @c_authority = ''
      EXEC nspGetRight
            @c_Facility  = ''
         ,  @c_StorerKey = @c_StorerKey
         ,  @c_sku       = NULL
         ,  @c_ConfigKey = 'EPACKCTNTrackNo_SP'
         ,  @b_Success   = @b_Success    OUTPUT
         ,  @c_authority = @c_authority  OUTPUT
         ,  @n_err       = @n_err        OUTPUT
         ,  @c_errmsg    = @c_errmsg     OUTPUT

      IF @b_Success = 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 102200
         SET @c_errmsg='Execution Error : NSQL'+CONVERT(char(5),@n_err)+': Error Executing ' + @c_CTNTrackNo_SP + '. (isp_UnpackReversal)'
                        + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ). Function : isp_TP_GenLabelNo_Wrapper '
         GOTO QUIT_SP
      END

      SET @c_CTNTrackNo_SP = ''
      IF EXISTS ( SELECT 1 FROM dbo.sysobjects
                  WHERE name = @c_authority
                  AND Type = 'P'
            )
      BEGIN
         SET @c_CTNTrackNo_SP = RTRIM(@c_authority)
      END

      IF @c_CTNTrackNo_SP <> ''
      BEGIN
         SET @c_CTNTrackNo = @c_LabelNo
         SET @c_SQL = N'EXEC ' + @c_CTNTrackNo_SP
                    + ' @c_PickSlipNo, @n_CartonNo, @c_CTNTrackNo OUTPUT, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT'

         SET @c_SQLParms = N'@c_PickSlipNo   NVARCHAR(10)'
                           +', @n_CartonNo   INT'
                           +', @c_CTNTrackNo NVARCHAR(40)   OUTPUT'
                           +', @b_Success    INT OUTPUT'
                           +', @n_err        INT OUTPUT'
                           +', @c_errmsg     NVARCHAR(255)  OUTPUT'

         EXEC sp_executesql @c_SQL
               ,  @c_SQLParms
               ,  @c_PickSlipNo
               ,  @n_CartonNo
               ,  @c_CTNTrackNo  OUTPUT
               ,  @b_Success     OUTPUT
               ,  @n_err         OUTPUT
               ,  @c_errmsg      OUTPUT

         IF @b_Success <> 1
         BEGIN
            SET @n_continue = 3
            SET @n_err = 102201
            SET @c_errmsg='Execution Error : NSQL'+CONVERT(char(5),@n_err)+': Error Executing ' + @c_CTNTrackNo_SP + '. (isp_UnpackReversal)'
                           + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ). Function : isp_TP_GenLabelNo_Wrapper'
            GOTO QUIT_SP
         END

         SET @c_LabelNo = ISNULL(RTRIM(@c_CTNTrackNo),'')
      END
      GOTO QUIT_SP
   END
   --(Wan02) - END

   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 102202
      SELECT @c_ErrMsg = 'Execution Error : NSQL' + CONVERT(CHAR(5), @n_Err)
                     + ': Storerconfig GenLabelNo_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))
                     + '). (isp_GenLabelNo_Wrapper). Function : isp_TP_GenLabelNo_Wrapper'
      GOTO QUIT_SP
   END


  IF EXISTS (SELECT 1
             FROM [INFORMATION_SCHEMA].[PARAMETERS]
             WHERE SPECIFIC_NAME = @c_SPCode
             AND PARAMETER_NAME = '@c_dropid')
   BEGIN
   	  --NJOW01
      SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_PickSlipNo, @n_CartonNo, @c_LabelNo OUTPUT, @c_DropID'

      EXEC sp_executesql @c_SQL
         ,  N'@c_PickSlipNo NVARCHAR(10), @n_CartonNo INT, @c_LabelNo NVARCHAR(20) OUTPUT, @c_DropID NVARCHAR(20)'
         ,  @c_PickSlipNo
         ,  @n_CartonNo
         ,  @c_LabelNo OUTPUT
         ,  @c_DropID

      IF @b_Success <> 1
      BEGIN
          SELECT @n_Continue = 3
          GOTO QUIT_SP
      END
   END
   ELSE
   BEGIN
      SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_PickSlipNo, @n_CartonNo, @c_LabelNo OUTPUT'

      EXEC sp_executesql @c_SQL
         ,  N'@c_PickSlipNo NVARCHAR(10), @n_CartonNo INT, @c_LabelNo NVARCHAR(20) OUTPUT'
         ,  @c_PickSlipNo
         ,  @n_CartonNo
         ,  @c_LabelNo OUTPUT

      IF @b_Success <> 1
      BEGIN
          SELECT @n_Continue = 3
          GOTO QUIT_SP
      END
   END

   QUIT_SP:
   IF @n_Continue = 3
   BEGIN
       SELECT @b_Success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_GenLabelNo_Wrapper'
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
END

GO