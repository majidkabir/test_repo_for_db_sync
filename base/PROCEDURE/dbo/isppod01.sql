SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Procedure: ispPOD01                                           */    
/* Creation Date: 22-Nov-2021                                           */    
/* Copyright: LFL                                                       */    
/* Written by: Mingle                                                   */    
/*                                                                      */    
/* Purpose: WMS-18336 - MYSûSBUXMûDefault value in POD Entry column     */  
/*                      upon update POD Status                          */       
/*                                                                      */    
/* Called By: isp_PODTrigger_Wrapper from POD Trigger                   */    
/*                                                                      */    
/* GitLab Version: 1.0                                                  */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */      
/* Date         Author   Ver  Purposes                                  */     
/* 22-NOV-2021  mingle   1.0  DevOps Combine Script(Created)            */    
/* 21-FEB-2023  NJOW01   1.1  Fix to close cur_pod                      */
/************************************************************************/    
    
CREATE   PROC [dbo].[ispPOD01]    
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
           @c_Mbolkey        NVARCHAR(10),     
           @c_mbolLineNumber   NVARCHAR(5)   
                                                                                                                                    
   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1    
    
   IF @c_Action NOT IN('INSERT','UPDATE','DELETE')    
      GOTO QUIT_SP          
    
   IF OBJECT_ID('tempdb..#INSERTED') IS NULL OR OBJECT_ID('tempdb..#DELETED') IS NULL    
   BEGIN    
      GOTO QUIT_SP    
   END        
   
   --SELECT @c_Mbolkey = I.Mbolkey    
   --FROM #INSERTED I    
   --WHERE I.Storerkey = @c_Storerkey    
         
       
   --BEGIN TRAN    
       
       
   IF @c_Action IN ('UPDATE')     
   BEGIN          
      --Update PODDef06 = 'SKTS' if Status = '7' or '8'    
      DECLARE CUR_POD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
           SELECT  I.Mbolkey ,I.mbolLineNumber    
                  FROM #INSERTED I    
                  JOIN #DELETED D ON I.Mbolkey = D.Mbolkey    
                  AND I.Storerkey = @c_Storerkey    
                  AND I.Mbolkey = D.Mbolkey    
                  AND I.Status IN ('7','8')    
                  AND I.Status <> D.Status    
                  AND (I.PODDef06 = '' OR I.PODDef06 IS NULL)  
           ORDER BY  I.Mbolkey ,I.mbolLineNumber   
              
      OPEN CUR_POD  
      
      FETCH NEXT FROM CUR_POD INTO @c_Mbolkey, @c_mbolLineNumber  
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
      BEGIN  
         UPDATE POD WITH (ROWLOCK)    
         SET PODDef06 = N'SKTS'  , trafficcop = null  
         WHERE Mbolkey = @c_Mbolkey  
         AND mbolLineNumber = @c_mbollinenumber  
         --AND (I.PODDef06 = '' OR I.PODDef06 IS NULL)  
           
         SELECT @n_err = @@ERROR    
           
         IF @n_err <> 0    
         BEGIN    
            SET @n_continue = 3      
            SET @n_err = 63905-- Should Be Set To The SQL Errmessage but I don't know how to do so.     
            SET @c_errmsg='NSQL'+CONVERT(char(5), @n_err)+': Failed to UPDATE POD table. (ispPOD01)'       
         END    
    
         FETCH NEXT FROM CUR_POD INTO @c_Mbolkey, @c_mbolLineNumber      
      END  
      CLOSE CUR_POD  
      DEALLOCATE CUR_POD  
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
      EXECUTE dbo.nsp_LogError @n_Err, @c_Errmsg, 'ispPOD01'      
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