SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: ispPOUNI02                                         */    
/* Creation Date: 05-Aug-2014                                           */    
/* Copyright: LFL                                                       */    
/* Written by: Chee Jun Yan                                             */    
/*                                                                      */    
/* Purpose: SOS#315963 - Assign unique CaseID to FullCase & ZoneID for  */    
/*          SKU in wave                                                 */    
/*                                                                      */    
/* Called By:                                                           */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 1.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver.  Purposes                                */    
/* 08-Sep-2014  Shong     1.1   Update ZoneID to PickDetail.DropID      */    
/* 08-Oct-2014  Chee      1.2   Update PickDetail.UOMQty (Chee01)       */    
/* 27-Oct-2014  Shong     1.3   Change BUSR6 to BUSR7                   */    
/* 30-Oct-2014  Chee      1.4   Bug Fix (Chee02)                        */    
/************************************************************************/    
CREATE PROC [dbo].[ispPOUNI02]    
    @c_WaveKey                      NVARCHAR(10)    
  , @c_UOM                          NVARCHAR(10)    
  , @c_LocationTypeOverride         NVARCHAR(10)    
  , @c_LocationTypeOverRideStripe   NVARCHAR(10)    
  , @b_Success                      INT           OUTPUT    
  , @n_Err                          INT           OUTPUT    
  , @c_ErrMsg                       NVARCHAR(250) OUTPUT    
  , @b_Debug                        INT = 0    
