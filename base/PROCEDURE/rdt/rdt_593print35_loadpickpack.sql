SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_593Print35_LoadPickPack                         */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 01-04-2022 1.0  Ung         WMS-19306 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_593Print35_LoadPickPack] (
   @cLoadKey     NVARCHAR( 10), 
   @cCartonType  NVARCHAR( 10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess    INT
   DECLARE @nRowCount   INT
   DECLARE @nErrNo      INT
   DECLARE @cErrMsg     NVARCHAR( 20)
   DECLARE @cStorerKey  NVARCHAR( 15)
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cTrackingNo NVARCHAR( 40)
   DECLARE @cPickslipNo NVARCHAR( 10)
   DECLARE @cLabelNo    NVARCHAR( 20)

   -- Loop orders, by load
   DECLARE @curOrder CURSOR
   SET @curOrder = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey, StorerKey, TrackingNo
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE LoadKey = @cLoadKey
   OPEN @curOrder
   FETCH NEXT FROM @curOrder INTO @cOrderKey, @cStorerKey, @cTrackingNo
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Get PickHeader info
      SET @cPickSlipNo = ''
      SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey  

      -- Handling transaction
      DECLARE @nTranCount  INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_Pack_Confirm -- For rollback or commit only our own transaction

      -- Create PickSlipNo
      IF @cPickSlipNo = ''
      BEGIN
         EXECUTE dbo.nspg_GetKey
            'PICKSLIP',
            9 ,
            @cPickSlipNo   OUTPUT,
            @bSuccess      OUTPUT,
            @nErrNo        OUTPUT,
            @cErrMsg       OUTPUT
         IF @bSuccess <> 1
            GOTO RollBackTran

         SET @cPickSlipNo = 'P' + @cPickSlipNo
      END
      
      -- PickHeader
      IF NOT EXISTS( SELECT 1 FROM dbo.PickHeader WITH (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo)
      BEGIN
         INSERT INTO dbo.PickHeader
            (PickHeaderKey, ExternOrderKey, OrderKey, PickType, Zone)
         VALUES
            (@cPickSlipNo, @cLoadKey, @cOrderKey, '0', 'D')
         IF @@ERROR  <> 0
            GOTO RollBackTran
      END

      -- PickingInfo
      IF NOT EXISTS( SELECT 1 FROM dbo.PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)  
      BEGIN  
         INSERT INTO dbo.PickingInfo (PickSlipNo, ScanInDate, PickerID)  
         VALUES (@cPickSlipNo, GETDATE(), SUSER_SNAME())  
         IF @@ERROR <> 0
            GOTO RollBackTran
      END

      -- PackHeader
      IF NOT EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickslipNo = @cPickslipNo)
      BEGIN
         INSERT INTO dbo.PackHeader (PickSlipNo, StorerKey, OrderKey, LoadKey)
         VALUES (@cPickSlipNo, @cStorerKey, @cOrderKey, @cLoadKey)
         IF @@ERROR <> 0
            GOTO RollBackTran
      END

      -- PackDetail
      IF NOT EXISTS( SELECT TOP 1 1 FROM dbo.PackDetail WITH (NOLOCK) WHERE PickslipNo = @cPickslipNo)
      BEGIN
         -- Create LabelNo
         SET @cLabelNo = ''
         EXEC isp_GenUCCLabelNo
            @cStorerKey,
            @cLabelNo      OUTPUT, 
            @bSuccess      OUTPUT,
            @nErrNo        OUTPUT,
            @cErrMsg       OUTPUT
         IF @nErrNo <> 0
            GOTO RollBackTran

         -- Loop PickDetail, by order
         INSERT INTO dbo.PackDetail
            (PickSlipNo, CartonNo, LabelNo, LabelLine, StorerKey, SKU, QTY)
         SELECT 
            @cPickSlipNo, 1, @cLabelNo, RIGHT( '0000' + CAST( ROW_NUMBER() OVER(ORDER BY StorerKey, SKU) AS NVARCHAR(5)), 5), 
            @cStorerKey, SKU, ISNULL( SUM( QTY), 0)
         FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey
            AND QTY > 0
            AND Status <> '4'
         GROUP BY StorerKey, SKU
         SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT 
         IF @nErrNo <> 0
            GOTO RollBackTran

         IF @nRowCount > 0
         BEGIN
            -- Loop PickDetail, by order
            DECLARE @cPickDetailKey NVARCHAR( 10)
            DECLARE @curPD CURSOR
            SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT PickDetailKey
               FROM dbo.PickDetail WITH (NOLOCK) 
               WHERE OrderKey = @cOrderKey
                  AND CaseID = ''
                  AND QTY > 0
                  AND Status <> '4'
            OPEN @curPD
            FETCH NEXT FROM @curPD INTO @cPickDetailKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Update CaseID
               UPDATE dbo.PickDetail SET
                  CaseID = @cLabelNo, 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE PickDetailKey = @cPickDetailKey
               IF @nErrNo <> 0
                  GOTO RollBackTran
                  
               FETCH NEXT FROM @curPD INTO @cPickDetailKey
            END
         END
      END

      -- Get SKU weight
      DECLARE @nWeight FLOAT
      SELECT @nWeight = SUM( PD.QTY * SKU.GrossWgt)
      FROM dbo.PackDetail PD WITH (NOLOCK) 
         JOIN dbo.SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
      WHERE PD.PickslipNo = @cPickslipNo

      -- Get carton weight
      DECLARE @nCartonWeight FLOAT
      SELECT @nCartonWeight = ISNULL( CartonWeight, 0)
      FROM dbo.Cartonization C WITH (NOLOCK) 
         JOIN dbo.Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)
      WHERE S.StorerKey = @cStorerKey
         AND C.CartonType = @cCartonType
      
      -- Total weight
      SET @nWeight = @nWeight + @nCartonWeight
      
      -- PackInfo
      IF NOT EXISTS( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)  
      BEGIN  
         INSERT INTO dbo.PackInfo 
            (PickslipNo, CartonNo, QTY, CartonType, Weight, TrackingNo)            
         SELECT 
            @cPickSlipNo, 1, SUM( QTY), @cCartonType, @nWeight, @cTrackingNo
         FROM dbo.PackDetail WITH (NOLOCK)
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = 1
         IF @@ERROR <> 0
            GOTO RollBackTran
      END
      ELSE
      BEGIN  
         UPDATE dbo.PackInfo SET
            CartonType = @cCartonType, 
            Weight = @nWeight, 
            TrackingNo = @cTrackingNo, 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME()
         WHERE PickSlipNo = @cPickSlipNo
            AND CartonNo = 1
         IF @@ERROR <> 0
            GOTO RollBackTran
      END

      -- Pack confirm
      IF EXISTS( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickslipNo = @cPickslipNo AND Status < '9')
      BEGIN
         UPDATE dbo.PackHeader SET
            Status = '9', 
            EditDate = GETDATE(), 
            EditWho = SUSER_SNAME()
         WHERE PickSlipNo = @cPickSlipNo
         IF @@ERROR <> 0
            GOTO RollBackTran
      END

      GOTO Quit
      
      RollBackTran:
         ROLLBACK TRAN rdt_Pack_Confirm -- Only rollback change made here
      Quit:
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN

      FETCH NEXT FROM @curOrder INTO @cOrderKey, @cStorerKey, @cTrackingNo
   END
END

GO