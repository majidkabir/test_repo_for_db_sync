SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_API_ScanSerialNumber]              */              
/* Creation Date: 08-MAR-2023                                           */
/* Copyright: Maersk                                                    */
/* Written by: AlexKeoh                                                 */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: SCEAPI                                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date           Author   Purposes                                     */
/* 08-MAR-2023    Alex     #JIRA PAC-4 Initial                          */
/* 09-JUL-2024    Alex01   #JIRA PAC-344 & PAC-350                      */
/************************************************************************/    
CREATE   PROC [API].[isp_ECOMP_API_ScanSerialNumber](
     @b_Debug           INT            = 0
   , @c_Format          VARCHAR(10)    = ''
   , @c_UserID          NVARCHAR(256)  = ''
   , @c_OperationType   NVARCHAR(60)   = ''
   , @c_RequestString   NVARCHAR(MAX)  = ''
   , @b_Success         INT            = 0   OUTPUT
   , @n_ErrNo           INT            = 0   OUTPUT
   , @c_ErrMsg          NVARCHAR(250)  = ''  OUTPUT
   , @c_ResponseString  NVARCHAR(MAX)  = ''  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue                    INT            = 1
         , @n_StartCnt                    INT            = @@TRANCOUNT

         , @c_ComputerName                NVARCHAR(30)   = ''
         , @c_TaskBatchID                 NVARCHAR(10)   = ''
         , @c_DropID                      NVARCHAR(20)   = ''
         , @c_OrderKey                    NVARCHAR(10)   = ''

         , @c_PickSlipNo                  NVARCHAR(10)   = ''
         , @c_SKU                         NVARCHAR(20)   = ''
         , @c_SerialNumber                NVARCHAR(500)  = ''
         , @c_StorerKey                   NVARCHAR(15)   = ''

         , @c_IsSerialNoMandatory         NVARCHAR(1)    = '0'
         , @b_RespSuccess                 INT            = 0

   DECLARE 
           @n_CartonNo                    INT            = 0
         , @c_TrackingNumber              NVARCHAR(40)   = ''
         , @n_SumQty                      INT            = 0
         , @f_Weight                      FLOAT          = 0
         , @c_CartonGroup                 NVARCHAR(10)   = ''
         , @c_CartonType                  NVARCHAR(10)   = ''
         , @f_Cube                        FLOAT
         , @f_CartonLength                FLOAT

         --Alex01 Begin
         , @c_Facility                    NVARCHAR(5)    = ''
         , @c_QRCode                      NVARCHAR(500)  = ''
         , @c_DecodeSerialNoSP            NVARCHAR(30)   = ''
         , @c_SQLQuery                    NVARCHAR(2000) = ''
         , @c_SQLParams                   NVARCHAR(500)  = ''
         --Alex01 End

         , @b_sp_Success                  INT
         , @n_sp_err                      INT
         , @c_sp_errmsg                   NVARCHAR(250)= ''

   DECLARE @t_PackTaskOrderSts AS TABLE (
         TaskBatchNo          NVARCHAR(10)      NULL
      ,  OrderKey             NVARCHAR(10)      NULL
      ,  TotalOrder           INT               NULL
      ,  PackedOrder          INT               NULL
      ,  PendingOrder         INT               NULL
      ,  CancelledOrder       INT               NULL
      ,  InProgOrderKey       NVARCHAR(10)      NULL
      ,  NonEPackSO           NVARCHAR(150)     NULL
   )

   SET @b_Success                         = 0
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''
   SET @c_ResponseString                  = ''

   --Change Login User
   SET @n_sp_err = 0     
   EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserID OUTPUT, @n_Err = @n_sp_err OUTPUT, @c_ErrMsg = @c_sp_errmsg OUTPUT    
       
   EXECUTE AS LOGIN = @c_UserID    
       
   IF @n_sp_err <> 0     
   BEGIN      
      SET @n_Continue = 3      
      SET @n_ErrNo = @n_sp_err      
      SET @c_ErrMsg = @c_sp_errmsg     
      GOTO QUIT      
   END  

   SELECT @c_PickSlipNo       = ISNULL(RTRIM(PickSlipNo     ), '')
         --,@c_StorerKey        = ISNULL(RTRIM(StorerKey      ), '')
         ,@c_SKU              = ISNULL(RTRIM(SKU            ), '')
         ,@c_SerialNumber     = ISNULL(RTRIM(SerialNumber   ), '')
         ,@n_CartonNo         = ISNULL(CartonNo              , 0)
   FROM OPENJSON (@c_RequestString)
   WITH ( 
      PickSlipNo        NVARCHAR(10)       '$.PickSlipNo',
      --StorerKey         NVARCHAR(15)       '$.StorerKey',
      SKU               NVARCHAR(20)       '$.SKU',
      SerialNumber      NVARCHAR(500)      '$.SerialNumber',   --Alex01
      CartonNo          INT                '$.CartonNo'
   )

   IF @c_PickSlipNo = '' --OR @c_StorerKey = '' 
      OR @c_SKU = '' OR @c_SerialNumber = ''
   BEGIN
      SET @n_Continue = 3      
      SET @n_ErrNo = 51510      
      SET @c_ErrMsg = @c_sp_errmsg   
      GOTO QUIT 
   END

   SELECT @c_StorerKey = ISNULL(RTRIM(StorerKey), '')
         ,@c_TaskBatchID = ISNULL(RTRIM(TaskBatchNo), '')
   FROM [dbo].[PackHeader] WITH (NOLOCK) 
   WHERE PickSlipNo = @c_PickSlipNo

   SELECT @c_Facility = ISNULL(RTRIM([Facility]), '')
   FROM [dbo].[Orders] WITH (NOLOCK) 
   WHERE OrderKey IN ( SELECT TOP 1 OrderKey 
      FROM [dbo].[PackTaskDetail] WITH (NOLOCK) 
      WHERE TaskBatchNo = @c_TaskBatchID )

   IF NOT @@ROWCOUNT = 0
   BEGIN
      IF EXISTS ( SELECT 1 FROM [dbo].[PackDetail] WITH (NOLOCK) 
         WHERE PickSlipNo = @c_PickSlipNo AND [SKU] = @c_SKU )
      BEGIN
         GOTO GEN_RESPONSE
      END

      SELECT @c_IsSerialNoMandatory = CASE 
            WHEN ISNULL(RTRIM([SerialNoCapture]), '') IN ('1','3')  THEN '1' ELSE '0' END
      FROM [dbo].[SKU] WITH (NOLOCK) 
      WHERE StorerKey = @c_StorerKey
      AND SKU = @c_SKU

      IF @c_IsSerialNoMandatory = '1'
      BEGIN
         --Alex01 Begin
         SET @c_DecodeSerialNoSP = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'SerialNoDecode')

         IF ISNULL(RTRIM(@c_DecodeSerialNoSP), '') <> ''
         BEGIN
            IF EXISTS ( SELECT * FROM dbo.sysobjects WHERE name = RTRIM(@c_DecodeSerialNoSP) AND type = 'P' )
            BEGIN
               SET @c_SQLQuery = 'EXEC [API].[' + @c_DecodeSerialNoSP + '] '     + CHAR(13) + 
                               + ' @c_PickSlipNo     = @c_PickSlipNo   '         + CHAR(13) +
                               + ',@c_Storerkey      = @c_Storerkey    '         + CHAR(13) + 
                               + ',@c_Sku            = @c_Sku          '         + CHAR(13) + 
                               + ',@c_SerialNumber   = @c_SerialNumber  OUTPUT ' + CHAR(13) + 
                               + ',@c_QRCode         = @c_QRCode        OUTPUT ' + CHAR(13) + 
                               + ',@b_Success        = @b_sp_Success    OUTPUT ' + CHAR(13) + 
                               + ',@n_Err            = @n_sp_err        OUTPUT ' + CHAR(13) + 
                               + ',@c_ErrMsg         = @c_sp_errmsg     OUTPUT '

               SET @c_SQLParams = ' @c_PickSlipNo     NVARCHAR(10) '             + CHAR(13) +
                                + ',@c_Storerkey      NVARCHAR(15) '             + CHAR(13) +
                                + ',@c_Sku            NVARCHAR(60) '             + CHAR(13) +
                                + ',@c_SerialNumber   NVARCHAR(500)     OUTPUT ' + CHAR(13) +
                                + ',@c_QRCode         NVARCHAR(500)     OUTPUT ' + CHAR(13) +
                                + ',@b_sp_Success     INT               OUTPUT ' + CHAR(13) +
                                + ',@n_sp_err         INT               OUTPUT ' + CHAR(13) +
                                + ',@c_sp_errmsg      NVARCHAR(255)     OUTPUT '

               EXEC sp_ExecuteSQL @c_SQLQuery
                                , @c_SQLParams       
                                , @c_PickSlipNo
                                , @c_Storerkey        
                                , @c_Sku               
                                , @c_SerialNumber  OUTPUT
                                , @c_QRCode        OUTPUT
                                , @b_sp_Success    OUTPUT
                                , @n_sp_err        OUTPUT
                                , @c_sp_errmsg     OUTPUT

               IF @b_sp_Success <> 1
               BEGIN
                  SET @n_Continue = 3      
                  SET @n_ErrNo = 51511      
                  SET @c_ErrMsg = CONVERT(char(5),@n_ErrNo)+': ' 
                                + CONVERT(char(5),@n_sp_err) + ' - ' + @c_sp_errmsg     
                  GOTO QUIT
               END
            END
         END

         SET @b_sp_Success = 0
         SET @n_sp_err = 0
         SET @c_sp_errmsg = ''
         --Alex01 End

         EXEC [API].[isp_ECOMP_PackValidateSerialNo]
                 @c_PickSlipNo         = @c_PickSlipNo
               , @c_Storerkey          = @c_StorerKey
               , @c_Sku                = @c_SKU
               , @c_SerialNo           = @c_SerialNumber
               , @b_Success            = @b_sp_Success      OUTPUT  
               , @n_Err                = @n_sp_err          OUTPUT  
               , @c_ErrMsg             = @c_sp_errmsg       OUTPUT  

         IF @b_sp_Success <> 1
         BEGIN
            SET @n_Continue = 3      
            SET @n_ErrNo = 51512      
            SET @c_ErrMsg = CONVERT(char(5),@n_ErrNo)+': ' 
                          + CONVERT(char(5),@n_sp_err) + ' - ' + @c_sp_errmsg     
            GOTO QUIT
         END

         INSERT INTO [dbo].[PackSerialNo] (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, SerialNo, QTY, Barcode) --Alex01
         VALUES (@c_PickSlipNo, @n_CartonNo, '', '00001', @c_StorerKey, @c_SKU, @c_SerialNumber, 1, @c_QRCode)

         INSERT INTO [dbo].[PackDetail] (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, Qty, DropId)
         VALUES(@c_PickSlipNo, @n_CartonNo, '', '00001', @c_StorerKey, @c_SKU, 1, '')
         
         SET @b_RespSuccess = 1
      END
   END
   
   GEN_RESPONSE:
   SET @c_ResponseString = ISNULL(( 
                              SELECT CAST ( @b_RespSuccess AS BIT )   AS 'Success'
                                    ,( 
                                       SELECT PD.SKU                 As 'SKU'
                                             ,PD.QTY                 As 'QTY'
                                             ,PD.LOTTABLEVALUE       As 'LottableValue'
                                             ,S.STDGROSSWGT          As 'STDGrossWeight'
                                       FROM [dbo].[PackDetail] PD WITH (NOLOCK)
                                       JOIN [dbo].[SKU] S WITH (NOLOCK) 
                                       ON (PD.PickSlipNo = @c_PickSlipNo 
                                          AND S.StorerKey = PD.StorerKey
                                          AND S.SKU = PD.SKU )
                                       WHERE PickSlipNo = @c_PickSlipNo
                                       FOR JSON PATH 
                                     ) AS 'PackTask.CartonPackedSKU'
                              FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                           ), '')

   QUIT:
   IF @n_Continue= 3  -- Error Occured - Process And Return      
   BEGIN      
      SET @b_Success = 0      
      IF @@TRANCOUNT > @n_StartCnt AND @@TRANCOUNT = 1 
      BEGIN               
         ROLLBACK TRAN      
      END      
      ELSE      
      BEGIN      
         WHILE @@TRANCOUNT > @n_StartCnt      
         BEGIN      
            COMMIT TRAN      
         END      
      END   
      RETURN      
   END      
   ELSE      
   BEGIN      
      SELECT @b_Success = 1      
      WHILE @@TRANCOUNT > @n_StartCnt      
      BEGIN      
         COMMIT TRAN      
      END      
      RETURN      
   END
END -- Procedure  

GO