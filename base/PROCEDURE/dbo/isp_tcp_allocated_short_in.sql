SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store Procedure:  isp_TCP_ALLOCATED_SHORT_IN                         */    
/* Creation Date: 11-11-2011                                            */    
/* Copyright: IDS                                                       */    
/* Written by: Shong                                                    */    
/*                                                                      */    
/* Purpose: Picking from Bulk to Induction                              */    
/*          RedWerks to WMS Exceed                                      */    
/*                                                                      */    
/* Input Parameters:  @c_MessageNum    - Unique no for Incoming data    */    
/*                                                                      */    
/* Output Parameters: @b_Success       - Success Flag  = 0              */    
/*                    @n_Err           - Error Code    = 0              */    
/*                    @c_ErrMsg        - Error Message = ''             */    
/*                                                                      */    
/* PVCS Version: 1.3                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver.  Purposes                                */    
/* 02-Apr-2012  James     1.1   SOS237850 - Enhance Supervisor Alert    */
/*                              (james01)                               */
/* 08-May-2012  James     1.2   Stamp pickslipno if blank (james02)     */
/* 09-May-2012  Ung       1.3   Insert RefKeyLookup (ung01)             */
/* 29-Jun-2012  Chew      1.4   TM CycleCount Task Standardization      */
/*                              (ChewKP01)                              */
/* 03-09-2012   Leong     1.5   SOS# 254851 - Standardize in progress   */
/*                              update for table TCPSOCKET_INLOG        */
/* 07-Sep-2012  Leong     1.6   SOS# 255550 - Insert RefKeyLookUp with  */
/*                              EditWho                                 */
/************************************************************************/    
CREATE PROCEDURE [dbo].[isp_TCP_ALLOCATED_SHORT_IN]     
                @c_MessageNum  NVARCHAR(10)    
              , @b_Debug      INT    
              , @b_Success    INT        OUTPUT    
              , @n_Err        INT        OUTPUT    
              , @c_ErrMsg     NVARCHAR(250)  OUTPUT          
    
