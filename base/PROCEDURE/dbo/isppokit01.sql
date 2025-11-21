SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Procedure: ispPOKIT01                                            */  
/* Creation Date: 21-APR-2014                                              */  
/* Copyright: IDS                                                          */  
/* Written by: YTWan                                                       */  
/*                                                                         */  
/* Purpose: SOS#313159 - ANF - DTCTMALL Release task after Kitting finalize*/                                 
/*                                                                         */  
/* Called By:                                                              */  
/*                                                                         */  
/*                                                                         */  
/* PVCS Version: 1.0                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date       Ver  Author   Purposes                                       */  
/* 2014-08-07 1.1  ChewKP   Generate WCSRouting (ChewKP01)                 */     
/* 2014-08-28 1.2  ChewKP   Generate WCSRouting (ChewKP02)                 */    
/* 2014-09-05 1.3  ChewKP   Bug Fix (ChewKP03)                             */ 
/* 2014-10-14 1.1  YTWan    SOS#321081 - Finalize Kit enhancement (Wan01)  */ 
/***************************************************************************/    
CREATE PROC [dbo].[ispPOKIT01]    
(     @c_Kitkey      NVARCHAR(10)     
  ,   @b_Success     INT           OUTPUT  
  ,   @n_Err         INT           OUTPUT  
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT     
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @b_Debug              INT  
         , @n_Cnt                INT  
         , @n_Continue           INT   
         , @n_StartTCount        INT   
  
   DECLARE @c_IMLStatus          NVARCHAR(10)  
         , @c_TransferKey        NVARCHAR(10)  
           
         , @c_KitLineNumber      NVARCHAR(5)  
         , @c_Storerkey          NVARCHAR(15)  
         , @c_Sku                NVARCHAR(15)  
         , @c_Lot                NVARCHAR(10)  
         , @c_Loc                NVARCHAR(10)  
         , @c_ID                 NVARCHAR(18)  
         , @c_ToID               NVARCHAR(18)  
         , @n_Qty                INT  
         , @c_LogicalLoc         NVARCHAR(10)  
  
         , @c_UserID             NVARCHAR(30)  
         , @c_MoveToLoc          NVARCHAR(10)  
         , @c_LogicalMoveToLoc   NVARCHAR(10)  
  
         , @c_TaskdetailKey      NVARCHAR(10)  
         , @c_UOM                NVARCHAR(10)  
         , @c_Facility           NVARCHAR(10)  
         , @c_WCSKey             NVARCHAR(10)
  
   SET @b_Success= 1   
   SET @n_Err    = 0    
   SET @c_ErrMsg = ''  
   SET @b_Debug  = '0'   
   SET @n_Continue = 1    
   SET @n_StartTCount = @@TRANCOUNT    
   SET @c_UserID = SUSER_NAME()  
   SET @c_Facility = ''  
   SET @c_WCSKey = ''
  
   --(Wan01) - START
   IF @n_Continue = 1
   BEGIN
      SET @b_Success = 0  
      EXECUTE dbo.ispPOKIT02 
              @c_KitKey  = @c_KitKey
            , @b_Success = @b_Success     OUTPUT  
            , @n_Err     = @n_err         OUTPUT   
            , @c_ErrMsg  = @c_errmsg      OUTPUT  

      IF @n_err <> 0  
      BEGIN 
         SET @n_Continue= 3 
         SET @b_Success = 0
         SET @n_err  = 83000
         SET @c_errmsg = 'Execute ispPOKIT02 Failed.'
                       + '(' + @c_errmsg + ')'
         GOTO QUIT_SP 
      END 
   END
   --(Wan01) - END
   
   SELECT @c_TransferKey = ISNULL(RTRIM(ExternKitKey),'')  
   FROM KIT WITH (NOLOCK)  
   WHERE KitKey = @c_KitKey  
  
   SET @n_Cnt = 0  
   SELECT @c_IMLStatus = TransmitFlag  
        , @n_Cnt       = 1  
   FROM TRANSMITLOG3 TL3 WITH (NOLOCK)  
   WHERE TABLENAME = 'ANFTranAdd'  
   AND Key1 = @c_TransferKey  
  
   IF @n_Cnt = 0  
   BEGIN   
      GOTO QUIT_SP  
   END  
  
   IF @c_IMLStatus = 'IGNOR' OR -- NOT DTC transfer type  
      @c_IMLStatus = '0'        -- NOT Process Yet  
   BEGIN  
      GOTO QUIT_SP  
   END  
  
   BEGIN TRAN  
  
   DECLARE CUR_KIT2DET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT KitLineNumber= KD.KitLineNumber  
         ,Storerkey    = KD.Storerkey  
         ,Sku          = KD.Sku  
         ,Lot          = KD.Lot  
         ,Loc          = KD.Loc  
         ,ID           = KD.ID  
         ,Qty          = KD.Qty  
         ,LogicalLoc   = ISNULL(RTRIM(LOC.PALogicalLoc),'')  
   FROM KITDETAIL KD  WITH (NOLOCK)  
   JOIN LOC       LOC WITH (NOLOCK) ON (KD.Loc = LOC.Loc)  
   WHERE KD.KitKey = @c_Kitkey  
   AND   KD.Type   = 'T'  
   AND   KD.Status = '9'  
  
   OPEN CUR_KIT2DET  
  
   FETCH NEXT FROM CUR_KIT2DET INTO @c_KitLineNumber   
                                 ,  @c_Storerkey       
                                 ,  @c_Sku             
                                 ,  @c_Lot             
                                 ,  @c_Loc            
                                 ,  @c_ID             
                                 ,  @n_Qty             
                                 ,  @c_LogicalLoc  
  
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
  
      SELECT @c_Facility = Facility   
      FROM dbo.KIT WITH (NOLOCK)  
      WHERE KitKey = @c_Kitkey  
        
      SELECT TOP 1 @c_LOT = LOT   
      FROM ITRN WITH (NOLOCK)  
      WHERE StorerKey = @c_StorerKey   
      AND Sku   = @c_Sku  
      AND ToLoc = @c_Loc  
      AND ToId  = @c_ID  -- (ChewKP03) 
      AND SourceKey = @c_Kitkey + @c_KitLineNumber  
      AND TranType = 'DP'  
      AND SourceType IN ('ntrKitDetailAdd', 'ntrKitDetailUpdate')  
  
      EXEC @n_Err = [dbo].[nspRDTPASTD]  
                 @c_userid          = @c_UserID   
               , @c_storerkey       = @c_Storerkey  
               , @c_lot             = @c_Lot  
               , @c_sku             = @c_Sku  
               , @c_id              = @c_ID  -- (ChewKP01)
               , @c_fromloc         = @c_Loc  
               , @n_qty             = @n_Qty  
               , @c_uom             = '' -- not used  
               , @c_packkey         = '' -- optional, if pass-in SKU  
               , @n_putawaycapacity = 0  
               , @c_final_toloc     = @c_MoveToLoc OUTPUT  
  
  
      IF @n_Err <> 0  
      BEGIN  
         SET @n_Continue = 3   
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)       
         SET @n_Err = 83005      
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Executing Putaway Strategy nspRDTPASTD (ispPOKIT01)'  
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '     
         GOTO QUIT_SP  
      END  
  
      IF @c_MoveToLoc = ''  
      BEGIN  
         SET @n_Continue = 3   
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)       
         SET @n_Err = 83010  
         SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Empty Move To Loc found (ispPOKIT01)'  
    
         GOTO QUIT_SP  
      END  
        
      -- Create Pending Move In  
      IF @c_MoveToLoc <> ''    
      BEGIN    
         EXEC rdt.rdt_Putaway_PendingMoveIn @c_UserID, 'LOCK'    
            ,@c_Loc    
            ,@c_ID -- (ChewKP02)
            ,@c_MoveToLoc    
            ,@c_Storerkey    
            ,@n_Err  OUTPUT    
            ,@c_ErrMsg OUTPUT    
            ,@cSKU        = @c_Sku    
            ,@nPutawayQTY = @n_Qty    
            ,@cFromLOT    = @c_Lot    
            ,@cUCCNo      = ''  
      END    
                    
      -- Generate WCSRouting  
      EXEC [dbo].[ispWCSRO01]              
             @c_StorerKey     =  @c_Storerkey  
           , @c_Facility      =  @c_Facility           
           , @c_ToteNo        =  @c_ID            
           , @c_TaskType      =  'KIT'            
           , @c_ActionFlag    =  'D' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual         
           , @c_TaskDetailKey =  ''  
           , @c_Username      =  @c_UserID  
           , @c_RefNo01       =  @c_MoveToLoc         
           , @c_RefNo02       =  ''  
           , @c_RefNo03       =  ''  
           , @c_RefNo04       =  ''  
           , @c_RefNo05       =  ''  
           , @b_debug         =  '0'  
           , @c_LangCode      =  'ENG'   
           , @n_Func          =  0          
           , @b_Success       = @b_success OUTPUT              
           , @n_ErrNo         = @n_Err    OUTPUT            
           , @c_ErrMsg        = @c_ErrMsg   OUTPUT    
                       
        
      EXEC [dbo].[ispWCSRO01]              
             @c_StorerKey     =  @c_Storerkey  
           , @c_Facility      =  @c_Facility           
           , @c_ToteNo        =  @c_ID            
           , @c_TaskType      =  'KIT'            
           , @c_ActionFlag    =  'N' -- N = New, F = Full, S = Short, D = Delete, R = PA Risidual         
           , @c_TaskDetailKey =  ''  
           , @c_Username      =  @c_UserID  
           , @c_RefNo01       =  @c_MoveToLoc          
           , @c_RefNo02       =  ''  
           , @c_RefNo03       =  ''  
           , @c_RefNo04       =  ''  
           , @c_RefNo05       =  ''  
           , @b_debug         =  '0'  
           , @c_LangCode      =  'ENG'   
           , @n_Func          =  0          
           , @b_Success       = @b_success OUTPUT              
           , @n_ErrNo         = @n_Err    OUTPUT            
           , @c_ErrMsg        = @c_ErrMsg   OUTPUT    
           
      -- Update WCSRouting, WCSRoutingDetail to Status = '9'
      DECLARE CUR_WCSKIT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT WCSKey FROM dbo.WCSRouting WITH (NOLOCK)
      WHERE ToteNo = @c_ID
      AND TaskType = 'KIT'
      AND Status = '0'
      
      OPEN CUR_WCSKIT  
      
      FETCH NEXT FROM CUR_WCSKIT INTO @c_WCSKey
  
      
      WHILE @@FETCH_STATUS <> -1  
      BEGIN  
           
           
           UPDATE dbo.WCSRouting WITH (ROWLOCK)
           SET Status = '9'
           WHERE ToteNo = @c_ID 
           AND TaskType = 'KIT'
           AND Status = '0'
           AND WCSKey = @c_WCSKey 
           
           IF @@ERROR <> 0   
           BEGIN  
               SET @n_Continue = 3   
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)       
               SET @n_Err = 83010  
               SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Update WCSRouting Fail (ispPOKIT01)'  
          
               GOTO QUIT_SP  
           END  
           
           
           UPDATE dbo.WCSRoutingDetail WITH (ROWLOCK)
           SET Status = '9'
           WHERE ToteNo = @c_ID 
           AND WCSKey = @c_WCSKey
           
           IF @@ERROR <> 0   
           BEGIN  
               SET @n_Continue = 3   
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)       
               SET @n_Err = 83010  
               SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Update WCSRoutingDetail Fail (ispPOKIT01)'  
          
               GOTO QUIT_SP  
           END  

           FETCH NEXT FROM CUR_WCSKIT INTO @c_WCSKey
        
        
      END
      CLOSE CUR_WCSKIT  
      DEALLOCATE CUR_WCSKIT  
        
