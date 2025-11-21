SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_API_GetVasActivity]                */              
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
/* 05-Jul-2023    Allen    #JIRA PAC-7 add get multivasactivity logic   */
/************************************************************************/

CREATE   PROC [API].[isp_ECOMP_API_GetVasActivity](
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

         , @c_OrderKey                    NVARCHAR(10)   = ''
         , @c_StorerKey                   NVARCHAR(15)   = ''
         , @c_SKU                         NVARCHAR(20)   = ''

         , @b_sp_Success                  INT
         , @n_sp_err                      INT
         , @c_sp_errmsg                   NVARCHAR(250)= ''

   DECLARE @t_VasActivity AS TABLE (
         Orderkey             NVARCHAR(10)   NULL
      ,  OrderLineNumber      NVARCHAR(5)    NULL
      ,  Storerkey            NVARCHAR(15)   NULL
      ,  SKU                  NVARCHAR(20)   NULL
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


   SELECT @c_Orderkey       = ISNULL(RTRIM(OrderKey     ), '')
         ,@c_Storerkey      = ISNULL(RTRIM(Storerkey    ), '')
         ,@c_SKU            = ISNULL(RTRIM(SKU          ), '')
   FROM OPENJSON (@c_RequestString)
   WITH ( 
      OrderKey        NVARCHAR(10)       '$.OrderKey',
      Storerkey       NVARCHAR(10)       '$.Storer',
      SKU             NVARCHAR(20)       '$.SKU'
   )     

   IF @c_OrderKey = ''
   BEGIN
      SET @n_Continue = 3 
      SET @n_ErrNo = 51201
      SET @c_ErrMsg = 'No orderkey found.'
      GOTO QUIT
   END
   
   IF @b_Debug = 1
      BEGIN
         PRINT '@c_Orderkey = ' + @c_Orderkey
         PRINT '@c_Storerkey = ' + @c_Storerkey
         PRINT '@c_SKU = ' + @c_SKU
      END

   IF EXISTS ( SELECT 1 FROM [dbo].[OrderDetailRef] WITH (NOLOCK) 
      --WHERE OrderKey = @c_OrderKey AND [StorerKey] = @c_StorerKey AND ParentSKU = @c_SKU) --(AL01) 
      WHERE OrderKey = @c_OrderKey AND [StorerKey] = @c_StorerKey AND ParentSKU = CASE WHEN ISNULL(@c_SKU,'') = '' THEN ParentSKU ELSE @c_SKU END ) --(AL01)
   BEGIN
      IF @b_Debug = 1
      BEGIN
         PRINT 'Found VAS Activity...'
      END

      INSERT INTO @t_VasActivity (Orderkey, OrderLineNumber, Storerkey, SKU, Qty, Activity, Checked)
      EXEC [API].[isp_ECOMP_EPackVas_Activity]  
         @c_Orderkey    = @c_Orderkey  
      ,  @c_Storerkey   = @c_Storerkey   
      ,  @c_SKU         = @c_SKU

      IF @b_Debug = 1
      BEGIN
         DECLARE @n_TotalVAS INT = 0
         SELECT @n_TotalVAS = COUNT(1) FROM @t_VasActivity
         PRINT 'VAS COUNT: ' + CONVERT(NVARCHAR, @n_TotalVAS)
      END
      
   END

   --IF ISNULL(@c_SKU,'') = '' --(AL01) -S
   --BEGIN
   --    UPDATE @t_VasActivity SET Checked = 'Y' WHERE Orderkey = @c_OrderKey AND [StorerKey] = @c_StorerKey
   --END --(AL01) -E

   SET @c_ResponseString = ISNULL(( 
                              SELECT Orderkey            As 'Orderkey'
                                    ,OrderLineNumber     As 'OrderLineNumber'
                                    ,Storerkey           As 'Storerkey'
                                    ,SKU                 As 'SKU'
                                    ,Qty                 As 'QTY'
                                    ,Activity            As 'Activity'
                                    ,Checked             As 'Checked'
                              FROM @t_VasActivity
                              FOR JSON PATH
                           ), '[]')

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