SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/**************************************************************************/       
/* Stored Proc: ispPOGenReplen01                                          */       
/* Creation Date: 13-JAN-2018                                             */       
/* Copyright: LF Logistics                                                */       
/* Written by: Wan                                                        */       
/*                                                                        */       
/* Purpose: WMS-5218 - [CN] UA Relocation Phase II - Exceed Generate      */       
/*          and Confirm Replenishment(B2C)                                */        
/*                                                                        */        
/* Called By: ispPostGenEOrderReplenWrapper                               */       
/*          :                                                             */       
/* PVCS Version: 1.2                                                      */       
/*                                                                        */       
/* Version: 7.0                                                           */       
/*                                                                        */       
/* Data Modifications:                                                    */       
/*                                                                        */       
/* Updates:                                                               */       
/* Date        Author   Ver   Purposes                                    */       
/* 07-Apr-2019 NJOW01   1.0   Cater for WCS configuration                 */      
/* 23-Mar-2020 LZG      1.1   Added StorerKey filter (ZG01)               */    
/* 03-Jun-2023 NJOW02   1.2   Fix drop id not update due to pickdetial    */
/*                            qty groping with pickslipno                 */
/* 14-Jun-2023 NJOW03   1.3   WMS-22845 Send to WCS failed not to rollback*/
/*                            the updated ucc and pickdetail and continue */
/*                            next ucc. WCS issue will fix later sperately*/
/**************************************************************************/       
CREATE   PROC [dbo].[ispPOGenReplen01]       
           @c_ReplenishmentGroup NVARCHAR(10)        
         , @b_Success            INT            OUTPUT       
         , @n_Err                INT            OUTPUT       
         , @c_ErrMsg             NVARCHAR(255)  OUTPUT       
