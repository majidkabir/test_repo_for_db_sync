SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/  
/* Stored Procedure:  isp_InsertTraceInfo                               */  
/* Creation Date:                                                       */  
/* Copyright: IDS                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose:  INSERT TraceInfo log                                       */  
/*                                                                      */  
/************************************************************************/ 
CREATE PROC [dbo].[isp_InsertTraceInfo]     
(  @c_TraceCode   NVARCHAR(20)
   , @c_TraceName NVARCHAR(80)
   , @c_starttime datetime  
   , @c_endtime   datetime  
   , @c_step1     NVARCHAR(20)  
   , @c_step2     NVARCHAR(20)  
   , @c_step3     NVARCHAR(20)  
   , @c_step4     NVARCHAR(20)  
   , @c_step5     NVARCHAR(20)  
   , @c_col1      NVARCHAR(20)  
   , @c_col2      NVARCHAR(20)  
   , @c_col3      NVARCHAR(20)  
   , @c_col4      NVARCHAR(20)  
   , @c_col5      NVARCHAR(20)
   , @b_Success   INT           OUTPUT  
   , @n_Err       INT           OUTPUT  
   , @c_ErrMsg    NVARCHAR(250) OUTPUT     
)    
AS    
BEGIN    
   SET NOCOUNT ON       
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF      
    
   DECLARE @n_count     INT /* next key */    
   DECLARE @n_ncnt      int    
   DECLARE @n_starttcnt int /* Holds the current transaction count */    
   DECLARE @n_continue  int /* Continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip furthur processing */    
   DECLARE @n_cnt       int /* Variable to record if @@ROWCOUNT=0 after UPDATE */    
    
   SELECT  @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg=''    
    
   BEGIN TRANSACTION    

   IF EXISTS ( SELECT 1 FROM CodeList with (NOLOCK) WHERE LISTNAME = 'TraceInfo' And ListGroup = '1' ) -- Turn on Traceinfo
      AND EXISTS ( SELECT 1 FROM CodeLKUP with (NOLOCK) WHERE LISTNAME = 'TraceInfo' And Code = @c_TraceCode 
                     AND Short = '1')
   BEGIN
      INSERT INTO TraceInfo (TraceName, TimeIn, TimeOut, TotalTime, Step1, Step2, Step3, Step4, Step5, Col1, Col2, Col3, Col4, Col5)  
      VALUES ( @c_TraceName, @c_starttime, @c_endtime  
               , CONVERT(CHAR(12),@c_endtime-@c_starttime ,114)  
               , @c_step1,@c_step2,@c_step3,@c_step4,@c_step5  
               , @c_Col1,@c_Col2,@c_Col3,@c_Col4,@c_Col5 )  
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0    
      BEGIN    
        SELECT @n_continue = 3     
      END    
   END

   
   IF @n_continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SELECT @b_success = 0         
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt     
      BEGIN    
          ROLLBACK TRAN    
      END    
      ELSE     
      BEGIN    
          WHILE @@TRANCOUNT > @n_starttcnt     
          BEGIN    
              COMMIT TRAN    
          END              
      END    
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_InsertTraceInfo'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE     
   BEGIN    
      SELECT @b_success = 1    
    WHILE @@TRANCOUNT > @n_starttcnt     
    BEGIN    
         COMMIT TRAN    
    END    
    RETURN    
   END    
END 

GO