SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_CheckCartonLabelNo]                */              
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
/* 15-Feb-2023    Alex     #JIRA PAC-4 Initial                          */
/************************************************************************/
CREATE   PROC [API].[isp_ECOMP_CheckCartonLabelNo](
     @c_StorerKey                NVARCHAR(15)   = ''
   , @c_Facility                 NVARCHAR(15)   = ''
   , @c_SKU                      NVARCHAR(20)   = ''
   , @c_PickSlipNo               NVARCHAR(10)   = ''
   , @b_IsLabelNoCaptured        INT            = 0   OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_Continue                    INT            = 1
         , @n_StartCnt                    INT            = @@TRANCOUNT

         , @n_sc_Success                  INT
         , @n_sc_err                      INT
         , @c_sc_errmsg                   NVARCHAR(250)= ''
         , @c_sc_Option1                  NVARCHAR(50) = ''
         , @c_sc_Option2                  NVARCHAR(50) = ''
         , @c_sc_Option3                  NVARCHAR(50) = ''
         , @c_sc_Option4                  NVARCHAR(50) = ''
         , @c_sc_Option5                  NVARCHAR(50) = ''

         , @c_IsCaptureLabelNo            NVARCHAR(1)    = '0'
         , @c_CaptureLabelNoFunc          NVARCHAR(50)   = ''

         , @c_ToFields_Str                NVARCHAR(200)  = ''
         , @c_ToFields_Value              NVARCHAR(100)  = ''

         , @c_Fields                      NVARCHAR(100)  = ''

         , @c_SQLQuery                    NVARCHAR(4000) = ''
         , @c_SQLParams                   NVARCHAR(200)  = ''
         , @c_SQLCondi                    NVARCHAR(500)  = ''


   SET @n_sc_Success                      = 0
   SET @n_sc_err                          = 0
   SET @c_sc_errmsg                       = ''
   SET @c_IsCaptureLabelNo                = ''
   SET @c_CaptureLabelNoFunc              = ''
   
   SET @b_IsLabelNoCaptured               = 0

   EXEC [dbo].[nspGetRight]
            @c_Facility          = @c_Facility
         ,  @c_StorerKey         = @c_StorerKey
         ,  @c_sku               = ''
         ,  @c_ConfigKey         = 'EPACKSINGLECAPTURELABELNO'
         ,  @b_Success           = @n_sc_Success               OUTPUT     
         ,  @c_authority         = @c_IsCaptureLabelNo         OUTPUT    
         ,  @n_err               = @n_sc_err                   OUTPUT    
         ,  @c_errmsg            = @c_sc_errmsg                OUTPUT  
         ,  @c_Option5           = @c_CaptureLabelNoFunc       OUTPUT 
   
   IF @n_sc_Success <> 1   
   BEGIN   
      GOTO QUIT
   END

   IF @c_IsCaptureLabelNo = '1'
   BEGIN
      IF ISNULL(RTRIM(@c_CaptureLabelNoFunc), '') <> ''
      BEGIN
         SELECT @c_ToFields_Str = [Value] 
         FROM STRING_SPLIT ( @c_CaptureLabelNoFunc , ' ' ) 
         WHERE [Value] LIKE '%ToField%'

         IF ISNULL(RTRIM(@c_ToFields_Str), '') <> ''
         BEGIN
            SELECT @c_ToFields_Value = [Value] 
            FROM STRING_SPLIT ( @c_ToFields_Str , '=' ) 
            WHERE [Value] NOT LIKE '%ToField%'

            IF ISNULL(RTRIM(@c_ToFields_Value), '') <> ''
            BEGIN
               SELECT @c_SQLCondi = STRING_AGG('AND ' + UPPER([Value]) + ' <> ''''  ', CHAR(13)) 
               FROM STRING_SPLIT ( @c_ToFields_Value , ',' ) 
               WHERE [Value] NOT LIKE '%ToField%'

               SET @c_SQLQuery = 'SELECT @b_IsLabelNoCaptured = (1) ' + CHAR(13)
                               + 'FROM [dbo].[PackDetail] WITH (NOLOCK) ' + CHAR(13)
                               + 'WHERE StorerKey = @c_StorerKey ' + CHAR(13) 
                               + 'AND SKU = @c_SKU ' + CHAR(13) 
                               + 'AND PickSlipNo = @c_PickSlipNo ' + CHAR(13) 
                               + @c_SQLCondi

               SET @c_SQLParams = '@c_StorerKey NVARCHAR(15), @c_SKU NVARCHAR(20), @c_PickSlipNo NVARCHAR(10), @b_IsLabelNoCaptured INT OUTPUT'


               EXECUTE sp_ExecuteSql @c_SQLQuery, @c_SQLParams, @c_StorerKey, @c_SKU, @c_PickSlipNo, @b_IsLabelNoCaptured OUTPUT

               GOTO QUIT
            END
            
         END
      END

      SELECT @b_IsLabelNoCaptured = (1)
      FROM [dbo].[PackDetail] WITH (NOLOCK) 
      WHERE StorerKey = @c_StorerKey
      AND SKU = @c_SKU
      AND PickSlipNo = @c_PickSlipNo
      AND DropID <> ''

      --SELECT [Value] FROM STRING_SPLIT ( '@c_ToFields=dropid,refno,refno2 @c_AutoClose=Y' , ' ' ) 
      --WHERE [Value] like '%ToField%'
      --SELECT STRING_AGG('AND ' + [Value] + ' <> ''''  ', CHAR(13)) 
      --FROM STRING_SPLIT ( 'dropid,refno,refno2' , ',' ) 
      --WHERE [Value] NOT LIKE '%ToField%'
   END

   QUIT:
   IF @n_Continue= 3  -- Error Occured - Process And Return      
   BEGIN          
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
      WHILE @@TRANCOUNT > @n_StartCnt      
      BEGIN      
         COMMIT TRAN      
      END      
      RETURN      
   END
END -- Procedure  

GO