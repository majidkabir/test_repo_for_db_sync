SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/      
/* Store procedure: rdt_PicePick4AltPickLoc                             */      
/* Copyright      : IDS                                                 */      
/*                                                                      */      
/* Purpose: Propose Alternate Picking location                          */      
/*          Only suitable for piece picking                             */
/*                                                                      */      
/* Called from: rdtfnc_TM_Piece_Picking                                 */      
/*                                                                      */      
/* Exceed version: 5.4                                                  */      
/*                                                                      */      
/* Modifications log:                                                   */      
/*                                                                      */      
/* Date       Rev  Author   Purposes                                    */      
/* 2014-12-03 1.0  James    Created                                     */      
/************************************************************************/      
CREATE PROC [RDT].[rdt_PicePick4AltPickLoc] (    
     @nMobile        INT    
    ,@nFunc          INT    
    ,@cLangCode      NVARCHAR( 3)    
    ,@cStorerKey     NVARCHAR( 15)  
    ,@cAreaKey       NVARCHAR( 10)  
    ,@cTaskDetailKey NVARCHAR( 10)  
    ,@cAltLOC        NVARCHAR( 10)  OUTPUT
    ,@nMQty_TTL      INT            OUTPUT
    ,@nErrNo         INT            OUTPUT    
    ,@cErrMsg        NVARCHAR( 20)  OUTPUT -- screen limitation, 20 char max    
    ,@bDebug         INT
 )        
