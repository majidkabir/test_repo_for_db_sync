SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispTSKD08                                          */
/* Creation Date: 14-May-2020                                           */
/* Copyright: LF                                                        */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-16094 - [CN] ANFQHW_WMS_TransferAllocation              */   
/*                                                                      */
/* Called By: isp_TaskDetail_Wrapper from Taskdetail Trigger            */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author  Ver   Purposes                                  */ 
/* 22-FEB-2021  Wan     1.0   Created                                   */   
/************************************************************************/

CREATE PROC [dbo].[ispTSKD08]   
         @c_Action        NVARCHAR(10)
      ,  @c_Storerkey     NVARCHAR(15)  
      ,  @b_Success       INT             OUTPUT
      ,  @n_Err           INT             OUTPUT 
      ,  @c_ErrMsg        NVARCHAR(250)   OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT 
          
         , @n_UCC_RowRef      BIGINT = 0  
         , @Cur_Task          CURSOR
                                       
   SET @n_Err = 0
   SET @c_ErrMsg = ''
   SET @b_Success = 1
    
   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
   BEGIN
      GOTO QUIT_SP
   END      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END
      
   IF @c_Action = 'DELETE'
   BEGIN   
      SET @Cur_Task = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT UCC.UCC_RowRef
         FROM #DELETED D
         JOIN UCC (NOLOCK) ON D.Lot = UCC.Lot AND D.FromLoc = UCC.Loc AND D.FromID = UCC.ID AND D.CaseID = UCC.UCCNo
         WHERE D.Storerkey = @c_Storerkey
         AND D.Tasktype = 'RPF'
         AND D.[Status] NOT IN ('9','X')
         AND D.SourceType = 'ispTransferAllocation02'
         AND D.CaseID <> ''
         AND UCC.[Status] = '3'                
      OPEN @Cur_Task
       
      FETCH NEXT FROM @Cur_Task INTO @n_UCC_RowRef
            
      WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2)
      BEGIN        
         UPDATE UCC 
         SET Status = '1'
         WHERE UCC_RowRef = @n_UCC_RowRef
          
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3 
            SET @n_Err = 38010
            SET @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update UCC Failed. (ispTSKD08)'
         END          
          
         FETCH NEXT FROM @Cur_Task INTO @n_UCC_RowRef
      END
      CLOSE @Cur_Task
      DEALLOCATE @Cur_Task
   END                
   
   IF @c_Action = 'UPDATE' 
   BEGIN
      SET @Cur_Task = CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT UCC.UCC_RowRef
         FROM #INSERTED I 
         JOIN #DELETED D ON I.Taskdetailkey = D.Taskdetailkey
         JOIN UCC (NOLOCK) ON D.Lot = UCC.Lot AND D.FromLoc = UCC.Loc AND D.FromID = UCC.ID AND D.CaseID = UCC.UCCNo
         WHERE I.Storerkey = @c_Storerkey
         AND I.Tasktype = 'RPF'
         AND I.[Status] <> D.[Status]
         AND I.[Status] = 'X'                  
         AND D.[Status] <> '9'
         AND D.CaseID <> ''
         AND UCC.[Status] = '3'
         AND I.SourceType = 'ispTransferAllocation02'
                                  
      OPEN @Cur_Task
       
      FETCH NEXT FROM @Cur_Task INTO @n_UCC_RowRef
            
      WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2)
      BEGIN        
         UPDATE UCC 
         SET Status = '1'
         WHERE UCC_RowRef = @n_UCC_RowRef
         
         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue = 3 
            SET @n_Err = 38020
            SET @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update UCC Failed. (ispTSKD08)'
         END          
          
         FETCH NEXT FROM @Cur_Task INTO @n_UCC_RowRef
      END
      CLOSE @Cur_Task
      DEALLOCATE @Cur_Task
   END   
       
   QUIT_SP:
   
   IF @n_Continue=3  -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispTSKD08'     
      --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END  
END  

GO