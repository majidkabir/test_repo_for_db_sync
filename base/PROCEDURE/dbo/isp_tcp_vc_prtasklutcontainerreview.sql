SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
 /* Store Procedure:  isp_TCP_VC_prTaskLUTContainerReview                */  
 /* Creation Date: 13-Mar-2013                                           */  
 /* Copyright: IDS                                                       */  
 /* Written by: ChewKP                                                   */  
 /*                                                                      */  
 /* Purposes: prTaskLUTPtsContainer                                      */  
 /*                                                                      */  
 /*                                                                      */  
 /* Updates:                                                             */  
 /* Date         Author    Purposes                                      */  
/************************************************************************/  
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTContainerReview] (  
    @c_TranDate            NVARCHAR(20)  
   ,@c_DevSerialNo         NVARCHAR(20)  
   ,@c_OperatorID          NVARCHAR(20)  
   ,@c_SystemContainerID   NVARCHAR(20)   
   ,@c_GroupID             NVARCHAR(10) 
   ,@c_TaskDetailKey       NVARCHAR(10)
   ,@n_SerialNo            INT 
   ,@c_RtnMessage          NVARCHAR(500) OUTPUT      
   ,@b_Success             INT = 1 OUTPUT  
   ,@n_Error               INT = 0 OUTPUT  
   ,@c_ErrMsg              NVARCHAR(255) = '' OUTPUT   
  
)  
AS  
BEGIN  
   DECLARE @c_ErrorCode         NVARCHAR(20) --  0: No error. The VoiceApplication proceeds.  
                                            -- 98: Critical error. If this error is received,   
                                            --     the VoiceApplication speaks the error message, and forces the operator to sign off.   
                                            -- 99: Informational error. The VoiceApplication speaks the informational error message,   
                                            --     but does not force the operator to sign off.  
         , @c_Message            NVARCHAR(400)  
         , @c_SKU                NVARCHAR(20)  
         , @n_Qty                INT
         , @c_FromLoc            NVARCHAR(10)
         , @d_EditDate           DATETIME
         , @n_Counter            INT
         , @c_DropID             NVARCHAR(20)
           
   
   SET @c_RtnMessage = ''  
   SET @c_SKU = ''
   SET @n_Qty = 0 
   SET @c_FromLoc = ''
   SET @n_Counter = 1
   
   SELECT @c_DropID = DropID
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @c_TaskDetailKey 
   
   
   DECLARE CursorLutContainerReview CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
   
   SELECT  SKU
         , FromLoc
         , Qty
         , EditDate
   FROM dbo.TaskDetail WITH (NOLOCK)
   WHERE WaveKey = @c_GroupID
   AND DropID = @c_DropID         
   
   OPEN CursorLutContainerReview            
   
   FETCH NEXT FROM CursorLutContainerReview INTO @c_SKU, @c_FromLoc, @n_Qty, @d_Editdate 
   
   WHILE @@FETCH_STATUS <> -1     
   BEGIN
   
      IF @n_Counter = '1'
      BEGIN
         SET @c_RtnMessage = ISNULL(@c_DropID          ,'') + ',' +  
                             ISNULL(@c_SKU             ,'') + ',' +  
                             ISNULL(CAST(@n_Qty AS NVARCHAR(5)),'') + ',' +  
                             ISNULL(@c_FromLoc         ,'') + ',' +  
                             ISNULL(CONVERT(VARCHAR(20), @d_Editdate, 120) ,'') + ',' +  
                             ISNULL(@c_ErrorCode       ,'0') + ',' +  
                             ISNULL(@c_ErrMsg          ,'')  
      END
      ELSE
      BEGIN
          SET @c_RtnMessage = @c_RtnMessage + '<CR><LF>' + 
                             ISNULL(@c_DropID          ,'') + ',' +  
                             ISNULL(@c_SKU             ,'') + ',' +  
                             ISNULL(CAST(@n_Qty AS NVARCHAR(5)),'') + ',' +  
                             ISNULL(@c_FromLoc         ,'') + ',' +  
                             ISNULL(CONVERT(VARCHAR(20), @d_Editdate, 120) ,'') + ',' +  
                             ISNULL(@c_ErrorCode       ,'0') + ',' +  
                             ISNULL(@c_ErrMsg          ,'')   
                             
      END
      
      SET @n_Counter = @n_Counter + 1
      
     FETCH NEXT FROM CursorLutContainerReview INTO @c_SKU, @c_FromLoc, @n_Qty, @d_Editdate 
      
   END
   CLOSE CursorLutContainerReview            
   DEALLOCATE CursorLutContainerReview   
                                                       
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0   
   BEGIN  
      SET @c_RtnMessage = ',,,,,0,'   
   END  

   
   
  
END

GO