SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_GetTrackingNumber]                 */              
/* Creation Date: 13-FEB-2023                                           */
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
/* 6-Jul-2023     Alex     #JIRA PAC-7 Initial                          */
/* 1-Apr-2024     Alex01   #JIRA PAC-328 Bug Fixes                      */
/************************************************************************/    
CREATE   PROC [API].[isp_ECOMP_GetTrackingNumber](
      @b_Debug                   INT            = 0
    , @c_PickSlipNo              NVARCHAR(10)   = ''
    , @c_OrderKey                NVARCHAR(10)   = ''
    , @n_CartonNo                INT            = 1
    , @b_Success                 INT            = 0   OUTPUT
    , @n_ErrNo                   INT            = 0   OUTPUT
    , @c_ErrMsg                  NVARCHAR(250)  = ''  OUTPUT
    , @c_TrackingNo              NVARCHAR(40)   = ''  OUTPUT
)

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue                    INT            = 1
         , @n_StartCnt                    INT            = @@TRANCOUNT
        
   DECLARE @c_SQLQuery                    NVARCHAR(MAX)  = ''
         , @c_SQLWhereClause              NVARCHAR(2000) = ''
         , @c_SQLParams                   NVARCHAR(2000) = ''

         , @c_PHOrderKey                  NVARCHAR(10)   = ''
         , @c_Facility                    NVARCHAR(15)   = ''
         , @c_StorerKey                   NVARCHAR(15)   = ''

         , @n_IsExists                    INT            = 0
         , @b_IsWhereClauseExists         INT            = 0

         , @c_ORDTrackingNo               NVARCHAR(40)   = ''
         , @c_CTNTrackNoSP                NVARCHAR(40)   = ''
         , @b_sp_Success                  INT            = 0
         , @n_sp_ErrNo                    INT            = 0
         , @c_sp_ErrMsg                   NVARCHAR(255)  = ''

         , @c_CurrentTrackingNo           NVARCHAR(40)   = ''
         , @c_FirstTrackingNo             NVARCHAR(40)   = ''

   SET @b_Success                         = 0
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''

   SET @n_IsExists = 0
   SET @b_IsWhereClauseExists = 0

   IF @c_PickSlipNo <> ''
   BEGIN
      SELECT @c_PHOrderKey = ISNULL(RTRIM(OrderKey), '')
      FROM [dbo].[PackHeader] WITH (NOLOCK)
      WHERE PickSlipNo = @c_PickSlipNo
   END
   ELSE IF @c_PickSlipNo = '' AND @c_OrderKey <> ''
   BEGIN
      SET @c_PHOrderKey = @c_OrderKey
   END

   IF @c_PHOrderKey  = '' GOTO QUIT

   SELECT @c_Facility = ISNULL(RTRIM(Facility), '')
         ,@c_StorerKey = ISNULL(RTRIM(StorerKey), '')
   FROM [dbo].[ORDERS] WITH (NOLOCK) 
   WHERE OrderKey = @c_PHOrderKey

   EXEC [dbo].[nspGetRight]
         @c_Facility      = @c_Facility
      ,  @c_StorerKey     = @c_StorerKey
      ,  @c_sku           = ''
      ,  @c_ConfigKey     = 'EPACKCTNTrackNo_SP'
      ,  @b_Success       = @b_sp_Success          OUTPUT    
      ,  @c_authority     = @c_CTNTrackNoSP        OUTPUT  
      ,  @n_err           = @n_sp_ErrNo            OUTPUT  
      ,  @c_errmsg        = @c_sp_ErrMsg           OUTPUT
   
   SELECT 
      @c_ORDTrackingNo = CASE 
                           WHEN EXISTS (SELECT 1 FROM [dbo].[StorerConfig] WITH (NOLOCK) WHERE ConfigKey = 'EPACKGetTrackNoSkipUDF04' AND StorerKey = @c_StorerKey AND SValue = '1') 
                              THEN ISNULL(RTRIM(TrackingNo),'') ELSE 
                                 CASE WHEN ISNULL(RTRIM(TrackingNo),'') <> '' THEN TrackingNo ELSE ISNULL(RTRIM(UserDefine04),'') END
                         END
   FROM [dbo].[Orders] WITH (NOLOCK) 
   WHERE OrderKey = @c_PHOrderKey

   IF @n_CartonNo = 1 OR @c_CTNTrackNoSP = '' OR @c_CTNTrackNoSP = '0'
   BEGIN
      SET @c_TrackingNo = @c_ORDTrackingNo
   END
   ELSE IF @n_CartonNo >= 2
   BEGIN
      SELECT @n_IsExists = (1)
            ,@c_CurrentTrackingNo = ISNULL(RTRIM([TrackingNo]), '')
      FROM [dbo].[PackInfo] WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo
      AND CartonNo = @n_CartonNo

      --if [PackInfo] not exists, return order.tracking number.
      IF @n_IsExists = 0
      BEGIN
         SET @c_TrackingNo = @c_ORDTrackingNo
         GOTO QUIT
      END

      SELECT @c_FirstTrackingNo = ISNULL(RTRIM([TrackingNo]), '')
      FROM [dbo].[PackInfo] WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo
      AND CartonNo = 1

      IF @c_FirstTrackingNo <> @c_CurrentTrackingNo AND @c_CurrentTrackingNo <> ''
      BEGIN
         SET @c_TrackingNo = @c_CurrentTrackingNo
         GOTO QUIT
      END
   END
   --Assign Tracking Number (End)

   --Alex01 (Begin)
   IF @c_PickSlipNo <> '' 
      AND EXISTS ( SELECT 1 FROM [dbo].[PackInfo] WITH (NOLOCK) 
         WHERE PickSlipNo = @c_PickSlipNo
         AND CartonNo = @n_CartonNo )
   BEGIN
      IF ISNULL(RTRIM(@c_CTNTrackNoSP), '') <> '' AND @c_CTNTrackNoSP <> '0'
      BEGIN
         SET @c_SQLQuery = 'EXEC [dbo].[' + @c_CTNTrackNoSP + '] ' + CHAR(13) + 
                         + '      @c_PickSlipNo  = @c_PickSlipNo             ' + CHAR(13) +
                         + '   ,  @n_CartonNo    = @n_CartonNo               ' + CHAR(13) +
                         + '   ,  @c_CTNTrackNo  = @c_TrackingNo      OUTPUT ' + CHAR(13) +
                         + '   ,  @b_Success     = @b_sp_Success      OUTPUT ' + CHAR(13) +
                         + '   ,  @n_err         = @n_sp_ErrNo        OUTPUT ' + CHAR(13) +
                         + '   ,  @c_errmsg      = @c_sp_ErrMsg       OUTPUT ' + CHAR(13) 
   
         SET @c_SQLParams = '@c_PickSlipNo NVARCHAR(10), @n_CartonNo INT, @c_TrackingNo NVARCHAR(40) OUTPUT, @b_sp_Success INT OUTPUT, @n_sp_ErrNo INT OUTPUT , @c_sp_ErrMsg NVARCHAR(255) OUTPUT '
         
         BEGIN TRY
            EXECUTE sp_ExecuteSql 
                  @c_SQLQuery
                 ,@c_SQLParams
                 ,@c_PickSlipNo
                 ,@n_CartonNo
                 ,@c_TrackingNo           OUTPUT
                 ,@b_sp_Success           OUTPUT
                 ,@n_sp_ErrNo             OUTPUT
                 ,@c_sp_ErrMsg            OUTPUT
            
            IF @b_sp_Success = 0
            BEGIN
               SET @n_Continue = 3 
               SET @n_ErrNo = 51301
               SET @c_ErrMsg = CONVERT(char(5),@n_ErrNo)+': ' 
                             + CONVERT(char(5),@n_sp_ErrNo) + ' - ' + @c_sp_ErrMsg     
               GOTO QUIT
            END
         END TRY
         BEGIN CATCH
            SET @n_Continue = 3 
            SET @n_ErrNo = 51302
            SET @c_ErrMsg = ERROR_MESSAGE()
            GOTO QUIT
         END CATCH

         IF ISNULL(RTRIM(@c_TrackingNo), '') = '' AND @n_CartonNo > 1
         BEGIN
            SET @c_TrackingNo = @c_ORDTrackingNo
         END

         IF @b_Debug = 1
         BEGIN
            PRINT '@c_CTNTrackNoSP=' + @c_CTNTrackNoSP
            PRINT '@c_TrackingNo=' + @c_TrackingNo
         END
      END
   END
   --Alex01 (End)

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