AS    
BEGIN    
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF            
       
   DECLARE @n_Continue           INT    
         , @n_StartTCnt          INT    
    
   DECLARE @n_SerialNo         INT    
          ,@c_Status           NVARCHAR(1)         
          ,@c_DataString       NVARCHAR(4000)     

   DECLARE @c_NewLineChar NVARCHAR(2) 
   SET @c_NewLineChar =  master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10) 

   SELECT @n_Continue = 1, @b_Success = 1, @n_Err = 0    
   SET @n_StartTCnt = @@TRANCOUNT     
    
   BEGIN TRAN      
   SAVE TRAN WCS_SHORT_ALLOC     
          
   SELECT @n_SerialNo   = SerialNo,     
          @c_DataString = [Data]    
   FROM   dbo.TCPSocket_INLog WITH (NOLOCK)     
   WHERE  MessageNum     = @c_MessageNum    
   AND    MessageType   = 'RECEIVE'     
   AND    Status        = '0'    
    
   IF ISNULL(RTRIM(@n_SerialNo),'') = ''      
   BEGIN    
      IF @b_Debug = 1    
      BEGIN    
         SELECT 'Nothing to process. MessageNum = ' + @c_MessageNum        
      END    
       
      GOTO QUIT_SP    
   END    
    
   IF @b_Debug = 1    
   BEGIN    
      SELECT '@n_SerialNo : ' + CONVERT(VARCHAR, @n_SerialNo)     
           + ', @c_Status : '     + @c_Status    
           + ', @c_DataString : ' + @c_DataString          
   END    

   UPDATE dbo.TCPSOCKET_INLOG WITH (ROWLOCK) -- SOS# 254851
   SET Status = '1'
   WHERE SerialNo = @n_SerialNo
    
   IF ISNULL(RTRIM(@c_DataString),'') = ''      
   BEGIN    
      SET @n_Continue = 3    
      SET @c_Status = '5'          
      SET @c_ErrMsg = 'Data String is empty. Seq#: ' + CONVERT(VARCHAR, @n_SerialNo) + '. (isp_TCP_ALLOCATED_SHORT_IN)'    
      GOTO QUIT_SP    
   END    
    
   DECLARE     
    --@c_MessageNum       NVARCHAR(10)   ,   
      @c_MessageType      NVARCHAR(15)       
     ,@c_OrderKey         NVARCHAR(10)      
     ,@c_OrderLineNumber  NVARCHAR(5)       
     ,@c_ConsoOrderKey    NVARCHAR(30)      
     ,@c_TargetLoc        NVARCHAR(10)      
     ,@c_SKU              NVARCHAR(20)      
     ,@n_QtyShorted       INT              
     ,@c_TransCode        NVARCHAR(10)      
     ,@c_ReasonCode       NVARCHAR(10)      
     ,@c_StorerKey        NVARCHAR(15)    
     ,@c_Facility         NVARCHAR(5)    
     ,@n_QtyAllocated     INT     
     ,@c_PickDetailKey    NVARCHAR(10)    
     ,@c_LOT              NVARCHAR(10)    
     ,@c_LOC              NVARCHAR(10)    
     ,@c_ID               NVARCHAR(10)    
     ,@n_Qty              INT    
     ,@c_NewPickDetailKey NVARCHAR(10)      
     ,@c_TaskDetailKey    NVARCHAR(10)    
     ,@c_LogicalLocation  NVARCHAR(10)    
     ,@n_SystemQty        INT    
     ,@c_AreaKey          NVARCHAR(10)    
     ,@c_WaveKey          NVARCHAR(10)    
     ,@c_LoadKey          NVARCHAR(10)    
     ,@n_OriginQtyShort   INT    
     ,@c_PickSlipNo       NVARCHAR(10) 
     ,@c_CCKey            NVARCHAR(10)
        
   SET @c_ErrMsg           = ''    
   SET @c_Status           = '9'    
   SET @n_QtyShorted       = 0    
   SET @c_OrderKey         = ''     
   SET @c_MessageType      = ''      
   SET @c_MessageNum       = ''     
   SET @c_StorerKey        = ''    
   SET @c_Facility         = ''    
   SET @c_OrderLineNumber  = ''      
   SET @c_ConsoOrderKey    = ''    
   SET @c_TransCode        = ''    
   SET @c_SKU              = ''    
   SET @c_ReasonCode       = ''    
   SET @c_TargetLoc        = ''    
   SET @n_QtyAllocated     = 0    
   SET @n_OriginQtyShort   = 0     
            
   SELECT @c_MessageNum = MessageNum     
         ,@c_MessageType = MessageType     
         ,@c_StorerKey = StorerKey     
         ,@c_Facility = Facility     
         ,@c_OrderKey = OrderKey     
         ,@c_OrderLineNumber = OrderLineNumber     
         ,@c_ConsoOrderKey = ConsoOrderKey     
         ,@c_TargetLoc = TargetLoc     
         ,@c_SKU = SKU     
         ,@n_QtyShorted = QtyShorted     
         ,@c_TransCode = TransCode     
         ,@c_ReasonCode = ReasonCode    
   FROM fnc_GetTCPAllocatedShort( @n_SerialNo )    
    
   IF @b_Debug = 1    
   BEGIN    
      SELECT MessageNum = MessageNum     
               ,MessageType = MessageType     
               ,StorerKey = StorerKey     
               ,Facility = Facility     
               ,OrderKey = OrderKey     
               ,OrderLineNumber = OrderLineNumber     
               ,ConsoOrderKey = ConsoOrderKey     
               ,TargetLoc = TargetLoc     
               ,SKU = SKU     
               ,QtyShorted = QtyShorted     
               ,TransCode = TransCode     
               ,ReasonCode = ReasonCode    
         FROM fnc_GetTCPAllocatedShort( @n_SerialNo )              
   END     
      
   IF @c_MessageType <> 'ALLOCSHORT'    
   BEGIN    
      SET @n_Continue = 3    
      SET @c_Status = '5'          
      SET @c_ErrMsg = 'Wrong Message Type' + @c_MessageType + '. (isp_TCP_ALLOCATED_SHORT_IN)'    
      GOTO QUIT_SP        
   END    
    
       
   IF @n_QtyShorted <= 0    
   BEGIN    
      SET @n_Continue = 3    
      SET @c_Status = '5'          
      SET @c_ErrMsg = 'Qty Shorted Should Greater then ZERO. Qty Shorted=' + CAST(@n_QtyShorted AS NVARCHAR(10)) + '. (isp_TCP_ALLOCATED_SHORT_IN)'    
      GOTO QUIT_SP        
   END    
       
   SET @n_OriginQtyShort = @n_QtyShorted    
       
   SET @n_QtyAllocated = 0    
          
   SELECT @n_QtyAllocated = ISNULL(SUM(Qty),0)     
   FROM   PICKDETAIL WITH (NOLOCK)    
   WHERE  OrderKey = @c_OrderKey     
   AND    OrderLineNumber = @c_OrderLineNumber     
   AND    Storerkey = @c_StorerKey    
   AND    SKU = @c_SKU     
   AND    LOC = @c_TargetLoc     
   AND   [Status] < '4'     
       
   IF @n_QtyAllocated < @n_QtyShorted    
   BEGIN    
      SET @n_Continue = 3    
      SET @c_Status = '5'          
      SET @c_ErrMsg = 'Qty Allocated ' + CAST(@n_QtyAllocated AS NVARCHAR(10)) + ' > Qty Shorted ' + CAST(@n_QtyShorted AS NVARCHAR(10)) + '. (isp_TCP_ALLOCATED_SHORT_IN)'    
      GOTO QUIT_SP        
   END
       
   SET @c_WaveKey = ''
   SET @c_LoadKey = ''
   
   SELECT @c_WaveKey = o.UserDefine09    
         ,@c_LoadKey = o.LoadKey     
   FROM   ORDERS o WITH (NOLOCK)    
   WHERE  o.OrderKey = @c_OrderKey    
       
   DECLARE CUR_PICKDETAIL_SHORT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT p.PickDetailKey, P.LOT, P.LOC, P.ID, P.Qty     
   FROM   PICKDETAIL p WITH (NOLOCK)     
   WHERE  OrderKey = @c_OrderKey     
   AND    OrderLineNumber = @c_OrderLineNumber     
   AND    Storerkey = @c_StorerKey    
   AND    SKU = @c_SKU     
   AND    LOC = @c_TargetLoc     
   AND   [Status] < '4'        
   ORDER BY p.PickDetailKey     
       
   OPEN CUR_PICKDETAIL_SHORT    
       
   FETCH NEXT FROM CUR_PICKDETAIL_SHORT INTO @c_PickDetailKey, @c_LOT, @c_LOC, @c_ID, @n_Qty    
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
    IF @n_Qty <= @n_QtyShorted     
    BEGIN    
      SELECT TOP 1
         @c_PickSlipNo = ISNULL(RTRIM(PickHeaderKey),'')
      FROM dbo.PickHeader WITH (NOLOCK, INDEX(IX_PICKHEADER_ConsoOrderKey))
      WHERE ConsoOrderKey = @c_ConsoOrderKey --(james02)
         
     UPDATE PICKDETAIL WITH (ROWLOCK)    
        SET [Status] = '4', 
            TrafficCop = NULL, 
            PickSlipNo = CASE WHEN ISNULL(PickSlipNo, '') = '' THEN @c_PickSlipNo ELSE PickSlipNo END 
     WHERE PickDetailKey = @c_PickDetailKey    
     IF @@ERROR <> 0     
     BEGIN    
         SET @n_Continue = 3    
         SET @c_Status = '5'          
         SET @c_ErrMsg = 'Update PickDetail Failed (isp_TCP_ALLOCATED_SHORT_IN). ErrMsg:'     
         GOTO QUIT_SP        
     END         
     
     -- Insert into RefKeyLookup (ung01)
     IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookup (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey)       
     BEGIN                    
         INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey, EditWho) -- SOS# 255550
         VALUES (@c_PickDetailKey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber, @c_Loadkey, 'TCP01a.' + sUser_sName())
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_Continue = 3    
            SET @c_Status = '5'          
            SET @c_ErrMsg = 'Insert RefKeyLookup Failed (isp_TCP_ALLOCATED_SHORT_IN).'     
            GOTO QUIT_SP
         END  
     END
      
     SET @n_QtyShorted = @n_QtyShorted - @n_Qty    
         
     IF @n_QtyShorted = 0    
        BREAK     
    END    
    ELSE    
    BEGIN -- split line    
         EXECUTE dbo.nspg_GetKey      
            'PICKDETAILKEY',      
            10 ,      
            @c_NewPickDetailKey OUTPUT,      
            @b_Success          OUTPUT,      
            @n_Err              OUTPUT,      
            @c_ErrMsg           OUTPUT    
                
         IF @b_Success <> 1      
         BEGIN      
            SET @n_Continue = 3    
            SET @c_Status = '5'          
            SET @c_ErrMsg = 'Get PickDetail Key Failed (isp_TCP_ALLOCATED_SHORT_IN).'     
            GOTO QUIT_SP       
         END     
             
         -- Create a new PickDetail to hold the balance      
         INSERT INTO dbo.PICKDETAIL (      
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, LOT, StorerKey, SKU, AltSKU, UOM, UOMQTY, QTYMoved,      
            Status, DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,      
            DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, PickDetailKey,      
            QTY,      
            TrafficCop,      
            OptimizeCop)      
         SELECT      
            CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM,     
            (@n_Qty - @n_QtyShorted), -- UOMQTY    
            QTYMoved,      
            '0', -- Status     
            DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,      
            DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @c_NewPickDetailKey,      
            (@n_Qty - @n_QtyShorted), -- QTY      
            NULL, --TrafficCop,      
            '1'   --OptimizeCop      
         FROM dbo.PickDetail WITH (NOLOCK)      
         WHERE PickDetailKey = @c_PickDetailKey      
    
         IF @@ERROR <> 0      
         BEGIN      
            SET @n_Continue = 3    
            SET @c_Status = '5'          
            SET @c_ErrMsg = 'Insert PickDetail Failed (isp_TCP_ALLOCATED_SHORT_IN).'     
            GOTO QUIT_SP       
         END      

         SELECT TOP 1
            @c_PickSlipNo = ISNULL(RTRIM(PickHeaderKey),'')
         FROM dbo.PickHeader WITH (NOLOCK, INDEX(IX_PICKHEADER_ConsoOrderKey))
         WHERE ConsoOrderKey = @c_ConsoOrderKey --(james02)
     
         UPDATE dbo.PickDetail WITH (ROWLOCK)     
         SET QTY        = @n_QtyShorted,      
             [STATUS]   = '4',    
             Trafficcop = NULL,
             PickSlipNo = CASE WHEN ISNULL(PickSlipNo, '') = '' THEN @c_PickSlipNo ELSE PickSlipNo END 
         WHERE PickDetailKey = @c_PickDetailKey      
    
         IF @@ERROR <> 0      
         BEGIN      
            SET @n_Continue = 3    
            SET @c_Status = '5'          
            SET @c_ErrMsg = 'Update PickDetail Failed (isp_TCP_ALLOCATED_SHORT_IN).'     
            GOTO QUIT_SP      
         END      

         SELECT   
            @c_PickSlipNo = PD.PickSlipNo   
         FROM dbo.PickDetail PD WITH (NOLOCK)   
         INNER JOIN dbo.OrderDetail OD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber)  
         WHERE PD.PickDetailkey = @c_PickDetailKey  

         -- Insert RefKeyLookup, if not exists      
         IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookup (NOLOCK) WHERE PickDetailKey = @c_NewPickDetailKey)       
         BEGIN                    
            -- Insert into   
            INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey, EditWho) -- SOS# 255550
            VALUES (@c_NewPickDetailKey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber, @c_Loadkey, 'TCP01b.' + sUser_sName())
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_Continue = 3    
               SET @c_Status = '5'          
               SET @c_ErrMsg = 'Insert RefKeyLookup Failed (isp_TCP_ALLOCATED_SHORT_IN).'     
               GOTO QUIT_SP
            END  
         END       
                                           
         -- Insert RefKeyLookup, if not exists      
         IF NOT EXISTS (SELECT 1 FROM dbo.RefKeyLookup (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey)       
         BEGIN                    
            -- Insert into   
            INSERT INTO dbo.RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey, EditWho) -- SOS# 255550
            VALUES (@c_PickDetailKey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber, @c_Loadkey, 'TCP01c.' + sUser_sName())
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_Continue = 3    
               SET @c_Status = '5'          
               SET @c_ErrMsg = 'Insert RefKeyLookup Failed (isp_TCP_ALLOCATED_SHORT_IN).'     
               GOTO QUIT_SP
            END  
         END       

         BREAK                                                      
    END    
        
    FETCH NEXT FROM CUR_PICKDETAIL_SHORT INTO @c_PickDetailKey, @c_LOT, @c_LOC, @c_ID, @n_Qty    
   END     
   CLOSE CUR_PICKDETAIL_SHORT     
   DEALLOCATE CUR_PICKDETAIL_SHORT     
       
   IF @b_Debug = 1    
   BEGIN    
      SELECT '@c_MessageType : '       + @c_MessageType    
           + ', @c_MessageNum : '      + @c_MessageNum    
           + ', @c_StorerKey : '       + @c_StorerKey    
           + ', @c_SKU : '             + @c_SKU          
           + ', @c_ReasonCode : '      + @c_ReasonCode       
           + ', @n_QtyShorted : '      + CAST(@n_QtyShorted AS NVARCHAR(10))        
                                                                   
   END       
         
    
   -- Create Cycle Count Task    
   SET @b_Success = 1    
       
   EXECUTE dbo.nspg_getkey                         
   'TaskDetailKey'                        
   , 10                        
   , @c_TaskDetailKey OUTPUT                        
   , @b_Success OUTPUT                        
   , @n_Err     OUTPUT                        
   , @c_ErrMsg  OUTPUT               
   
    
   IF @b_Success <> 1      
   BEGIN      
      SET @n_Continue = 3    
      SET @c_Status = '5'          
      SET @c_ErrMsg = 'Get PickDetail Key Failed (isp_TCP_ALLOCATED_SHORT_IN).'     
      GOTO QUIT_SP       
   END     
       
   SELECT @c_LogicalLocation = LogicalLocation ,
          @c_AreaKey         = ISNULL(ad.AreaKey, '')    
   FROM   LOC WITH (NOLOCK)     
   LEFT OUTER JOIN AreaDetail ad WITH (NOLOCK) ON ad.PutawayZone = LOC.PutawayZone     
   WHERE  LOC = @c_TargetLoc    
             
   SET @n_SystemQty = 0     
   SELECT @n_SystemQty = ISNULL(SUM(QTY - QtyPicked),0)    
   FROM   SKUxLOC sl WITH (NOLOCK)    
   WHERE  sl.StorerKey = @c_StorerKey     
   AND    sl.Sku = @c_SKU     
   AND    sl.Loc = @c_LOC     
       
   -- If not outstanding cycle count task, then insert new cycle count task    
   IF NOT EXISTS(SELECT 1 FROM TaskDetail td (NOLOCK) WHERE td.TaskType = 'CC' AND td.FromLoc = @c_TargetLoc    
                 AND td.[Status] IN ('0','3'))    
   BEGIN    
        -- (ChewKP01)
        EXECUTE nspg_getkey
          'CCKey'
          , 10
          , @c_CCKey OUTPUT
          , @b_success OUTPUT
          , @n_Err OUTPUT
          , @c_Errmsg OUTPUT               
         
         IF NOT @b_success = 1                  
         BEGIN                  
            SET @n_Continue = 3
            SET @c_Status = '5'
            SET @c_ErrMsg = 'GetKey Failed (isp_TCP_ALLOCATED_SHORT_IN).'
            GOTO QUIT_SP  
         END  
      
      INSERT INTO dbo.TaskDetail                  
        (TaskDetailKey,TaskType,Storerkey,Sku,Lot,UOM,UOMQty,Qty,FromLoc,LogicalFromLoc,FromID,ToLoc,LogicalToLoc                  
        ,ToID,Caseid,PickMethod,Status,StatusMsg,Priority,SourcePriority,Holdkey,UserKey,UserPosition,UserKeyOverRide                  
        ,StartTime,EndTime,SourceType,SourceKey,PickDetailKey,OrderKey,OrderLineNumber,ListKey,WaveKey,ReasonKey                  
        ,Message01,Message02,Message03,RefTaskKey,LoadKey,AreaKey,DropID, SystemQty)    
        VALUES      
        (@c_TaskDetailKey    
         ,'CC' -- TaskType    
         ,@c_Storerkey    
         ,@c_Sku    
         ,'' -- Lot    
         ,'' -- UOM     
         ,0  -- UOMQty    
         ,0  -- Qty    
         ,@c_TargetLoc     
         ,@c_LogicalLocation    
         ,'' -- FromID    
         ,'' -- ToLoc    
         ,'' -- LogicalToLoc                  
         ,'' -- ToID    
         ,'' -- Caseid    
         ,'SKU' -- PickMethod   -- (ChewKP01) 
         ,'0' -- STATUS    
         ,''  -- StatusMsg    
         ,'5' -- Priority    
         ,''  -- SourcePriority    
         ,''  -- Holdkey    
         ,''  -- UserKey    
         ,''  -- UserPosition    
         ,''  -- UserKeyOverRide                  
         ,GETDATE() -- StartTime    
         ,GETDATE() -- EndTime    
         ,'ALLOCSHORT'   -- SourceType   -- (ChewKP01)  
         ,@c_CCKey -- SourceKey          -- (ChewKP01) 
         ,ISNULL(@c_PickDetailKey,'')    
         ,@c_OrderKey    
         ,@c_OrderLineNumber    
         ,'' -- ListKey    
         ,@c_WaveKey    
         ,'' --ReasonKey                  
         ,@c_ReasonCode -- Message01    
         ,'' -- Message02    
         ,'' -- Message03    
         ,'' -- RefTaskKey    
         ,@c_LoadKey    
         ,@c_AreaKey    
         ,'' -- DropID    
         ,@n_SystemQty)                 
         IF @@ERROR <> 0      
         BEGIN      
            SET @n_Continue = 3    
            SET @c_Status = '5'          
            SET @c_ErrMsg = 'Insert TaskDetail Failed (isp_TCP_ALLOCATED_SHORT_IN).'     
            GOTO QUIT_SP      
         END        
        
   END                     
       
   -- Create Alert for Supervisor    
   DECLARE @c_AlertMessage NVARCHAR(512)    
       