AS       
BEGIN       
   SET NOCOUNT ON       
   SET ANSI_NULLS OFF       
   SET QUOTED_IDENTIFIER OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF       
       
   DECLARE         
           @n_StartTCnt          INT       
         , @n_Continue           INT        
         , @n_Cnt                INT       
         , @n_PDCnt              INT       
         , @n_WCSCnt             INT       
         , @n_NoOfUCCNoNeed      INT       
       
         , @c_BatchNo            NVARCHAR(10)       
         , @c_Storerkey          NVARCHAR(15)       
         , @c_Lot                NVARCHAR(10)       
         , @c_FromLoc            NVARCHAR(10)       
         , @c_ID                 NVARCHAR(20)        
         , @c_ToLoc              NVARCHAR(10)         
       
         , @n_Qty                INT       
         , @n_CaseCnt            FLOAT       
       
         , @n_UCC_RowRef         BIGINT           
         , @c_UCCNo              NVARCHAR(20)       
         , @c_Replenishmentkey   NVARCHAR(10)       
         , @c_PickDetailKey      NVARCHAR(10)       
         , @c_PutawayZone        NVARCHAR(10)        
       
         , @c_WCSKey             NVARCHAR(10)       
         , @c_WCSStation         NVARCHAR(10)       
         , @c_WCSSequence        NVARCHAR(2)       
         , @c_WCSMessage         NVARCHAR(60)           
         , @c_DeviceType         NVARCHAR(10)         
         , @c_DeviceID           NVARCHAR(10)         
         , @c_WCS                NVARCHAR(10) --NJOW01       
       
             
         , @cur_PICKNREPLEN      CURSOR       
         , @cur_PD               CURSOR       
         , @cur_UCC              CURSOR     
           
         , @d_time_Debug         DATETIME    --(Wan01)  
       
   SET @n_StartTCnt = @@TRANCOUNT       
   SET @n_Continue = 1       
   SET @n_err      = 0       
   SET @c_errmsg   = ''       
       
   SET @c_DeviceType = 'WCS'        
   SET @c_DeviceID   = 'WCS'         
       
   BEGIN TRAN       
       
   SET @cur_PICKNREPLEN = CURSOR FAST_FORWARD READ_ONLY FOR       
   SELECT MAX(PD.Pickslipno) --PD.PickSlipNo     NJOW02 618 Fix    
         ,PD.Storerkey       
         ,PD.Lot       
         ,PD.Loc        
         ,PD.ID       
         ,ToLoc = 'PACK'       
         ,Qty = SUM(PD.Qty)       
         ,PK.CaseCnt       
   FROM   PICKDETAIL PD WITH (NOLOCK)       
   JOIN   SKU           WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)       
                                      AND(PD.Sku = SKU.Sku)       
   JOIN   PACK       PK WITH (NOLOCK) ON (SKU.Packkey   = PK.Packkey)       
   JOIN   PACKTASK   PT WITH (NOLOCK) ON (PD.PickSlipNo = PT.TaskBatchNo)       
                                      AND(PD.Orderkey   = PT.Orderkey)       
   WHERE  PT.ReplenishmentGroup = @c_ReplenishmentGroup       
   AND    PD.UOM = '2'       
   AND    PD.Status < '5'       
   AND    PD.ShipFlag NOT IN ('P','Y')        
   AND    NOT EXISTS (  SELECT 1 FROM UCC WITH (NOLOCK)       
                        WHERE UCC.UCCNo = PD.DropID       
                        AND UCC.StorerKey = PD.StorerKey        -- ZG01     
                     )       
   GROUP BY 
            --PD.PickSlipNo    --NJOW02 618 Fix 
            PD.Storerkey         
         ,  PD.Lot       
         ,  PD.Loc        
         ,  PD.ID        
         ,  PK.CaseCnt       
   UNION        
   SELECT RP.ReplenishmentKey        
         ,RP.Storerkey        
         ,RP.Lot       
         ,RP.FromLoc        
         ,RP.ID       
         ,RP.ToLoc        
         ,RP.Qty       
         ,PK.CaseCnt       
   FROM   REPLENISHMENT RP WITH (NOLOCK)       
   JOIN   SKU     WITH (NOLOCK) ON (RP.Storerkey = SKU.Storerkey)       
                                AND(RP.Sku = SKU.Sku)       
   JOIN   PACK PK WITH (NOLOCK) ON (SKU.Packkey  = PK.Packkey)       
   WHERE  RP.ReplenishmentGroup = @c_ReplenishmentGroup       
   AND    RP.Confirmed = 'N'       
   AND    PK.CaseCnt > 0       
   AND    NOT EXISTS (  SELECT 1 FROM UCC WITH (NOLOCK)       
                        WHERE UCC.UserDefined10 = RP.ReplenishmentKey       
                     )       
        
   OPEN @cur_PICKNREPLEN       
          
   FETCH NEXT FROM @cur_PICKNREPLEN INTO  @c_BatchNo       
                                       ,  @c_Storerkey       
                                       ,  @c_Lot       
                                       ,  @c_FromLoc       
                                       ,  @c_ID       
                                       ,  @c_ToLoc       
                                       ,  @n_Qty       
                                       ,  @n_CaseCnt       
   WHILE @@FETCH_STATUS <> -1       
   BEGIN       
      SET @c_ReplenishmentKey = @c_BatchNo       
      SET @n_Cnt = 0       
      SET @n_NoOfUCCNoNeed = FLOOR( @n_Qty / @n_CaseCnt )       
             
      WHILE @n_NoOfUCCNoNeed > 0 AND @n_Cnt < @n_NoOfUCCNoNeed       
      BEGIN       
         SET @n_Continue = 1       
         BEGIN TRAN       
       
         SET @c_UCCNo = ''       
       
         SELECT TOP 1 @c_UCCNo = UCCNo       
         FROM UCC WITH (NOLOCK)       
         WHERE UCC.Lot = @c_Lot       
         AND   UCC.Loc = @c_FromLoc       
         AND   UCC.ID  = @c_ID       
         AND   UCC.Status = '1'       
         ORDER BY UCC.EditDate DESC       
       
         IF @c_UCCNo = ''       
         BEGIN       
            SET @n_NoOfUCCNoNeed = 0       
            GOTO NEXT_UCC       
         END       
       
         SET @n_Cnt = @n_Cnt + 1       
       
         IF @c_ToLoc = 'PACK'       
         BEGIN       
            SET @n_PDCnt = 0       
            /*
            SET @cur_PD = CURSOR FAST_FORWARD READ_ONLY FOR       
            SELECT PickDetailkey        
            FROM   PICKDETAIL PD WITH (NOLOCK)       
            WHERE  PD.Lot = @c_Lot       
            AND    PD.Loc = @c_FromLoc       
            AND    PD.ID  = @c_ID       
            AND    PD.PickSlipNo = @c_BatchNo       
            AND    PD.UOM = '2'            
            AND    PD.Status < '5'         
            AND    PD.ShipFlag NOT IN ('P','Y')        
            AND    NOT EXISTS (  SELECT 1 FROM UCC WITH (NOLOCK)       
                                 WHERE UCC.UCCNo = PD.DropID       
                                 AND UCC.StorerKey = PD.StorerKey        -- ZG01     
                              )       
            */

            --NJOW02 618 FIX
            SET @cur_PD = CURSOR FAST_FORWARD READ_ONLY FOR       
            SELECT PickDetailkey        
            FROM   PICKDETAIL PD WITH (NOLOCK)       
            JOIN   PACKTASK   PT WITH (NOLOCK) ON (PD.PickSlipNo = PT.TaskBatchNo)       
                                                   AND(PD.Orderkey   = PT.Orderkey)       
            WHERE  PD.Lot = @c_Lot       
            AND    PD.Loc = @c_FromLoc       
            AND    PD.ID  = @c_ID       
            AND    PT.ReplenishmentGroup = @c_ReplenishmentGroup       
            AND    PD.UOM = '2'            
            AND    PD.Status < '5'         
            AND    PD.ShipFlag NOT IN ('P','Y')        
            AND    NOT EXISTS (  SELECT 1 FROM UCC WITH (NOLOCK)       
                                 WHERE UCC.UCCNo = PD.DropID       
                                 AND UCC.StorerKey = PD.StorerKey        -- ZG01     
                              )       
                                     
            OPEN @cur_PD       
       
            FETCH NEXT FROM @cur_PD INTO @c_PickDetailkey        
        
            WHILE @@FETCH_STATUS <> -1 AND @n_PDCnt < @n_CaseCnt       
            BEGIN       
             --(Wan01) - START  
             /*  SET @d_time_Debug = GETDATE()  
               EXEC dbo.isp_InsertTraceInfo  
                    @c_TraceCode = 'ispPOGenReplen01'  
                  , @c_TraceName = 'ispPOGenReplen01'  
                  , @c_starttime = @d_time_Debug , @c_endtime   = @d_time_Debug  
                  , @c_step1     = @c_ReplenishmentGroup, @c_step2 = @c_UCCNo, @c_step3 = @c_PickDetailkey, @c_step4 = '', @c_step5 = ''  
                  , @c_col1      = '', @c_col2      = '', @c_col3      = '', @c_col4      = '', @c_col5      = ''  
                  , @b_Success   = 1     
                  , @n_Err       = 0      
                  , @c_ErrMsg    = ''    
             */     
               --(Wan01) - END    
        
               UPDATE PICKDETAIL WITH (ROWLOCK)       
               SET DropID = @c_UCCNo       
                  ,TrafficCop  = NULL      
                  ,EditWho  = SUSER_SNAME()       
                  ,EditDate = GETDATE()       
               WHERE PickDetailkey = @c_PickDetailkey       
            
               IF @@ERROR <> 0       
               BEGIN       
                  SET @n_Continue = 3       
                  SET @n_Err = 62310       
                  SET @c_ErrMsg = 'NSQL' +CONVERT(CHAR(5), @n_Err) + ': Update PICKDETAIL Table Fail. (ispPOGenReplen01)'       
                  GOTO QUIT_SP       
               END       
       
               SET @n_PDCnt = @n_PDCnt + 1       
               FETCH NEXT FROM @cur_PD INTO @c_PickDetailkey        
            END       
            CLOSE @cur_PD       
            DEALLOCATE @cur_PD        
            SET @c_ReplenishmentKey = ''       
         END       
       
         SET @cur_UCC = CURSOR FAST_FORWARD READ_ONLY FOR       
         SELECT UCC_RowRef         
         FROM   UCC WITH (NOLOCK)       
         WHERE  UCC.UCCNo = @c_UCCNo       
         AND    UCC.Status = '1'       
          
         OPEN @cur_UCC       
       
         FETCH NEXT FROM @cur_UCC INTO @n_UCC_RowRef        
         WHILE @@FETCH_STATUS <> -1       
         BEGIN       
            UPDATE UCC WITH (ROWLOCK)       
            SET Status = '5'       
               ,UserDefined10 = @c_ReplenishmentKey       
               ,EditWho  = SUSER_SNAME()       
               ,EditDate = GETDATE()       
            WHERE UCC_RowRef = @n_UCC_RowRef       
       
            IF @@ERROR <> 0       
            BEGIN       
               SET @n_Continue = 3       
               SET @n_Err = 62320       
               SET @c_ErrMsg = 'NSQL' +CONVERT(CHAR(5), @n_Err) + ': Update UCC Table Fail. (ispPOGenReplen01)'       
               GOTO QUIT_SP       
            END       
       
            FETCH NEXT FROM @cur_UCC INTO @n_UCC_RowRef        
         END       
         CLOSE @cur_UCC       
         DEALLOCATE @cur_UCC        
        
         --(Wan01) - START         
         /*            
         IF EXISTS ( SELECT 1 FROM dbo.Loc WITH (NOLOCK)        
                     WHERE Loc = @c_FromLoc       
                     AND LocationCategory <> 'BULK')       
         BEGIN       
            SET @c_WCSStation = ''       
                               
            SELECT @c_WCSStation = CL.Short                       
            FROM dbo.CODELKUP CL WITH (NOLOCK)        
            WHERE CL.ListName = 'WCSSTATION'       
            AND CL.StorerKey = @c_StorerKey       
            AND CL.Code = 'CHECK'       
                               
            EXECUTE dbo.nspg_GetKey       
               'WCSKey'       
            ,  10        
            ,  @c_WCSKey   OUTPUT       
            ,  @b_Success  OUTPUT       
            ,  @n_Err      OUTPUT       
            ,  @c_ErrMsg   OUTPUT       
                               
            IF @b_Success <> 1       
            BEGIN       
               SET @n_Continue = 3       
               SET @n_Err = 62330       
               SET @c_ErrMsg = 'NSQL' +CONVERT(CHAR(5), @n_Err) + ': Error Executing nspg_GetKey. (ispPOGenReplen01)'       
               GOTO QUIT_SP       
            END       
           
            SET @c_WCSSequence =  '01' --RIGHT('00'+CAST(@nCount AS VARCHAR(2)),2)       
            SET @c_WCSMessage = CHAR(2) + @c_WCSKey + '|' + @c_WCSSequence + '|' + RTRIM(@c_UCCNo) + '|' + @c_BatchNo + '|' + @c_WCSStation + '|' + CHAR(3)        
                            
            EXEC [RDT].[rdt_GenericSendMsg]       
               @nMobile      = 0          
            ,  @nFunc        = 999               
            ,  @cLangCode    = 0           
            ,  @nStep        = 0    
            ,  @nInputKey    = 0           
            ,  @cFacility    = ''           
            ,  @cStorerKey   = @c_StorerKey          
            ,  @cType        = @c_DeviceType              
            ,  @cDeviceID    = @c_DeviceID       
            ,  @cMessage     = @c_WCSMessage            
            ,  @nErrNo       = @n_Err         OUTPUT       
            ,  @cErrMsg      = @c_ErrMsg      OUTPUT          
       
            IF @n_Err <> 0       
            BEGIN       
               SET @n_Continue = 3       
               SET @n_Err = 62340       
               SET @c_ErrMsg = 'NSQL' +CONVERT(CHAR(5), @n_Err) + ': Error Executing rdt_GenericSendMsg. (ispPOGenReplen01)'       
                             + '( ' + @c_ErrMsg + ' )'       
               EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPOGenReplen01'       
               GOTO NEXT_UCC       
            END       
       
            SET @n_WCSCnt = 2        
         END       
         ELSE        
         BEGIN       
            SET @n_WCSCnt = 1        
         END       
         */       
         SET @n_WCSCnt = 1        
         --(Wan01) - END       
                
         --NJOW01        
         SELECT @c_WCS = dbo.fnc_GetRight('BS15', @c_Storerkey, '', 'WCS')                  
        
         IF @c_WCS = '1'       
         BEGIN                   
            SET @c_PutawayZone = ''         
            SET @c_WCSStation = ''        
                   
            IF EXISTS ( SELECT 1        
                        FROM CODELKUP CL WITH (NOLOCK)       
                WHERE CL.ListName = 'UALOC'       
                        AND   CL.Code = '3'       
                        AND   CL.Short = @c_ToLoc --NJOW01       
                       )--@c_ToLoc = 'PACK'       
            BEGIN       
               SET @c_PutawayZone = 'SINGLE'       
            END       
            ELSE       
            BEGIN                            
               SELECT @c_PutawayZone = PutawayZone        
               FROM dbo.Loc WITH (NOLOCK)        
               WHERE Loc = @c_ToLoc        
               AND LocationType = 'PICK'       
            END       
                           
            SELECT @c_WCSStation = CL.Short                       
            FROM dbo.CODELKUP CL WITH (NOLOCK)        
            WHERE CL.ListName = 'WCSSTATION'       
            AND CL.StorerKey = @c_StorerKey       
            AND CL.Code = @c_PutawayZone           
                               
            EXECUTE dbo.nspg_GetKey       
               'WCSKey'       
            ,  10        
            ,  @c_WCSKey   OUTPUT       
            ,  @b_Success  OUTPUT       
            ,  @n_Err      OUTPUT       
            ,  @c_ErrMsg   OUTPUT       
    
            IF @b_Success <> 1       
            BEGIN       
               SET @n_Continue = 3       
               SET @n_Err = 62350       
               SET @c_ErrMsg = 'NSQL' +CONVERT(CHAR(5), @n_Err) + ': Error Executing nspg_GetKey. (ispPOGenReplen01)'       
               GOTO QUIT_SP       
            END       
                               
            SET @c_WCSSequence = RIGHT('00'+CAST(@n_WCSCnt AS VARCHAR(2)),2)       
            SET @c_WCSMessage = CHAR(2) + @c_WCSKey + '|' + @c_WCSSequence + '|' + RTRIM(@c_UCCNo) + '|' + @c_BatchNo + '|' + @c_WCSStation + '|' + CHAR(3)        
                               
            EXEC [RDT].[rdt_GenericSendMsg]       
               @nMobile      = 0          
            ,  @nFunc        = 999               
            ,  @cLangCode    = 0           
            ,  @nStep        = 0               
            ,  @nInputKey    = 0           
            ,  @cFacility    = ''           
            ,  @cStorerKey   = @c_StorerKey          
            ,  @cType        = @c_DeviceType              
            ,  @cDeviceID    = @c_DeviceID       
            ,  @cMessage     = @c_WCSMessage            
            ,  @nErrNo       = @n_Err         OUTPUT       
            ,  @cErrMsg      = @c_ErrMsg      OUTPUT          
                   
            IF @n_Err <> 0       
            BEGIN       
               --SET @n_Continue = 3   --NJOW03 Removed
               SET @n_Err = 62360       
               SET @c_ErrMsg = 'NSQL' +CONVERT(CHAR(5), @n_Err) + ': Error Executing rdt_GenericSendMsg. (ispPOGenReplen01)'       
                              + '( ' + @c_ErrMsg + ' )'       
               EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPOGenReplen01'       
               GOTO NEXT_UCC       
            END       
         END       
       
         NEXT_UCC:       
         IF @n_Continue = 3       
         BEGIN       
            ROLLBACK TRAN       
         END       
         ELSE       
         BEGIN       
            WHILE @@TRANCOUNT> 0        
            BEGIN       
               COMMIT TRAN       
            END        
         END               
      END       
      FETCH NEXT FROM @cur_PICKNREPLEN INTO  @c_BatchNo       
                                          ,  @c_Storerkey       
                                          ,  @c_Lot       
                                          ,  @c_FromLoc       
                                          ,  @c_ID       
                                          ,  @c_ToLoc       
                                          ,  @n_Qty       
                                          ,  @n_CaseCnt             
   END       
   CLOSE @cur_PICKNREPLEN       
   DEALLOCATE @cur_PICKNREPLEN        
