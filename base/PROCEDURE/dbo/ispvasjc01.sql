SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispVASJC01                                         */  
/* Creation Date: 23-JUN-2015                                           */  
/* Copyright: IDS                                                       */  
/* Written by: YTWan                                                    */  
/*                                                                      */  
/* Purpose: SOS#318089 - Project Merlion VAP Add or Delete Work Order   */ 
/*                                                                      */  
/* Called By: isp_VASCancJob_Wrapper                                    */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver.  Purposes                                  */ 
/* 13-Jan-2016 Wan01    1.1   Manual Reserved                           */ 
/* 26-JAN-2016 YTWan    1.1   SOS#315603 - Project Merlion - VAP SKU    */
/*                            Reservation Strategy - MixSku in 1 Pallet */
/*                            enhancement                               */	  
/************************************************************************/  
CREATE PROC [dbo].[ispVASJC01]    
     @c_JobKey     NVARCHAR(10)
   , @b_Success    INT           OUTPUT    
   , @n_Err        INT           OUTPUT    
   , @c_ErrMsg     NVARCHAR(250) OUTPUT    
AS    
BEGIN    
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF  
    
   DECLARE  @n_Continue       INT     
         ,  @n_StartTCnt      INT  -- Holds the current transaction count  

         ,  @c_JobLineNo      NVARCHAR(5)   
         ,  @c_SourceType     NVARCHAR(10)
         ,  @c_WOOperation    NVARCHAR(10)
  
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue   =  1
   SET @b_Success    =  1 
   SET @n_Err        =  0  
   SET @c_ErrMsg     =  '' 
   SET @c_SourceType = 'VAS'
   

   IF EXISTS ( SELECT 1
               FROM WORKORDERJOBDETAIL WITH (NOLOCK)
               WHERE JobKey = @c_JobKey
               AND   JobStatus = '9'
               )
   BEGIN
      SET @n_Continue= 3    
      SET @n_Err     = 63500   
      SET @c_ErrMsg  = 'Job is completed. Cancellation deny. (ispVASJC01)'
      GOTO QUIT_SP
   END


  IF EXISTS ( SELECT 1
                  FROM TASKDETAIL WITH (NOLOCK)
                  WHERE SourceType = @c_SourceType
                  AND   LEFT(Sourcekey,10)  = @c_JobKey  
                  AND   Status NOT IN ('S', '0', 'X', '9')
                )
   BEGIN
      SET @n_Continue= 3    
      SET @n_Err     = 63505  
      SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Task in progress. Cancel job reject. (ispVASJC01)'      
      GOTO QUIT_SP 
   END

   BEGIN TRAN

   IF EXISTS ( SELECT 1
               FROM TASKDETAIL WITH (NOLOCK)
               WHERE SourceType = @c_SourceType
               AND   LEFT(Sourcekey,10)  = @c_JobKey  
               AND   Status IN ('S', '0')
              )
   BEGIN
      EXEC isp_VASJobCancTasks_Wrapper 
              @c_JobKey    = @c_JobKey 
            , @b_Success   = @b_Success         OUTPUT            
            , @n_err       = @n_err             OUTPUT          
            , @c_errmsg    = @c_errmsg          OUTPUT

      IF @@ERROR <> 0 OR @b_Success <> 1  
      BEGIN  
         SET @n_Continue= 3    
         SET @n_Err     = 63510 
         SET @c_ErrMsg  =  'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC isp_VASJobCancTasks_Wrapper ' +    
                           CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (ispVASJC01)'
         GOTO QUIT_SP                          
      END 
   END
   
   DECLARE CUR_WOJO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT JobLine 
         ,WOOperation  
   FROM WORKORDERJOBOPERATION  WOJO WITH (NOLOCK)
   WHERE  Jobkey = @c_jobKey
   ORDER BY CASE WOOperation  WHEN 'VAS Move To Line' THEN 8
                              WHEN 'VAS Move'  THEN 7
                              WHEN 'VAS Pick'  THEN 2
                              WHEN 'ASRS Pull' THEN 1
                              ELSE 9 
                              END
          , JobLine

   OPEN CUR_WOJO
   FETCH NEXT FROM CUR_WOJO INTO @c_JobLineNo
                              ,  @c_WOOperation

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN

      SET @c_WOOperation = CASE @c_WOOperation WHEN 'ASRS Pull' THEN 'VA'
                                               WHEN 'VAS Pick'  THEN 'VP'
                                               WHEN 'VAS Move'  THEN 'VM'
                                               WHEN 'VAS Move To Line' THEN 'VL' 
                                               WHEN 'Begin FG'  THEN 'FG'
                                               END
 
      --Move back to Virtual loc if not call out yet
      IF @c_WOOperation IN ('VA', 'VP')
      BEGIN
 
         IF NOT EXISTS ( SELECT 1
                         FROM TASKDETAIL WITH (NOLOCK)
                         WHERE SourceType = @c_SourceType
                         AND   Sourcekey  = @c_JobKey + @c_JobLineNo
                         AND   Status = '9'
                       )
         BEGIN
            --(Wan01) - START
            DELETE WORKORDERJOBMOVE WITH (ROWLOCK)
            WHERE JobKey = @c_JobKey
            AND   JobLine= @c_JobLineNo 
      
            SET @n_Err = @@ERROR
            IF @n_Err <> 0  
            BEGIN
               SET @n_Continue= 3
               SET @n_Err     = 63515 
               SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Delete record from Table WORKORDERJOBMOVE. (ispVASJC01)' 
               GOTO QUIT_SP
            END
            /*
            EXEC isp_WOJobInvReverse 
                    @c_JobKey    = @c_JobKey 
                  , @c_JobLineNo = @c_JobLineNo          
                  , @b_Success   = @b_Success         OUTPUT            
                  , @n_err       = @n_err             OUTPUT          
                  , @c_errmsg    = @c_errmsg          OUTPUT

            IF @@ERROR <> 0 OR @b_Success <> 1  
            BEGIN  
               SET @n_Continue= 3    
               SET @n_Err     = 63515 
               SET @c_ErrMsg  =  'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC isp_WOJobInvReverse' +   
                                 CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (ispVASJC01)'
               GOTO QUIT_SP                          
            END
            */
            --(Wan01) - END 
         END
      END

      FETCH NEXT FROM CUR_WOJO INTO @c_JobLineNo
                                 ,  @c_WOOperation
   END
   CLOSE CUR_WOJO
   DEALLOCATE CUR_WOJO

QUIT_SP:
   IF CURSOR_STATUS( 'LOCAL', 'CUR_WOJO') in (0 , 1)  
   BEGIN
      CLOSE CUR_WOJO
      DEALLOCATE CUR_WOJO
   END

   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      SET @b_Success = 0    
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
  
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispVASJC01'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN    
   END    
   ELSE    
   BEGIN 
      SET @b_Success = 1    
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   
      RETURN    
   END    
    
END -- Procedure  

GO