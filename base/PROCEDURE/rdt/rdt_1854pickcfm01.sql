SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/****************************************************************************/    
/* Store procedure: rdt_1854PickCfm01                                      */    
/* Copyright      : IDS                                                     */    
/*                                                                          */    
/* Purpose: normal receipt                                                  */       
/*                                                                          */    
/* Modifications log:                                                       */    
/*                                                                          */    
/* Date       Rev  Author   Purposes                                        */    
/* 2021-07-09 1.0  Chermaine  WMS-17140. Created                            */
/****************************************************************************/    
    
CREATE PROCEDURE [RDT].[rdt_1854PickCfm01] (    
   @nErrNo        INT OUTPUT,     
   @cErrMsg       NVARCHAR( 20) OUTPUT, -- screen limitation, 20 VARCHAR max    
   @cLangCode     NVARCHAR( 18),     
   @cPickSlipNo   NVARCHAR( 10),     
   @cDropID       NVARCHAR( 18),     
   @cLOC          NVARCHAR( 10),     
   @cID           NVARCHAR( 18),     
   @cStorerKey    NVARCHAR( 15),     
   @cSKU          NVARCHAR( 20),     
   @cUOM          NVARCHAR( 10),   
   @cLottable01   NVARCHAR( 18),    -- (james03)   
   @cLottable02   NVARCHAR( 18),     
   @cLottable03   NVARCHAR( 18),     
   @dLottable04   DATETIME,   
   @dLottable05   DATETIME,
   @cLottable06   NVARCHAR( 30),
   @cLottable07   NVARCHAR( 30),
   @cLottable08   NVARCHAR( 30),
   @cLottable09   NVARCHAR( 30),
   @cLottable10   NVARCHAR( 30),
   @cLottable11   NVARCHAR( 30),
   @cLottable12   NVARCHAR( 30),
   @dLottable13   DATETIME,
   @dLottable14   DATETIME,
   @dLottable15   DATETIME,  
   @nTaskQTY      INT,     
   @nConfirmQTY   INT,     
   @cUCCTask      NVARCHAR( 1),    
   @cPickType     NVARCHAR( 1),    
   @nMobile       INT     
) AS    
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @cZone          NVARCHAR( 18),  
           @cPH_OrderKey   NVARCHAR( 10), 
           @cPH_LoadKey    NVARCHAR( 10) 
           
   SELECT @cZone = Zone, 
          @cPH_OrderKey = OrderKey     
   FROM dbo.PickHeader WITH (NOLOCK)     
   WHERE PickHeaderKey = @cPickSlipNo    
      
   DECLARE 
   	@cOrderKey           VARCHAR(10)     
      ,@cFacility          NVARCHAR(5)    
      ,@cUserName          NVARCHAR(18)    
      ,@nFunc              INT    
      ,@cNotUpdateDropID   NVARCHAR(1)   
      ,@cPDUOM             NVARCHAR(10)   
      ,@nUOMQty            INT          
      ,@cPackKey           NVARCHAR(10)  
      ,@nPDMode            INT  
      ,@cNewPickDetailKey  NVARCHAR(10)   
      ,@cNewPDUOM          NVARCHAR(10)   
      ,@nNewPDUOMQty       INT  
      ,@cSplitPDByUOM      NVARCHAR(1)   
      ,@nInnerQty          INT   
      ,@nPDMod             INT  
      ,@b_success          INT  
      ,@cConfirm_SP        NVARCHAR(20)
      ,@cPalletType        NVARCHAR(5)
      ,@cClass             NVARCHAR(10)
      ,@cColor             NVARCHAR(10)
      ,@cFilter            NVARCHAR(50)
      ,@cCustomSQL         NVARCHAR(MAX)
      ,@cSQLParam          NVARCHAR(500)
      
   SELECT @cFacility = Facility    
         ,@cUserName = UserName    
         ,@nFunc     = Func    
         ,@cPalletType = V_String5
   FROM rdt.rdtMobRec WITH (NOLOCK)    
   WHERE Mobile = @nMobile  
   
   SELECT 
      @cClass = Class,
      @cColor = Color
   FROM SKU WITH (NOLOCK)
   WHERE SKU = @cSKU
   AND storerKey = @cStorerKey
     
   SET @cNotUpdateDropID = ''  
   SET @cNotUpdateDropID = rdt.RDTGetConfig( @nFunc, 'NotUpdateDropID', @cStorerKey) 
   
   SET @cSplitPDByUOM = ''  
   SET @cSplitPDByUOM = rdt.RDTGetConfig( @nFunc, 'SplitPDByUOM', @cStorerKey)     
   
   SET @cConfirm_SP = rdt.RDTGetConfig( @nFunc, 'Confirm_SP', @cStorerKey)     

   SET @nErrNo = 0     
   SET @cFilter = ''  
       
   -- PickDetail in the task    
   DECLARE @tPD TABLE    
   (    
      PickDetailKey    NVARCHAR( 18) NOT NULL,     
      PD_QTY           INT NOT NULL DEFAULT (0),     
      Final_QTY        INT NOT NULL DEFAULT (0),     
      OrderKey         NVARCHAR( 10) NOT NULL, -- (ChewKP01)    
    PRIMARY KEY CLUSTERED     
    (    
     [PickDetailKey]    
    )    
   )    
   
   IF (@cClass = 'R')  OR --  (lot02)
      (@cClass = 'N' AND @cColor IN ('GA','RACK') AND @cPalletType = 'PP') OR
      (@cClass = 'N' AND @cColor NOT IN ('GA','RACK') AND @cPalletType = 'PP')
   BEGIN
   	SET @cFilter = 'AND lottable02 = @cID'
   END
   ELSE
   BEGIN
   	SET @cFilter = 'AND PD.ID = @cID'
   END   	
    
   -- conso picklist (james01)    
   If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' -- OR ISNULL(@cZone, '') = '7'    
   BEGIN    
   	SET @cCustomSQL =      
   	' SELECT PD.PickDetailKey, PD.QTY, PD.OrderKey ' +
      ' FROM dbo.PickHeader PH (NOLOCK) ' +
      ' JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey) ' +   
      ' JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey) ' +
      ' JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT)  '+    
      ' WHERE PH.PickHeaderKey = @cPickSlipNo ' +   
      '   AND PD.Status < ''5'' ' + -- Not yet picked    
      '   AND PD.LOC = @cLOC ' +      
      '   AND PD.SKU = @cSKU ' +    
      '   AND PD.UOM = @cUOM '   
      
      IF @cFilter <> ''
      BEGIN
         SET @cCustomSQL = @cCustomSQL + @cFilter
      END
   END    
   ELSE  -- discrete picklist    
   BEGIN    
      IF ISNULL(@cPH_OrderKey, '') <> ''  -- (james02)
      BEGIN  
         -- Get PickDetail in the task    
         SET @cCustomSQL =  
         ' SELECT PD.PickDetailKey, PD.QTY, PD.OrderKey ' +    
         ' FROM dbo.PickHeader PH (NOLOCK) ' +     
         '  INNER JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey) ' +    
         '  INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT) ' +    
         ' WHERE PH.PickHeaderKey = @cPickSlipNo ' +    
         '   AND PD.Status < ''5'' ' + -- Not yet picked    
         '   AND PD.LOC = @cLOC ' +    
         '   AND PD.SKU = @cSKU ' +    
         '   AND PD.UOM = @cUOM ' 
         
         IF @cFilter <> ''
         BEGIN
         	SET @cCustomSQL = @cCustomSQL + @cFilter
         END
         
      END   
      ELSE
      BEGIN
         -- Get PickDetail in the task    
         SET @cCustomSQL =    
         ' SELECT PD.PickDetailKey, PD.QTY, PD.OrderKey ' +    
         ' FROM dbo.PickHeader PH (NOLOCK) ' +     
         ' INNER JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey ' +  
         ' INNER JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey) ' +      
         ' INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT) ' +      
         ' WHERE PH.PickHeaderKey = @cPickSlipNo ' +    
         '   AND PD.Status < ''5''  ' + -- Not yet picked    
         '   AND PD.LOC = @cLOC ' +    
         '   AND PD.SKU = @cSKU ' +    
         '   AND PD.UOM = @cUOM ' 
         
         IF @cFilter <> ''
         BEGIN
         	SET @cCustomSQL = @cCustomSQL + @cFilter
         END    
      END   
   END    
   
   SET @cSQLParam =       
   ' @cPickSlipNo NVARCHAR(10), ' +        
   ' @cLOC        NVARCHAR(10), ' +       
   ' @cID         NVARCHAR(18), ' + 
   ' @cSKU        NVARCHAR(20), ' +
   ' @cUOM        NVARCHAR(10), ' +
   ' @cLottable02 NVARCHAR(18)  ' 
   
   INSERT INTO @tPD (PickDetailKey, PD_QTY, OrderKey)
   EXEC sp_ExecuteSQL @cCustomSQL, @cSQLParam,      
   @cPickSlipNo,       
   @cLOC,       
   @cID,
   @cSKU,  
   @cUOM,
   @cLottable02  
       
   IF @@ERROR <> 0    
   BEGIN    
      SET @nErrNo = 175101    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Get PKDtl fail'    
      GOTO Fail    
   END    
   
   --INSERT INTO traceInfo (TraceName,TimeIn,col1,col2,col3,col4,col5,Step1)
   --VALUES ('1854cmfsp01',GETDATE(),@cPickSlipNo,@cLOC,@cID,@cSKU,@cUOM,@cLottable02)
   
   --INSERT INTO traceInfo (TraceName,TimeIn,col1,col2,col3,col4)
   --SELECT'1854cmfsp01Val',GETDATE(),PickDetailKey, PD_QTY, OrderKey,Final_QTY  FROM @tPD
    
   -- Validate task still exists    
   IF NOT EXISTS( SELECT 1 FROM @tPD)    
   BEGIN    
      SET @nErrNo = 175102    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Task changed'    
      GOTO Fail    
   END    
    
   ---- Validate task already changed by other    
   --IF (SELECT SUM( PD_QTY) FROM @tPD) <> @nTaskQTY    
   --BEGIN    
   --   SET @nErrNo = 175102    
   --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Task changed'    
   --   GOTO Fail    
   --END    
    
   DECLARE @cPickDetailKey  NVARCHAR( 18)    
   DECLARE @nTask_Bal  INT    
   DECLARE @nPD_QTY    INT    
    
   -- Prepare cursor    
   DECLARE @curPD CURSOR    
          
   If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' -- OR ISNULL(@cZone, '') = '7'    
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
   FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nPD_QTY, @cOrderKey -- (ChewKP01)    
   WHILE @@FETCH_STATUS = 0    
   BEGIN    
      -- Exact match    
      IF @nTask_Bal = @nPD_QTY    
      BEGIN    
         UPDATE @tPD SET     
            Final_QTY = @nPD_QTY    
         WHERE PickDetailKey = @cPickDetailKey     
    
         SET @nTask_Bal = 0    
             
         -- (ChewKP01)    
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
             @cLottable02   = @cLottable02,     
             @cLottable03   = @cLottable03,     
             @dLottable04   = @dLottable04,     
             @cRefNo1       = @cPickSlipNo,    
             @cRefNo2       = @cDropID,    
             @cRefNo3       = @cPickType,    
             @cOrderKey     = @cOrderKey,     
             @cPickSlipNo   = @cPickSlipNo,     
             @cDropID       = @cDropID    
                 
         BREAK -- Finish    
      END    
    
      -- Over match    
      ELSE IF @nTask_Bal > @nPD_QTY    
      BEGIN    
         UPDATE @tPD SET     
            Final_QTY = @nPD_QTY    
         WHERE PickDetailKey = @cPickDetailKey     
    
         SET @nTask_Bal = @nTask_Bal - @nPD_QTY  -- Reduce task balance, get next PD to offset    
             
         -- (ChewKP01)    
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
             @cLottable02   = @cLottable02,     
             @cLottable03   = @cLottable03,     
             @dLottable04   = @dLottable04,     
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
            Final_QTY = @nTask_Bal    
         WHERE PickDetailKey = @cPickDetailKey     
    
         SET @nTask_Bal = 0    
             
         -- (ChewKP01)    
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
             @cLottable02   = @cLottable02,     
             @cLottable03   = @cLottable03,     
             @dLottable04   = @dLottable04,     
             @cRefNo1       = @cPickSlipNo,    
             @cRefNo2       = @cDropID,    
             @cRefNo3       = @cPickType,    
             @cOrderKey     = @cOrderKey,    
             @cPickSlipNo   = @cPickSlipNo,    
             @cDropID       = @cDropID    
             
         BREAK  -- Finish    
      END    
          
  
    
      FETCH NEXT FROM @curPD INTO @cPickDetailKey, @nPD_QTY, @cOrderKey -- (ChewKP01)    
   END  -- Loop PickDetail    
    
   -- Still have balance, means offset has error    
   IF @nTask_Bal <> 0    
   BEGIN    
      SET @nErrNo = 175103    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'offset error'    
      CLOSE @curPD    
      DEALLOCATE @curPD    
      GOTO Fail    
   END    
    
   CLOSE @curPD    
   DEALLOCATE @curPD    
    
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
      AND Lottable02 = @cLottable02    
      AND Lottable03 = @cLottable03    
      AND Lottable04 = @dLottable04    
    
   /* Update PickDetail    
      NOTE: Short pick will leave record in @tPD untouch (Final_QTY = 0)    
            Those records will update PickDetail as short pick (PickDetail.QTY = 0 AND Status = 5)    
   */    
   --INSERT INTO traceInfo (TraceName,TimeIn,col1,col2,col3,col4)
   --SELECT'1854cmfsp01UpdPkDt',GETDATE(),PickDetailKey, PD_QTY, OrderKey,Final_QTY FROM @tPD
   
   BEGIN TRAN    
   IF @cPickType <> 'D'    
   BEGIN    
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
         DropID = CASE WHEN @cNotUpdateDropID = '1' THEN DropID ELSE @cDropID END,  -- (ChewKP02)  
         QTY = Final_QTY,     
         Status = 5    
      FROM dbo.PickDetail PD    
         INNER JOIN @tPD T ON (PD.PickDetailKey = T.PickDetailKey)    
      -- Compare just in case PickDetail changed    
      WHERE PD.Status < '5'    
         AND PD.QTY = T.PD_QTY    
   END    
   ELSE    
   IF @cPickType = 'D'    
   BEGIN    
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
--         DropID = @cDropID, ignore the update on dropid if pick by dropid only    
         QTY = Final_QTY,     
         Status = 5    
      FROM dbo.PickDetail PD    
         INNER JOIN @tPD T ON (PD.PickDetailKey = T.PickDetailKey)    
      -- Compare just in case PickDetail changed    
      WHERE PD.Status < '5'    
         AND PD.QTY = T.PD_QTY    
   END    
    
   SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT    
          
   -- Check if update PickDetail fail    
   IF @nErrNo <> 0    
   BEGIN    
      SET @nErrNo = 175104    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd PKDtl fail'    
      GOTO RollBackTran    
   END    
    
   -- Check if other process had updated PickDetail    
   IF @nRowCount <> @nRowCount_PD    
   BEGIN    
      SET @nErrNo = 175105    
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Task changed'    
      GOTO RollBackTran    
   END    
    
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
         AND T.Lottable02 = @cLottable02    
         AND T.Lottable03 = @cLottable03    
         AND IsNULL( T.Lottable04, 0) = IsNULL( @dLottable04, 0)    
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
         SET @nErrNo = 175106    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd UCC fail'    
         GOTO RollBackTran    
      END    
       
      -- Check if other process had updated UCC    
      IF @nRowCount <> @nRowCount_UCC    
      BEGIN    
         SET @nErrNo = 175107    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Task changed'    
         GOTO RollBackTran    
      END    
   END  
   
      IF @cSplitPDByUOM = '1'   
   BEGIN   
      -- Split PickDetail If Qty > CaseCnt  * Quantity.  
      If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' OR ISNULL(@cZone, '') = '7'      
      BEGIN      
         -- Get PickDetail in the task      
         DECLARE CursorPDUOM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
         SELECT PD.PickDetailKey, PD.QTY, PD.OrderKey, PD.UOM , PD.UOMQty  
         FROM dbo.PickHeader PH (NOLOCK)       
         JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)      
         JOIN dbo.PickDetail PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)      
         JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT)      
         WHERE PH.PickHeaderKey = @cPickSlipNo      
            AND PD.Status = '5' -- Not yet picked      
            AND PD.LOC = @cLOC      
            AND PD.ID = @cID      
            AND PD.SKU = @cSKU      
            --AND PD.UOM = @cUOM      
            AND LA.Lottable02 = @cLottable02      
            AND LA.Lottable03 = @cLottable03      
            AND IsNULL( @dLottable04, 0) = IsNULL( LA.Lottable04, 0)       
            AND PD.CaseID = ''    
            AND PD.UOM IN ( '2', '3' )      
            AND PD.StorerKey = @cStorerKey    
      END      
      ELSE  -- discrete picklist      
      BEGIN      
         -- Get PickDetail in the task      
         DECLARE CursorPDUOM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
         SELECT PD.PickDetailKey, PD.QTY, PD.OrderKey  , PD.UOM  , PD.UOMQty  
         FROM dbo.PickHeader PH (NOLOCK)       
            INNER JOIN dbo.PickDetail PD (NOLOCK) ON (PH.OrderKey = PD.OrderKey)      
            INNER JOIN dbo.LotAttribute LA (NOLOCK) ON (PD.LOT = LA.LOT)      
         WHERE PH.PickHeaderKey = @cPickSlipNo      
            AND PD.Status = '5'    
            AND PD.LOC = @cLOC      
            AND PD.ID = @cID      
            AND PD.SKU = @cSKU      
            --AND PD.UOM = @cUOM      
            AND LA.Lottable02 = @cLottable02      
            AND LA.Lottable03 = @cLottable03      
            AND IsNULL( @dLottable04, 0) = IsNULL( LA.Lottable04, 0)     
            AND PD.CaseID = ''          
            AND PD.UOM IN ( '2', '3' )   
            AND PD.StorerKey = @cStorerKey         END      
        
      OPEN CursorPDUOM              
                    
      FETCH NEXT FROM CursorPDUOM INTO @cPickDetailKey, @nPD_QTY, @cOrderKey , @cPDUOM , @nUOMQty  
        
        
      WHILE @@FETCH_STATUS <> -1       
      BEGIN  
            
     
          SET @cPackKey = ''  
          SELECT @cPackKey = PackKey  
          FROM SKU (NOLOCK)  
          where StorerKey = @cStorerKey  
          and SKU = @cSKU  
                  
                  
          SELECT   
              @nUOMQty = CASE @cPDUOM  
                         WHEN '1' THEN Pallet   
                         WHEN '2' THEN CaseCnt   
                         WHEN '3' THEN InnerPack   
                         WHEN '4' THEN CONVERT(INT,OtherUnit1)   
                         WHEN '5' THEN CONVERT(INT,OtherUnit2)   
                         WHEN '6' THEN 1   
                         WHEN '7' THEN 1   
                         ELSE 0   
                         END   
             , @nInnerQty = InnerPack  
               
          FROM PACK (NOLOCK)   
          WHERE PackKey = @cPackKey   
            
                           
          SET @nPDMod = (@nPD_QTY % @nUOMQty)   
              
          IF @nPDMod <> 0   
          BEGIN  
              EXECUTE dbo.nspg_GetKey    
                       'PICKDETAILKEY',    
                       10 ,    
                       @cNewPickDetailKey OUTPUT,    
                       @b_success         OUTPUT,    
                       @nErrNo            OUTPUT,    
                       @cErrMsg           OUTPUT    
               
