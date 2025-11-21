SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_API_GetOrderList_S]                */              
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

CREATE   PROC [API].[isp_ECOMP_API_GetOrderList_S](
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

         , @c_TaskBatchNo                 NVARCHAR(10)   = ''
         , @c_OrderKey                    NVARCHAR(10)   = ''
         , @c_DropID                      NVARCHAR(10)   = ''

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
   
   SELECT @c_TaskBatchNo   = ISNULL(RTRIM(TaskBatchNo ), '')
         ,@c_OrderKey      = ISNULL(RTRIM(OrderKey    ), '')
         ,@c_DropID        = ISNULL(RTRIM(DropID      ), '')
   FROM OPENJSON (@c_RequestString)
   WITH ( 
      TaskBatchNo          NVARCHAR(10)       '$.TaskBatchNo',
      OrderKey             NVARCHAR(10)       '$.OrderKey', 
      DropID               NVARCHAR(10)       '$.DropID'
   )     

   IF @c_DropID <> ''
   BEGIN
      SELECT @c_TaskBatchNo = ISNULL(RTRIM(TaskBatchNo), '')
      FROM dbo.PACKTASKDETAIL PTD WITH (NOLOCK) 
      WHERE EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
         WHERE PD.DropID = @c_DropID AND PD.OrderKey = PTD.Orderkey)
   END
   ELSE IF @c_TaskBatchNo = '' AND @c_OrderKey <> ''
   BEGIN
      SELECT @c_TaskBatchNo = TaskBatchNo
      FROM [dbo].[PackTask] WITH (NOLOCK) 
      WHERE OrderKey = @c_OrderKey
   END

   SET @c_ResponseString = ISNULL(( 
                              SELECT PTD.TaskBatchNo                                    , OH.Orderkey                                    , OH.LoadKey                                    , PTD.Sku                                    , PTD.QtyAllocated                                    , ISNULL(PD.QtyPacked,0) AS QtyPacked                                    , OH.[Status]                                    , OH.SOStatus                               FROM PACKTASKDETAIL PTD WITH (NOLOCK)                               JOIN ORDERS OH WITH (NOLOCK) ON OH.OrderKey = PTD.Orderkey                               OUTER APPLY (SELECT SUM(Qty) AS QtyPacked                                            FROM PACKDETAIL WITH (NOLOCK)                                            WHERE PickSlipNo = PTD.PickSlipNo                                           AND PickSlipNo <> '') AS PD                                WHERE PTD.TaskBatchNo = @c_TaskBatchNo                               AND PTD.[Status] < '9'                              GROUP BY PTD.TaskBatchNo                                      , OH.Orderkey                                      , OH.LoadKey                                      , PTD.Sku                                      , PTD.QtyAllocated                                      , ISNULL(PD.QtyPacked,0)                                      , OH.[Status]                                      , OH.SOStatus 
                              FOR JSON PATH
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