SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_955PickCfm01                                    */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: Pick task confirm                                           */  
/*                                                                      */  
/* Called from: rdtfnc_Pick_CaptureDropID                               */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 31-10-2017 1.0  James    WMS3294. Created                            */
/************************************************************************/  
  
CREATE PROCEDURE [RDT].[rdt_955PickCfm01] (  
   @nMobile       INT,   
   @nFunc         INT, 
   @cLangCode     NVARCHAR( 18),   
   @cPickSlipNo   NVARCHAR( 10),   
   @cDropID       NVARCHAR( 20),   
   @cLOC          NVARCHAR( 10),   
   @cID           NVARCHAR( 18),   
   @cStorerKey    NVARCHAR( 15),   
   @cSKU          NVARCHAR( 20),   
   @cUOM          NVARCHAR( 10),   
   @cLottable1    NVARCHAR( 18),   
   @cLottable2    NVARCHAR( 18),   
   @cLottable3    NVARCHAR( 18),   
   @dLottable4    DATETIME,   
   @nTaskQTY      INT,   
   @nConfirmQTY   INT,   
   @cUCCTask      NVARCHAR( 1),  
   @cPickType     NVARCHAR( 1),  
   @bSuccess      INT            OUTPUT,   
   @nErrNo        INT            OUTPUT,   
   @cErrMsg       NVARCHAR( 20)  OUTPUT  -- screen limitation, 20 NVARCHAR max  
) AS  
SET NOCOUNT ON  
SET QUOTED_IDENTIFIER OFF  
SET ANSI_NULLS OFF  
SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cZone    NVARCHAR(18)  
   DECLARE @cOrderKey      NVARCHAR( 10)   
          ,@cFacility      NVARCHAR( 5)  
          ,@cUserName      NVARCHAR( 18) 
          ,@cPH_OrderKey   NVARCHAR( 10)
          ,@cPH_LoadKey    NVARCHAR( 10)
          ,@cDefaultUOM    NVARCHAR( 10)
          ,@cPackKey       NVARCHAR( 10)
          ,@cSKUGroup      NVARCHAR( 10)
          ,@cItemClass     NVARCHAR( 10)
          ,@nCaseQty       INT
  
   SELECT @cZone = Zone, @cPH_OrderKey = OrderKey, @cPH_LoadKey = ExternOrderKey        
   FROM dbo.PickHeader WITH (NOLOCK)   
   WHERE PickHeaderKey = @cPickSlipNo  
     
   SELECT @cFacility = Facility  
         ,@cUserName = UserName  
         ,@cDefaultUOM  = V_String10  
   FROM rdt.rdtMobRec WITH (NOLOCK)  
   WHERE Mobile = @nMobile  

   DECLARE  @nStep            INT, 
            @cUOMQty          INT, 
            @nAllocatedQty    INT, 
            @nPickedQty       INT, 
            @nShortPickQty    INT, 
            @cLot             NVARCHAR(10),
            @cRDTFuncID       NVARCHAR(20), 
            @c_AlertMessage   NVARCHAR(512), 
            @c_NewLineChar    NVARCHAR(2) 

   SET @c_NewLineChar =  master.dbo.fnc_GetCharASCII(13) + master.dbo.fnc_GetCharASCII(10)   

   SET @nErrNo = 0  

   SELECT @cSKUGroup = SKUGroup, 
          @cPackKey = PackKey, 
          @cItemClass = ItemClass
   FROM dbo.SKU WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   SKU = @cSKU

   IF EXISTS ( SELECT 1 FROM dbo.CODElKUP WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   ListName = 'DROPIDREQ'
               AND   Code = @cSKUGroup
               AND   Udf01 = 'Y') AND @cItemClass = 'MHD-FG'
   BEGIN
      -- If the skugroup is setup in codelkup then value X not allowed
      IF @cDropID = 'X'
      BEGIN  
         SET @nErrNo = 116420
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Pls Scan CtnID'  
         GOTO Fail  
      END 

      SELECT @nCaseQty = CaseCnt FROM dbo.Pack WITH (NOLOCK) WHERE PackKey = @cPackKey

      -- If the qty left is less than a carton then allow NA else error
      IF @cDropID = 'NA'
      BEGIN
         INSERT INTO TRACEINFO (TRACENAME, TIMEIN, COL1, COL2, COL3) VALUES 
         ('955', GETDATE(), @cDefaultUOM, @nTaskQTY, @nCaseQty)
         IF @cDefaultUOM = '2'
         BEGIN
            IF @nTaskQTY >= @nCaseQty
            BEGIN  
               SET @nErrNo = 116421  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Not Last Ctn'  
               GOTO Fail  
            END 
         END
      END
      ELSE
         -- 1 dropid = 1 carton qty
         SET @nConfirmQTY = @nCaseQty
   END
   ELSE
   BEGIN
      -- SKUgroup not setup in codelkup then only X is allow as dropid
      IF @cDropID <> 'X'
      BEGIN  
         SET @nErrNo = 116422
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Invalid DropID'  
         GOTO Fail  
      END 
   END
   -- Validate parameters  
   IF (@nTaskQTY IS NULL OR @nTaskQTY <= 0)  
   BEGIN  
      SET @nErrNo = 116401  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Bad TaskQTY'  
      GOTO Fail  
   END  
  
   IF rdt.RDTGetConfig( @nFunc, 'PickAllowZeroQty', @cStorerKey) <> '1'  
   BEGIN  
      IF (@nConfirmQTY IS NULL OR @nConfirmQTY <= 0)  
      BEGIN  
         SET @nErrNo = 116402  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Bad ConfirmQTY'  
         GOTO Fail  
      END  
   END  
     
   IF (@nConfirmQTY > @nTaskQTY)  
   BEGIN  
      SET @nErrNo = 116403  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Over pick'  
      GOTO Fail  
   END  
  
   IF @cUCCTask IS NULL OR (@cUCCTask <> 'Y' AND @cUCCTask <> 'N')  
   BEGIN  
      SET @nErrNo = 116404  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Bad UCC param'  
      GOTO Fail  
   END  
     
   -- PickDetail in the task  
   DECLARE @tPD TABLE  
   (  
      PickDetailKey    NVARCHAR( 18) NOT NULL,   
      PD_QTY           INT NOT NULL DEFAULT (0),   
      Final_QTY        INT NOT NULL DEFAULT (0),   
      OrderKey         NVARCHAR( 10) NOT NULL, 
      [Status]         NVARCHAR( 10) NOT NULL, 
    PRIMARY KEY CLUSTERED   
    (  
     [PickDetailKey]  
    )  
   )  
  
   -- conso picklist (james01)/(james03)
   If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' OR ISNULL(@cZone, '') = '7'  
   BEGIN  
      -- Get PickDetail in the task  
      INSERT INTO @tPD (PickDetailKey, PD_QTY, OrderKey, [Status])  
      SELECT PD.PickDetailKey, PD.QTY, PD.OrderKey, '0'  
      FROM dbo.PickDetail PD (NOLOCK) 
      JOIN RefKeyLookup RPL WITH (NOLOCK) ON RPL.PickDetailKey = PD.PickDetailKey
      JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT)    
      WHERE RPL.PickslipNo = @cPickSlipNo    
         AND PD.Status < '5' -- Not yet picked  
         AND PD.LOC = @cLOC  
         AND PD.ID = @cID  
         AND PD.SKU = @cSKU  
         AND PD.UOM = @cUOM  
         AND LA.Lottable01 = @cLottable1
         AND LA.Lottable02 = @cLottable2  
         AND LA.Lottable03 = @cLottable3  
         AND IsNULL( @dLottable4, 0) = IsNULL( LA.Lottable04, 0)         
   END  
   ELSE  -- discrete picklist  
   BEGIN  
      IF ISNULL(@cPH_OrderKey, '') <> ''  
      BEGIN
         -- Get PickDetail in the task  
         INSERT INTO @tPD (PickDetailKey, PD_QTY, OrderKey, [Status])  
         SELECT PD.PickDetailKey, PD.QTY, PD.OrderKey, '0'  
         FROM dbo.PickHeader PH (NOLOCK)   
            INNER JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)  
            INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT)  
         WHERE PH.PickHeaderKey = @cPickSlipNo  
            AND PD.Status < '5' -- Not yet picked  
            AND PD.LOC = @cLOC  
            AND PD.ID = @cID  
            AND PD.SKU = @cSKU  
            AND PD.UOM = @cUOM  
            AND LA.Lottable01 = @cLottable1
            AND LA.Lottable02 = @cLottable2  
            AND LA.Lottable03 = @cLottable3  
            AND IsNULL( @dLottable4, 0) = IsNULL( LA.Lottable04, 0)         
      END
      ELSE
      BEGIN
         -- Get PickDetail in the task  
         INSERT INTO @tPD (PickDetailKey, PD_QTY, OrderKey, [Status])  
         SELECT PD.PickDetailKey, PD.QTY, PD.OrderKey, '0'  
         FROM dbo.PickHeader PH (NOLOCK)     
         INNER JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
         INNER JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)    
         INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT)    
         WHERE PH.PickHeaderKey = @cPickSlipNo  
            AND PD.Status < '5' -- Not yet picked  
            AND PD.LOC = @cLOC  
            AND PD.ID = @cID  
            AND PD.SKU = @cSKU  
            AND PD.UOM = @cUOM  
            AND LA.Lottable01 = @cLottable1
            AND LA.Lottable02 = @cLottable2  
            AND LA.Lottable03 = @cLottable3  
            AND IsNULL( @dLottable4, 0) = IsNULL( LA.Lottable04, 0)         
      END
   END  
     
   IF @@ERROR <> 0  
   BEGIN  
      SET @nErrNo = 116404  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Get PKDtl fail'  
      GOTO Fail  
   END  
  
   -- Validate task still exists  
   IF NOT EXISTS( SELECT 1 FROM @tPD)  
   BEGIN  
      SET @nErrNo = 116406  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Task changed'  
      GOTO Fail  
   END  
  
   -- Validate task already changed by other  
   IF (SELECT SUM( PD_QTY) FROM @tPD) <> @nTaskQTY  
   BEGIN  
      SET @nErrNo = 116407  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Task changed'  
      GOTO Fail  
   END  
  
   DECLARE @cPickDetailKey  NVARCHAR( 18)  
   DECLARE @nTask_Bal  INT  
   DECLARE @nPD_QTY    INT  
  
   -- Prepare cursor  
   DECLARE @curPD CURSOR  
        
   If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' OR ISNULL(@cZone, '') = '7'  
   BEGIN  
      SET @curPD = CURSOR SCROLL FOR   
         SELECT t.PickDetailKey, t.PD_QTY, t.OrderKey  
         FROM @tPD t  
         JOIN Orders O WITH (NOLOCK) ON (t.OrderKey = O.OrderKey)  
         ORDER BY O.Priority, t.Orderkey  
      OPEN @curPD  
   END  
   ELSE  
   BEGIN  
      SET @curPD = CURSOR SCROLL FOR   
         SELECT PickDetailKey, PD_QTY, OrderKey  
         FROM @tPD  
         ORDER BY PickDetailKey  
      OPEN @curPD  
   END  
     
   SET @nTask_Bal = @nConfirmQTY  
  
   -- Loop PickDetail to offset  
   FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nPD_QTY, @cOrderKey 
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      -- Exact match  
      IF @nTask_Bal = @nPD_QTY  
      BEGIN  
         UPDATE @tPD SET   
            Final_QTY = @nPD_QTY, 
            [Status]  = '5'      -- (james02)
         WHERE PickDetailKey = @cPickDetailKey   
  
         -- commented to support conso pick  -- (james02)
         -- SET @nTask_Bal = 0  
         SET @nTask_Bal = @nTask_Bal - @nPD_QTY
           
         EXEC RDT.rdt_STD_EventLog
             @cActionType   = '3', -- Picking  
             @cUserID      = @cUserName,  
             @nMobileNo     = @nMobile,  
             @nFunctionID   = @nFunc,  
             @cFacility     = @cFacility,  
             @cStorerKey    = @cStorerKey,  
             @cLocation     = @cLOC,  
             @cID           = @cID,  
             @cSKU          = @cSKU,  
             @cUOM          = @cUOM,  
             @nQTY          = @nPD_QTY,  
             @cLottable01   = @cLottable1,
             @cLottable02   = @cLottable2,   
             @cLottable03   = @cLottable3,   
             @dLottable04   = @dLottable4,   
             @cRefNo1       = @cPickSlipNo,  
             @cRefNo2       = @cDropID,  
             @cRefNo3       = @cPickType,  
             @cOrderKey     = @cOrderKey,   
             @cPickSlipNo   = @cPickSlipNo,   
             @cDropID       = @cDropID  

         -- commented to support conso pick
         -- BREAK -- Finish  
      END  
  
      -- Over match  
      ELSE IF @nTask_Bal > @nPD_QTY  
      BEGIN  
         UPDATE @tPD SET   
            Final_QTY = @nPD_QTY, 
            [Status]  = '5'      -- (james02)
         WHERE PickDetailKey = @cPickDetailKey   
  
         SET @nTask_Bal = @nTask_Bal - @nPD_QTY  -- Reduce task balance, get next PD to offset  
           
         EXEC RDT.rdt_STD_EventLog  
             @cActionType   = '3', -- Picking  
             @cUserID       = @cUserName,  
             @nMobileNo     = @nMobile,  
             @nFunctionID   = @nFunc,  
             @cFacility     = @cFacility,  
             @cStorerKey    = @cStorerKey,  
             @cLocation     = @cLOC,  
             @cID           = @cID,  
             @cSKU          = @cSKU,  
             @cUOM          = @cUOM,  
             @nQTY          = @nPD_QTY,  
             @cLottable01   = @cLottable1,
             @cLottable02   = @cLottable2,   
             @cLottable03   = @cLottable3,   
             @dLottable04   = @dLottable4,   
             @cRefNo1       = @cPickSlipNo,  
             @cRefNo2       = @cDropID,  
             @cRefNo3       = @cPickType,  
             @cOrderKey     = @cOrderKey,  
             @cPickSlipNo   = @cPickSlipNo,  
             @cDropID       = @cDropID  
               
      END  
  
      -- Under match (short pick)  
      ELSE IF @nTask_Bal < @nPD_QTY  
      BEGIN  
         -- Reduce PD balance  
         UPDATE @tPD SET   
            Final_QTY = @nTask_Bal, 
            [Status]  = '4'      -- (james02)
         WHERE PickDetailKey = @cPickDetailKey   
  
         SET @nTask_Bal = 0  
           
         EXEC RDT.rdt_STD_EventLog  
             @cActionType   = '3', -- Picking  
             @cUserID       = @cUserName,  
             @nMobileNo     = @nMobile,  
             @nFunctionID   = @nFunc,  
             @cFacility     = @cFacility,  
             @cStorerKey    = @cStorerKey,  
             @cLocation     = @cLOC,  
             @cID           = @cID,  
             @cSKU          = @cSKU,  
             @cUOM          = @cUOM,  
             @nQTY          = @nTask_Bal,  
             @cLottable01   = @cLottable1,
             @cLottable02   = @cLottable2,   
             @cLottable03   = @cLottable3,   
             @dLottable04   = @dLottable4,   
             @cRefNo1       = @cPickSlipNo,  
             @cRefNo2       = @cDropID,  
             @cRefNo3       = @cPickType,  
             @cOrderKey     = @cOrderKey,  
             @cPickSlipNo   = @cPickSlipNo,  
             @cDropID       = @cDropID  
             
         BREAK  -- Finish  
      END  
      
      IF @nTask_Bal = 0
         BREAK
  
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nPD_QTY, @cOrderKey 
   END  -- Loop PickDetail  
  
   -- Still have balance, means offset has error  
   IF @nTask_Bal <> 0  
   BEGIN  
      SET @nErrNo = 116408  
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'offset error'  
      CLOSE @curPD  
      DEALLOCATE @curPD  
      GOTO Fail  
   END  
  
   CLOSE @curPD  
   DEALLOCATE @curPD  
  
