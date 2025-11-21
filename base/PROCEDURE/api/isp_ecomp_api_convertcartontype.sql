SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_API_ConvertCartonType]             */              
/* Creation Date: 30-MAR-2023                                           */
/* Copyright: Maersk                                                    */
/* Written by: Alex Keoh                                                */
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
/* 30-MAR-2023    Alex     #JIRA PAC-4 Initial                          */
/************************************************************************/

CREATE   PROC [API].[isp_ECOMP_API_ConvertCartonType](
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

         , @c_Facility                    NVARCHAR(10)   = ''
         , @c_StorerKey                   NVARCHAR(15)   = ''
         , @c_CartonType                  NVARCHAR(60)   = ''
         , @c_NewCartonType               NVARCHAR(15)   = ''
         , @c_CartonGroup                 NVARCHAR(15)   = ''
         , @f_CartonWeight                FLOAT          = 0 

         , @b_sp_Success                  INT
         , @n_sp_err                      INT
         , @c_sp_errmsg                   NVARCHAR(250)= ''

   DECLARE @t_VasActivity AS TABLE (
         Orderkey             NVARCHAR(10)   NULL
      ,  OrderLineNumber      NVARCHAR(5)    NULL
      ,  Storerkey            NVARCHAR(15)   NULL
      ,  Sku                  NVARCHAR(20)   NULL
      ,  Qty                  INT            NULL
      ,  Activity             NVARCHAR(1000) NULL
      ,  Checked              CHAR(1)        NULL
   )

   SET @b_Success                         = 0
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''
   SET @c_ResponseString                  = ''

   --Change Login User
   --SET @n_sp_err = 0     
   --EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserID OUTPUT, @n_Err = @n_sp_err OUTPUT, @c_ErrMsg = @c_sp_errmsg OUTPUT    
       
   --EXECUTE AS LOGIN = @c_UserID    
       
   --IF @n_sp_err <> 0     
   --BEGIN      
   --   SET @n_Continue = 3      
   --   SET @n_ErrNo = @n_sp_err      
   --   SET @c_ErrMsg = @c_sp_errmsg     
   --   GOTO QUIT      
   --END  
   
   SELECT @c_Facility       = ISNULL(RTRIM(Facility     ), '')
         ,@c_StorerKey      = ISNULL(RTRIM(Storer       ), '')
         ,@c_CartonType     = ISNULL(RTRIM(CartonType   ), '')
   FROM OPENJSON (@c_RequestString)
   WITH ( 
      Facility          NVARCHAR(10)       '$.Facility',
      Storer            NVARCHAR(15)       '$.Storer',
      CartonType        NVARCHAR(60)       '$.CartonType'
   )     
  
   EXEC [API].[isp_ECOMP_ConvertCartonType]
      @c_Facility       = @c_Facility
   ,  @c_StorerKey      = @c_StorerKey
   ,  @c_CartonType     = @c_CartonType
   ,  @c_NewCartonType  = @c_NewCartonType      OUTPUT
   ,  @c_CartonGroup    = @c_CartonGroup        OUTPUT

   IF @c_NewCartonType = ''
   BEGIN
      SET @n_Continue = 3      
      SET @n_ErrNo = 81200      
      SET @c_ErrMsg = CONVERT(CHAR(5), @n_ErrNo) + ' - Invalid Carton Type : ' + @c_CartonType
      GOTO QUIT      
   END

   SELECT @f_CartonWeight = ISNULL([CartonWeight], 0)
   FROM [dbo].[Cartonization] WITH (NOLOCK) 
   WHERE CartonizationGroup = @c_CartonGroup AND CartonType = @c_NewCartonType

   

   SET @c_ResponseString = ISNULL(( 
                              SELECT @c_NewCartonType          As 'CartonType'
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