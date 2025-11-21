SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_TM_ReplenTo_ConfirmTask                             */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Comfirm Pick                                                */  
/*                                                                      */  
/* Called from: rdtfnc_TM_Picking                                       */  
/*                                                                      */  
/* Exceed version: 5.4                                                  */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 2011-08-03 1.0  ChewKP   Created                                     */  
/************************************************************************/  
CREATE PROC [RDT].[rdt_TM_ReplenTo_ConfirmTask] (
     @nMobile INT
    ,@nFunc INT
    ,@cStorerKey CHAR(15)
    ,@cUserName CHAR(15)
    ,@cFacility CHAR(5)
    ,@cTaskDetailKey CHAR(10)
    ,@cLoadKey CHAR(10)
    ,@cSKU CHAR(20)
    ,@cAltSKU CHAR(20)
    ,@cLOC CHAR(10)
    ,@cToLOC CHAR(10)
    ,@cID CHAR(18)
    ,@cDropID CHAR(18)
    ,@nPickQty INT
    ,@cLangCode CHAR(3)
    ,@nErrNo INT OUTPUT
    ,@cErrMsg VARCHAR(20) OUTPUT -- screen limitation, 20 char max
    ,@c_PickMethod CHAR(10)=''
    
    
 )    
AS    
BEGIN
    SET NOCOUNT ON    
    SET QUOTED_IDENTIFIER OFF    
    SET ANSI_NULLS OFF    
    SET CONCAT_NULL_YIELDS_NULL OFF    
    
    DECLARE @b_success             INT
           ,@n_err                 INT
           ,@c_errmsg              CHAR(250)
           ,@nTranCount            INT    
    
    DECLARE @cTaskLot              CHAR(10)
           ,@nTaskQty              INT
           ,@cExecArguments        nvarchar(4000) 
           ,@cExecStatements       nvarchar(4000)
           ,@cLogLot               CHAR(10)
           ,@nQty                  INT
           ,@nQtyToTake            INT
           ,@cPackKey              CHAR(10)
           ,@cUOM                  CHAR(10)
           ,@cMVType               CHAR(2) -- 01 = SKU
                                           -- 02 = ID
                                           -- 03 = Lot
           ,@cRefTaskKey           CHAR(10)
           ,@cSourceKey            CHAR(10)
           ,@cFromLocCategory      CHAR(10)
           ,@cToLocCategory        CHAR(10)
           ,@cHoldKey              CHAR(10)
           ,@cFromLocAisle         CHAR(10)
           ,@cToLocAisle           CHAR(10) 
           ,@cPNDTaskDetailKey     CHAR(10) 
           ,@cMessage01            CHAR(10)
           ,@c_taskdetailkeyMV     CHAR(10)
           ,@c_PnDToLocation       CHAR(10)
           
    SET @nTranCount = @@TRANCOUNT 
    
    
    
    BEGIN TRAN 
    SAVE TRAN TM_Move_ConfirmTask    
    
    SELECT @cTaskLot       = Lot 
           ,@nTaskQty      = Qty
           ,@cRefTaskKey   = RefTaskKey
           ,@cSourceKey    = SourceKey
           ,@cHoldKey      = HoldKey
    FROM dbo.TaskDetail WITH (NOLOCK)
    WHERE TaskDetailKey = @cTaskDetailKey
    
    
    SELECT @cFromLocCategory = LocationCategory
          ,@cFromLocAisle = LocAisle
    FROM dbo.Loc WITH (NOLOCK)
    WHERE Loc = @cLOC
    
    SELECT @cToLocCategory = LocationCategory
          ,@cToLocAisle = LocAisle
    FROM dbo.Loc WITH (NOLOCK)
    WHERE Loc = @cToLoc
    
    IF ISNULL(RTRIM(@cLoc),'') <> '' AND ISNULL(RTRIM(@cSKU),'') <> '' AND @cTaskLot = ''
    BEGIN
         SET @cExecStatements = N'DECLARE CUR_LOTxLOCxID_MOVE CURSOR FAST_FORWARD READ_ONLY FOR ' + 
                                 ' SELECT LOT, ' + 
                                 '        LLI.QTY- LLI.QTYALLOCATED- LLI.QTYPICKED -    ' +
                                 '            (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END) ' +
                                 ' FROM   LOTxLOCxID LLI WITH (NOLOCK) ' +
                                 ' WHERE  LLI.StorerKey = @cStorerKey ' +
                                 ' AND    LLI.SKU = @cSku ' +
                                 ' AND    LLI.LOC = @cLoc ' +   
                                 ' AND    LLI.ID  = @cID '  +
                                 ' AND    QTY-QtyPicked-QtyAllocated-QtyReplen > 0  ' +
                                 ' ORDER BY LLI.Loc, LLI.SKU '
                                 
        
         SET @cExecArguments = N'@cStorerkey varchar(15) ' +
                                ',@cSKU  varchar(20) ' +
                                ',@cLOC  varchar(10) ' + 
                                ',@cID   varchar(18) '
                                          
         EXEC sp_ExecuteSql @cExecStatements
                           ,@cExecArguments 
                           ,@cStorerkey
                           ,@cSKU      
                           ,@cLoc
                           ,@cID       
                           
        SET @cMVType = '01'                               
                           
    END
    ELSE IF ISNULL(RTRIM(@cLoc),'') <> '' AND ISNULL(RTRIM(@cSKU),'') = ''  AND @cTaskLot = ''
    BEGIN
         SET @cExecStatements = N'DECLARE CUR_LOTxLOCxID_MOVE CURSOR FAST_FORWARD READ_ONLY FOR ' + 
                                 ' SELECT LOT, ' +
                                 '        LLI.QTY- LLI.QTYALLOCATED- LLI.QTYPICKED -    '  +
                                 '            (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END) ' +
                                 ' FROM   LOTxLOCxID LLI WITH (NOLOCK) ' +
                                 ' WHERE  LLI.StorerKey = @cStorerKey ' +
                                 ' AND    LLI.LOC = @cLoc ' +   
                                 ' AND    LLI.ID  = @cID ' +
                                 ' AND    QTY-QtyPicked-QtyAllocated-QtyReplen > 0  ' +
                                 ' ORDER BY LLI.Loc, LLI.SKU '
                                 
         SET @cExecArguments = N'@cStorerkey varchar(15) ' +
                                ',@cLOC  varchar(10) ' + 
                                ',@cID   varchar(18) '
                                          
         EXEC sp_ExecuteSql @cExecStatements
                           ,@cExecArguments 
                           ,@cStorerkey
                           ,@cLoc
                           ,@cID      
         
         SET @cMVType = '02'                  
                                                            
    END
    ELSE IF ISNULL(RTRIM(@cLoc),'') <> '' AND ISNULL(RTRIM(@cSKU),'') <>  '' AND ISNULL(RTRIM(@cTaskLot),'') <>  '' 
    BEGIN
         SET @cExecStatements = N'DECLARE CUR_LOTxLOCxID_MOVE CURSOR FAST_FORWARD READ_ONLY FOR ' + 
                                 ' SELECT LOT, ' +
                                 '        LLI.QTY- LLI.QTYALLOCATED- LLI.QTYPICKED -    '  +
                                 '            (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END) ' +
                                 ' FROM   LOTxLOCxID LLI WITH (NOLOCK) ' +
                                 ' WHERE  LLI.StorerKey = @cStorerKey ' +
                                 ' AND    LLI.LOC = @cLoc ' +   
                                 ' AND    LLI.ID  = @cID ' + 
                                 ' AND    LLI.Lot  = @cTaskLot ' +
                                 ' AND    LLI.SKU  = @cSKU ' +  
                                 --' AND    QTY-QtyPicked-QtyAllocated-QtyReplen > 0  '
                                 ' ORDER BY LLI.Loc, LLI.SKU '
                                 
         SET @cExecArguments = N'@cStorerkey varchar(15) ' +
                                ',@cLOC  varchar(10) ' + 
                                ',@cID   varchar(18) ' + 
                                ',@cSKU  varchar(20) ' +
                                ',@cTaskLot varchar(10)' 
                                          
         EXEC sp_ExecuteSql @cExecStatements
                           ,@cExecArguments 
                           ,@cStorerkey
                           ,@cLoc
                           ,@cID 
                           ,@cSKU                        
                           ,@cTaskLot        
                           
         SET @cMVType = '03'                                          
    END
    
    OPEN CUR_LOTxLOCxID_MOVE 
         
    FETCH NEXT FROM CUR_LOTxLOCxID_MOVE INTO @cLogLot, @nQty--, @nAllocatedQty 
    WHILE @@FETCH_STATUS <> -1
    BEGIN
            SET @nQtyToTake = 0 
            
            IF @cMVType = '02'
            BEGIN
                SET @nQtyToTake = @nQty 
            END
            ELSE
            BEGIN
               -- If Qty Available > Qty Move 
               
               IF @nQty < 0 
               BEGIN
                  SET @nErrNo = 73801      
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QtyNotEnoughToMove 
                  GOTO RollBackTran
               END
               ELSE
               BEGIN
                  IF @nQty >= @nPickQty 
                  BEGIN
                     SET @nQtyToTake = @nPickQty 
                     --SET @nQtyAllocToTake=0               
                  END
      --            ELSE IF @nQty + @nAllocatedQty >= @nLogQty 
      --            BEGIN
      --               SET @nQtyToTake = @nLogQty
      --               --SET @nQtyAllocToTake = @nLogQty - @nQty  
      --            END
                  ELSE
                  BEGIN
                     SET @nQtyToTake = @nPickQty - @nQty --@nQty + @nAllocatedQty 
                     --SET @nQtyAllocToTake = @nAllocatedQty
                  END
               END   
            END
            
            

            IF @nQtyToTake > 0 
            BEGIN

