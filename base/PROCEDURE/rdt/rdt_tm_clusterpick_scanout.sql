SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_TM_ClusterPick_ScanOut                          */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Date         Rev  Author      Purposes                               */  
/* 2020-03-17   1.0  James       WMS-12055 Created                      */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_TM_ClusterPick_ScanOut] (  
    @nMobile         INT  
   ,@nFunc           INT  
   ,@cLangCode       NVARCHAR( 3)  
   ,@nStep           INT  
   ,@nInputKey       INT  
   ,@cFacility       NVARCHAR( 5)  
   ,@cStorerKey      NVARCHAR( 15)  
   ,@cTaskDetailKey  NVARCHAR( 10)  
   ,@nErrNo          INT           OUTPUT  
   ,@cErrMsg         NVARCHAR(250) OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @nTranCount   INT  
   DECLARE @cAutoScanOut NVARCHAR( 1)  
   DECLARE @cCaseID        NVARCHAR( 20)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @cLOC           NVARCHAR( 10)

   SET @nTranCount = @@TRANCOUNT  
     
   -- Get storer config  
   SET @cAutoScanOut = rdt.rdtGetConfig( @nFunc, 'AutoScanOut', @cStorerKey)  
  
   -- Auto scan out  
   IF @cAutoScanOut = '1'  
   BEGIN  
      DECLARE @cLoadKey  NVARCHAR( 10)  
      DECLARE @cOrderKey NVARCHAR( 10)  
      DECLARE @cZone     NVARCHAR( 18)  
      DECLARE @cScanOut  NVARCHAR(1)  
      DECLARE @cPickConfirmStatus NVARCHAR(1)  
  
      -- Get storer config  
      SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)  
      IF @cPickConfirmStatus = '0'  
         SET @cPickConfirmStatus = '5'  

      SELECT @cSKU = SKU,
             @cCaseID = Caseid,
             @cLOC = FromLoc
      FROM dbo.TaskDetail WITH (NOLOCK)
      WHERE TaskDetailKey = @cTaskDetailKey
   
      SELECT TOP 1 @cOrderKey = OrderKey
      FROM dbo.PICKDETAIL WITH (NOLOCK)
      WHERE Storerkey = @cStorerKey
      AND   CaseID = @cCaseID
      AND   Sku = @cSKU
      AND   Loc = @cLOC
      AND   [Status] < @cPickConfirmStatus
      ORDER BY 1
   
      SELECT @cLoadKey = LoadKey
      FROM dbo.ORDERS WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

      SELECT @cPickSlipNo = PickheaderKey
      FROM dbo.PICKHEADER WITH (NOLOCK) 
      WHERE OrderKey = @cOrderKey 
   
      IF ISNULL( @cPickSlipNo, '') = ''
         SELECT @cPickSlipNo = PickheaderKey FROM dbo.PICKHEADER WITH (NOLOCK) WHERE LoadKey = @cLoadKey

      IF ISNULL( @cPickSlipNo, '') = ''
         SELECT @cPickSlipNo = PickheaderKey FROM dbo.PICKHEADER WITH (NOLOCK) WHERE ExternOrderKey = @cLoadKey
      
      -- Get PickHeader info  
      SET @cOrderKey = ''  
      SET @cLoadKey = ''  
      SET @cZone = ''  
      SELECT TOP 1  
         @cOrderKey = OrderKey,  
         @cLoadKey = ExternOrderKey,  
         @cZone = Zone  
      FROM dbo.PickHeader WITH (NOLOCK)  
      WHERE PickHeaderKey = @cPickSlipNo  
  
      SET @cScanOut = 'N'  
        
      -- Cross dock PickSlip  
      IF @cZone IN ('XD', 'LB', 'LP')  
      BEGIN  
         -- Check outstanding PickDetail  
         IF NOT EXISTS( SELECT 1  
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)  
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)  
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE RKL.PickSlipNo = @cPickSlipNo  
               AND PD.QTY > 0  
               AND (PD.Status = '4' OR PD.Status < @cPickConfirmStatus))  
            SET @cScanOut = 'Y'  
      END  
  
      -- Discrete PickSlip  
      ELSE IF @cOrderKey <> ''  
      BEGIN  
         -- Check outstanding PickDetail  
         IF NOT EXISTS( SELECT 1  
            FROM dbo.PickDetail PD WITH (NOLOCK)  
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE PD.OrderKey = @cOrderKey  
               AND PD.QTY > 0  
               AND (PD.Status = '4' OR PD.Status < @cPickConfirmStatus))  
            SET @cScanOut = 'Y'  
      END  
  
      -- Conso PickSlip  
      ELSE IF @cLoadKey <> ''  
      BEGIN  
         -- Check outstanding PickDetail  
         IF NOT EXISTS( SELECT 1  
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)   
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)      
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)  
            WHERE LPD.LoadKey = @cLoadKey    
               AND PD.QTY > 0  
               AND (PD.Status = '4' OR PD.Status < @cPickConfirmStatus))  
            SET @cScanOut = 'Y'  
      END  
        
      -- Scan-out  
      IF @cScanOut = 'Y'  
      BEGIN  
         -- Handling transaction  
         BEGIN TRAN  
         SAVE TRAN rdt_TM_ClusterPick_ScanOut -- For rollback or commit only our own transaction  
           
         UPDATE dbo.PickingInfo SET  
            ScanOutDate = GETDATE()  
         WHERE PickSlipNo = @cPickSlipNo  
         SET @nErrNo = @@ERROR   
         IF @nErrNo <> 0  
      BEGIN  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')  
            GOTO RollBackTran  
         END  
           
         COMMIT TRAN rdt_TM_ClusterPick_ScanOut  
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
            COMMIT TRAN  
      END  
   END  
  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_TM_ClusterPick_ScanOut -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO