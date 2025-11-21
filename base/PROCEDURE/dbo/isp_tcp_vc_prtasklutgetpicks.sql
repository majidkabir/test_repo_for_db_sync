SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/          
/* Store Procedure:  isp_TCP_VC_prTaskLUTGetPicks                       */          
/* Creation Date: 26-Feb-2013                                           */          
/* Copyright: IDS                                                       */          
/* Written by: Shong                                                    */          
/*                                                                      */          
/* Purposes: The message retrieves individual pick item records for a   */          
/*           picking assignment from the host system.                   */          
/*                                                                      */          
/* Updates:                                                             */          
/* Date         Author    Purposes                                      */     
/* 27-03-2013   ChewKP    Revise (ChewKP01)                             */       
/* 02-Jun-2014  TKLIM     Added Lottables 06-15                         */
/************************************************************************/          
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTGetPicks] (          
    @c_TranDate            NVARCHAR(20)          
   ,@c_DevSerialNo         NVARCHAR(20)          
   ,@c_OperatorID          NVARCHAR(20)          
   ,@c_GroupID             NVARCHAR(20)  -- SourceKey -- (ChewKP01)  
   ,@c_ShortSkipFlag       NVARCHAR(10)  -- Set to 1 only when the VoiceApplication is requesting to go back for shorts before passing the assignment          
   ,@c_GoBackShort         NVARCHAR(10)          
   ,@c_OrderType           NVARCHAR(10)  -- 0 = normal order, 1 = reverse order          
   ,@n_SerialNo            INT          
   ,@c_RtnMessage          NVARCHAR(4000) OUTPUT              
   ,@b_Success             INT = 1 OUTPUT          
   ,@n_Error               INT = 0 OUTPUT          
   ,@c_ErrMsg              NVARCHAR(255) = '' OUTPUT           
          
)          
AS          
BEGIN          
   DECLARE @c_ErrorCode          NVARCHAR(20) --  0: No error. The VoiceApplication proceeds.          
                                            -- 98: Critical error. If this error is received,           
                                            --     the VoiceApplication speaks the error message, and forces the operator to sign off.           
                                            -- 99: Informational error. The VoiceApplication speaks the informational error message,           
                                            --     but does not force the operator to sign off.          
         , @c_Message            NVARCHAR(400)          
         , @c_PickStatus         NVARCHAR(1)     -- N = not picked, N = not picked, S = skipped, G = go back for short               
         , @c_BaseItem           NVARCHAR(1)     -- 0 = item is not spoken in base item, 1 = item is spoken in base item summary          
         , @c_Sequence           NVARCHAR(10) -- TaskDetailKey           
         , @c_LOC                NVARCHAR(10)          
         , @c_Region             NVARCHAR(10) -- Numeric position where items for the work ID should be placed.          
         , @c_PreAisleDirec      NVARCHAR(10) -- Pre-Aisle Direction          
         , @c_Aisle              NVARCHAR(10) -- Aisle          
         , @c_PostAisleDirec     NVARCHAR(50) -- Post-Aisle Direction          
         , @c_Bay                NVARCHAR(10) -- Location Bay          
         , @n_QtyToPick          INT                    
         , @c_UOMDesc            NVARCHAR(50)  -- UOM description             
         , @c_SKU                NVARCHAR(20)            
         , @c_VariableWeight     NVARCHAR(1)      -- 0 = device does not prompt the operator to speak weight(s) for the pick          
                                              -- 1 = device prompts the operator to speak weight(s) for the pick          
         , @c_WeightMin          NVARCHAR(10)  -- Only required when the variable weight field = 1.          
         , @c_WeightMax          NVARCHAR(10)  -- Only required when the variable weight field = 1.                   
         , @n_QtyPicked          INT          
         , @c_CheckDigit         NVARCHAR(10)  -- Check digits of the pickæs location.          
         , @c_ScanSKU            NVARCHAR(20)          
         , @c_SpokenSKU          NVARCHAR(5)          
         , @c_SKUDesc            NVARCHAR(60)          
         , @c_Size               NVARCHAR(10)          
         , @c_UPC                NVARCHAR(20)          
         , @c_AssignID           NVARCHAR(10)  -- TaskDetailKey          
         , @c_AssignIDDesc       NVARCHAR(100)          
         , @c_DeliveryLoc        NVARCHAR(10)          
         , @c_CombineFlag        NVARCHAR(1)          
         , @c_Store              NVARCHAR(100)          
         , @c_CaseLblChkDigit    NVARCHAR(10)          
         , @c_TargetContainer    NVARCHAR(20)       -- Alter Column Length (ChewKP01)   
         , @c_CaptureLottable    NVARCHAR(1)       -- 0 = No, 1=Yes                 
         , @c_PickMessage        NVARCHAR(250)          
         , @c_VerifyLoc          NVARCHAR(1) 
         , @c_CycleCount         NVARCHAR(1) 
         , @c_CaptureSerialNo    NVARCHAR(1) 
         , @c_SpeakSKUDesc       NVARCHAR(1) 
         , @c_PackKey            NVARCHAR(10)
         , @c_UOM                NVARCHAR(5) 
         , @c_OrderKey           NVARCHAR(10)
         , @c_FromID             NVARCHAR(18)
         , @c_StorerKey          NVARCHAR(15)
         , @c_Status             NVARCHAR(10)
         , @c_AreaKey            NVARCHAR(10)
         , @c_NextTaskdetailkey  NVARCHAR(10)
         , @c_TTMTasktype        NVARCHAR(20)
         , @c_RefKey01           NVARCHAR(20)
         , @c_RefKey02           NVARCHAR(20)
         , @c_RefKey03           NVARCHAR(20)
         , @c_RefKey04           NVARCHAR(20)
         , @c_RefKey05           NVARCHAR(20)
         , @c_SuggToLoc          NVARCHAR(10)
         , @c_outstring          NVARCHAR(255)
         , @c_TaskDetailKey      NVARCHAR(10)
         , @n_Counter            INT  
         , @n_GetNextTask        INT  
         , @c_PickZone           NVARCHAR(10)
         , @c_Aisle_Desc         NVARCHAR(10)
                   
   DECLARE @c_LottableDesc       NVARCHAR(60)
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
         , @c_LangCode           NVARCHAR(10)
         , @c_LottableValue      NVARCHAR(18)
     
   SET @c_LangCode               = 'ENG'             
   SET @c_PickStatus             = N'N'   
   SET @c_BaseItem               = N'0'   
   SET @c_Sequence               = N'1'   
   SET @c_VariableWeight         = N'0'   
   SET @c_WeightMin              = N'0'   
   SET @c_WeightMax              = N'0'   
   SET @n_QtyPicked              = 0   
   SET @c_ScanSKU                = N''  
   SET @c_SpokenSKU              = N''   
   SET @c_CombineFlag            = N'0'     
   SET @c_CaseLblChkDigit        = N''  
   SET @c_TargetContainer        = N''  
   SET @c_CaptureLottable        = N'0'  
   SET @c_PickMessage            = N''       
   SET @c_VerifyLoc              = N'0'     
   SET @c_CycleCount             = N'0'      
   SET @c_CaptureSerialNo        = N'0'         
   SET @c_SpeakSKUDesc           = N'1'        
   SET @c_FromID                 = N''                
   SET @c_Bay                    = N''     
   SET @c_Lottable01Label        = N''
   SET @c_Lottable02Label        = N''
   SET @c_Lottable03Label        = N''
   SET @c_Lottable04Label        = N''
   SET @c_Lottable06Label        = N''
   SET @c_Lottable07Label        = N''
   SET @c_Lottable08Label        = N''
   SET @c_Lottable09Label        = N''
   SET @c_Lottable10Label        = N''
   SET @c_Lottable11Label        = N''
   SET @c_Lottable12Label        = N''
   SET @c_Lottable13Label        = N''
   SET @c_Lottable14Label        = N''
   SET @c_Lottable15Label        = N''
   SET @c_LottableDesc           = N''       
   SET @c_TaskDetailKey          = '' 
   SET @n_Counter                = 1  
   SET @c_RtnMessage             = ''     
   SET @c_ErrorCode              = 0     
   SET @c_Message                = '' 
   SET @n_GetNextTask            = 0  
   SET @c_Aisle_Desc             = N''
   SET @c_CheckDigit             = ''
         
   SELECT @c_TaskDetailKey = V_TaskDetailKey     
   FROM rdt.rdtMobRec WITH (NOLOCK)     
   WHERE DeviceID = @c_DevSerialNo     
  
   SELECT @c_LangCode = r.DefaultLangCode        
   FROM rdt.RDTUser r (NOLOCK)        
   WHERE r.UserName = @c_OperatorID                    
                 
   GenGetPicks:    
            
   --IF @c_Status = '3'  -- (ChewKP01)         
   BEGIN      
      DECLARE CursorGetPicks CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
                   
      SELECT TOP 1 td.FromLoc,           
             td.AreaKey,           
             --'Facility ' + CASE WHEN ISNULL(RTRIM(f.Descr), '') = '' THEN l.Facility ELSE f.Descr END,          
             '', -- ISNULL(L.PickZone, ''),   
             L.LocAisle,           
             '',          
             ISNULL(L.LocBay,''),          
             L.LocAisle,           
             TD.Qty,           
             SKU.PackKey,     
             td.UOMQty,           
             TD.Sku,          
             L.LocCheckDigit,           
             SKU.DESCR,          
             sku.[Size],           
             '', --SKU.ALTSKU,           
             TD.TaskDetailKey, -- (ChewKP01)  
             TD.TaskDetailKey,           
             '', --ISNULL(TD.ToLoc,''),          
             TD.OrderKey,           
             ISNULL(TD.FromID, ''),          
             TD.Storerkey,          
             ISNULL(SKU.Lottable01LABEL, ''),
             ISNULL(SKU.Lottable02LABEL, ''),
             ISNULL(SKU.Lottable03LABEL, ''),
             ISNULL(SKU.Lottable04LABEL, ''),
             ISNULL(SKU.Lottable06LABEL, ''),
             ISNULL(SKU.Lottable07LABEL, ''),
             ISNULL(SKU.Lottable08LABEL, ''),
             ISNULL(SKU.Lottable09LABEL, ''),
             ISNULL(SKU.Lottable10LABEL, ''),
             ISNULL(SKU.Lottable11LABEL, ''),
             ISNULL(SKU.Lottable12LABEL, ''),
             ISNULL(SKU.Lottable13LABEL, ''),
             ISNULL(SKU.Lottable14LABEL, ''),
             ISNULL(SKU.Lottable15LABEL, ''),
             '' -- TD.DropID  
      FROM TaskDetail td WITH (NOLOCK)           
      JOIN SKU WITH (NOLOCK) ON SKU.Storerkey = td.Storerkey AND SKU.Sku = td.Sku           
      JOIN LOC l WITH (NOLOCK) ON td.FromLoc = l.Loc          
      JOIN FACILITY f WITH (NOLOCK) ON f.Facility = l.Facility           
      WHERE td.SourceKey = @c_GroupID        
      AND   td.UserKey = @c_OperatorID          
      AND   td.[Status] = '3'           
      Order by l.logicallocation, td.sku
        
        
      OPEN CursorGetPicks              
     
      FETCH NEXT FROM CursorGetPicks INTO   
               @c_LOC               , @c_Region             , @c_PickZone           , @c_Aisle              , @c_PostAisleDirec  
             , @c_Bay               , @c_Aisle              , @n_QtyToPick          , @c_PackKey            , @c_UOM  
             , @c_SKU               , @c_CheckDigit         , @c_SKUDesc            , @c_Size               , @c_UPC  
             , @c_AssignID          , @c_AssignIDDesc       , @c_DeliveryLoc        , @c_OrderKey           , @c_FromID  
             , @c_StorerKey         , @c_TargetContainer    
             , @c_Lottable01Label   , @c_Lottable02Label    , @c_Lottable03Label    , @c_Lottable04Label    
             , @c_Lottable06Label   , @c_Lottable07Label    , @c_Lottable08Label    , @c_Lottable09Label    , @c_Lottable10Label
             , @c_Lottable11Label   , @c_Lottable12Label    , @c_Lottable13Label    , @c_Lottable14Label    , @c_Lottable15Label
              
      WHILE @@FETCH_STATUS <> -1       
      BEGIN        
  
         --SET @c_SKUDesc = MASTER.dbo.fn_ANSI2UNICODE(@c_SKUDesc, 'CHT')        
                      
         -- Flag to indicate whether the VoiceApplication should capture the serial           
         -- number of each individual item picked          
         SELECT @c_CaptureSerialNo = ISNULL(sc.SValue,'0')           
         FROM StorerConfig sc WITH (NOLOCK)            
         WHERE sc.StorerKey = @c_StorerKey           
         AND   sc.ConfigKey = 'VoicePK_CaptureSerialNo'           
                
         -- Flag to indicate whether the VoiceApplication should speak the item description           
         -- of the item being picked in the pick prompt.          
         SELECT @c_SpeakSKUDesc = ISNULL(sc.SValue,'0')   
         FROM StorerConfig sc WITH (NOLOCK)            
         WHERE sc.StorerKey = @c_StorerKey           
         AND   sc.ConfigKey = 'VoicePK_SpeakSKUDesc'           
                         
         SET @c_Store = ''              
         SELECT @c_Store = ISNULL(o.ConsigneeKey,'')          
         FROM ORDERS o WITH (NOLOCK)          
         JOIN STORER s WITH (NOLOCK) ON s.StorerKey = o.ConsigneeKey          
                   
                         
         SET @c_CaptureLottable = '0'          
         SELECT @c_CaptureLottable = ISNULL(sc.SValue,'0'),         
                  @c_LottableDesc = CASE WHEN sc.SValue IN ('1','2','3','4') THEN sc.ConfigDesc ELSE '' END           
         FROM StorerConfig sc WITH (NOLOCK)           
         WHERE sc.StorerKey = @c_StorerKey          
         AND   sc.ConfigKey = 'VoicePK_CaptureLottable'          
         
                   
         IF @c_CaptureLottable IN ('1','2','3','4','6','7','8','9','10','11','12','13','14','15')           
         BEGIN          
            
            IF @c_CaptureLottable = '1'
            BEGIN
               
               SELECT @c_LottableDesc = UDF01
               FROM dbo.Codelkup WITH (NOLOCK)
               WHERE ListName = 'Lottable01' 
               AND Code = @c_Lottable01Label
               
               SELECT @c_LottableValue = ISNULL(LA.Lottable01,'')
               FROM dbo.LotAttribute LA WITH (NOLOCK)
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.Lot = LA.Lot
               WHERE PD.TaskDetailKey = @c_TaskDetailKey
               AND PD.StorerKey = @c_StorerKey
               AND PD.SKU = @c_SKU
                
            END
            ELSE IF @c_CaptureLottable = '2'
            BEGIN
               
               SELECT @c_LottableDesc = UDF01
               FROM dbo.Codelkup WITH (NOLOCK)
               WHERE ListName = 'Lottable02' 
               AND Code = @c_Lottable02Label
               
               SELECT @c_LottableValue = ISNULL(LA.Lottable02,'')
               FROM dbo.LotAttribute LA WITH (NOLOCK)
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.Lot = LA.Lot
               WHERE PD.TaskDetailKey = @c_TaskDetailKey
               AND PD.StorerKey = @c_StorerKey
               AND PD.SKU = @c_SKU
               
               IF @c_LottableValue = ''
               BEGIN
                  SELECT @c_LottableDesc = UDF01
                  FROM dbo.Codelkup WITH (NOLOCK)
                  WHERE ListName = 'Lottable04' 
                  AND Code = @c_Lottable02Label
                  
                  SELECT @c_LottableValue = ISNULL(LA.Lottable04,'')
                  FROM dbo.LotAttribute LA WITH (NOLOCK)
                  INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.Lot = LA.Lot
                  WHERE PD.TaskDetailKey = @c_TaskDetailKey
                  AND PD.StorerKey = @c_StorerKey
                  AND PD.SKU = @c_SKU
                  
               END
               
               
            END
            ELSE IF @c_CaptureLottable = '3'
            BEGIN
               
               SELECT @c_LottableDesc = UDF01
               FROM dbo.Codelkup WITH (NOLOCK)
               WHERE ListName = 'Lottable03' 
               AND Code = @c_Lottable03Label
               
               SELECT @c_LottableValue = ISNULL(LA.Lottable03,'')
               FROM dbo.LotAttribute LA WITH (NOLOCK)
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.Lot = LA.Lot
               WHERE PD.TaskDetailKey = @c_TaskDetailKey
               AND PD.StorerKey = @c_StorerKey
               AND PD.SKU = @c_SKU
               
            END
            ELSE IF @c_CaptureLottable = '4'
            BEGIN
               
               SELECT @c_LottableDesc = UDF01
               FROM dbo.Codelkup WITH (NOLOCK)
               WHERE ListName = 'Lottable04' 
               AND Code = @c_Lottable04Label
               
               SELECT @c_LottableValue = ISNULL(CAST (LA.Lottable04 AS NVARCHAR(18)),'')
               FROM dbo.LotAttribute LA WITH (NOLOCK)
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.Lot = LA.Lot
               WHERE PD.TaskDetailKey = @c_TaskDetailKey
               AND PD.StorerKey = @c_StorerKey
               AND PD.SKU = @c_SKU
               
            END
            ELSE IF @c_CaptureLottable = '6'
            BEGIN
               
               SELECT @c_LottableDesc = UDF01
               FROM dbo.Codelkup WITH (NOLOCK)
               WHERE ListName = 'Lottable06' 
               AND Code = @c_Lottable06Label
               
               SELECT @c_LottableValue = ISNULL(LA.Lottable06,'')
               FROM dbo.LotAttribute LA WITH (NOLOCK)
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.Lot = LA.Lot
               WHERE PD.TaskDetailKey = @c_TaskDetailKey
               AND PD.StorerKey = @c_StorerKey
               AND PD.SKU = @c_SKU
               
            END
            ELSE IF @c_CaptureLottable = '7'
            BEGIN
               
               SELECT @c_LottableDesc = UDF01
               FROM dbo.Codelkup WITH (NOLOCK)
               WHERE ListName = 'Lottable07' 
               AND Code = @c_Lottable07Label
               
               SELECT @c_LottableValue = ISNULL(LA.Lottable07,'')
               FROM dbo.LotAttribute LA WITH (NOLOCK)
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.Lot = LA.Lot
               WHERE PD.TaskDetailKey = @c_TaskDetailKey
               AND PD.StorerKey = @c_StorerKey
               AND PD.SKU = @c_SKU
               
            END
            ELSE IF @c_CaptureLottable = '8'
            BEGIN
               
               SELECT @c_LottableDesc = UDF01
               FROM dbo.Codelkup WITH (NOLOCK)
               WHERE ListName = 'Lottable08' 
               AND Code = @c_Lottable08Label
               
               SELECT @c_LottableValue = ISNULL(LA.Lottable08,'')
               FROM dbo.LotAttribute LA WITH (NOLOCK)
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.Lot = LA.Lot
               WHERE PD.TaskDetailKey = @c_TaskDetailKey
               AND PD.StorerKey = @c_StorerKey
               AND PD.SKU = @c_SKU
               
            END
            ELSE IF @c_CaptureLottable = '9'
            BEGIN
               
               SELECT @c_LottableDesc = UDF01
               FROM dbo.Codelkup WITH (NOLOCK)
               WHERE ListName = 'Lottable09' 
               AND Code = @c_Lottable09Label
               
               SELECT @c_LottableValue = ISNULL(LA.Lottable09,'')
               FROM dbo.LotAttribute LA WITH (NOLOCK)
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.Lot = LA.Lot
               WHERE PD.TaskDetailKey = @c_TaskDetailKey
               AND PD.StorerKey = @c_StorerKey
               AND PD.SKU = @c_SKU
               
            END
            ELSE IF @c_CaptureLottable = '10'
            BEGIN
               
               SELECT @c_LottableDesc = UDF01
               FROM dbo.Codelkup WITH (NOLOCK)
               WHERE ListName = 'Lottable10' 
               AND Code = @c_Lottable10Label
               
               SELECT @c_LottableValue = ISNULL(LA.Lottable10,'')
               FROM dbo.LotAttribute LA WITH (NOLOCK)
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.Lot = LA.Lot
               WHERE PD.TaskDetailKey = @c_TaskDetailKey
               AND PD.StorerKey = @c_StorerKey
               AND PD.SKU = @c_SKU
               
            END
            ELSE IF @c_CaptureLottable = '11'
            BEGIN
               
               SELECT @c_LottableDesc = UDF01
               FROM dbo.Codelkup WITH (NOLOCK)
               WHERE ListName = 'Lottable11' 
               AND Code = @c_Lottable11Label
               
               SELECT @c_LottableValue = ISNULL(LA.Lottable11,'')
               FROM dbo.LotAttribute LA WITH (NOLOCK)
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.Lot = LA.Lot
               WHERE PD.TaskDetailKey = @c_TaskDetailKey
               AND PD.StorerKey = @c_StorerKey
               AND PD.SKU = @c_SKU
               
            END
            ELSE IF @c_CaptureLottable = '12'
            BEGIN
               
               SELECT @c_LottableDesc = UDF01
               FROM dbo.Codelkup WITH (NOLOCK)
               WHERE ListName = 'Lottable12' 
               AND Code = @c_Lottable12Label
               
               SELECT @c_LottableValue = ISNULL(LA.Lottable12,'')
               FROM dbo.LotAttribute LA WITH (NOLOCK)
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.Lot = LA.Lot
               WHERE PD.TaskDetailKey = @c_TaskDetailKey
               AND PD.StorerKey = @c_StorerKey
               AND PD.SKU = @c_SKU
               
            END
            ELSE IF @c_CaptureLottable = '13'
            BEGIN
               
               SELECT @c_LottableDesc = UDF01
               FROM dbo.Codelkup WITH (NOLOCK)
               WHERE ListName = 'Lottable13' 
               AND Code = @c_Lottable13Label
               
               SELECT @c_LottableValue = ISNULL(CAST (LA.Lottable13 AS NVARCHAR(18)),'')
               FROM dbo.LotAttribute LA WITH (NOLOCK)
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.Lot = LA.Lot
               WHERE PD.TaskDetailKey = @c_TaskDetailKey
               AND PD.StorerKey = @c_StorerKey
               AND PD.SKU = @c_SKU
               
            END
            ELSE IF @c_CaptureLottable = '14'
            BEGIN
               
               SELECT @c_LottableDesc = UDF01
               FROM dbo.Codelkup WITH (NOLOCK)
               WHERE ListName = 'Lottable14' 
               AND Code = @c_Lottable14Label
               
               SELECT @c_LottableValue = ISNULL(CAST (LA.Lottable14 AS NVARCHAR(18)),'')
               FROM dbo.LotAttribute LA WITH (NOLOCK)
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.Lot = LA.Lot
               WHERE PD.TaskDetailKey = @c_TaskDetailKey
               AND PD.StorerKey = @c_StorerKey
               AND PD.SKU = @c_SKU
               
            END
            ELSE IF @c_CaptureLottable = '15'
            BEGIN
               
               SELECT @c_LottableDesc = UDF01
               FROM dbo.Codelkup WITH (NOLOCK)
               WHERE ListName = 'Lottable15' 
               AND Code = @c_Lottable15Label
               
               SELECT @c_LottableValue = ISNULL(CAST (LA.Lottable15 AS NVARCHAR(18)),'')
               FROM dbo.LotAttribute LA WITH (NOLOCK)
               INNER JOIN dbo.PickDetail PD WITH (NOLOCK) ON PD.Lot = LA.Lot
               WHERE PD.TaskDetailKey = @c_TaskDetailKey
               AND PD.StorerKey = @c_StorerKey
               AND PD.SKU = @c_SKU
               
            END
            ELSE
            BEGIN
               SET @c_LottableDesc = 'None'     
            END
            
            
            IF @c_LottableDesc = 'None'          
            BEGIN          
               SET @c_CaptureLottable = '0'          
               SET @c_LottableDesc = ''          
            END           
            ELSE
            BEGIN
               --SET @c_PickMessage = ', SKU ' + @c_SKU + ' ' --+ @c_LottableDesc + ' ' + @c_LottableValue
               SET @c_PickMessage = [dbo].[fnc_GetVC_Message](@c_LangCode, 'vc_prTaskLUTGetPicks_06', N'SKU ',@c_SKU,'','','','')
               --SET @c_CaptureLottable = '1'
               SET @c_UPC = @c_LottableDesc + ' ' + @c_LottableValue
               --SET @c_UPC = @c_LottableDesc 
               --SET @c_LottableDesc = [dbo].[fnc_GetVC_Message](@c_LangCode, 'vc_prTaskLUTGetPicks_05', N'First 4 Digit of',@c_LottableDesc,'','','','')
               SET @c_CaptureLottable = '0'          
               SET @c_LottableDesc = ''          
               
            END
                                          
         END                   
         ELSE          
         BEGIN          
            SET @c_CaptureLottable = '0'          
            SET @c_LottableDesc = ''           
         END          
                      
         IF ISNULL(RTRIM(@c_UOM), '') = ''        
            SET @c_UOM = '6'        
                    
         SET @c_UOMDesc = 'Units'          
         SELECT @c_UOMDesc = CASE WHEN @c_LangCode = 'ENG' THEN C.Description ELSE ISNULL(C.[Long], 'Units') END           
         FROM CODELKUP c WITH (NOLOCK)           
         WHERE Code = @c_UOM           
         AND   c.LISTNAME = 'TMUOM'           
                
