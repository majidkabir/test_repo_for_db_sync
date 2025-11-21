SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispTSKD10                                             */
/* Creation Date: 06-Sep-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-20668 - AdidasVN cancel task update UCC Status             */
/*                                                                         */
/* Called By: isp_TaskDetail_Wrapper from Taskdetail Trigger               */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 06-Sep-2022  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/

CREATE   PROC [dbo].[ispTSKD10]   
      @c_Action        NVARCHAR(10),
      @c_Storerkey     NVARCHAR(15),  
      @b_Success       INT      OUTPUT,
      @n_Err           INT      OUTPUT, 
      @c_ErrMsg        NVARCHAR(250) OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_Continue        INT,
           @n_StartTCnt       INT,
           @c_Sku             NVARCHAR(15),
           @c_UCCNo           NVARCHAR(20)     
                                         
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
    
   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END
      
   IF @c_Action = 'DELETE'
   BEGIN      
      DECLARE Cur_Task CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT D.Sku, UCC.UCCNO
         FROM #DELETED D
         JOIN UCC (NOLOCK) ON D.Lot = UCC.Lot AND D.FromLoc = UCC.Loc AND D.FromID = UCC.ID AND D.CaseID = UCC.UCCNo
         WHERE D.Storerkey = @c_Storerkey
         AND D.Tasktype = 'RPF'
         AND D.Status NOT IN ('9','X')
         AND UCC.Status = '4'
         AND D.SourceType = 'ispRLREP06'
                
      OPEN Cur_Task
       
      FETCH NEXT FROM Cur_Task INTO @c_Sku, @c_UCCNo
            
      WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2)
      BEGIN           
         UPDATE UCC WITH (ROWLOCK)
         SET Status = '1'
         WHERE Storerkey = @c_Storerkey
         AND Sku = @c_Sku
         AND UCCNo = @c_UCCNo
           
         IF @@ERROR <> 0
         BEGIN
            SELECT @n_Continue = 3 
            SELECT @n_Err = 38010
            SELECT @c_Errmsg = 'NSQL' + CONVERT(varchar(5),@n_Err)+': Update UCC Failed. (ispTSKD10)'
         END           
           
         FETCH NEXT FROM Cur_Task INTO @c_Sku, @c_UCCNo
      END
      CLOSE Cur_Task
      DEALLOCATE Cur_Task
   END                   
   
   IF @c_Action = 'UPDATE' 
   BEGIN
      DECLARE Cur_Task CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT D.Sku, UCC.UCCNO
         FROM #INSERTED I 
         JOIN #DELETED D ON I.Taskdetailkey = D.Taskdetailkey
         JOIN UCC (NOLOCK) ON D.Lot = UCC.Lot AND D.FromLoc = UCC.Loc AND D.FromID = UCC.ID AND D.CaseID = UCC.UCCNo
         WHERE I.Storerkey = @c_Storerkey
         AND I.Tasktype = 'RPF'
         AND D.Status <> '9'
         AND I.Status <> D.Status
         AND I.Status = 'X'                  
         AND UCC.Status = '4'
         AND I.SourceType = 'ispRLREP06'
                                  
      OPEN Cur_Task
       
      FETCH NEXT FROM Cur_Task INTO @c_Sku, @c_UCCNo
            
      WHILE @@FETCH_STATUS <> -1 AND (@n_continue = 1 or @n_continue = 2)
      BEGIN
         UPDATE UCC WITH (ROWLOCK)
         SET Status = '1'
         WHERE Storerkey = @c_Storerkey
         AND Sku = @c_Sku
         AND UCCNo = @c_UCCNo

         IF @@ERROR <> 0
         BEGIN
            SELECT @n_Continue = 3 
            SELECT @n_Err = 38020
            SELECT @c_Errmsg = 'NSQL' + CONVERT(varchar(5),@n_Err)+': Update UCC Failed. (ispTSKD10)'
         END           
           
         FETCH NEXT FROM Cur_Task INTO @c_Sku, @c_UCCNo
      END
      CLOSE Cur_Task
      DEALLOCATE Cur_Task
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispTSKD10'      
      --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END  
END  

GO