QUIT_SP:       
       
   IF CURSOR_STATUS( 'VARIABLE', '@cur_PICKNREPLEN') in (0 , 1)         
   BEGIN       
      CLOSE @cur_PICKNREPLEN       
      DEALLOCATE @cur_PICKNREPLEN       
   END       
       
   IF CURSOR_STATUS( 'VARIABLE', '@cur_PD') in (0 , 1)         
   BEGIN       
      CLOSE @cur_PD       
      DEALLOCATE @cur_PD       
   END       
       
   IF CURSOR_STATUS( 'VARIABLE', '@cur_UCC') in (0 , 1)         
   BEGIN       
      CLOSE @cur_UCC       
      DEALLOCATE @cur_UCC       
   END       
       
   IF @n_Continue=3  -- Error Occured - Process And Return       
   BEGIN       
      SET @b_Success = 0       
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt       
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
       
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPOGenReplen01'       
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012       
   END       
   ELSE       
   BEGIN       
      SET @b_Success = 1       
      WHILE @@TRANCOUNT > @n_StartTCnt       
      BEGIN       
         COMMIT TRAN       
      END       
   END       
       
   WHILE @@TRANCOUNT < @n_StartTCnt       
   BEGIN       
      BEGIN TRAN       
   END       
   RETURN       
END -- procedure   

GO