--         IF LEN(ISNULL(RTRIM(@c_FromID),'')) > 0           
--         BEGIN          
--            SET @c_PickMessage = [dbo].[fnc_GetVC_Message](@c_LangCode, 'vc_prTaskLUTGetPicks_01', N'Pallet ID %s',RIGHT(RTRIM(@c_FromID), 3),'','','','')          
--         END          
                         
           
         IF ISNULL(RTRIM(@c_Bay),'') = ''           
         BEGIN        
            SET @c_PostAisleDirec   = [dbo].[fnc_GetVC_Message](@c_LangCode, 'vc_prTaskLUTGetPicks_02', N'Go to Location %s',@c_LOC,'','','','')          
         END        
                    
                
         IF ISNULL(RTRIM(@c_PickZone),'') <> ''  
         BEGIN  
            SET @c_PreAisleDirec = [dbo].[fnc_GetVC_Message](@c_LangCode, 'vc_prTaskLUTGetPicks_04', N'Zone %s',@c_PickZone,'','','','')         
         END  
         ELSE  
            SET @c_PreAisleDirec = ''          
           
         SET @c_Aisle_Desc = '' 
         SET @c_Aisle_Desc = @c_Aisle 
--         SET @n_Counter = 1   
--         WHILE @n_Counter <= LEN(@c_Aisle)  
--         BEGIN  
--            SET @c_Aisle_Desc = ISNULL(RTRIM(@c_Aisle_Desc),'') +   
--                                CASE WHEN ISNULL(RTRIM(@c_Aisle_Desc),'') = '' THEN '' ELSE ' ' END +   
--                                SUBSTRING(@c_Aisle, @n_Counter, 1)  
--                                  
--           SET @n_Counter = @n_Counter + 1                       
--         END  
           
  
         SET @c_RtnMessage = RTRIM(@c_RtnMessage) +   
              CASE WHEN LEN(ISNULL(RTRIM(@c_RtnMessage),'')) = 0 THEN '' ELSE '<CR><LF>' END +   
              ISNULL(RTRIM(@c_PickStatus),'') + ',' +           
              ISNULL(RTRIM(@c_BaseItem),'')   + ',' +          
              ISNULL(RTRIM(@c_Sequence),'')   + ',' +           
              ISNULL(RTRIM(@c_LOC),'')        + ',' +          
              ISNULL(RTRIM(@c_Region),'')     + ',' +          
              ISNULL(RTRIM(@c_PreAisleDirec),'')  + ',' + -- 6          
              ISNULL(RTRIM(@c_Aisle_Desc),'')          + ',' + -- 7          
              ISNULL(RTRIM(@c_PostAisleDirec),'') + ',' + -- 8          
              ISNULL(RTRIM(@c_Bay),'') + N',' + -- 9 Slot          
              CAST(@n_QtyToPick AS NVARCHAR(10)) + ',' + -- 10          
              ISNULL(RTRIM(@c_UOMDesc),'') + ',' + -- 11          
              ISNULL(RTRIM(@c_SKU),'') +  ',' + -- 12          
              ISNULL(RTRIM(@c_VariableWeight),'') + ',' + -- 13          
              ISNULL(RTRIM(@c_WeightMin),'') + ',' +          
              ISNULL(RTRIM(@c_WeightMax),'') + ',' + -- 15          
              CAST(@n_QtyPicked AS NVARCHAR(10)) + ',' + -- 16          
              ISNULL(RTRIM(@c_CheckDigit),'')  + ',' + -- 17           
              ISNULL(RTRIM(@c_ScanSKU),'')  + ',' + -- 18          
              ISNULL(RTRIM(@c_SpokenSKU),'')  + ',' + -- 19           
              '''' + ISNULL(RTRIM(@c_SKUDesc),'')  + '''' + ',' + -- 20          
              ISNULL(RTRIM(@c_Size),'')  + ',' + -- 21          
              ISNULL(RTRIM(@c_UPC),'')  + ',' + -- 22          
              ISNULL(RTRIM(@c_AssignID),'')  + ',' + -- 23          
              ISNULL(RTRIM(@c_AssignIDDesc),'')  + ',' + -- 24          
              ISNULL(RTRIM(@c_DeliveryLoc),'')  + ',' + -- 25          
              ISNULL(RTRIM(@c_CombineFlag),'')  + ',' + -- 26          
              ISNULL(RTRIM(@c_Store),'')  + ',' + -- 27          
              ISNULL(RTRIM(@c_CaseLblChkDigit),'')  + ',' + -- 28          
              ISNULL(RTRIM(@c_TargetContainer),'')  + ',' + -- 29          
              ISNULL(RTRIM(@c_CaptureLottable),'')  + ',' + -- 30          
              ISNULL(RTRIM(@c_LottableDesc),'')  + ',' + -- 31          
              ISNULL(RTRIM(@c_PickMessage),'')  + ',' + -- 32          
              ISNULL(RTRIM(@c_VerifyLoc),'')  + ',' + -- 33          
              ISNULL(RTRIM(@c_CycleCount),'')  + ',' + -- 34           
              ISNULL(RTRIM(@c_CaptureSerialNo),'')  + ',' + -- 35          
              ISNULL(RTRIM(@c_SpeakSKUDesc),'')  + ',' + -- 36          
              ISNULL(RTRIM(@c_ErrorCode),'')  + ',' +           
              ISNULL(RTRIM(@c_Message),'')     
                            
            
         SET @n_Counter = @n_Counter + 1   
               
                                              
         FETCH NEXT FROM CursorGetPicks INTO   
               @c_LOC             , @c_Region            , @c_PickZone            , @c_Aisle             , @c_PostAisleDirec  
             , @c_Bay             , @c_Aisle             , @n_QtyToPick           , @c_PackKey           , @c_UOM  
             , @c_SKU             , @c_CheckDigit        , @c_SKUDesc             , @c_Size              , @c_UPC  
             , @c_AssignID        , @c_AssignIDDesc      , @c_DeliveryLoc         , @c_OrderKey          , @c_FromID  
             , @c_StorerKey       , @c_Lottable01Label   , @c_Lottable02Label     , @c_Lottable03Label   , @c_Lottable04Label  
             , @c_TargetContainer    
                                 
      END  
      CLOSE CursorGetPicks              
      DEALLOCATE CursorGetPicks                             
   END      
   --ELSE IF @c_Status = '9' -- Task Completed      
     
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0 AND @n_GetNextTask = 0   
   BEGIN      
      SET @n_GetNextTask = 1  
        
      -- Get Next Task    
      SELECT @c_AreaKey   = r.V_String1,       
             @c_SuggToLoc = r.V_Loc      
      FROM RDT.RDTMOBREC r WITH (NOLOCK)      
      WHERE r.UserName = @c_OperatorID       
      AND   r.DeviceID = @c_DevSerialNo      
           
      SELECT @c_ErrMsg = '', @c_NextTaskdetailkey = '', @c_TTMTasktype = ''      
    
      EXEC dbo.nspTMTM01      
       @c_sendDelimiter = null      
      ,  @c_ptcid         = 'VOICE'      
      ,  @c_userid        = @c_OperatorID      
      ,  @c_taskId        = 'VOICE'      
      ,  @c_databasename  = NULL      
      ,  @c_appflag       = NULL      
      ,  @c_recordType    = NULL      
      ,  @c_server        = NULL      
      ,  @c_ttm           = NULL      
      ,  @c_areakey01     = @c_AreaKey      
      ,  @c_areakey02     = ''      
      ,  @c_areakey03     = ''      
      ,  @c_areakey04     = ''      
      ,  @c_areakey05     = ''      
      ,  @c_lastloc       = @c_SuggToLoc      
      ,  @c_lasttasktype  = 'VNPK'      
      ,  @c_outstring     = @c_outstring     OUTPUT      
      ,  @b_Success       = @b_Success       OUTPUT      
      ,  @n_err           = @n_Error         OUTPUT      
      ,  @c_errmsg        = @c_ErrMsg        OUTPUT      
      ,  @c_taskdetailkey = @c_NextTaskdetailkey OUTPUT      
      ,  @c_ttmtasktype   = @c_TTMTasktype   OUTPUT      
      ,  @c_RefKey01      = @c_RefKey01      OUTPUT        
      ,  @c_RefKey02      = @c_RefKey02      OUTPUT        
      ,  @c_RefKey03      = @c_RefKey03      OUTPUT        
      ,  @c_RefKey04      = @c_RefKey04      OUTPUT        
      ,  @c_RefKey05      = @c_RefKey05      OUTPUT        
          
      IF ISNULL(RTRIM(@c_NextTaskdetailkey),'') <> ''      
      BEGIN      
         SET @c_GroupID = ''  
           
         --SET @c_GroupID       = @c_NextTaskdetailkey  -- (ChewKP01)    
         SELECT @c_GroupID = SourceKey  
         FROM dbo.TaskDetail WITH (NOLOCK)     
         WHERE TaskDetailKey = @c_NextTaskdetailkey    
                
         SET @c_TaskDetailKey = @c_NextTaskdetailkey    
                
              
         UPDATE rdt.RDTMOBREC      
            SET V_TaskDetailKey =  @c_NextTaskdetailkey      
         FROM RDT.RDTMOBREC WITH (NOLOCK)      
         WHERE UserName = @c_OperatorID       
         AND   DeviceID = @c_DevSerialNo        
             
         GOTO GenGetPicks                                     
      END      
      ELSE      
      BEGIN      
         SET @c_PickMessage = [dbo].[fnc_GetVC_Message](@c_LangCode, 'vc_prTaskLUTGetPicks_03', N'No More Assignment. Please SignOff',RIGHT(RTRIM(@c_FromID), 3),'','','','')        
         SET @c_RtnMessage = 'N,0,,,,,,,,,,,,,,,,,,,,,,,0,0,0,,,0,,,0,0,0,0,89,' + @c_PickMessage       
      END                
   END      
                                          
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0           
   BEGIN   
      --    
      SET @c_RtnMessage = "N,0,,,,,,,,,,,,,,,,,,,,,,,0,0,0,,,0,,,0,0,0,0,89,No Pick Task"          
   END    
   
  
          
END


GO