SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*********************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_API_ValidateCartonType]                     */              
/* Creation Date: 31-JAN-2023                                                    */
/* Copyright: Maersk                                                             */
/* Written by: Alex Keoh                                                         */
/*                                                                               */
/* Purpose:                                                                      */
/*                                                                               */
/* Called By: SCEAPI                                                             */
/*                                                                               */
/* PVCS Version: 1.0                                                             */
/*                                                                               */
/* Version: 1.0                                                                  */
/*                                                                               */
/* Data Modifications:                                                           */
/*                                                                               */
/* Updates:                                                                      */
/* Date           Author   Purposes                                              */
/* 30-MAR-2023    Alex     #JIRA PAC-320 Validate carton type after user input   */
/* 28-JUN-2024    Alex01   #PAC-346 - Bug fixes                                  */
/*********************************************************************************/

CREATE   PROC [API].[isp_ECOMP_API_ValidateCartonType](
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

         , @c_Facility                    NVARCHAR(10)   = ''
         , @c_StorerKey                   NVARCHAR(15)   = ''
         , @c_CartonType                  NVARCHAR(60)   = ''
         , @f_CartonWeight                FLOAT          = 0 

         , @c_PickSlipNo                  NVARCHAR(10)   = ''
         , @n_CartonNo                    INT            = 0
         , @b_IsValid                     BIT            = 0
         , @c_Authority                   NVARCHAR(1)    = ''
         , @c_AlertMsg                    NVARCHAR(255)  = ''

   DECLARE @t_CartonType AS TABLE (
         CartonizationKey     NVARCHAR(10)      NULL
      ,  CartonType           NVARCHAR(10)      NULL
      ,  [Cube]               FLOAT             NULL
      ,  MaxWeight            FLOAT             NULL
      ,  MaxCount             INT               NULL
      ,  CartonWeight         FLOAT             NULL
      ,  CartonLength         FLOAT             NULL
      ,  CartonWidth          FLOAT             NULL
      ,  CartonHeight         FLOAT             NULL
      ,  AlertMsg             NVARCHAR(255)     NULL
   )

   SET @b_Success                         = 0
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''
   SET @c_ResponseString                  = ''
   
   SELECT @c_Facility       = ISNULL(RTRIM(Facility     ), '')
         ,@c_StorerKey      = ISNULL(RTRIM(Storer       ), '')
         ,@c_CartonType     = ISNULL(RTRIM(CartonType   ), '')
         ,@c_PickSlipNo     = ISNULL(RTRIM(PickSlipNo   ), '')
         ,@n_CartonNo       = ISNULL(CartonNo            , 1)
   FROM OPENJSON (@c_RequestString)
   WITH ( 
      Facility          NVARCHAR(10)         '$.Facility',
      Storer            NVARCHAR(15)         '$.Storer',
      CartonType        NVARCHAR(60)         '$.CartonType',
      CartonNo          INT                  '$.CartonNo',
      PickSlipNo        NVARCHAR(10)         '$.PickSlipNo'
   )
   
   --Alex01 Begin
   IF @c_CartonType = '' 
   BEGIN
      SET @n_Continue = 3 
      SET @n_ErrNo = 53101
      SET @c_ErrMsg = CONVERT(CHAR(5),@n_ErrNo) + ' - CartonType cannot be blank..' 
      GOTO QUIT
   END

   --SET @c_Authority = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'CtnTypeInput')

   --IF @c_Authority = '1'
   --BEGIN
   INSERT INTO @t_CartonType( CartonizationKey, CartonType, [Cube], MaxWeight, MaxCount, CartonWeight, CartonLength, CartonWidth, CartonHeight, AlertMsg )
   EXEC [API].[isp_ECOMP_GetPackCartonType]      
      @c_Facility          = @c_Facility      
   ,  @c_Storerkey         = @c_Storerkey
   ,  @c_CartonType        = @c_CartonType      
   ,  @c_CartonGroup       = ''          
   ,  @c_PickSlipNo        = @c_PickSlipNo         
   ,  @n_CartonNo          = @n_CartonNo 
   ,  @c_SourceApp         = 'SCE'

   SELECT @b_IsValid       = (1)
         ,@c_CartonType    = ISNULL(RTRIM(CartonType) , '')
         ,@f_CartonWeight  = ISNULL(CartonWeight      , 0)
         ,@c_AlertMsg      = ISNULL(RTRIM(AlertMsg)   , '')
   FROM @t_CartonType

   IF @c_AlertMsg <> ''
   BEGIN
      SET @n_Continue = 3 
      SET @n_ErrNo = 53102
      SET @c_ErrMsg = CONVERT(CHAR(5),@n_ErrNo) + ' - ' + @c_AlertMsg
      GOTO QUIT
   END
   --END
   --ELSE 
   --BEGIN
   --   --CtnTypeInput is turned off, validation is not required, always return 1.
   --   SET @b_IsValid = 1
   --END
   --Alex01 End
   SET @n_CartonNo = CASE WHEN @n_CartonNo = 0 THEN 1 ELSE @n_CartonNo END

   


   SET @c_ResponseString = ISNULL(( 
                              SELECT @b_IsValid                As 'IsValid'
                                    ,@c_CartonType             As 'CartonType'
                                    ,@f_CartonWeight           As 'CartonWeight'
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