--   SET @c_AlertMessage = 'TaskDetailKey: ' + @c_TaskDetailKey + ' Task Type: CC ReasonCode:' + @c_ReasonCode + ' LoadKey: ' + @c_LoadKey +     
--                         ' Short Qty: ' + CAST(@n_OriginQtyShort AS NVARCHAR(10)) + ' DateTime: ' + CONVERT(VARCHAR(20), GETDATE())      

   SET @c_AlertMessage = 'Allocated Short for Orderkey: ' + @c_OrderKey + @c_NewLineChar 
   SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' TaskDetailKey: ' + @c_TaskDetailKey + @c_NewLineChar 
   SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Task Type: CC ReasonCode: ' + @c_ReasonCode + @c_NewLineChar 
   SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' LoadKey: ' + @c_LoadKey + @c_NewLineChar 
   SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Short QTY: ' + CAST(@n_OriginQtyShort AS NVARCHAR(10)) +  @c_NewLineChar 
   SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' DateTime: ' + CONVERT(VARCHAR(20), GETDATE())  +  @c_NewLineChar 

-- (ChewKP01)        
--   EXEC nspLogAlert    
--    @c_modulename   = 'isp_TCP_ALLOCATED_SHORT_IN',    
--    @c_AlertMessage = @c_AlertMessage,    
--    @n_Severity = 0,    
--    @b_success  = @b_Success OUTPUT,    
--    @n_err      = @n_Err    OUTPUT,    
--    @c_errmsg   = @c_ErrMsg OUTPUT   

