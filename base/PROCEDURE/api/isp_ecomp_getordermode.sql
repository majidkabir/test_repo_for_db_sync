SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/              
/* Store procedure: [API].[isp_ECOMP_GetOrderMode]                      */              
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
/************************************************************************/    
CREATE   PROC [API].[isp_ECOMP_GetOrderMode](
      @b_Debug                   INT            = 0
    , @c_TaskBatchID             NVARCHAR(10)   = ''  OUTPUT
    , @c_DropID                  NVARCHAR(20)   = ''
    , @c_OrderKey                NVARCHAR(10)   = ''
    , @b_Success                 INT            = 0   OUTPUT
    , @n_ErrNo                   INT            = 0   OUTPUT
    , @c_ErrMsg                  NVARCHAR(250)  = ''  OUTPUT
    , @c_OrderMode               NVARCHAR(1)    = ''  OUTPUT
    , @c_Top1_OrderKey           NVARCHAR(10)   = ''  OUTPUT
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

         , @n_IsExists                    INT            = 0
         , @b_IsWhereClauseExists         INT            = 0

   SET @b_Success                         = 0
   SET @n_ErrNo                           = 0
   SET @c_ErrMsg                          = ''
   SET @c_OrderMode                       = ''
   SET @c_Top1_OrderKey                   = ''


   SET @n_IsExists = 0
   SET @b_IsWhereClauseExists = 0

   --Search For PackTask (Begin)
   IF @c_TaskBatchID <> ''
   BEGIN
      SET @c_SQLWhereClause = @c_SQLWhereClause 
                            + 'WHERE TaskBatchNo = @c_TaskBatchID ' + CHAR(13)
      SET @b_IsWhereClauseExists = 1
   END
   
   IF @c_OrderKey <> ''
   BEGIN
      SET @c_SQLWhereClause =  @c_SQLWhereClause
                      + CASE WHEN @b_IsWhereClauseExists = 0 THEN 'WHERE' ELSE 'AND' END
                      + ' OrderKey = @c_OrderKey ' + CHAR(13)
      SET @b_IsWhereClauseExists = 1
   END

   IF @c_DropID <> ''
   BEGIN
       SET @c_SQLWhereClause = @c_SQLWhereClause 
                       + CASE WHEN @b_IsWhereClauseExists = 0 THEN 'WHERE' ELSE 'AND' END
                       + ' EXISTS ( SELECT 1  ' + CHAR(13) 
                       + '    FROM [dbo].[PickDetail] pic WITH (NOLOCK) ' + CHAR(13) 
                       + '    WHERE pic.DropID = @c_DropID ' + CHAR(13) 
                       + '    AND pic.OrderKey = m.OrderKey) ' + CHAR(13) 

   END

   SET @c_SQLQuery = 'SELECT TOP 1 ' + CHAR(13) + 
                   + '       @n_IsExists = (1) '  + CHAR(13) + 
                   + '      ,@c_OrderMode = Left(UPPER(OrderMode),1) '  + CHAR(13) + 
                   + '      ,@c_TaskBatchID = TaskBatchNo ' + CHAR(13) +
                   + '      ,@c_Top1_OrderKey = OrderKey '  + CHAR(13) + 
                   + 'FROM [dbo].[PackTask] m WITH (NOLOCK) '  + CHAR(13) +
                   + @c_SQLWhereClause

   SET @c_SQLParams = '@c_TaskBatchID NVARCHAR(10) OUTPUT, @c_OrderKey NVARCHAR(10), @c_DropID NVARCHAR(20), @n_IsExists INT OUTPUT, @c_OrderMode NVARCHAR(1) OUTPUT, @c_Top1_OrderKey NVARCHAR(10) OUTPUT'


   IF @b_Debug = 1
   BEGIN
      PRINT '>>>>>>>>>>>>>>>> @c_SQLQuery'
      PRINT @c_SQLQuery
   END

   BEGIN TRY
      EXECUTE sp_ExecuteSql 
         @c_SQLQuery
       , @c_SQLParams
       , @c_TaskBatchID       OUTPUT
       , @c_OrderKey
       , @c_DropID
       , @n_IsExists          OUTPUT
       , @c_OrderMode         OUTPUT
       , @c_Top1_OrderKey     OUTPUT

      IF @n_IsExists = 0
      BEGIN
         SET @n_Continue = 3 
         SET @n_ErrNo = 51001
         SET @c_ErrMsg = 'PackTask not found.'
         GOTO QUIT
      END
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3 
      SET @n_ErrNo = 51002
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO QUIT
   END CATCH

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