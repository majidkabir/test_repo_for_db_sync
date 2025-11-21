SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispTSKD05                                          */
/* Creation Date: 13-Jan-2020                                           */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-11388 PH update areakey to all taskdetail               */   
/*                                                                      */
/* Called By: isp_TaskDetail_Wrapper from Taskdetail Trigger            */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 2019-11-21   Wan01    1.1  WMS-10158 - NIKE - PH Wave Release Task   */
/*                            Enhancement                               */
/************************************************************************/

CREATE PROC [dbo].[ispTSKD05]   
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
           @c_Lot             NVARCHAR(10),
           @c_FromLoc         NVARCHAR(10),
           @c_FromID          NVARCHAR(18),
           @n_Qty             INT,
           @n_QtyReplen       INT
                                      
   --(Wan01) -- START                                      
   DECLARE @n_Cnt                INT = 0
         , @c_TaskDetailkey      NVARCHAR(10)   = ''  
         , @c_Wavekey            NVARCHAR(10)   = '' 
         , @c_UCCNo              NVARCHAR(20)   = ''   

         , @CUR_DEL              CURSOR
   --(Wan01) -- END         
            
   DECLARE @n_IsRDT Int
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT
   
    SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1
    
   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')
      GOTO QUIT_SP      

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END
      
   IF @c_Action = 'INSERT'
   BEGIN          
      IF EXISTS(SELECT 1 
                FROM #INSERTED I 
                WHERE I.Storerkey = @c_Storerkey
                AND I.Tasktype IN ('RPF','CC')
                AND ISNULL(I.Areakey,'') = '')
      BEGIN
           UPDATE TASKDETAIL WITH (ROWLOCK)
           SET TASKDETAIL.Areakey = AREADET.Areakey
           FROM TASKDETAIL 
           JOIN LOC (NOLOCK) ON TASKDETAIL.FromLoc = LOC.Loc
           JOIN #INSERTED I ON TASKDETAIL.Taskdetailkey = I.Taskdetailkey
          CROSS APPLY (SELECT TOP 1 AREADETAIL.Areakey FROM AREADETAIL (NOLOCK) WHERE AREADETAIL.Putawayzone = LOC.PickZone ORDER BY AREADETAIL.AreaKey) AS AREADET
          WHERE I.Storerkey = @c_Storerkey
          AND I.Tasktype IN ('RPF','CC')
          AND ISNULL(I.Areakey,'') = ''
                             
           IF @@ERROR <> 0
           BEGIN
              SELECT @n_Continue = 3 
              SELECT @n_Err = 38001
              SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update TASKDETAIL Failed. (ispTSKD05)'
             GOTO QUIT_SP 
          END
      END     
   END                
   
   --(Wan01) - START
   IF @c_Action = 'DELETE'
   BEGIN
      SET @CUR_DEL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
      SELECT D.TaskDetailKey
         ,   D.Wavekey
         ,   D.CaseID 
      FROM #DELETED D
      WHERE D.CaseID <> '' AND D.CaseID  IS NOT NULL
      AND  D.Wavekey <> '' AND D.Wavekey IS NOT NULL
      AND  D.SourceType like 'ispRLWAV20-%'
      ORDER BY D.TaskDetailKey

      OPEN @CUR_DEL   
      
      FETCH NEXT FROM @CUR_DEL INTO @c_TaskDetailKey, @c_Wavekey, @c_UCCNo

      WHILE @@FETCH_STATUS <> -1               
      BEGIN
         IF EXISTS ( SELECT 1
                     FROM  PICKDETAIL PD WITH (NOLOCK)
                     WHERE PD.TaskdetailKey = @c_TaskDetailkey
                     AND PD.Wavekey <> @c_Wavekey
                  )                                                 
         BEGIN
            SET @n_Continue = 3 
            SET @n_Err = 35110
            SET @c_Errmsg= 'NSQL'+CONVERT(varchar(5),@n_Err)+': UCC#:' + @c_UCCNo 
                         + ' is Shared with Other Wave . Delete Reject. (ispTSKD05)'
            GOTO QUIT_SP
         END

         NEXT_REC:
         FETCH NEXT FROM @CUR_DEL INTO @c_TaskDetailKey, @c_Wavekey, @c_UCCNo          
      END
      CLOSE @CUR_DEL         
      DEALLOCATE @CUR_DEL               
   END
   --END
   
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
       EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispTSKD05'    
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