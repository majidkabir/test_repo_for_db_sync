SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Store procedure: rdt_839ExtUpd03                                           */  
/* Purpose: Update pickdetail.caseid for "balance pick later" option          */  
/*                                                                            */  
/* Modifications log:                                                         */  
/*                                                                            */  
/* Date         Author    Ver.  Purposes                                      */  
/* 2021-12-22   James     1.0   WMS-18004. Created                            */ 
/* 2022-04-20   YeeKung   1.1   WMS-19311 Add Data capture (yeekung02)        */
/******************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_839ExtUpd03]  
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
  
   DECLARE @nTranCount     INT  
   DECLARE @cPickDetailKey NVARCHAR( 10) = ''  
   DECLARE @cOrderKey      NVARCHAR( 10) = ''  
   DECLARE @cLoadKey       NVARCHAR( 10) = ''  
   DECLARE @cZone          NVARCHAR( 18) = ''  
   DECLARE @cPickConfirmStatus NVARCHAR( 1)  
   DECLARE @curBal         CURSOR  
     
   IF @nFunc = 839  
   BEGIN        
      IF @nStep = 5 -- Confirm option screen  
      BEGIN  
         IF @nInputKey = 1   
         BEGIN  
            SELECT @cOption = I_Field01  
            FROM rdt.RDTMOBREC WITH (NOLOCK)  
            WHERE Mobile = @nMobile  
  
            IF @cOption = 2  
            BEGIN  
               -- Get PickHeader info  
               SELECT TOP 1  
                  @cOrderKey = OrderKey,  
                  @cLoadKey = ExternOrderKey,  
                  @cZone = Zone  
               FROM dbo.PickHeader WITH (NOLOCK)  
               WHERE PickHeaderKey = @cPickSlipNo  
  
               -- Get storer config  
               SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
               IF @cPickConfirmStatus = '0'  
                  SET @cPickConfirmStatus = '5'  
        
               -- Handling transaction  
               SET @nTranCount = @@TRANCOUNT  
               BEGIN TRAN  -- Begin our own transaction  
               SAVE TRAN rdt_PickPiece_Confirm -- For rollback or commit only our own transaction  
     
               -- Cross dock PickSlip  
               IF @cZone IN ('XD', 'LB', 'LP')  
                  SET @curBal = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                     SELECT PD.PickDetailKey  
                     FROM dbo.RefKeyLookup RKL WITH (NOLOCK)  
                        JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)  
                     WHERE RKL.PickSlipNo = @cPickSlipNo  
                        AND PD.LOC = @cLOC  
                        AND PD.SKU = @cSKU  
                        AND PD.QTY > 0  
                        AND PD.Status <> '4'  
                        AND PD.Status < @cPickConfirmStatus  
                          
               -- Discrete PickSlip  
               ELSE IF @cOrderKey <> ''  
                  SET @curBal = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                     SELECT PD.PickDetailKey  
                     FROM dbo.PickDetail PD WITH (NOLOCK)  
                        JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
                     WHERE PD.OrderKey = @cOrderKey  
                        AND PD.LOC = @cLOC  
                        AND PD.SKU = @cSKU  
                        AND PD.QTY > 0  
                        AND PD.Status <> '4'  
                        AND PD.Status < @cPickConfirmStatus  
  
               -- Conso PickSlip  
               ELSE IF @cLoadKey <> ''  
                  SET @curBal = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                     SELECT PD.PickDetailKey  
                     FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)  
                        JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)  
                        JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
                     WHERE LPD.LoadKey = @cLoadKey  
                        AND PD.LOC = @cLOC  
                        AND PD.SKU = @cSKU  
                        AND PD.QTY > 0  
                        AND PD.Status <> '4'  
                        AND PD.Status < @cPickConfirmStatus  
  
               -- Custom PickSlip  
               ELSE  
                  SET @curBal = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                     SELECT PD.PickDetailKey  
                     FROM dbo.PickDetail PD WITH (NOLOCK)  
                        JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
                     WHERE PD.PickSlipNo = @cPickSlipNo  
                        AND PD.LOC = @cLOC  
                        AND PD.SKU = @cSKU  
                        AND PD.QTY > 0  
                        AND PD.Status <> '4'  
                        AND PD.Status < @cPickConfirmStatus  
  
               -- Loop PickDetail  
               OPEN @curBal  
               FETCH NEXT FROM @curBal INTO @cPickDetailKey  
               WHILE @@FETCH_STATUS = 0  
               BEGIN  
                  UPDATE dbo.PickDetail WITH (ROWLOCK) SET   
                     CaseID = 'Bal',  
                     EditDate = GETDATE(),  
                     EditWho  = SUSER_SNAME()  
                  WHERE PickDetailKey = @cPickDetailKey  
                  IF @@ERROR <> 0  
                     GOTO RollBackTran  
  
                  FETCH NEXT FROM @curBal INTO @cPickDetailKey  
               END                 
  
               GOTO CommitTran  
  
               RollBackTran:  
                  ROLLBACK TRAN rdt_839ExtUpd03 -- Only rollback change made here  
               CommitTran:  
                  WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
                     COMMIT TRAN rdt_839ExtUpd03    
            END  
         END  
      END  
   END  
  
Quit:  
  
  
END  

GO