AS    
BEGIN    
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE        
      @n_Continue    INT,        
      @n_StartTCnt   INT        
        
   DECLARE        
      @c_PickDetailKey    NVARCHAR(18),        
      @c_NewPickDetailKey NVARCHAR(18),        
      @c_CaseID           NVARCHAR(20),        
      @c_PackKey          NVARCHAR(10),        
      @n_PackSize         INT,        
      @n_Qty              INT,        
      @n_Count            INT,    
    
      -- (Chee01)    
      @n_UOMQty           INT,    
      @n_PDQty            INT,    
      @c_OrderKey         NVARCHAR(10),       
      @c_OrderLineNumber  NVARCHAR(5),    
      @c_StorerKey        NVARCHAR(15),   
      @c_LOT              NVARCHAR(10),  
      @c_LOC              NVARCHAR(10)     
    
   SELECT @n_StartTCnt = @@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0, @c_ErrMsg=''        
        
   -- Update PickDetail.DropID with ZoneID (Unique by WaveKey & SKU)        
   DECLARE @t_ZoneID TABLE (      
      ZoneID      NVARCHAR(20)      
     ,SKU         NVARCHAR(20)      
     ,PutawayZone NVARCHAR(10))      
      
   DECLARE @c_SKU NVARCHAR(20)      
          ,@c_PutawayZone NVARCHAR(10)      
          ,@c_ZoneLblNo   NVARCHAR(10)      
                
   INSERT INTO @t_ZoneID        
   SELECT MAX(ISNULL(PD.DropID,'')) AS ZoneID, PD.SKU, LOC.PutawayZone      
   FROM dbo.PickDetail PD WITH (NOLOCK)       
   JOIN ORDERS AS O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey       
   JOIN WAVEDETAIL AS W WITH (NOLOCK) ON w.OrderKey = O.OrderKey       
   LEFT OUTER JOIN StoreToLocDetail AS stld WITH (NOLOCK) ON stld.ConsigneeKey = O.ConsigneeKey AND stld.[Status] = '1'       
   LEFT OUTER JOIN LOC AS LOC WITH (NOLOCK) ON LOC.LOC = stld.LOC        
   WHERE W.WaveKey = @c_WaveKey       
   GROUP BY PD.SKU, loc.PutawayZone      
      
   DECLARE CUR_ZONE_ID CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT SKU, PutawayZone       
   FROM   @t_ZoneID      
   WHERE  ZoneID = ''      
   ORDER BY SKU, PutawayZone      
      
   OPEN CUR_ZONE_ID      
      
   FETCH NEXT FROM CUR_ZONE_ID INTO @c_SKU, @c_PutawayZone       
   WHILE @@FETCH_STATUS <> -1      
   BEGIN      
      EXECUTE dbo.nspg_getkey          
         'ZONELBLID'          
         ,10          
         , @c_ZoneLblNo OUTPUT          
         , @b_success OUTPUT          
         , @n_err OUTPUT       
         , @c_errmsg OUTPUT             
            
      UPDATE @t_ZoneID      
      SET ZoneID = @c_ZoneLblNo      
      WHERE SKU = @c_SKU      
      AND   PutawayZone = @c_PutawayZone      
            
      FETCH NEXT FROM CUR_ZONE_ID INTO @c_SKU, @c_PutawayZone      
   END      
   CLOSE CUR_ZONE_ID      
   DEALLOCATE CUR_ZONE_ID      
      
   UPDATE PD       
      SET Dropid = Z.ZoneID, TrafficCop=NULL      
   FROM dbo.PickDetail PD WITH (NOLOCK)       
   JOIN ORDERS AS O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey       
   JOIN WAVEDETAIL AS W WITH (NOLOCK) ON w.OrderKey = O.OrderKey       
   JOIN StoreToLocDetail AS stld WITH (NOLOCK) ON stld.ConsigneeKey = O.ConsigneeKey AND stld.[Status] = '1'       
   JOIN LOC AS LOC WITH (NOLOCK) ON LOC.LOC = stld.LOC       
   JOIN @t_ZoneID Z ON Z.PutawayZone = LOC.PutawayZone AND Z.Sku = PD.Sku        
   WHERE W.WaveKey = @c_WaveKey       
   AND   (PD.DropID IS NULL OR PD.DropID = '')      
   IF @@ERROR <> 0          
   BEGIN          
      SET @n_Continue = 3          
      SET @n_Err = 14001         
      SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +           
                      ': Update PickDetail Failed. (ispPOUNI02)'          
      GOTO Quit          
   END    
    
   -- Swap this procedure from after generating CaseID to before (Chee02)    
   -- Update Pickdetail.UOMQty = PickQty / PackQty (Chee01)      
   DECLARE CURSOR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR          
   SELECT PD.PickDetailKey, PD.OrderKey, PD.OrderLineNumber, PD.StorerKey,       
          PD.SKU, PD.UOM, PD.Qty, PD.PackKey, PD.LOT, PD.LOC       
   FROM dbo.PickDetail PD WITH (NOLOCK)          
   JOIN WAVEDETAIL AS W WITH (NOLOCK) ON W.OrderKey = PD.OrderKey      
   WHERE W.WaveKey = @c_WaveKey      
     AND ISNULL(PD.CaseID, '') = ''      
   ORDER BY PD.SKU      
      
   OPEN CURSOR_PICKDETAIL      
   FETCH NEXT FROM CURSOR_PICKDETAIL INTO @c_PickDetailKey, @c_OrderKey, @c_OrderLineNumber, @c_StorerKey,      
                                          @c_SKU, @c_UOM, @n_Qty, @c_PackKey, @c_LOT, @c_LOC     
    
   WHILE (@@FETCH_STATUS <> -1)          
   BEGIN          
      SELECT @n_PackSize = CASE @c_UOM      
                           WHEN '1' THEN Pallet      
                           WHEN '2' THEN CaseCnt      
                           WHEN '3' THEN InnerPack      
                           WHEN '4' THEN CONVERT(INT,OtherUnit1)      
                           WHEN '5' THEN CONVERT(INT,OtherUnit2)      
                           WHEN '6' THEN 1      
                           WHEN '7' THEN 1      
                           ELSE 1      
                        END      
      FROM PACK WITH (NOLOCK)      
      WHERE PackKey = @c_PackKey      
      
      WHILE @n_Qty > 0          
      BEGIN      
         IF @n_Qty % @n_PackSize = 0      
         BEGIN      
            SET @n_PDQty = @n_Qty      
      
            UPDATE PickDetail WITH (ROWLOCK)          
            SET UOM = @c_UOM,   
                UOMQty = @n_PDQty / @n_PackSize,   
                Qty = @n_PDQty,   
                TrafficCop = NULL, Notes = ISNULL(Notes, ',') + 'Update Qty ' + CAST(@n_PDQty AS VARCHAR(10)) +   
                                       ' FROM P.Qty ' +  CAST(Qty AS VARCHAR(10))         
            WHERE PickDetailKey = @c_PickDetailKey           
          
            IF @@ERROR <> 0          
            BEGIN          
               SET @n_Continue = 3          
               SET @n_Err = 14006          
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +           
                               ': Update PickDetail Failed. (ispPOUNI02)'          
               GOTO Quit          
            END      
         END      
         ELSE      
         BEGIN      
            SET @n_UOMQty = @n_Qty / @n_PackSize      
      
            -- Split line based on UOM Qty      
            IF @n_UOMQty > 0      
            BEGIN      
               SET @n_PDQty = @n_PackSize * @n_UOMQty      
      
               -- Split PickDetail Lines                 
               EXECUTE dbo.nspg_GetKey              
                     'PICKDETAILKEY',              
                     10,              
                     @c_NewPickDetailKey OUTPUT,              
                     @b_Success          OUTPUT,              
                     @n_Err              OUTPUT,              
                     @c_ErrMsg           OUTPUT              
               
               IF @b_Success <> 1              
               BEGIN              
                  SET @b_Success = 0            
                  SET @n_Err = 14007          
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +            
                                  ': Unable to retrieve new PickdetailKey. (ispPOUNI02)'            
                  GOTO Quit           
               END            
                               
               -- Create a new PickDetail              
               INSERT INTO dbo.PICKDETAIL              
                  (              
                    CaseID               ,PickHeaderKey     ,OrderKey              
                   ,OrderLineNumber      ,LOT               ,StorerKey              
                   ,SKU                  ,AltSKU            ,UOM              
                   ,UOMQTY               ,QTYMoved          ,STATUS              
                   ,DropID               ,LOC               ,ID              
                   ,PackKey              ,UpdateSource      ,CartonGroup              
                   ,CartonType           ,ToLoc             ,DoReplenish              
                   ,ReplenishZone        ,DoCartonize       ,PickMethod              
                   ,WaveKey              ,EffectiveDate     ,ArchiveCop              
                   ,ShipFlag             ,PickSlipNo        ,PickDetailKey              
                   ,QTY                  ,TrafficCop        ,OptimizeCop           
                   ,TaskDetailkey        ,Notes              
                  )              
               SELECT          
                    CaseID               ,PickHeaderKey     ,OrderKey              
                   ,OrderLineNumber      ,Lot               ,StorerKey              
                   ,SKU                  ,AltSku            ,@c_UOM              
                   ,@n_UOMQty            ,QTYMoved          ,STATUS              
                   ,DropID               ,LOC               ,ID              
                   ,PackKey              ,UpdateSource      ,CartonGroup              
                   ,CartonType           ,ToLoc             ,DoReplenish              
                   ,ReplenishZone        ,DoCartonize       ,PickMethod              
                   ,WaveKey              ,EffectiveDate     ,ArchiveCop              
                   ,ShipFlag             ,PickSlipNo        ,@c_NewPickDetailKey              
                   ,@n_PDQty             ,NULL              ,'1'           
                   ,TaskDetailkey        ,'ispPOUNI02-A'      
               FROM   dbo.PickDetail WITH (NOLOCK)              
               WHERE PickDetailKey = @c_PickDetailKey          
          
   IF @@ERROR <> 0               
               BEGIN              
                  SET @b_Success = 0            
                  SET @n_Err = 14008         
                  SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +            
                                  ': Insert Pickdetail Failed. (ispPOUNI02)'            
                  GOTO Quit           
               END      
            END -- IF @n_UOMQty > 0    
            ELSE      
            BEGIN      
