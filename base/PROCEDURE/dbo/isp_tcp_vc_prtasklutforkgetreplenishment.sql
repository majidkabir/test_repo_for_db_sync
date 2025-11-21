SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
 /* Store Procedure:  isp_TCP_VC_prTaskLUTForkGetReplenishment           */
 /* Creation Date: 26-Feb-2013                                           */
 /* Copyright: IDS                                                       */
 /* Written by: Shong                                                    */
 /*                                                                      */
 /* Purposes: The message returns the regions where the operator is      */
 /*           allowed to perform the selection function.                 */
 /*                                                                      */
 /* Updates:                                                             */
 /* Date         Author    Purposes                                      */
/************************************************************************/
CREATE PROC [dbo].[isp_TCP_VC_prTaskLUTForkGetReplenishment] (
    @c_TranDate     NVARCHAR(20)
   ,@c_DevSerialNo  NVARCHAR(20)
   ,@c_OperatorID   NVARCHAR(20)
   ,@n_SerialNo     INT
   ,@c_RtnMessage   NVARCHAR(500) OUTPUT    
   ,@b_Success      INT = 1 OUTPUT
   ,@n_Error        INT = 0 OUTPUT
   ,@c_ErrMsg       NVARCHAR(255) = '' OUTPUT 

)
AS
BEGIN
   DECLARE 
           @c_AreaKey            NVARCHAR(10)
         , @c_SuggToLoc          NVARCHAR(10)
         , @c_outstring          NVARCHAR(255)
         , @c_NextTaskdetailkey  NVARCHAR(10)
         , @c_TTMTasktype        NVARCHAR(20)
         , @c_RefKey01           NVARCHAR(20)
         , @c_RefKey02           NVARCHAR(20)
         , @c_RefKey03           NVARCHAR(20)
         , @c_RefKey04           NVARCHAR(20)
         , @c_RefKey05           NVARCHAR(20)   
         , @c_GroupID            NVARCHAR(100)        
         , @c_AssignMntID        NVARCHAR(10)
         , @c_AssignMntDesc      NVARCHAR(100)  
         , @c_FromLOC            NVARCHAR(10)  
         , @c_FromZone           NVARCHAR(20)
         , @c_ToZone             NVARCHAR(20)               

         -- Output Columns
         , @c_ReplenishmentKey   NVARCHAR(10)
         , @c_LPNumber           NVARCHAR(18)
         , @c_ReqSpecificLPN     NVARCHAR(1)
         , @c_RegionNo           NVARCHAR(5)  -- OperatorΓÇÿs response to picking region prompt.         
         , @c_SKU                NVARCHAR(20)          
         , @c_SKUDesc            NVARCHAR(60)
         , @c_QtyReplen          NVARCHAR(10)
         , @c_FromPreAisleDrtn   NVARCHAR(50)
         , @c_FromAisle          NVARCHAR(100)
         , @c_FromPostAisleDrtn  NVARCHAR(50)
         , @c_FromSlot           NVARCHAR(100)
         , @c_FromCheckDigit     NVARCHAR(2)
         , @c_FromScanValidate   NVARCHAR(100)
         , @c_ToPreAisleDrtn     NVARCHAR(50)
         , @c_ToAisle            NVARCHAR(100)
         , @c_ToPostAisleDrtn    NVARCHAR(50)
         , @c_ToSlot             NVARCHAR(100)
         , @c_ToCheckDigit       NVARCHAR(2)
         , @c_ToScanValidate     NVARCHAR(100)
         , @c_ToLOC              NVARCHAR(100)
         , @c_GoalTime           NVARCHAR(10)
         , @c_ErrorCode          NVARCHAR(20) --  0: No error. The VoiceApplication proceeds.
                                            -- 98: Critical error. If this error is received, 
                                            --     the VoiceApplication speaks the error message, and forces the operator to sign off. 
                                            -- 99: Informational error. The VoiceApplication speaks the informational error message, 
                                            --     but does not force the operator to sign off.
         , @c_Message            NVARCHAR(400)
         , @c_LangCode           NVARCHAR(10)      
   
   SET @c_LangCode = 'ENG'         
         
          
   SET @c_RtnMessage        = N''
   SET @c_ReplenishmentKey  = N''
   SET @c_LPNumber          = N''
   SET @c_ReqSpecificLPN    = N''
   SET @c_RegionNo          = N''
   SET @c_SKU               = N''
   SET @c_SKUDesc           = N''
   SET @c_QtyReplen         = N''
   SET @c_FromPreAisleDrtn  = N''
   SET @c_FromAisle         = N''
   SET @c_FromPostAisleDrtn = N''
   SET @c_FromSlot          = N''
   SET @c_FromCheckDigit    = N''
   SET @c_FromScanValidate  = N''
   SET @c_ToPreAisleDrtn    = N''
   SET @c_ToAisle           = N''
   SET @c_ToPostAisleDrtn   = N''
   SET @c_ToSlot            = N''
   SET @c_ToCheckDigit      = N''
   SET @c_ToScanValidate    = N''
   SET @c_ToLOC             = N''
   SET @c_GoalTime          = N''   
   
   SELECT @c_AreaKey   = r.V_String1, 
          @c_SuggToLoc = r.V_Loc
   FROM RDT.RDTMOBREC r WITH (NOLOCK)
   WHERE r.UserName = @c_OperatorID 
   AND   r.DeviceID = @c_DevSerialNo

   UPDATE RDT.rdtMobRec 
      SET V_TaskDetailKey = ''
   WHERE UserName = @c_OperatorID 
   AND   DeviceID = @c_DevSerialNo

   SELECT @c_LangCode = r.DefaultLangCode      
   FROM rdt.RDTUser r (NOLOCK)      
   WHERE r.UserName = @c_OperatorID     
   
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
   ,  @c_LastLoc       = @c_SuggToLoc
   ,  @c_lasttasktype  = 'VRPL'
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

   SET @c_ErrorCode = 0 
   SET @c_Message = ''
   
   IF ISNULL(RTRIM(@c_NextTaskdetailkey),'') <> ''
   BEGIN
      SET @c_GroupID       = @c_NextTaskdetailkey
      SET @c_AssignMntID   = @c_NextTaskdetailkey
      SET @c_AssignMntDesc = @c_TTMTasktype
      SET @c_ReqSpecificLPN = '0'    
      
      SELECT 
              @c_ReplenishmentKey = @c_NextTaskdetailkey
            , @c_LPNumber = td.FromID          
            , @c_RegionNo = td.AreaKey          
            , @c_SKU = td.Sku                
            , @c_SKUDesc = s.DESCR           
            , @c_QtyReplen = td.Qty  
            , @c_FromLOC   = td.FromLoc       
            , @c_ToLOC = td.ToLoc               
            , @c_GoalTime = '0'                 
      FROM TaskDetail td WITH (NOLOCK) 
      JOIN SKU s WITH (NOLOCK) ON s.Storerkey = td.Storerkey AND s.Sku = td.Sku 
      WHERE td.TaskDetailKey = @c_NextTaskdetailkey
      AND   td.UserKey = @c_OperatorID
      AND   td.[Status] = '3'
      
      --SET @c_SKUDesc = MASTER.dbo.fn_ANSI2UNICODE(@c_SKUDesc, 'CHT')
      
      SELECT  @c_FromZone = L.PutawayZone     
            , @c_FromAisle = L.LocAisle   
            , @c_FromPostAisleDrtn = ''  
            , @c_FromSlot = l.LocBay            
            , @c_FromCheckDigit = CASE WHEN ISNUMERIC(L.LocCheckDigit) = 1 THEN RIGHT('0'+ RTRIM(L.LocCheckDigit), 2) ELSE '' END    
            , @c_FromScanValidate = ''   
      FROM LOC L WITH (NOLOCK)
      WHERE L.LOC = @c_FromLOC

      SELECT @c_FromPreAisleDrtn =  pz.Descr  
      FROM   PutawayZone pz WITH (NOLOCK)
      WHERE  pz.PutawayZone = @c_FromZone

      SELECT  @c_ToZone = L.PutawayZone    
            , @c_ToAisle = L.LocAisle            
            , @c_ToPostAisleDrtn = ''   
            , @c_ToSlot = L.LocBay             
            , @c_ToCheckDigit = CASE WHEN ISNUMERIC(L.LocCheckDigit) = 1 THEN RIGHT('0'+ RTRIM(L.LocCheckDigit), 2) ELSE '' END      
            , @c_ToScanValidate = ''          
      FROM LOC L WITH (NOLOCK)
      WHERE L.LOC = @c_ToLOC

      SELECT @c_ToPreAisleDrtn =  pz.Descr  
      FROM   PutawayZone pz WITH (NOLOCK)
      WHERE  pz.PutawayZone = @c_ToZone
            
      UPDATE MR
         SET MR.V_TaskDetailKey =  @c_NextTaskdetailkey, 
             MR.v_Loc = @c_FromLOC, 
             MR.V_SKU = @c_SKU, 
             MR.V_ID = @c_LPNumber, 
             MR.V_SKUDescr = @c_SKUDesc, 
             MR.V_Qty = @c_QtyReplen 
      FROM RDT.RDTMOBREC MR  
      WHERE UserName = @c_OperatorID 
      AND   DeviceID = @c_DevSerialNo       
   END
   ELSE
   BEGIN
      SET @c_ErrorCode = '89'
      SET @c_Message  = [dbo].[fnc_GetVC_Message](@c_LangCode, 'vc_prTaskLUTForkGetReplenishment_01', N'No Replenishment Task','','','','','')  
   END
   
   SET @c_RegionNo = @c_AreaKey
   
   SET @c_RtnMessage = @c_ReplenishmentKey  + ',' + 
                        @c_LPNumber          + ',' + 
                        @c_ReqSpecificLPN    + ',' + 
                        @c_RegionNo          + ',' + 
                        @c_SKU               + ',' + 
                        @c_SKUDesc           + ',' + 
                        @c_QtyReplen         + ',' + 
                        @c_FromPreAisleDrtn  + ',' + 
                        @c_FromAisle         + ',' + 
                        @c_FromPostAisleDrtn + ',' + 
                        @c_FromSlot          + ',' + 
                        @c_FromCheckDigit    + ',' + 
                        @c_FromScanValidate  + ',' + 
                        @c_ToPreAisleDrtn    + ',' + 
                        @c_ToAisle           + ',' + 
                        @c_ToPostAisleDrtn   + ',' + 
                        @c_ToSlot            + ',' + 
                        @c_ToCheckDigit      + ',' + 
                        @c_ToScanValidate    + ',' + 
                        @c_ToLOC             + ',' + 
                        @c_GoalTime          + ',' + 
                        @c_ErrorCode         + ',' +
                        @c_Message           
   
   IF LEN(ISNULL(@c_RtnMessage,'')) = 0 
   BEGIN
      SET @c_RtnMessage = ",,0,1,,,,,,,,,,,,,,,,,,89,Error" 
   END
   

END

GO