--               SET @cPickLoc=''
--               
--               SELECT TOP 1 @cPickLoc = LOC
--               FROM   SKUxLOC WITH (NOLOCK)
--               WHERE  StorerKey = @cStorerKey 
--               AND    SKu = @cLogSKU
--               AND    LocationType IN ('PICK','CASE')
--               
--               IF ISNULL(RTRIM(@cPickLoc),'') = '' 
--               BEGIN
--                  ROLLBACK TRAN TM_RPMOVECASE            
--                  SET @nErrNo = 72369            
--                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoPPLoc            
--                  GOTO QUIT               
--               END

               SELECT @cPackKey = SKU.PackKey, 
                      @cUOM     = PACK.PACKUOM3 
               FROM   SKU WITH (NOLOCK) 
               JOIN   PACK WITH (NOLOCK) ON SKU.PACKKEY = PACK.PackKey 
               WHERE  StorerKey = @cStorerKey 
                 AND  SKU = @cSKU 

               
               EXECUTE nspItrnAddMove                
                  @n_ItrnSysId    = NULL,                  
                  @c_itrnkey      = NULL,                
                  @c_Storerkey    = @cStorerKey,                
                  @c_SKU          = @cSKU,                
                  @c_Lot          = @cLogLot,                
                  @c_FromLoc      = @cLOC,                
                  @c_FromID       = @cID,                 
                  @c_ToLoc        = @cToLoc,                 
                  @c_ToID         = '',                
                  @c_Status       = '',                
                  @c_Lottable01   = '', -- @cCaseId,                
                  @c_Lottable02   = '',                
                  @c_Lottable03   = '',                
                  @d_Lottable04   = NULL,                
                  @d_Lottable05   = NULL,                
                  @n_casecnt      = 0,                
                  @n_innerpack    = 0,                      
                  @n_Qty          = @nQtyToTake,                
                  @n_Pallet       = 0,                
                  @f_Cube         = 0,                
                  @f_GrossWgt     = 0,                
                  @f_NetWgt       = 0,               
                  @f_OtherUnit1   = 0,                
                  @f_OtherUnit2   = 0,                
                  @c_SourceKey    = @cTaskdetailkey,                
                  @c_SourceType   = 'MV',                
                  @c_PackKey      = @cPackKey,                
                  @c_UOM          = @cUOM,                
                  @b_UOMCalc      = 1,                
                  @d_EffectiveDate = NULL,                
                  @b_Success      = @b_Success  OUTPUT,                
                  @n_err          = @nErrNo     OUTPUT,                
                  @c_errmsg       = @cErrmsg    OUTPUT                
                     
               IF ISNULL(RTRIM(@cErrMsg),'') <> ''            
               BEGIN            
                  SET @nErrNo = @nErrNo            
                  SET @cErrMsg = @cErrmsg            
                  GOTO RollBackTran        
               END            
                     
               SET @nPickQty = @nPickQty - @nQtyToTake 

               IF @nPickQty = 0
               BEGIN
                  BREAK 
               END    
               
            END
               
        FETCH NEXT FROM CUR_LOTxLOCxID_MOVE INTO @cLogLot, @nQty
    END
    CLOSE CUR_LOTxLOCxID_MOVE 
    DEALLOCATE CUR_LOTxLOCxID_MOVE 
    
    
    -- Task Creating and Generating
    IF @cHoldKey = '2' OR @cHoldKey = '3'
    BEGIN
       -- Generate Next Task  
       IF @cHoldKey = '2'
       BEGIN
         
         -- Generate SubSequence Final To Loc Task with DropID , Partial Pallet = PP
         DECLARE CUR_PNDLOC_MOVE CURSOR FAST_FORWARD READ_ONLY FOR 
         SELECT TaskDetailKey, Message01
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE StorerKEy = @cStorerKey
         AND DropID = @cDropID
         AND Status = '9'
         AND PickMethod = 'PP'
         
         --AND HoldKey = ''
         --AND SourceKey = @cSourceKey -- Original SourceKey
         
         OPEN CUR_PNDLOC_MOVE 
         
         FETCH NEXT FROM CUR_PNDLOC_MOVE INTO @cPNDTaskDetailKey, @cMessage01
         WHILE @@FETCH_STATUS <> -1
         BEGIN
         
            EXECUTE dbo.nspg_getkey       
                   'TaskDetailKey'      
                   , 10      
                   , @c_taskdetailkeyMV OUTPUT      
                   , @b_success OUTPUT      
                   , @nErrNo OUTPUT      
                   , @cErrMsg OUTPUT      
         
                   IF NOT @b_success = 1      
                   BEGIN      
                         SET @nErrNo = 73802
                         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TASK GEN FAIL'
                         GOTO Quit
                   END   
            
            INSERT TASKDETAIL                  
                  ( TaskDetailKey   ,TaskType      ,Storerkey        ,Sku                                    
                   ,Lot             ,FromLOC       ,LogicalFromLoc   ,LoadKey                                  
                   ,ToLoc           ,LogicalToLoc  ,CaseID           ,SourceType                             
                   ,UOM             ,UOMQTY        ,QTY              ,Sourcekey              
                   ,RefTaskKey      ,Priority      ,STATUS           ,SystemQty     
                   ,FromID          ,ToID          ,HoldKey          ,DropID
                   )                  
                   SELECT @c_taskdetailkeyMV    ,TaskType      ,Storerkey        ,SKU
                          ,Lot                  ,@cToLoc       ,''               ,LoadKey
                          ,@cMessage01          ,''            ,CaseID           ,SourceType
                          ,UOM                  ,UOMQty        ,Qty              ,SourceKey
                          ,@cPNDTaskDetailKey   ,Priority      ,'0'              ,SystemQty
                          ,FromID               ,ToID          ,'3'              ,DropID
                  FROM dbo.TaskDetail WITH (NOLOCK)
                  WHERE TaskDetailKey = @cPNDTaskDetailKey     
                     
                  
                  IF @@ERROR <> 0            
                  BEGIN            
                     SET @nErrNo = 73803            
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InsTaskdetFail'            
                     GOTO RollBackTran       
                  END     
         
            
            FETCH NEXT FROM CUR_PNDLOC_MOVE INTO @cPNDTaskDetailKey, @cMessage01
            
         END
         CLOSE CUR_PNDLOC_MOVE 
         DEALLOCATE CUR_PNDLOC_MOVE 
         
         
          -- Release TM Move Task where Status = 'Q'
          IF EXISTS ( SELECT 1
                      FROM dbo.TaskDetail TD WITH (NOLOCK)
                      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON (Loc.Loc = TD.ToLoc ) 
                      WHERE TD.StorerKey = @cStorerKey
                      AND TD.Status = 'Q'
                      AND Loc.LocAisle = @cFromLocAisle
                      AND Loc.LocationCategory = @cFromLocCategory
                      AND TD.HoldKey = '2'  )
          BEGIN
                      SET @c_taskdetailkeyMV = ''
                      
                      SELECT TOP 1 @c_taskdetailkeyMV = TD.TaskDetailKey
                      FROM dbo.TaskDetail TD WITH (NOLOCK)
                      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON (Loc.Loc = TD.ToLoc ) 
                      WHERE TD.StorerKey = @cStorerKey
                      AND TD.Status = 'Q'
                      AND Loc.LocAisle = @cFromLocAisle
                      AND Loc.LocationCategory = @cFromLocCategory
                      AND TD.HoldKey = '2'
                      Order By Priority, TaskDetailKey
                      
                      IF @c_taskdetailkeyMV <> ''
                      BEGIN
                        
                               
                         UPDATE TaskDetail
                         SET ToLoc = @c_PnDToLocation
                           ,Status = '0'
                         WHERE TaskDetailKey = @c_taskdetailkeyMV      
                         
                         
                      END     
                            
                      
                        
          END
         
       
       END
       ELSE IF @cHoldKey = '3'
       BEGIN
            IF EXISTS ( SELECT 1
                      FROM dbo.TaskDetail TD WITH (NOLOCK)
                      INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON (Loc.Loc = TD.ToLoc ) 
                      WHERE TD.StorerKey = @cStorerKey
                      AND TD.Status = 'Q'
                      AND Loc.LocAisle = @cFromLocAisle
                      AND Loc.LocationCategory = @cFromLocCategory
                      AND TD.HoldKey = '3'  )
             BEGIN
                         SET @c_taskdetailkeyMV = ''
                         
                         SELECT TOP 1 @c_taskdetailkeyMV = TD.TaskDetailKey
                         FROM dbo.TaskDetail TD WITH (NOLOCK)
                         INNER JOIN dbo.Loc Loc WITH (NOLOCK) ON (Loc.Loc = TD.ToLoc ) 
                         WHERE TD.StorerKey = @cStorerKey
                         AND TD.Status = 'Q'
                         AND Loc.LocAisle = @cFromLocAisle
                         AND Loc.LocationCategory = @cFromLocCategory
                         AND TD.HoldKey = '3'
                         Order By Priority, TaskDetailKey
                         
                         IF @c_taskdetailkeyMV <> ''
                         BEGIN
                                  
                            UPDATE TaskDetail
                            SET ToLoc = @c_PnDToLocation
                              ,Status = '0'
                            WHERE TaskDetailKey = @c_taskdetailkeyMV      
                            
                         END     
             END
       END
    
    END
    
    
    
    
    
    
    
    GOTO Quit 
    
    RollBackTran: 
    ROLLBACK TRAN TM_Move_ConfirmTask 
    
    Quit:    
    WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started    
          COMMIT TRAN TM_Move_ConfirmTask
END

GO