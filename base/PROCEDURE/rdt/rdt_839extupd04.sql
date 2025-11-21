SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_839ExtUpd04                                           */
/* Purpose: Confirm pick for sku.skugroup = POP (Physical user no need pick)  */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2022-02-24   James     1.0   WMS-18978. Created                            */
/* 2022-04-20   YeeKung   1.1   WMS-19311 Add Data capture (yeekung02)        */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_839ExtUpd04]
    @nMobile         INT                   
   ,@nFunc           INT                    
   ,@cLangCode       NVARCHAR( 3)           
   ,@nStep           INT                    
   ,@nInputKey       INT                    
   ,@cFacility       NVARCHAR( 5)           
   ,@cStorerKey      NVARCHAR( 15)          
   ,@cPickSlipNo     NVARCHAR( 10)          
   ,@cPickZone       NVARCHAR( 10)          
   ,@cDropID         NVARCHAR( 20)          
   ,@cLOC            NVARCHAR( 10)          
   ,@cSKU            NVARCHAR( 20)          
   ,@nQTY            INT                    
   ,@cOption         NVARCHAR( 1)           
   ,@cLottableCode   NVARCHAR( 30)          
   ,@cLottable01     NVARCHAR( 18)          
   ,@cLottable02     NVARCHAR( 18)          
   ,@cLottable03     NVARCHAR( 18)          
   ,@dLottable04     DATETIME               
   ,@dLottable05     DATETIME               
   ,@cLottable06     NVARCHAR( 30)          
   ,@cLottable07     NVARCHAR( 30)          
   ,@cLottable08     NVARCHAR( 30)          
   ,@cLottable09     NVARCHAR( 30)          
   ,@cLottable10     NVARCHAR( 30)          
   ,@cLottable11     NVARCHAR( 30)          
   ,@cLottable12     NVARCHAR( 30)          
   ,@dLottable13     DATETIME               
   ,@dLottable14     DATETIME               
   ,@dLottable15     DATETIME
   ,@cPackData1      NVARCHAR( 30)
   ,@cPackData2      NVARCHAR( 30)
   ,@cPackData3      NVARCHAR( 30)  
   ,@nErrNo          INT           OUTPUT   
   ,@cErrMsg         NVARCHAR(250) OUTPUT   
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOrderKey      NVARCHAR( 10)    
   DECLARE @cLoadKey       NVARCHAR( 10)    
   DECLARE @cZone          NVARCHAR( 18)    
   DECLARE @cPickDetailKey NVARCHAR( 18)    
   DECLARE @cPickConfirmStatus NVARCHAR( 1)    
   DECLARE @nQTY_Bal       INT    
   DECLARE @nQTY_PD        INT    
   DECLARE @bSuccess       INT    
   DECLARE @curPD          CURSOR    
   DECLARE @cWhere         NVARCHAR( MAX)    
   DECLARE @cSQL           NVARCHAR( MAX)    
   DECLARE @cSQLParam      NVARCHAR( MAX)    
   DECLARE @nTranCount     INT    
      
   IF @nInputKey = 1
   BEGIN      
      IF @nStep = 2
      BEGIN
         SET @cOrderKey = ''    
         SET @cLoadKey = ''    
         SET @cZone = ''    
    
         -- Get storer config    
         SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)    
         IF @cPickConfirmStatus = '0'    
            SET @cPickConfirmStatus = '5'    
    
         -- Get PickHeader info    
         SELECT TOP 1    
            @cOrderKey = OrderKey,    
            @cLoadKey = ExternOrderKey,    
            @cZone = Zone    
         FROM dbo.PickHeader WITH (NOLOCK)    
         WHERE PickHeaderKey = @cPickSlipNo    
   
         -- Cross dock PickSlip    
         IF @cZone IN ('XD', 'LB', 'LP')    
            SET @cSQL =     
               ' SELECT PD.PickDetailKey ' +    
               ' FROM dbo.RefKeyLookup RKL WITH (NOLOCK) ' +    
               '    JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey) ' +    
               '    JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU) ' +
            ' WHERE RKL.PickSlipNo = @cPickSlipNo ' +    
               '   AND PD.QTY > 0 ' +    
               '   AND PD.Status <> ''4'' ' +    
               '   AND PD.Status < @cPickConfirmStatus ' +    
               '   AND SKU.SKUGROUP = ''POP'' ' 
               
         -- Discrete PickSlip    
         ELSE IF @cOrderKey <> ''    
            SET @cSQL =     
               ' SELECT PD.PickDetailKey ' +    
               ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +    
               '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +    
               '    JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU) ' +     
               ' WHERE PD.OrderKey = @cOrderKey ' +    
               '    AND PD.QTY > 0 ' +    
               '    AND PD.Status <> ''4'' ' +    
               '    AND PD.Status < @cPickConfirmStatus ' +    
               '    AND SKU.SKUGROUP = ''POP'' ' 
    
         -- Conso PickSlip    
         ELSE IF @cLoadKey <> ''    
            SET @cSQL =     
               ' SELECT PD.PickDetailKey ' +    
               ' FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) ' +    
               '    JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey) ' +    
               '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +    
               '    JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU) ' +
               ' WHERE LPD.LoadKey = @cLoadKey ' +    
               '    AND PD.QTY > 0 ' +    
               '    AND PD.Status <> ''4'' ' +    
               '    AND PD.Status < @cPickConfirmStatus ' +    
               '    AND SKU.SKUGROUP = ''POP'' ' 
    
         -- Custom PickSlip    
         ELSE    
            SET @cSQL =     
               ' SELECT PD.PickDetailKey ' +    
               ' FROM dbo.PickDetail PD WITH (NOLOCK) ' +    
               '    JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC) ' +    
               '    JOIN dbo.SKU SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU) ' +
               ' WHERE PD.PickSlipNo = @cPickSlipNo ' +    
               '    AND PD.QTY > 0 ' +    
               '    AND PD.Status <> ''4'' ' +    
               '    AND PD.Status < @cPickConfirmStatus ' +    
               '    AND SKU.SKUGROUP = ''POP'' ' 
    
         -- Open cursor    
         SET @cSQL =     
            ' SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR ' +     
               @cSQL +     
            ' OPEN @curPD '     
       
         SET @cSQLParam =     
            ' @curPD       CURSOR OUTPUT, ' +     
            ' @cPickSlipNo NVARCHAR( 10), ' +     
            ' @cOrderKey   NVARCHAR( 10), ' +     
            ' @cLoadKey    NVARCHAR( 10), ' +     
            ' @cPickConfirmStatus NVARCHAR( 1) ' 
    
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, @curPD OUTPUT, @cPickSlipNo, @cOrderKey, @cLoadKey, @cPickConfirmStatus
    
         -- Handling transaction    
         SET @nTranCount = @@TRANCOUNT    
         BEGIN TRAN  -- Begin our own transaction    
         SAVE TRAN rdt_839ExtUpd04 -- For rollback or commit only our own transaction    
    
         -- Loop PickDetail    
         FETCH NEXT FROM @curPD INTO @cPickDetailKey    
         WHILE @@FETCH_STATUS = 0    
         BEGIN    
            -- Confirm PickDetail    
            UPDATE dbo.PickDetail WITH (ROWLOCK) SET    
               Status = @cPickConfirmStatus,    
               EditDate = GETDATE(),    
               EditWho  = SUSER_SNAME()    
            WHERE PickDetailKey = @cPickDetailKey    
            IF @@ERROR <> 0    
            BEGIN    
               SET @nErrNo = 183551    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- UPD PKDtl Fail    
               GOTO RollBackTran    
            END    
    
            FETCH NEXT FROM @curPD INTO @cPickDetailKey    
         END    
    
         COMMIT TRAN rdt_839ExtUpd04    

         GOTO Quit    
    
      RollBackTran:    
         ROLLBACK TRAN rdt_839ExtUpd04 -- Only rollback change made here    
      Quit:    
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
            COMMIT TRAN    
      END
   END


END

GO