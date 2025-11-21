SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store Procedure:  isp_TCP_VC_prTaskLUTSendLot                        */    
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
/* 27-Mar-2013  ChewKP    Revise (ChewKP01)                             */        
/* 30-May-2014  TKLIM     Added Lottables 06-15                         */
/************************************************************************/    
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTSendLot] (    
    @c_TranDate     NVARCHAR(20)    
   ,@c_DevSerialNo  NVARCHAR(20)    
   ,@c_OperatorID   NVARCHAR(20)    
   ,@c_Lottable     NVARCHAR(18)    
   ,@n_QtyPicked    INT    
   ,@c_AssignmentID NVARCHAR(20)    
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
         , @c_Message            NVARCHAR(400)    
         , @c_TaskDetailKey      NVARCHAR(10)  
         , @c_TaskType           NVARCHAR(10)  
         , @c_StorerKey          NVARCHAR(15)  
         , @c_SKU                NVARCHAR(20)  
         , @n_TaskQty            INT  
         , @c_CaptureLottable    NVARCHAR(10)  
         , @c_LOT                NVARCHAR(10)  
         , @c_Lottable01         NVARCHAR(18)  
         , @c_Lottable02         NVARCHAR(18)  
         , @c_Lottable03         NVARCHAR(18)  
         , @c_Lottable06         NVARCHAR(30)
         , @c_Lottable07         NVARCHAR(30)
         , @c_Lottable08         NVARCHAR(30)
         , @c_Lottable09         NVARCHAR(30)
         , @c_Lottable10         NVARCHAR(30)
         , @c_Lottable11         NVARCHAR(30)
         , @c_Lottable12         NVARCHAR(30)
         , @c_LottableDesc       NVARCHAR(60)  
         , @c_Lottable01Label    NVARCHAR(20)  
         , @c_Lottable02Label    NVARCHAR(20)  
         , @c_Lottable03Label    NVARCHAR(20)  
         , @c_Lottable04Label    NVARCHAR(20)  
         , @c_Lottable06Label    NVARCHAR(20)
         , @c_Lottable07Label    NVARCHAR(20)
         , @c_Lottable08Label    NVARCHAR(20)
         , @c_Lottable09Label    NVARCHAR(20)
         , @c_Lottable10Label    NVARCHAR(20)
         , @c_Lottable11Label    NVARCHAR(20)
         , @c_Lottable12Label    NVARCHAR(20)
         , @c_Lottable13Label    NVARCHAR(20)
         , @c_Lottable14Label    NVARCHAR(20)
         , @c_Lottable15Label    NVARCHAR(20)
         , @c_ListName           NVARCHAR(10)  
         , @c_SysLottable        NVARCHAR(20)  
         , @d_Lottable04         DATETIME   
         , @d_Lottable05         DATETIME   
         , @d_Lottable13         DATETIME
         , @d_Lottable14         DATETIME
         , @d_Lottable15         DATETIME
         , @c_PickDetailKey      NVARCHAR(10)  
         , @n_PickDetailQty      INT   
         , @n_QtyToTake          INT   
         , @c_NewPickDetailKey   NVARCHAR(10)  
         , @n_Continue           INT   
         , @c_Status             NVARCHAR(1)  
         , @b_LotFound           INT  
         , @c_AlertMessage       NVARCHAR( 255)
         , @c_NewLineChar        NVARCHAR(2)       
         
         -- (ChewKP01)
         , @n_Mobile             INT            
         , @n_Func               INT
         , @c_Facility           NVARCHAR(5)
         , @c_FromLoc            NVARCHAR(10)
         , @c_FromID             NVARCHAR(18)
         , @c_ToLoc              NVARCHAR(10)
         , @c_ToID               NVARCHAR(18)

   SET @c_ErrorCode  = '0'  
   SET @c_RtnMessage = ''    
   SET @c_Message    = ''     
   SET @n_Continue   = 1      
   SET @b_LotFound   = 0  
   SET @c_AlertMessage = ''  
   SET @c_StorerKey = ''
   SET @c_Facility = ''
   SET @n_Func = 0 
   SET @n_Mobile = 0 
   
   SET @c_NewLineChar =  CHAR(13) + CHAR(10)
           
   SET @c_TaskDetailKey = @c_AssignmentID  
   
   SELECT @n_Mobile = Mobile
         ,@n_Func   = Func
         ,@c_Facility = Facility
   FROM rdt.rdtMobRec WITH (NOLOCK)   
   WHERE DeviceID = @c_DevSerialNo   
   AND UserName = @c_OperatorID
             
   -- Sample Message  
   -- prTaskLUTSendLot('03-01-13 16:06:23','572517045','shong','225','50','0000038489','1')  
   SELECT @c_TaskType = td.TaskType  
         ,@c_StorerKey = td.Storerkey  
         ,@c_SKU = td.Sku  
         ,@n_TaskQty = td.Qty   
         ,@c_FromLoc = FromLoc
         ,@c_FromID  = FromId
         ,@c_ToLoc   = ToLoc
         ,@c_ToID    = ToID
   FROM TaskDetail td WITH (NOLOCK)  
   WHERE td.TaskDetailKey = @c_TaskDetailKey   
  
   SET @c_CaptureLottable = '0'
   SELECT @c_CaptureLottable = ISNULL(sc.SValue,'0'),   
          @c_LottableDesc    = ISNULL(sc.ConfigDesc,'Lottable ')    
   FROM StorerConfig sc WITH (NOLOCK)   
   WHERE sc.StorerKey = @c_StorerKey  
   AND   sc.ConfigKey = 'VoicePK_CaptureLottable'  
     
   -- If Capture Lottable turn on, confirm Pick 1st.  
   IF @c_CaptureLottable IN ('1','2','3','4','6','7','8','9','10','11','12','13','14','15')  
   BEGIN  
-- (ChewKP01)      
--      SET @c_Lottable01Label = ''  
--      SET @c_Lottable02Label = ''  
--      SET @c_Lottable03Label = ''  
--      SET @c_Lottable04Label = ''   
--            
--      SELECT   
--          @c_Lottable01Label = ISNULL(SKU.Lottable01LABEL, ''),  
--          @c_Lottable02Label = ISNULL(SKU.Lottable02LABEL, ''),  
--          @c_Lottable03Label = ISNULL(SKU.Lottable03LABEL, ''),  
--          @c_Lottable04Label = ISNULL(SKU.Lottable04LABEL, '')      
--      FROM SKU WITH (NOLOCK)   
--      WHERE SKU.Storerkey = @c_Storerkey   
--      AND   SKU.Sku = @c_Sku   
              
      -- Assume the ispLottableRule_Wrapper will return correct Lottable01 - 05  
      DECLARE @c_SQL NVARCHAR(4000)  
        
      SET @c_SQL =    
      N'DECLARE CUR_PickDetail_Records CURSOR FAST_FORWARD READ_ONLY FOR ' +   
      N'SELECT P.PickDetailKey, P.Qty, P.LOT ' +   
      N'FROM PICKDETAIL p WITH (NOLOCK) ' +   
      N'JOIN LOTATTRIBUTE l WITH (NOLOCK) ON p.Lot = l.Lot  ' +   
      N'WHERE  p.TaskDetailKey = @c_TaskDetailKey ' +   
      N'AND    p.Storerkey = @c_StorerKey ' +   
      N'AND    p.SKU = @c_SKU ' +   
      N'AND    p.[Status] < ''5'' '   
            
      EXEC sp_ExecuteSQL @c_SQL, N'@c_StorerKey NVARCHAR(15), @c_SKU NVARCHAR(20), @c_TaskDetailKey NVARCHAR(10)',   
           @c_StorerKey, @c_SKU, @c_TaskDetailKey   
  
           
      OPEN CUR_PickDetail_Records  
        
      FETCH NEXT FROM CUR_PickDetail_Records INTO @c_PickDetailKey, @n_PickDetailQty, @c_LOT   
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
           
         SELECT @c_Lottable01 = l.Lottable01,   
                @c_Lottable02 = l.Lottable02,  
                @c_Lottable03 = l.Lottable03,   
                @d_Lottable04 = l.Lottable04,   
                @d_Lottable05 = l.Lottable05,
                @c_Lottable06 = l.Lottable06,
                @c_Lottable07 = l.Lottable07,
                @c_Lottable08 = l.Lottable08,
                @c_Lottable09 = l.Lottable09,
                @c_Lottable10 = l.Lottable10,
                @c_Lottable11 = l.Lottable11,
                @c_Lottable12 = l.Lottable12,
                @d_Lottable13 = l.Lottable13,
                @d_Lottable14 = l.Lottable14,
                @d_Lottable15 = l.Lottable15
         FROM LOTATTRIBUTE l WITH (NOLOCK)  
         WHERE l.Lot = @c_LOT  
         
         IF @@ROWCOUNT=0  
         BEGIN  
            GOTO GET_NEXT_Pickdetail  
         END   
         
         -- (ChewKP01)
         IF @c_CaptureLottable = '1'
         BEGIN
            IF @c_Lottable = LEFT(RTRIM(@c_Lottable01),4) 
            BEGIN
               SET @b_LotFound = 1  
            END
         END
         ELSE IF @c_CaptureLottable = '2'
         BEGIN
            IF @c_Lottable = LEFT(RTRIM(@c_Lottable02),4) 
            BEGIN
               SET @b_LotFound = 1  
            END
         END
         ELSE IF @c_CaptureLottable = '3'
         BEGIN
            IF @c_Lottable = LEFT(RTRIM(@c_Lottable03),4) 
            BEGIN
               SET @b_LotFound = 1  
            END
         END
         ELSE IF @c_CaptureLottable = '4'
         BEGIN
            IF @c_Lottable = LEFT(RTRIM(@d_Lottable04),4) 
            BEGIN
               SET @b_LotFound = 1  
            END
         END
         ELSE IF @c_CaptureLottable = '6'
         BEGIN
            IF @c_Lottable = LEFT(RTRIM(@c_Lottable06),4) 
            BEGIN
               SET @b_LotFound = 1  
            END
         END
         ELSE IF @c_CaptureLottable = '7'
         BEGIN
            IF @c_Lottable = LEFT(RTRIM(@c_Lottable07),4) 
            BEGIN
               SET @b_LotFound = 1  
            END
         END
         ELSE IF @c_CaptureLottable = '8'
         BEGIN
            IF @c_Lottable = LEFT(RTRIM(@c_Lottable08),4) 
            BEGIN
               SET @b_LotFound = 1  
            END
         END
         ELSE IF @c_CaptureLottable = '9'
         BEGIN
            IF @c_Lottable = LEFT(RTRIM(@c_Lottable09),4) 
            BEGIN
               SET @b_LotFound = 1  
            END
         END
         ELSE IF @c_CaptureLottable = '10'
         BEGIN
            IF @c_Lottable = LEFT(RTRIM(@c_Lottable10),4) 
            BEGIN
               SET @b_LotFound = 1  
            END
         END
         ELSE IF @c_CaptureLottable = '11'
         BEGIN
            IF @c_Lottable = LEFT(RTRIM(@c_Lottable11),4) 
            BEGIN
               SET @b_LotFound = 1  
            END
         END
         ELSE IF @c_CaptureLottable = '12'
         BEGIN
            IF @c_Lottable = LEFT(RTRIM(@c_Lottable12),4) 
            BEGIN
               SET @b_LotFound = 1  
            END
         END
         ELSE IF @c_CaptureLottable = '13'
         BEGIN
            IF @c_Lottable = LEFT(RTRIM(@d_Lottable13),4) 
            BEGIN
               SET @b_LotFound = 1  
            END
         END
         ELSE IF @c_CaptureLottable = '14'
         BEGIN
            IF @c_Lottable = LEFT(RTRIM(@d_Lottable14),4) 
            BEGIN
               SET @b_LotFound = 1  
            END
         END
         ELSE IF @c_CaptureLottable = '15'
         BEGIN
            IF @c_Lottable = LEFT(RTRIM(@d_Lottable15),4) 
            BEGIN
               SET @b_LotFound = 1  
            END
         END
         
         IF @b_LotFound = 0 
         BEGIN
            GOTO GET_NEXT_Pickdetail  
         END
           
--         SET @c_SysLottable = ''  
--         SET @c_SysLottable = CASE @c_CaptureLottable     
--                           WHEN '1' THEN @c_Lottable01  
--                           WHEN '2' THEN @c_Lottable02     
--                           WHEN '3' THEN @c_Lottable03  
--                           WHEN '4' THEN CONVERT(VARCHAR(20), @d_Lottable04, 112)      
--                       END                          
  
--         SELECT '@c_Lottable01: ' + @c_Lottable01 + NVARCHAR(13) +   
--                '@c_Lottable02: ' + @c_Lottable02 + NVARCHAR(13) +   
--                '@c_Lottable03: ' + @c_Lottable03 + NVARCHAR(13) +   
--                '@c_CaptureLottable: ' + @c_CaptureLottable + NVARCHAR(13) +  
--                '@c_SysLottable: ' + @c_SysLottable + NVARCHAR(13) +  
--                'RIGHT(@c_SysLottable,3): ' + RIGHT(RTRIM(@c_SysLottable),3)  
  
                           
--         IF ( RIGHT(RTRIM(@c_SysLottable),3) <> ISNULL(RTRIM(@c_Lottable),'') AND   
--              ISNULL(RTRIM(@c_Lottable),'') <> '' )                
--         BEGIN  
--            GOTO GET_NEXT_Pickdetail              
--         END  
                      
         --SET @b_LotFound = 1  
                
         IF @n_QtyPicked <= 0   
         BEGIN  
            BREAK  
         END  
           
         SET @n_QtyToTake = 0   
           
         IF @n_PickDetailQty > @n_QtyPicked  
            SET @n_QtyToTake = @n_QtyPicked  
         ELSE  
            SET @n_QtyToTake = @n_PickDetailQty  
           
         IF @n_QtyToTake < @n_PickDetailQty  
         BEGIN  
            -- split line   
            EXECUTE dbo.nspg_GetKey  
                     'PICKDETAILKEY',  
                     10 ,  
                     @c_NewPickDetailKey OUTPUT,  
                     @b_Success          OUTPUT,  
                     @n_Error            OUTPUT,  
                     @c_ErrMsg           OUTPUT  
  
            IF @b_Success <> 1  
            BEGIN  
               SET @n_Continue = 3  
               SET @c_ErrMsg = 'Get PickDetail Key Failed (isp_TCP_VC_prTaskLUTSendLot).'  
               GOTO QUIT_SP  
            END  
              
            INSERT INTO dbo.PICKDETAIL (  
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,  
               Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,  
               DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,  
               QTY, TaskDetailKey,   
               TrafficCop,  
               OptimizeCop)  
            SELECT  
               CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,  
               (@n_PickDetailQty - @n_QtyToTake),   
               QTYMoved,  
               '4', -- Status  
               DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,  
               DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @c_NewPickDetailKey,  
               (@n_PickDetailQty - @n_QtyToTake), -- QTY  
               TaskDetailKey,   
               NULL, --TrafficCop,  
               '1'   --OptimizeCop  
            FROM dbo.PickDetail WITH (NOLOCK)  
            WHERE PickDetailKey = @c_PickDetailKey                 
  
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_Continue = 3  
               SET @c_ErrMsg = 'Insert PickDetail Failed (isp_TCP_VC_prTaskLUTSendLot).'  
               GOTO QUIT_SP  
            END  
            
            UPDATE dbo.PickDetail WITH (ROWLOCK)  
            SET QTY        = @n_QtyToTake,  
                Trafficcop = NULL
            WHERE PickDetailKey = @c_PickDetailKey  
     
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_Continue = 3  
               SET @c_ErrMsg = 'Update PickDetail Failed (isp_TCP_VC_prTaskODRPicked).'  
               GOTO QUIT_SP  
            END
            
         END  
         
         UPDATE dbo.PickDetail WITH (ROWLOCK)  
            SET [STATUS]      = '5'
         WHERE PickDetailKey  = @c_PickDetailKey  
  
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_Continue = 3  
            SET @c_ErrMsg = 'Update PickDetail Failed (isp_TCP_VC_prTaskLUTSendLot).'  
            GOTO QUIT_SP  
         END  
         
         -- (ChewKP01)
         --Add to RDT.RDTEventLog
         EXEC RDT.rdt_STD_EventLog
              @cActionType      = '3', 
              @cUserID          = @c_OperatorID,
              @nMobileNo        = @n_Mobile,
              @nFunctionID      = @n_Func,
              @cFacility        = @c_Facility,
              @cStorerKey       = @c_StorerKey,
              @cLocation        = @c_FromLoc,  
              @cToLocation      = @c_ToLoc,  
              @cID              = @c_FromID,  
              @cToID            = @c_ToID,  
              @cSKU             = @c_SKU,  
              @nQTY             = @n_QtyPicked,
              @cLot             = @c_LOT,  
              @cRefNo1          = @c_DevSerialNo,
              @cTaskDetailKey   = @c_TaskDetailKey
              
           
         SET @n_QtyPicked = @n_QtyPicked - @n_QtyToTake  
           
  
   GET_NEXT_Pickdetail:           
           
         FETCH NEXT FROM CUR_PickDetail_Records INTO @c_PickDetailKey, @n_PickDetailQty, @c_LOT   
      END  
      CLOSE CUR_PickDetail_Records  
      DEALLOCATE CUR_PickDetail_Records  
   END   
   IF @b_LotFound = 0   
   BEGIN  
      SET @c_ErrorCode ='99'  
      SET @c_Message = @c_LottableDesc + N' Is Wrong'  
      
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' DeviceSerialNo: ' + @c_DevSerialNo  +  @c_NewLineChar   
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Lottable: ' + @c_CaptureLottable + @c_NewLineChar 
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' LottableValue: ' + @c_Lottable + @c_NewLineChar  
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Qty: ' + CAST(@n_QtyPicked AS NVARCHAR(5)) + @c_NewLineChar  
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' UserKey: ' + @c_OperatorID + @c_NewLineChar  
         
      EXEC nspLogAlert
              @c_modulename         = 'isp_TCP_VC_prTaskLUTSendLot'     
            , @c_AlertMessage       = @c_AlertMessage   
            , @n_Severity           = '5'       
            , @b_success            = @b_success        
            , @n_err                = @c_ErrorCode            
            , @c_errmsg             = @c_Message         
            , @c_Activity           = 'SendLot'
            , @c_Storerkey          = @c_StorerKey      
            , @c_SKU                = @c_SKU            
            , @c_UOM                = ''            
            , @c_UOMQty             = ''         
            , @c_Qty                = @n_QtyPicked         
            , @c_Lot                = ''         
            , @c_Loc                = ''            
            , @c_ID                 = ''               
            , @c_TaskDetailKey      = @c_TaskDetailKey
            , @c_UCCNo              = ''
                  
      
   END  
  
QUIT_SP:     
   -- Return Error Message If Batch No Not match   
   SET @c_RtnMessage = @c_ErrorCode + ',''' + RTRIM(@c_Message) + ''''   
     
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0     
   BEGIN    
      SET @c_RtnMessage = "0,"     
   END    
   

    
END


GO