--               SELECT @n_UOMQty = 0, @n_PDQty = 0    
--                   
--               SELECT @n_UOMQty = SUM(PD.Qty)      
--               FROM dbo.PickDetail PD WITH (NOLOCK)      
--               JOIN WAVEDETAIL AS W WITH (NOLOCK) ON W.OrderKey = PD.OrderKey      
--               WHERE W.WaveKey = @c_WaveKey      
--                 AND ISNULL(PD.CaseID, '') = ''      
--                 AND PD.OrderKey = @c_OrderKey      
--                 AND PD.OrderLineNumber = @c_OrderLineNumber      
--                 AND PD.StorerKey = @c_StorerKey      
--                 AND PD.SKU = @c_SKU      
--                 AND PD.UOM > @c_UOM      
--                 AND PD.LOT = @c_LOT  
--                 AND PD.LOC = @c_LOC   
--      
--                Regroup UOM if exists UOM > current UOM      
--               IF @n_UOMQty > 0      
--               BEGIN      
--                  SET @n_UOMQty = @n_UOMQty + @n_Qty      
--                  SET @n_Qty = @n_UOMQty      
--      
--                   Update ArchiveCop to 9 to avoid trigger when delete      
--                  UPDATE PD      
--                  SET ArchiveCop = '9'      
--                  FROM dbo.PickDetail PD WITH (NOLOCK)      
--                  JOIN WAVEDETAIL AS W WITH (NOLOCK) ON W.OrderKey = PD.OrderKey      
--                  WHERE W.WaveKey = @c_WaveKey      
--                    AND ISNULL(PD.CaseID, '') = ''      
--                    AND PD.OrderKey = @c_OrderKey      
--                    AND PD.OrderLineNumber = @c_OrderLineNumber      
--                    AND PD.StorerKey = @c_StorerKey      
--                    AND PD.SKU = @c_SKU      
--                    AND PD.UOM > @c_UOM    
--                    AND PD.LOT = @c_LOT  
--                    AND PD.LOC = @c_LOC                       
--    
--                  IF @@ERROR <> 0       
--                  BEGIN    
--                     SET @b_Success = 0            
--                     SET @n_Err = 14009        
--                     SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +            
--                                     ': Update Pickdetail Failed. (ispPOUNI02)'            
--                     GOTO Quit           
--                  END      
--      
--                  DELETE PD      
--                  FROM dbo.PickDetail PD WITH (NOLOCK)      
--                  JOIN WAVEDETAIL AS W WITH (NOLOCK) ON W.OrderKey = PD.OrderKey      
--                  WHERE W.WaveKey = @c_WaveKey      
--                    AND ISNULL(PD.CaseID, '') = ''      
--                    AND PD.OrderKey = @c_OrderKey      
--                    AND PD.OrderLineNumber = @c_OrderLineNumber      
--                    AND PD.StorerKey = @c_StorerKey      
--                    AND PD.SKU = @c_SKU      
--                    AND PD.UOM > @c_UOM      
--                    AND PD.LOT = @c_LOT  
--                    AND PD.LOC = @c_LOC   
--                       
--                  IF @@ERROR <> 0      
--                  BEGIN      
--                     SET @b_Success = 0      
--                     SET @n_Err = 14010      
--                     SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +      
--                                     ': Delete Pickdetail Failed. (ispPOUNI02)'      
--                     GOTO Quit           
--                  END      
--      
--                   Set suitable PackSize      
--                  SELECT @n_PackSize = 0, @c_UOM = '1'      
--                  WHILE @n_PackSize = 0      
--                  BEGIN      
--                     SELECT @n_PackSize = CASE @c_UOM      
--                                          WHEN '1' THEN Pallet      
--                                          WHEN '2' THEN CaseCnt      
--                                          WHEN '3' THEN InnerPack      
--                                          WHEN '4' THEN CONVERT(INT,OtherUnit1)      
--                                          WHEN '5' THEN CONVERT(INT,OtherUnit2)      
--                                          ELSE 1      
--                                       END      
--                     FROM PACK WITH (NOLOCK)      
--                     WHERE PackKey = @c_PackKey      
--      
--                     IF @n_PackSize > @n_UOMQty      
--                        SET @n_PackSize = 0      
--      
--                     IF @c_UOM >= '6'      
--                        SET @n_PackSize = 1      
--                     ELSE IF @n_PackSize = 0      
--                        SELECT @c_UOM = CONVERT(NVARCHAR(1), CONVERT(INT,@c_UOM)+1)      
--                  END -- WHILE @n_PackSize = 0      
--               END -- IF @n_UOMQty > 0      
--               ELSE      
               BEGIN      
                  SET @n_PDQty = @n_Qty      
      
                  -- Update UOMQty = Remaining Qty, UOM = '6' (piece)      
                  UPDATE PickDetail WITH (ROWLOCK)          
                  SET UOM = '6', UOMQty = @n_PDQty, Qty = @n_PDQty,   
                      TrafficCop = NULL, Notes = ISNULL(Notes, ',') + 'Update UOM = 6 '   
                                       + CAST(@n_PDQty AS VARCHAR(10)) +   
                                       ' FROM P.Qty ' +  CAST(Qty AS VARCHAR(10))         
                  WHERE PickDetailKey = @c_PickDetailKey    
    
                  IF @@ERROR <> 0    
                  BEGIN    
                     SET @n_Continue = 3    
                     SET @n_Err = 14011    
                     SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +      
                                     ': Update PickDetail Failed. (ispPOUNI02)'    
                     GOTO Quit    
                  END    
               END -- IF @n_UOMQty = 0    
            END -- IF @n_UOMQty = 0    
         END -- IF @n_Qty % @n_PackSize <> 0    
         SET @n_Qty = @n_Qty - @n_PDQty    
      END -- WHILE @n_Qty > 0    
    
      FETCH NEXT FROM CURSOR_PICKDETAIL INTO @c_PickDetailKey, @c_OrderKey, @c_OrderLineNumber, @c_StorerKey,    
                                             @c_SKU, @c_UOM, @n_Qty, @c_PackKey, @c_LOT, @c_LOC     
   END -- END WHILE FOR CURSOR_PICKDETAIL    
   CLOSE CURSOR_PICKDETAIL    
   DEALLOCATE CURSOR_PICKDETAIL          
        
   -- Generate unique CaseID for Full Case Carton        
   DECLARE CURSOR_PICKDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT PD.PickDetailKey, PD.Qty,    
          CASE WHEN SKU.BUSR7 = 'CTN' THEN ISNULL(P.CaseCnt, 0)    
               WHEN SKU.BUSR7 = 'IN'  THEN ISNULL(P.InnerPack, 0)    
               WHEN SKU.BUSR7 = 'EA'  THEN 1    
          END    
   FROM dbo.PickDetail PD WITH (NOLOCK)    
   JOIN WAVEDETAIL AS w WITH (NOLOCK) ON w.OrderKey = PD.OrderKey    
   JOIN dbo.SKU SKU WITH (NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU    
   JOIN Pack P WITH (NOLOCK) ON SKU.PackKey = P.PackKey    
   WHERE W.WaveKey = @c_WaveKey    
     AND SKU.BUSR7 IN ('CTN', 'IN','EA')    
     AND ISNULL(PD.CaseID, '') = ''    
        
   OPEN CURSOR_PICKDETAIL    
   FETCH NEXT FROM CURSOR_PICKDETAIL INTO @c_PickDetailKey, @n_Qty, @n_PackSize    
    
   WHILE (@@FETCH_STATUS <> -1)    
   BEGIN        
      IF @n_PackSize = 0         
         GOTO FETCH_NEXT_PICKDETAIL        
                 
      -- SPLIT PickDetail record for each case              
      WHILE @n_Qty > 0     
            AND @n_Qty % @n_PackSize = 0 -- (Chee02)      
      BEGIN              
         EXECUTE dbo.nspg_GetKey                  
            'UnityCaseID',                  
   10,                  
            @c_CaseID      OUTPUT,                        
            @b_Success     OUTPUT,              
            @n_Err         OUTPUT,              
            @c_ErrMsg      OUTPUT              
              
         IF @b_Success <> 1                  
         BEGIN                  
            SET @b_Success = 0                
            SET @n_Err = 14002              
            SET @c_Errmsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +                 
                           ': Unable to retrieve new CaseID. (ispPOUNI02)'               
            GOTO Quit               
         END               
         
         IF @n_Qty > @n_PackSize               
         BEGIN                        
            -- Split PickDetail Lines                     
            EXECUTE dbo.nspg_GetKey                  
                  'PICKDETAILKEY',                  
                  10,                  
                  @c_NewPickDetailKey OUTPUT,                  
                  @b_Success          OUTPUT,                  
                  @n_Err              OUTPUT,                  
                  @c_ErrMsg           OUTPUT                  
                   
            IF @b_Success <> 1                  
            BEGIN                  
               SET @b_Success = 0                
               SET @n_Err = 14003              
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +                
                               ': Unable to retrieve new PickdetailKey. (ispPOUNI02)'                
               GOTO Quit               
            END                
                                   
            -- Create a new PickDetail                  
            INSERT INTO dbo.PICKDETAIL                  
               (                  
                 CaseID               ,PickHeaderKey     ,OrderKey                  
                ,OrderLineNumber      ,LOT               ,StorerKey                  
                ,SKU                  ,AltSKU            ,UOM                  
                ,UOMQTY               ,QTYMoved          ,STATUS                  
                ,DropID               ,LOC               ,ID                  
                ,PackKey              ,UpdateSource      ,CartonGroup                  
                ,CartonType           ,ToLoc             ,DoReplenish                  
                ,ReplenishZone        ,DoCartonize       ,PickMethod                  
                ,WaveKey              ,EffectiveDate     ,ArchiveCop                  
                ,ShipFlag             ,PickSlipNo        ,PickDetailKey                  
                ,QTY                  ,TrafficCop        ,OptimizeCop               
                ,TaskDetailkey        ,Notes          
               )                  
            SELECT              
                 @c_CaseID            ,PickHeaderKey     ,OrderKey                  
                ,OrderLineNumber      ,Lot               ,StorerKey                  
                ,SKU                  ,AltSku            ,UOM                  
                ,1                    ,QTYMoved          ,STATUS                  
                ,DropID               ,LOC               ,ID                  
                ,PackKey              ,UpdateSource      ,CartonGroup                  
                ,CartonType           ,ToLoc             ,DoReplenish                  
                ,ReplenishZone        ,DoCartonize       ,PickMethod                  
                ,WaveKey              ,EffectiveDate     ,ArchiveCop                  
                ,ShipFlag             ,PickSlipNo        ,@c_NewPickDetailKey                  
                ,@n_PackSize          , NULL             ,'1'               
                ,TaskDetailkey        ,'ispPOUNI02-B'          
            FROM   dbo.PickDetail WITH (NOLOCK)                  
            WHERE PickDetailKey = @c_PickDetailKey        
              
            IF @@ERROR <> 0                   
            BEGIN                  
               SET @b_Success = 0                
               SET @n_Err = 14004              
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +                
                               ': Insert Pickdetail Failed. (ispPOUNI02)'                
               GOTO Quit               
            END              
              
            SET @n_Qty = @n_Qty - @n_PackSize              
         END                 
         ELSE              
         BEGIN              
            UPDATE PickDetail WITH (ROWLOCK)              
            SET CaseID = CASE WHEN @n_Qty = @n_PackSize THEN @c_CaseID ELSE '' END, -- (SHONG01)        
                Qty = @n_Qty,         
                UOMQty = 1,         
                TrafficCop = NULL,   
                Notes = 'Update Qty (Case ID) ' + CAST(@n_Qty AS VARCHAR(10)) +   
                                       ' FROM P.Qty ' +  CAST(Qty AS VARCHAR(10))               
            WHERE PickDetailKey = @c_PickDetailKey               
         
            IF @@ERROR <> 0              
            BEGIN              
               SET @n_Continue = 3              
               SET @n_Err = 14005              
               SET @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5),ISNULL(@n_Err,0)) +               
                               ': Update PickDetail Failed. (ispPOUNI02)'              
               GOTO Quit              
            END              
            SET @n_Qty = 0    
         END    
      END -- WHILE @n_Qty > 0    
    
      FETCH_NEXT_PICKDETAIL:    
      FETCH NEXT FROM CURSOR_PICKDETAIL INTO @c_PickDetailKey, @n_Qty, @n_PackSize    
   END -- END WHILE FOR CURSOR_PICKDETAIL        
   CLOSE CURSOR_PICKDETAIL        
   DEALLOCATE CURSOR_PICKDETAIL    
    
QUIT:        
   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_PICKDETAIL')) >=0        
   BEGIN        
      CLOSE CURSOR_PICKDETAIL        
      DEALLOCATE CURSOR_PICKDETAIL        
   END        
        
   IF @n_Continue=3  -- Error Occured - Process And Return        
   BEGIN        
      SELECT @b_Success = 0        
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOUNI02'        
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012        
      RETURN        
   END        
   ELSE        
   BEGIN        
      SELECT @b_Success = 1        
      WHILE @@TRANCOUNT > @n_StartTCnt        
      BEGIN        
         COMMIT TRAN        
      END        
      RETURN        
   END        
        
END -- Procedure 


GO