-- (ChewKP01) 
   EXEC nspLogAlert
        @c_modulename       = 'TCP_ALLOCSHORT'     
      , @c_AlertMessage     = @c_AlertMessage   
      , @n_Severity         = '5'       
      , @b_success          = @b_success     OUTPUT       
      , @n_err              = @n_Err         OUTPUT         
      , @c_errmsg           = @c_Errmsg      OUTPUT      
      , @c_Activity	       = 'TCP_ALLOCSHORT'
      , @c_Storerkey	       = @c_Storerkey	   
      , @c_SKU	             = @c_Sku	         
      , @c_UOM	             = ''	         
      , @c_UOMQty	          = ''	      
      , @c_Qty	             = @n_OriginQtyShort
      , @c_Lot	             = ''         
      , @c_Loc	             = @c_TargetLoc	         
      , @c_ID	             = @c_ID	            
      , @c_TaskDetailKey	 = @c_MessageNum
      , @c_UCCNo	          = ''
                 
                           
           
   QUIT_SP:    
    
   IF @b_Debug = 1    
   BEGIN    
      SELECT 'Update TCPSocket_INLog >> @c_Status : ' + @c_Status    
           + ', @c_ErrMsg : ' + @c_ErrMsg    
   END    
       
   IF @n_Continue=3  -- Error Occured - Process And Return    
   BEGIN    
      ROLLBACK TRAN WCS_SHORT_ALLOC      
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'isp_TCP_ALLOCATED_SHORT_IN'    
   END    
       
   UPDATE dbo.TCPSocket_INLog WITH (ROWLOCK)    
   SET STATUS   = @c_Status    
     , ErrMsg   = @c_ErrMsg    
     , Editdate = GETDATE()    
     , EditWho  = SUSER_SNAME()    
   WHERE SerialNo = @n_SerialNo    
       
   WHILE @@TRANCOUNT > @n_StartTCnt -- Commit until the level we started      
      COMMIT TRAN WCS_SHORT_ALLOC      
       
   RETURN    
END

GO