SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_TP_GenSSCCLabel_Wrapper                        */
/*                                                                      */
/* Purpose: SOS#241579 - QS- Carton label                               */
/*          Storerconfig GenSSCCLabel_SP={SPName} to call customize SP  */
/*          If no setup then default to call isp_GenSSCCLabel           */
/*                                                                      */
/* Called By: nep_w_packing_maintenance - ue_new_carton event           */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Ver   Purposes                               */
/*10/04/2020   Chermaine   1.0   Duplicated from isp_GenSSCCLabel_Wrapper*/
/************************************************************************/
CREATE   PROCEDURE [API].[isp_TP_GenSSCCLabel_Wrapper]
      @c_PickSlipNo     NVARCHAR(10)
   ,  @n_CartonNo       INT
   ,  @c_SSCC_LabelNo   NVARCHAR(20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue     INT
         , @n_Count        INT
         , @b_Success      INT
         , @n_Err          INT
         , @c_ErrMsg       NVARCHAR(255)
         , @c_SPCode       NVARCHAR(50)
         , @c_StorerKey    NVARCHAR(15)
         , @c_OrderStatus  NVARCHAR(10)
         , @c_SQL          NVARCHAR(MAX)

   SET @n_err        = 0
   SET @b_Success    = 1
   SET @c_errmsg     = ''

   SET @n_Continue   = 1
   SET @n_Count      = 0
   SET @c_SPCode     = ''
   SET @c_StorerKey  = ''
   SET @c_OrderStatus= ''
   SET @c_SQL        = ''

   SELECT @c_StorerKey = ISNULL(RTRIM(OH.Storerkey),'')
   FROM PICKHEADER PH WITH (NOLOCK)
   JOIN ORDERS OH WITH (NOLOCK) ON (PH.Orderkey = OH.Orderkey)
   WHERE PH.PickHeaderKey = @c_PickSlipNo

   IF RTRIM(@c_StorerKey) = ''
   BEGIN
      SELECT @c_StorerKey = ISNULL(RTRIM(OH.Storerkey),'')
      FROM PICKHEADER PH WITH (NOLOCK)
      JOIN ORDERS OH WITH (NOLOCK) ON (PH.ExternOrderkey = OH.Loadkey)
      WHERE PH.PickHeaderKey = @c_PickSlipNo
   END

   SELECT @c_SPCode = sVALUE
   FROM   StorerConfig WITH (NOLOCK)
   WHERE  StorerKey = @c_StorerKey
   AND    ConfigKey = 'GenSSCCLabel_SP'

   IF ISNULL(RTRIM(@c_SPCode),'') = ''
   BEGIN
      SET @c_SPCode = 'isp_GenSSCCLabelNo'
   END

   IF NOT EXISTS (SELECT 1 FROM dbo.sysobjects WHERE name = RTRIM(@c_SPCode) AND type = 'P')
   BEGIN
       SET @n_Continue = 3
       SET @n_Err = 102300
       SELECT @c_ErrMsg = 'Execution Error : NSQL' + CONVERT(CHAR(5), @n_Err)
                        + ': Storerconfig GenSSCCLabel_SP - Stored Proc name invalid ('+RTRIM(ISNULL(@c_SPCode,''))
                        + '). (isp_GenSSCCLabel_Wrapper). Function : isp_packfindsingleorder'
       GOTO QUIT_SP
   END


   SET @c_SQL = 'EXEC ' + @c_SPCode + ' @c_PickSlipNo, @n_CartonNo, @c_SSCC_LabelNo OUTPUT'

   EXEC sp_executesql @c_SQL
      ,  N'@c_PickSlipNo NVARCHAR(10), @n_CartonNo INT, @c_SSCC_LabelNo NVARCHAR(20) OUTPUT'
      ,  @c_PickSlipNo
      ,  @n_CartonNo
      ,  @c_SSCC_LabelNo OUTPUT

   IF @b_Success <> 1
   BEGIN
       SELECT @n_Continue = 3
       GOTO QUIT_SP
   END

   QUIT_SP:
   IF @n_Continue = 3
   BEGIN
       SELECT @b_Success = 0
       EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_GenSSCCLabel_Wrapper'
       RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
END

GO