--              IF @b_success<>1    
--              BEGIN    
--                 SET @nErrNo = 91512    
--                 SET @cErrMsg = 'Get PickDetailKey Fail'  
--                 GOTO RollBackTran    
--              END    
                
              IF @nInnerQty = 0   
              BEGIN   
                  SET @cNewPDUOM    = '6'  
                  SET @nNewPDUOMQty = @nPDMod  
              END  
              ELSE   
              BEGIN  
                  SET @cNewPDUOM = '3'  
                  SET @nNewPDUOMQty = @nPDMod / @nInnerQty  
  
                  IF @nNewPDUOMQty = 0  
                  BEGIN  
                     SET @cNewPDUOM    = '6'  
                     SET @nNewPDUOMQty = @nPDMod  
                  END  
  
              END  
               
              -- Create a new PickDetail to hold the balance    
              INSERT INTO dbo.PICKDETAIL (    
                   CaseID                  ,PickHeaderKey   ,OrderKey    
                  ,OrderLineNumber         ,LOT             ,StorerKey    
                  ,SKU                     ,AltSKU          ,UOM    
                  ,UOMQTY                  ,QTYMoved        ,STATUS    
                  ,DropID                  ,LOC             ,ID    
                  ,PackKey                 ,UpdateSource    ,CartonGroup    
                  ,CartonType              ,ToLoc           ,DoReplenish    
                  ,ReplenishZone           ,DoCartonize     ,PickMethod    
                  ,WaveKey                 ,EffectiveDate   ,ArchiveCop    
                  ,ShipFlag                ,PickSlipNo      ,PickDetailKey    
                  ,QTY                     ,TrafficCop      ,OptimizeCop    
                  ,TaskDetailkey    
                 )    
              SELECT CaseID                ,PickHeaderKey    ,OrderKey    
                     ,OrderLineNumber      ,Lot              ,StorerKey    
                     ,SKU                  ,AltSku           ,@cNewPDUOM    
                     ,@nNewPDUOMQty        ,QTYMoved         ,Status  
                     ,DropID               ,LOC              ,ID    
                     ,PackKey              ,UpdateSource     ,CartonGroup    
                     ,CartonType           ,ToLoc            ,DoReplenish    
                     ,ReplenishZone        ,DoCartonize      ,PickMethod    
                     ,WaveKey              ,EffectiveDate    ,ArchiveCop    
                     ,ShipFlag             ,PickSlipNo       ,@cNewPickDetailKey    
                     ,@nPDMod  ,NULL            ,'1'  --OptimizeCop,    
                     ,TaskDetailKey    
              FROM   dbo.PickDetail WITH (NOLOCK)    
              WHERE  PickDetailKey = @cPickDetailKey    
               
              IF @@ERROR <> 0    
              BEGIN    
                 SET @nErrNo = 175108    
                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'InsPKDtl Fail'  
                 GOTO RollBackTran    
              END    
               
              -- If short pick & no split line needed. Update pickdetail.qty with no trafficcop    
              -- Change orginal PickDetail with exact QTY (with TrafficCop)    
              UPDATE dbo.PickDetail WITH (ROWLOCK)    
              SET    QTY = @nPD_QTY - @nPDMod  
                    ,UOMQty = @nPD_QTY / @nUOMQty  
                    ,Trafficcop = NULL    
              WHERE  PickDetailKey = @cPickDetailKey  
              AND Status = '5'    
               
              IF @@ERROR <> 0    
              BEGIN    
                 SET @nErrNo = 175109    
                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPKDtl Fail'  
                 GOTO RollBackTran    
              END    
          END  
          ELSE  
          BEGIN  
              UPDATE dbo.PickDetail WITH (ROWLOCK)    
              SET    UOMQty = @nPD_QTY / @nUOMQty  
                    ,Trafficcop = NULL    
              WHERE  PickDetailKey = @cPickDetailKey  
              AND Status = '5'    
                
              IF @@ERROR <> 0    
              BEGIN    
                 SET @nErrNo = 175110    
                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdPKDtl Fail'  
                 GOTO RollBackTran    
              END    
          END  
           
         FETCH NEXT FROM CursorPDUOM INTO @cPickDetailKey, @nPD_QTY, @cOrderKey , @cPDUOM , @nUOMQty  
      END  
      CLOSE CursorPDUOM              
      DEALLOCATE CursorPDUOM     
   END 

   -- Scan out pickslip if fully picked
   IF rdt.RDTGetConfig( @nFunc, 'AUTOSCANOUTPS', @cStorerKey) = '1'  
   BEGIN
      If ISNULL(@cZone, '') = 'XD' OR ISNULL(@cZone, '') = 'LB' OR ISNULL(@cZone, '') = 'LP' 
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
            AND   ScanOutDate IS NULL

            IF @@ERROR <> 0
            BEGIN  
               SET @nErrNo = 175111  
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
            AND   ScanOutDate IS NULL

            IF @@ERROR <> 0
            BEGIN  
               SET @nErrNo = 175112  
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