AS        
BEGIN    
    SET NOCOUNT ON        
    SET QUOTED_IDENTIFIER OFF        
    SET ANSI_NULLS OFF        
    SET CONCAT_NULL_YIELDS_NULL OFF        
        
    DECLARE @b_success             INT    
           ,@n_err                 INT    
           ,@c_errmsg              NVARCHAR(250)    
           ,@nTranCount            INT  
           
    DECLARE @cStartTime    datetime 
           ,@cEndTime      datetime 

        
    DECLARE @cFacility              NVARCHAR( 5)    
           ,@cPD_LOC                NVARCHAR( 10)   
           ,@cPD_ID                 NVARCHAR( 18)   
           ,@cAltID                 NVARCHAR( 18)    
           ,@cPickDetailKey         NVARCHAR(10)    
           ,@cAltLOT                NVARCHAR(10)    
           ,@cNewPickDetailKey      NVARCHAR( 10)    
           ,@cTwilightLoc           NVARCHAR( 10)    
           ,@cUserName              NVARCHAR( 18)  
           ,@cSKU                   NVARCHAR( 20)    
           ,@cLOC                   NVARCHAR( 10) 
           ,@cOrderKey              NVARCHAR( 10) 
           ,@cOrderLineNumber       NVARCHAR( 5) 
           ,@cMoveID                NVARCHAR( 18)
           ,@cMoveLOT               NVARCHAR( 10)
           ,@nSUMMQty_TTL           INT 
           ,@nQty2Alloc             INT 
           ,@nPD_QTY                INT   
           ,@nMoveQty               INT
           ,@cTtl_Qty               INT
        
   IF NOT EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
                   WHERE StorerKey = @cStorerKey
                   AND   ListName = 'TWLIGHTLOC'
                   AND   CODE = @cAreaKey
                   AND   Short = '1')
      RETURN
         
   SELECT @cFacility = Facility, 
          @cUserName = UserName 
   FROM RDT.RDTMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   SELECT @cSKU = SKU, 
          @cLOC = FROMLOC 
   FROM dbo.TaskDetail WITH (NOLOCK) 
   WHERE TaskDetailKey = @cTaskDetailKey

   SET @cStartTime = GETDATE()   

   SET @nTranCount = @@TRANCOUNT     
      
   BEGIN TRAN     
   SAVE TRAN PickFrom_AltPick        

   SELECT @cTtl_Qty = ISNULL( SUM( QTY), 0) 
   FROM   dbo.PickDetail WITH (NOLOCK)    
   WHERE  TaskDetailKey = @cTaskDetailKey
   AND    Status = '0'

   DECLARE CursorPickDetail CURSOR LOCAL READ_ONLY FAST_FORWARD FOR  
   SELECT PickDetailKey, QTY, LOC, ID 
   FROM   dbo.PickDetail WITH (NOLOCK)    
   WHERE  TaskDetailKey = @cTaskDetailKey
   AND    Status = '0'
   ORDER BY 1    
            
   OPEN CursorPickDetail     
   FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nPD_QTY, @cPD_LOC, @cPD_ID 
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      IF @bDebug = 1
      BEGIN
         SELECT '@cTaskDetailKey', @cTaskDetailKey, '@cPickDetailKey', @cPickDetailKey, '@nPD_QTY', @nPD_QTY, '@cPD_LOC', @cPD_LOC, '@cPD_ID', @cPD_ID, '@nTranCount', @nTranCount
         SELECT '@cStorerKey', @cStorerKey, '@cSKU', @cSKU, '@cFacility', @cFacility, '@cPD_LOC', @cPD_LOC, '@cTtl_Qty', @cTtl_Qty
      END

      -- look for available loc with qty
      SELECT TOP 1      
         @cAltLOT = LLI.LOT,      
         @cAltLOC = LLI.LOC,      
         @cAltID = LLI.ID,      
         @nMQty_TTL = ( LLI.QTY- LLI.QTYALLOCATED- LLI.QTYPICKED -     
                        (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))      
      FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)      
      JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)      
      JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON ( LLI.SKU = SL.SKU AND LLI.LOC = SL.LOC)  
      JOIN dbo.ID ID WITH (NOLOCK) ON ( LLI.ID = ID.ID) 
      JOIN dbo.LOT LOT WITH (NOLOCK) ON ( LLI.LOT = LOT.LOT) 
      WHERE LLI.StorerKey = @cStorerKey  
         AND (LLI.QTY - LLI.QTYALLOCATED- LLI.QTYPicked - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0      
         AND LLI.SKU = @cSKU      
         AND LOC.Facility = @cFacility      
         AND LOC.PutawayZone = @cAreaKey  -- same user area     
         AND LOC.LOC <> @cPD_LOC  -- not from same loc
         AND LOC.Locationflag<>'HOLD'      
         AND LOC.Locationflag<>'DAMAGE'      
         AND LOC.Status<>'HOLD'      
         AND LOC.LocationType IN ('PICK' ,'CASE')    
         AND LOC.LocationType NOT IN ('DynPickP', 'DYNPICKR')  
         AND ID.Status<>'HOLD' 
         AND LOT.STATUS<>'HOLD'        
         AND SL.LocationType NOT IN ('PICK' ,'CASE')  
      ORDER BY LLI.LOC 

      IF ISNULL( @cAltLOC, '') <> '' AND ISNULL( @nMQty_TTL, 0) > 0
      BEGIN

         IF @nMQty_TTL >= @nPD_QTY 
            SET @nQty2Alloc = @nPD_QTY
         ELSE
            SET @nQty2Alloc = @nMQty_TTL

         IF @bDebug = 1
         BEGIN
            SELECT '@cLOT', @cAltLOT, '@cAltLOC', @cAltLOC, '@cID', @cAltID, '@nMQty_TTL', @nMQty_TTL, '@nQty2Alloc', @nQty2Alloc
         END

         -- deduct from current pickdetail
         UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
            Qty = CASE WHEN ( Qty - @nQty2Alloc) <= 0 THEN 0 ELSE ( Qty - @nQty2Alloc) END,  -- piece picking
            [Status] = CASE WHEN ( Qty - @nQty2Alloc) <= 0 THEN '4' ELSE [Status] END  
         WHERE PickDetailKey = @cPickDetailKey

         IF @@ERROR<>0    
         BEGIN    
            SET @nErrNo = 50951  
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'OffSetPDtlFail'  
            CLOSE CursorPickDetail     
            DEALLOCATE CursorPickDetail    
            GOTO RollBackTran    
         END    

         -- allocate new line
         EXECUTE dbo.nspg_GetKey     
            'PICKDETAILKEY',     
            10 ,     
            @cNewPickDetailKey   OUTPUT,     
            @b_success           OUTPUT,     
            @n_err               OUTPUT,     
            @c_errmsg            OUTPUT        
                    
         IF @b_success<>1    
         BEGIN    
            SET @nErrNo = 50952        
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') -- 'GetDetKeyFail'       
            CLOSE CursorPickDetail     
            DEALLOCATE CursorPickDetail    
            GOTO RollBackTran    
         END     

         -- Create a new PickDetail to hold the balance        
         INSERT INTO dbo.PICKDETAIL    
         (    
         CaseID                ,PickHeaderKey         ,OrderKey    
         ,OrderLineNumber       ,LOT                   ,StorerKey    
         ,SKU                   ,AltSKU                ,UOM    
         ,UOMQTY                ,QTYMoved              ,STATUS    
         ,DropID                ,LOC                   ,ID    
         ,PackKey               ,UpdateSource          ,CartonGroup    
         ,CartonType            ,ToLoc                 ,DoReplenish    
         ,ReplenishZone         ,DoCartonize           ,PickMethod    
         ,WaveKey               ,EffectiveDate         ,ShipFlag              
         ,PickSlipNo            ,PickDetailKey         ,QTY                   
         ,TaskDetailkey    
         )    
         SELECT CaseID             ,PickHeaderKey            ,OrderKey    
         ,OrderLineNumber          ,@cAltLOT                 ,StorerKey    
         ,SKU                      ,AltSku                   ,UOM    
         ,UOMQTY                   ,QTYMoved                 ,'0'    
         ,''                       ,@cAltLOC                 ,@cAltID    
         ,PackKey                  ,UpdateSource             ,CartonGroup    
         ,CartonType               ,ToLoc                    ,DoReplenish    
         ,ReplenishZone            ,DoCartonize              ,PickMethod    
         ,WaveKey                  ,EffectiveDate            ,ShipFlag                 
         ,PickSlipNo               ,@cNewPickDetailKey       ,@nQty2Alloc              
         ,TaskDetailkey    
         FROM   dbo.PickDetail WITH (NOLOCK)    
         WHERE  PickDetailKey = @cPickDetailKey        
      
         IF @@ERROR<>0    
         BEGIN    
            SET @nErrNo = 50953        
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Ins PDtl Fail'        
            CLOSE CursorPickDetail     
            DEALLOCATE CursorPickDetail    
            GOTO RollBackTran    
         END     

         SET @cEndTime = GETDATE()
         -- Insert traceinfo
         EXEC isp_InsertTraceInfo   
            @c_TraceCode = 'PIECE_PICK_ALT_LOC',  
            @c_TraceName = 'rdt_PicePick4AltPickLoc',  
            @c_starttime = @cStartTime, 
            @c_endtime = @cEndTime,  
            @c_step1 = @cTaskDetailKey,  
            @c_step2 = @cPickDetailKey,  
            @c_step3 = @cPD_LOC,  
            @c_step4 = @cPD_ID,  
            @c_step5 = @nQty2Alloc,  
            @c_col1 = @cAltLOT,   
            @c_col2 = @cAltLOC,  
            @c_col3 = @cAltID,  
            @c_col4 = @nMQty_TTL,  
            @c_col5 = @cSKU,  
            @b_Success = 1,  
            @n_Err = 0,  
            @c_ErrMsg = ''      

         SET @cTtl_Qty = @cTtl_Qty - @nQty2Alloc

         -- send the available qty from original allocated loc into twilight zone
         -- get the twilight loc
         SELECT @cTwilightLoc = rdt.RDTGetConfig( @nFunc, 'TwilightLoc', @cStorerKey)  

         IF ISNULL( @cTwilightLoc, '') IN ('0', '') 
         BEGIN    
            SET @nErrNo = 50954        
            SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'No Twilight LOC'        
            CLOSE CursorPickDetail     
            DEALLOCATE CursorPickDetail    
            GOTO RollBackTran    
         END     

         DECLARE CUR_MOVEQTY CURSOR STATIC FORWARD_ONLY FOR 
         SELECT LOT, ID, LLI.QTY- LLI.QTYALLOCATED- LLI.QTYPICKED -     
                        (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)
         FROM dbo.LOTXLOCXID LLI WITH (NOLOCK) 
         JOIN dbo.LOC LOC WITH (NOLOCK) ON (LOC.LOC = LLI.LOC)  
         WHERE LLI.StorerKey = @cStorerKey
         AND   LLI.SKU = @cSKU
         AND   LLI.LOC = @cPD_LOC
         AND   LLI.QTY- LLI.QTYALLOCATED- LLI.QTYPICKED -     
               (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END) > 0 
         AND   LOC.Facility = @cFacility
         
         OPEN CUR_MOVEQTY
         FETCH NEXT FROM CUR_MOVEQTY INTO @cMoveLOT, @cMoveID, @nMoveQty
         WHILE @@FETCH_STATUS <> -1
         BEGIN

            IF @bdebug = 1
            BEGIN
               SELECT '@cFROM LOC', @cPD_LOC, '@cMoveLOT', @cMoveLOT, '@cMoveID', @cMoveID, '@nMoveQty', @nMoveQty
            END

            EXECUTE rdt.rdt_Move      
               @nMobile     = @nMobile,      
               @cLangCode   = @cLangCode,       
               @nErrNo      = @nErrNo  OUTPUT,      
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max      
               @cSourceType = 'rdt_PicePick4AltPickLoc',       
               @cStorerKey  = @cStorerKey,      
               @cFacility   = @cFacility,    
               @cFromLOT    = @cMoveLOT,   
               @cFromLOC    = @cPD_LOC,       
               @cToLOC      = @cTwilightLoc,       
               @cFromID     = @cMoveID,         
               @cToID       = NULL,     -- NULL means not changing ID.  PPA is Lose ID      
               @cSKU        = @cSKU,   
               @nQTY        = @nMoveQty      

            IF @nErrNo<>0    
            BEGIN    
               SET @nErrNo = 50955        
               SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'Move Qty Fail' 
               CLOSE CursorPickDetail     
               DEALLOCATE CursorPickDetail    
               GOTO RollBackTran    
            END     

            FETCH NEXT FROM CUR_MOVEQTY INTO @cMoveLOT, @cMoveID, @nMoveQty
         END
         CLOSE CUR_MOVEQTY
         DEALLOCATE CUR_MOVEQTY
         
         IF @cTtl_Qty <= 0
            BREAK
      END
      ELSE
      BEGIN
         SET @nErrNo = 50956        
         SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'No Alt LOC' 
         CLOSE CursorPickDetail     
         DEALLOCATE CursorPickDetail    
         GOTO RollBackTran    
      END

      FETCH NEXT FROM CursorPickDetail INTO @cPickDetailKey, @nPD_QTY, @cPD_LOC, @cPD_ID
   END -- While Loop for PickDetail Key      
   CLOSE CursorPickDetail     
   DEALLOCATE CursorPickDetail    
    --END 

   if @bdebug = 1
   begin
      select * from pickdetail (nolock) where loc = @cAltLOC and sku = @cSKU
      select * from lotxlocxid (nolock) where LOT = @cAltLOT and LOC = @cAltLOC and ID = @cAltID      
      select * from skuxloc (nolock) where loc = @cAltLOC and sku = @cSKU
      select * from lot (nolock) where lot = @cAltLOT
      SELECT top 10 * FROM ITRN (NOLOCK) WHERE FROMLOC = @cPD_LOC order by 1 desc
   end

   GOTO Quit     
     
   RollBackTran:     
      ROLLBACK TRAN PickFrom_AltPick     
     
   Quit:  
      WHILE @@TRANCOUNT>@nTranCount 
         COMMIT TRAN     
END        

GO