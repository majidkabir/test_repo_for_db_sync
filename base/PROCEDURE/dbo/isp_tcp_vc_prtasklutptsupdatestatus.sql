SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  isp_TCP_VC_prTaskLutPtsUpdateStatus                */  
/* Creation Date: 26-Feb-2013                                           */  
/* Copyright: IDS                                                       */  
/* Written by: Shong                                                    */  
/*                                                                      */  
/* Purposes: The device sends this message to either transmit a lot and */
/*           the quantity associated to that lot to the host system so  */
/*           that it can be validated                                   */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Purposes                                      */  
/************************************************************************/  
CREATE PROC [dbo].[isp_TCP_VC_prTaskLutPtsUpdateStatus] (  
    @c_TranDate     NVARCHAR(20)  
   ,@c_DevSerialNo  NVARCHAR(20)  
   ,@c_OperatorID   NVARCHAR(20)  
   ,@c_GroupID      NVARCHAR(20)
   ,@c_LocationID   NVARCHAR(10)     
   ,@c_WhatToUpdate NVARCHAR(1)  -- 0 = update slot, 1 = update aisle, 2 = update entire assignment
   ,@c_WhatToUpdTo  NVARCHAR(10) -- N = update status to not put, S = update status to skipped
   ,@n_SerialNo     INT  
   ,@c_RtnMessage   NVARCHAR(500) OUTPUT      
   ,@b_Success      INT = 1 OUTPUT  
   ,@n_Error        INT = 0 OUTPUT  
   ,@c_ErrMsg       NVARCHAR(255) = '' OUTPUT   
  
)  
AS  
BEGIN  
   DECLARE @c_ErrorCode      NVARCHAR(20) --  0: No error. The VoiceApplication proceeds.  
                                         -- 98: Critical error. If this error is received,   
                                         --     the VoiceApplication speaks the error message, and forces the operator to sign off.   
                                         -- 99: Informational error. The VoiceApplication speaks the informational error message,   
                                         --     but does not force the operator to sign off.  
         , @c_Message         NVARCHAR(400)  
         , @c_TaskDetailKey   NVARCHAR(10)
         , @c_TaskType        NVARCHAR(10)
         , @c_StorerKey       NVARCHAR(15)
         , @c_SKU             NVARCHAR(20)
         , @n_TaskQty         INT
         , @c_CaptureLottable NVARCHAR(10)
         , @c_LOT             NVARCHAR(10)
         , @c_GroupID01       NVARCHAR(18)
         , @c_GroupID02       NVARCHAR(18)
         , @c_GroupID03       NVARCHAR(18)
         , @c_GroupIDDesc     NVARCHAR(60)
         , @c_GroupID01Label  NVARCHAR(20)
         , @c_GroupID02Label  NVARCHAR(20)
         , @c_GroupID03Label  NVARCHAR(20)
         , @c_GroupID04Label  NVARCHAR(20)
         , @c_ListName        NVARCHAR(10)
         , @c_SysLottable     NVARCHAR(20)
         , @d_Lottable04      DATETIME 
         , @d_Lottable05      DATETIME 
         , @c_PickDetailKey   NVARCHAR(10)
         , @n_PickDetailQty   INT 
         , @n_QtyToTake       INT 
         , @c_NewPickDetailKey NVARCHAR(10)
         , @n_Continue        INT 
         , @c_Status          NVARCHAR(1)
         , @b_LotFound        INT
         

   SET @c_ErrorCode  = '0'
   SET @c_RtnMessage = ''  
   SET @c_Message    = ''   
   SET @n_Continue   = 1    
   SET @b_LotFound   = 0  
         

QUIT_SP:   
   -- Return Error Message If Batch No Not match 
   SET @c_RtnMessage = @c_ErrorCode + ',''' + RTRIM(@c_Message) + '''' 
        
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0   
   BEGIN  
      SET @c_RtnMessage = "0,"   
   END  
   

  
END

GO