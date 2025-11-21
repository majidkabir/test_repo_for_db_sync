SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure:  isp_TCP_VC_prTaskLUTValidLots                      */  
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
/* 30-May-2014  TKLIM     Added Lottables 06-15                         */
/************************************************************************/  
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTValidLots] (  
    @c_TranDate     NVARCHAR(20)  
   ,@c_DevSerialNo  NVARCHAR(20)  
   ,@c_OperatorID   NVARCHAR(20)  
   ,@c_GroupID      NVARCHAR(20)
   ,@c_AssignmentID NVARCHAR(20)  
   ,@c_LOC          NVARCHAR(10) 
   ,@c_SKU          NVARCHAR(20)   
   ,@c_SeqNo        NVARCHAR(10)
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
         , @n_TaskQty         INT
         , @c_CaptureLottable NVARCHAR(10)
         , @c_Short           NVARCHAR(10)
         , @c_StoredProd      NVARCHAR(250)
         , @c_Lottable        NVARCHAR(18)
         , @c_Lottable02      NVARCHAR(18)
         , @c_Lottable03      NVARCHAR(18)
         , @c_Lottable04      NVARCHAR(20)
         , @c_Lottable06      NVARCHAR(30)
         , @c_Lottable07      NVARCHAR(30)
         , @c_Lottable08      NVARCHAR(30)
         , @c_Lottable09      NVARCHAR(30)
         , @c_Lottable10      NVARCHAR(30)
         , @c_Lottable11      NVARCHAR(30)
         , @c_Lottable12      NVARCHAR(30)
         , @c_Lottable13      NVARCHAR(20)
         , @c_Lottable14      NVARCHAR(20)
         , @c_Lottable15      NVARCHAR(20)
         , @c_Lottable01Label NVARCHAR(20)
         , @c_Lottable02Label NVARCHAR(20)
         , @c_Lottable03Label NVARCHAR(20)
         , @c_Lottable04Label NVARCHAR(20)
         , @c_Lottable06Label NVARCHAR(20)
         , @c_Lottable07Label NVARCHAR(20)
         , @c_Lottable08Label NVARCHAR(20)
         , @c_Lottable09Label NVARCHAR(20)
         , @c_Lottable10Label NVARCHAR(20)
         , @c_Lottable11Label NVARCHAR(20)
         , @c_Lottable12Label NVARCHAR(20)
         , @c_Lottable13Label NVARCHAR(20)
         , @c_Lottable14Label NVARCHAR(20)
         , @c_Lottable15Label NVARCHAR(20)
         , @c_ListName        NVARCHAR(10)
         , @c_LottableLabel   NVARCHAR(20)
         , @d_Lottable04      DATETIME 
         , @d_Lottable05      DATETIME 
         , @d_Lottable13      DATETIME 
         , @d_Lottable14      DATETIME 
         , @d_Lottable15      DATETIME 
         , @c_PickDetailKey   NVARCHAR(10)
         , @n_PickDetailQty   INT 
         , @n_QtyToTake       INT 
         , @c_NewPickDetailKey NVARCHAR(10)
         , @n_Continue        INT 
         , @c_Lot             NVARCHAR(10)
         , @c_LotAttribute    NVARCHAR(18)
         

   SET @c_ErrorCode  = '0'
   SET @c_RtnMessage = ''  
   SET @c_Message    = ''   
   SET @n_Continue   = 1    
   SET @c_LotAttribute = ''
   SET @c_Lot = ''
         
   SET @c_TaskDetailKey = @c_AssignmentID
           
   -- Sample Message
   -- prTaskLUTValidLots('03-06-13 11:42:32','572517055','dlim','0000038530','0000038530','A1AA0105','82152040','1')
   SELECT @c_TaskType = td.TaskType
         ,@c_StorerKey = td.Storerkey
         ,@c_SKU = td.Sku
         ,@n_TaskQty = td.Qty 
   FROM TaskDetail td WITH (NOLOCK)
   WHERE td.TaskDetailKey = @c_TaskDetailKey 

   SET @c_CaptureLottable = '0'
   SELECT @c_CaptureLottable = ISNULL(sc.SValue,'0') 
   FROM StorerConfig sc WITH (NOLOCK) 
   WHERE sc.StorerKey = @c_StorerKey
   AND   sc.ConfigKey = 'VoicePK_CaptureLottable'
   
   
   -- Get Lottable Values from Lotaatribute Tables
   DECLARE CursorLot CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
   
   SELECT DISTINCT Lot 
   FROM dbo.PickDetail WITH (NOLOCK)
   WHERE TaskDetailKey = @c_AssignmentID
   AND Loc = @c_LOC
   AND SKU = @c_SKU
   AND StorerKey = @c_StorerKey
   
   OPEN CursorLot            
   
   FETCH NEXT FROM CursorLot INTO @c_Lot
   
   WHILE @@FETCH_STATUS <> -1     
   BEGIN
      
      SELECT @c_LotAttribute = CASE WHEN @c_CaptureLottable = '1'  THEN Lottable01
                                    WHEN @c_CaptureLottable = '2'  THEN Lottable02
                                    WHEN @c_CaptureLottable = '3'  THEN Lottable03
                                    WHEN @c_CaptureLottable = '6'  THEN Lottable06
                                    WHEN @c_CaptureLottable = '7'  THEN Lottable07
                                    WHEN @c_CaptureLottable = '8'  THEN Lottable08
                                    WHEN @c_CaptureLottable = '9'  THEN Lottable09
                                    WHEN @c_CaptureLottable = '10' THEN Lottable10
                                    WHEN @c_CaptureLottable = '11' THEN Lottable11
                                    WHEN @c_CaptureLottable = '12' THEN Lottable12
                                    ELSE ''
                               END     
      FROM dbo.LotAttribute WITH (NOLOCK)
      WHERE Lot = @c_Lot
      AND SKU = @c_SKU
      AND StorerKey = @c_StorerKey         
      
      SET @c_RtnMessage = RTRIM(@c_RtnMessage) + 
                          CASE WHEN LEN(ISNULL(RTRIM(@c_RtnMessage),'')) = 0 THEN '' ELSE '<CR><LF>' END +   
                          ISNULL(RTRIM(@c_LotAttribute)      ,'') + ',' +  
                          ISNULL(@c_ErrorCode                ,'0') + ',' +  
                          ISNULL(@c_ErrMsg                   ,'')                             
      
      FETCH NEXT FROM CursorLot INTO @c_Lot   
   END
   CLOSE CursorLot            
   DEALLOCATE CursorLot  
   


        
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0   
   BEGIN  
      SET @c_RtnMessage = "'',0,"   
   END  
   
   
  
END


GO