--  delete from tPD
--  insert into tPD 
--  select * from @tPD 
--  
--  goto fail
   DECLARE @nRowCount INT  
   DECLARE @nRowCount_PD INT  
   DECLARE @nRowCount_UCC INT  
  
   -- Get rowcount  
   SELECT @nRowCount_PD = COUNT(1) FROM @tPD  
   SELECT @nRowCount_UCC = COUNT( 1)   
   FROM RDT.RDTTempUCC (NOLOCK)  
   WHERE TaskType = 'PICK'  
      AND PickSlipNo = @cPickSlipNo  
      AND LOC = @cLOC  
      AND ID = @cID  
      AND SKU = @cSKU  
      -- AND UOM = @cUOM  -- UCC is always UOM = 2  
      AND Lottable01 = @cLottable1
      AND Lottable02 = @cLottable2  
      AND Lottable03 = @cLottable3  
      AND Lottable04 = @dLottable4  
  
   /* Update PickDetail  
      NOTE: Short pick will leave record in @tPD untouch (Final_QTY = 0)  
            Those records will update PickDetail as short pick (PickDetail.QTY = 0 AND Status = 5)  
   */  
   -- Prepare cursor  
   DECLARE @curShortPK     CURSOR  
   DECLARE @nFinal_QTY     INT, 
           @b_success      INT, 
           @n_err          INT, 
           @c_errmsg       NVARCHAR( 20) 

   BEGIN TRAN  
   
   SET @curShortPK = CURSOR SCROLL FOR   
   SELECT PickDetailKey, Final_QTY
   FROM @tPD 
   WHERE [Status] = '4'
   OPEN @curShortPK  
   -- Loop PickDetail to offset  
   FETCH NEXT FROM @curShortPK INTO @cPickDetailKey, @nFinal_QTY
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
      -- Get new pickdetailkey here
      DECLARE @cNewPickDetailKey NVARCHAR( 10)
      EXECUTE dbo.nspg_GetKey
         'PICKDETAILKEY',
         10 ,
         @cNewPickDetailKey OUTPUT,
         @b_success         OUTPUT,
         @n_err             OUTPUT,
         @c_errmsg          OUTPUT

      IF @b_success <> 1
      BEGIN
         SET @nErrNo = 116409
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'GetDetKeyFail'
         GOTO RollBackTran
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
         CaseID, PickHeaderKey, OrderKey, OrderLineNumber, Lot, StorerKey, SKU, AltSku, UOM, UOMQTY, QTYMoved,
         '0', DropID, LOC, ID, PackKey, UpdateSource, CartonGroup, CartonType, ToLoc, DoReplenish, ReplenishZone,
         DoCartonize, PickMethod, WaveKey, EffectiveDate, ArchiveCop, ShipFlag, PickSlipNo, @cNewPickDetailKey,
         QTY - @nFinal_QTY, -- QTY
         NULL, --TrafficCop,
         '1'  --OptimizeCop
      FROM dbo.PickDetail WITH (NOLOCK)
      WHERE PickDetailKey = @cPickDetailKey

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 116410
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins PDtl Fail'
         GOTO RollBackTran
      END

      -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop
      -- Change orginal PickDetail with exact QTY (with TrafficCop)
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET
         QTY = @nFinal_QTY,
         Trafficcop = NULL
      WHERE PickDetailKey = @cPickDetailKey

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 116411
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
         GOTO RollBackTran
      END

      -- Confirm orginal PickDetail with exact QTY
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET
         DropID = CASE WHEN @cPickType = 'D' THEN DropID ELSE @cDropID END, 
         Status = '5'
      WHERE PickDetailKey = @cPickDetailKey

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 116412
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
         GOTO RollBackTran
      END
      
      FETCH NEXT FROM @curShortPK INTO @cPickDetailKey, @nFinal_QTY
   END
   CLOSE @curShortPK
   DEALLOCATE @curShortPK
   
   -- Handle full pick here
   UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
      DropID = CASE WHEN @cPickType = 'D' THEN DropID ELSE @cDropID END, 
      QTY = Final_QTY,   
      Status = 5  
   FROM dbo.PickDetail PD  
      INNER JOIN @tPD T ON (PD.PickDetailKey = T.PickDetailKey)  
   -- Compare just in case PickDetail changed  
   WHERE PD.Status < '5'  
      AND PD.QTY = T.PD_QTY  
   -- Only get those pickdetailkey which fully picked
      AND T.Status = '5'

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 116413
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
      GOTO RollBackTran
   END

   -- Handle remaining unpick pickdetail here
   UPDATE dbo.PickDetail WITH (ROWLOCK) SET  
      Status = '0' 
   FROM dbo.PickDetail PD  
      INNER JOIN @tPD T ON (PD.PickDetailKey = T.PickDetailKey)  
   -- Compare just in case PickDetail changed  
   WHERE PD.Status < '5'  
      AND T.Status = '0'

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 116414
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'OffSetPDtlFail'
      GOTO RollBackTran
   END

   -- Set remaining task to short pick
   UPDATE @tPD SET 
      [Status] = '4'
   WHERE [Status] = '0'

   -- Insert Alert here
   SELECT @nFunc = Func, @nStep = Step
   FROM rdt.RDTMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile
   
   SET @cRDTFuncID = 'Fn' + CAST(@nFunc AS NVARCHAR( 4)) + 'Sn' + CAST(@nStep AS NVARCHAR( 2)) + 'M' + CAST(@nMobile AS NVARCHAR( 4))

   DECLARE @curShortPKAlert CURSOR  
   SET @curShortPKAlert = CURSOR SCROLL FOR   
   SELECT PickDetailKey, OrderKey, PD_Qty, Final_QTY
   FROM @tPD 
   WHERE [Status] = '4'
   OPEN @curShortPKAlert  
   FETCH NEXT FROM @curShortPKAlert INTO @cPickDetailKey, @cOrderKey, @nAllocatedQty, @nPickedQty
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  

      SET @nShortPickQty = @nAllocatedQty - @nPickedQty
      
      SELECT @cUOM = UOM, @cUOMQty = UOMQty, @cLot = LOT 
      FROM dbo.PickDetail WITH (NOLOCK) 
      WHERE PickDetailKey = @cPickDetailKey
      
      SET @c_AlertMessage = 'Short Pick for PickSlip: ' + @cPickSlipNo + @c_NewLineChar   
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' OrderKey: ' + @cOrderKey + @c_NewLineChar   
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Allocated Qty: ' + CAST(@nAllocatedQty AS NVARCHAR(10)) + @c_NewLineChar   
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Picked Qty: ' + CAST(@nPickedQty AS NVARCHAR(10)) + @c_NewLineChar   
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' RDT Function ID: ' + @cRDTFuncID  +  @c_NewLineChar   
      SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' DateTime: ' + CONVERT(NVARCHAR(20), GETDATE())  +  @c_NewLineChar   

      EXEC nspLogAlert  
           @c_modulename         = 'Pick by SKU/UPC'       
         , @c_AlertMessage       = @c_AlertMessage     
         , @n_Severity           = '5'         
         , @b_success            = @b_success     OUTPUT         
         , @n_err                = @n_Err         OUTPUT           
         , @c_errmsg             = @c_Errmsg      OUTPUT        
         , @c_Activity           = 'Picking'  
         , @c_Storerkey          = @cStorerkey      
         , @c_SKU                = @cSku            
         , @c_UOM                = @cUOM            
         , @c_UOMQty             = @cUOMQty         
         , @c_Qty                = @nShortPickQty  
         , @c_Lot                = @cLot           
         , @c_Loc                = @cLoc            
         , @c_ID                 = @cID               
         , @c_TaskDetailKey      = ''  
         , @c_UCCNo              = ''        

      IF @n_Err <> 0
      BEGIN
         SET @nErrNo = 116415
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Ins Alert Fail'
         GOTO RollBackTran
      END
   
      FETCH NEXT FROM @curShortPKAlert INTO @cPickDetailKey, @cOrderKey, @nAllocatedQty, @nPickedQty
   END
   CLOSE @curShortPKAlert
   DEALLOCATE @curShortPKAlert

   -- Update UCC  
   IF @cUCCTask = 'Y'  
   BEGIN  
      UPDATE dbo.UCC WITH (ROWLOCK) SET  
         Status = 6 -- Pick / Replenish  
      FROM dbo.UCC UCC  
         INNER JOIN RDT.RDTTempUCC T ON (UCC.UCCNo = T.UCCNo)  
      WHERE T.TaskType = 'PICK'  
         AND T.PickSlipNo = @cPickSlipNo  
         AND T.StorerKey = @cStorerKey  
         AND T.LOC = @cLOC  
         AND T.ID = @cID  
         AND T.SKU = @cSKU  
         AND T.Lottable01 = @cLottable1
         AND T.Lottable02 = @cLottable2  
         AND T.Lottable03 = @cLottable3  
         AND IsNULL( T.Lottable04, 0) = IsNULL( @dLottable4, 0)  
         -- Compare just in case UCC changed  
         AND T.StorerKey = UCC.StorerKey  
         AND T.SKU = UCC.SKU  
         AND T.Lot = UCC.LOT  
         AND T.LOC = UCC.LOC  
         AND T.[ID] = UCC.[ID]  
         AND UCC.Status = 1 -- Received  
           
      SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT  
        
      -- Check if update UCC fail  
      IF @nErrNo <> 0  
      BEGIN  
         SET @nErrNo = 116416  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd UCC fail'  
         GOTO RollBackTran  
      END  
     
      -- Check if other process had updated UCC  
      IF @nRowCount <> @nRowCount_UCC  
      BEGIN  
         SET @nErrNo = 116417  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Task changed'  
         GOTO RollBackTran  
      END  
   END  

   -- Scan out pickslip if fully picked
   IF rdt.RDTGetConfig( @nFunc, 'AUTOSCANOUTPS', @cStorerKey) = '1'  
   BEGIN
      If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' OR ISNULL(@cZone, '') = '7'  
      BEGIN
         -- conso picklist 
         IF NOT EXISTS ( SELECT 1 
                         FROM dbo.PickHeader PH WITH (NOLOCK)   
                         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)  
                         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
                         WHERE PH.PickHeaderKey = @cPickSlipNo  
                         AND   PD.StorerKey = @cStorerKey
                         AND   PD.Status < '5' )
         BEGIN
            -- Scan out pickslip
            UPDATE dbo.PickingInfo WITH (ROWLOCK) SET   
               ScanOutDate = GETDATE(),   
               AddWho = sUser_sName()   
            WHERE PickSlipNo = @cPickSlipNo  

            IF @@ERROR <> 0
            BEGIN  
               SET @nErrNo = 116418  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Scan Out Fail'  
               GOTO RollBackTran  
            END  
         END
      END
      ELSE  
      BEGIN  
         -- discrete picklist  
         IF NOT EXISTS ( SELECT 1 
                         FROM dbo.PickHeader PH (NOLOCK)   
                         INNER JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)  
                         WHERE PH.PickHeaderKey = @cPickSlipNo  
                         AND   PD.StorerKey = @cStorerKey
                         AND   PD.Status < '5' )
         BEGIN
            -- Scan out pickslip
            UPDATE dbo.PickingInfo WITH (ROWLOCK) SET   
               ScanOutDate = GETDATE(),   
               AddWho = sUser_sName()   
            WHERE PickSlipNo = @cPickSlipNo  

            IF @@ERROR <> 0
            BEGIN  
               SET @nErrNo = 116419  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Scan Out Fail'  
               GOTO RollBackTran  
            END  
         END
      END  
   END
   COMMIT TRAN  
  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN  
Fail:
Quit:

GO