--      SET @c_ToID = @c_ID  
--  
--      IF EXISTS ( SELECT 1   
--                  FROM LOC WITH (NOLOCK)  
--                  WHERE Loc = @c_MoveToLoc  
--                  AND LocationType = 'DYNPPICK' )  
--      BEGIN  
--         SET @c_toid = ''  
--      END  
--  
--      IF NOT EXISTS(SELECT 1 FROM LOTXLOCXID LLI WITH (NOLOCK)  
--                    WHERE LLI.Storerkey = @c_Storerkey  
--                    AND LLI.Sku = @c_Sku   
--                    AND LLI.Lot = @c_Lot  
--                    AND LLI.Loc = @c_MoveToLoc  
--                    AND LLI.Id  = @c_toid)  
--      BEGIN  
--         INSERT INTO LOTXLOCXID (Storerkey, Sku, Lot, Loc, ID, Qty, PendingMoveIN)  
--         VALUES (@c_Storerkey, @c_Sku, @c_Lot, @c_MoveToLoc, @c_toid, 0, @n_Qty)  
--  
--         SET @n_err = @@ERROR    
--  
--         IF @n_err <> 0       
--         BEGIN    
--            SET @n_continue = 3      
--            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
--            SET @n_err = 83010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
--            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': INSERT LOTxLOCxID Failed. (ispPOKIT01)'   
--                         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
--            GOTO QUIT_SP    
--         END   
--      END  
--      ELSE  
--      BEGIN  
--         UPDATE LOTXLOCXID WITH (ROWLOCK)  
--         SET PendingMoveIN = PendingMoveIN + @n_Qty  
--         WHERE Storerkey = @c_Storerkey  
--         AND Sku = @c_Sku  
--         AND Lot = @c_Lot  
--         AND Loc = @c_MoveToLoc  
--         AND ID  = @c_toid  
--  
--         SET @n_err = @@ERROR     
--  
--         IF @n_err <> 0      
--         BEGIN    
--            SET @n_continue = 3      
--            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
--            SET @n_err = 83015  -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
--            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update LOTxLOCxID Failed. (ispPOKIT01)'   
--                         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
--            GOTO QUIT_SP    
--         END   
--      END      
--  
--      
--      SET @b_success = 1      
--      EXECUTE nspg_getkey      
--               'TaskDetailKey'      
--              , 10      
--              , @c_TaskdetailKey OUTPUT      
--              , @b_success       OUTPUT      
--              , @n_err           OUTPUT      
--              , @c_errmsg        OUTPUT   
--  
--      IF NOT @b_success = 1      
--      BEGIN      
--         SET @n_continue = 3      
--         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
--         SET @n_err = 83020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
--         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert TASKDETAIL Failed. (ispPOKIT01)'   
--                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '    
--         GOTO QUIT_SP    
--      END      
--  
--      IF @b_success = 1      
--      BEGIN   
--         SELECT @c_UOM = PACK.PackUOM3  
--         FROM SKU  WITH (NOLOCK)  
--         JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)  
--         WHERE Storerkey = @c_Storerkey  
--         AND   Sku = @c_Sku  
--  
--         SELECT @c_LogicalMoveToLoc = ISNULL(RTRIM(LOC.PALogicalLoc),'')  
--         FROM LOC WITH (NOLOCK)  
--         WHERE Loc = @c_MoveToLoc  
--         
--         INSERT TASKDETAIL      
--            (      
--               TaskDetailKey      
--            ,  TaskType      
--            ,  Storerkey      
--            ,  Sku      
--            ,  UOM      
--            ,  UOMQty      
--            ,  Qty      
--            ,  SystemQty    
--            ,  Lot      
--            ,  FromLoc      
--            ,  FromID      
--            ,  ToLoc      
--            ,  ToID  
--            ,  PickMethod      
--            ,  SourceType      
--            ,  SourceKey      
--            ,  Priority      
--            ,  SourcePriority      
--            ,  Status      
--            ,  LogicalFromLoc      
--            ,  LogicalToLoc      
--            )      
--         VALUES      
--            (      
--               @c_Taskdetailkey      
--            ,  'PA'           --Tasktype      
--            ,  @c_Storerkey      
--            ,  @c_Sku      
--            ,  @c_UOM         -- UOM,      
--            ,  @n_Qty   
--            ,  @n_Qty      
--            ,  @n_Qty         --systemqty    
--            ,  @c_Lot       
--            ,  @c_loc       
--            ,  @c_ID          -- from id      
--            ,  @c_MoveToLoc     
--            ,  @c_toid        -- to id  
--            ,  'PP'      
--            ,  'ispPOKIT01'   --Sourcetype      
--            ,  @c_KitKey + @c_KitLineNumber  
--            ,  '9'            -- Priority      
--            ,  '9'            -- Sourcepriority      
--            ,  '0'            -- Status      
--            ,  @c_LogicalLoc  --Logical from loc      
--            ,  @c_LogicalMoveToLoc   --Logical to loc      
--            )    
--  
--         SET @n_err = @@ERROR     
--  
--         IF @n_err <> 0      
--         BEGIN    
--  
--            SET @n_continue = 3      
--            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
--            SET @n_err = 83025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
--            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert TASKDETAIL Failed. (ispPOKIT01)'   
--                         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '      
--  
--            GOTO QUIT_SP    
--         END   
--      END     
      FETCH NEXT FROM CUR_KIT2DET INTO @c_KitLineNumber   
                                    ,  @c_Storerkey       
                                    ,  @c_Sku             
                                    ,  @c_Lot             
                                    ,  @c_Loc            
                                    ,  @c_ID             
                                    ,  @n_Qty             
                                    ,  @c_LogicalLoc   
   END  
   CLOSE CUR_KIT2DET  
   DEALLOCATE CUR_KIT2DET  
  
   QUIT_SP:  
  
   IF CURSOR_STATUS('LOCAL' , 'CUR_KIT2DET') in (0 , 1)  
   BEGIN  
      CLOSE CUR_KIT2DET  
      DEALLOCATE CUR_KIT2DET  
   END  
  
   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_success = 0  
  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCount  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCount  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      Execute nsp_logerror @n_err, @c_errmsg, 'ispPOKIT01'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTCount  
      BEGIN  
         COMMIT TRAN  
      END   
  
      RETURN  
   END   
END 


GO