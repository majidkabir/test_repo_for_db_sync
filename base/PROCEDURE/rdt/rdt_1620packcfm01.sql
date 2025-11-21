SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_1620PackCfm01                                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Pack confirm                                                */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 2019-08-15   1.0  James    WMS-10274 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1620PackCfm01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @tAutoPackCfm   VariableTable READONLY, 
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount     INT
   DECLARE @cZone          NVARCHAR( 10)
   DECLARE @cPH_LoadKey    NVARCHAR( 10)
   DECLARE @cPH_OrderKey   NVARCHAR( 10)
   DECLARE @cPSType        NVARCHAR( 10)
   DECLARE @cPickConfirmStatus NVARCHAR( 1)
   DECLARE @nSum_Picked    INT
   DECLARE @nSum_Packed    INT
   DECLARE @cPackConfirm   NVARCHAR( 1)
   DECLARE @cWaveKey       NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @curPD          CURSOR

   SET @nErrNo = 0

   -- Variable mapping
   SELECT @cWaveKey = Value FROM @tAutoPackCfm WHERE Variable = '@cWaveKey'
   SELECT @cLoadKey = Value FROM @tAutoPackCfm WHERE Variable = '@cLoadKey'
   SELECT @cOrderKey = Value FROM @tAutoPackCfm WHERE Variable = '@cOrderKey'

   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1620PackCfm01

   IF ISNULL( @cWaveKey, '') <> ''
   BEGIN
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey
      FROM dbo.WAVEDETAIL WITH (NOLOCK)
      WHERE WaveKey = @cWaveKey
   END
   ELSE
   IF ISNULL( @cLoadKey, '') <> ''
   BEGIN
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey
      FROM dbo.LoadPlanDetail WITH (NOLOCK)
      WHERE LoadKey = @cLoadKey
   END
   ELSE
   BEGIN
      SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderKey
      FROM dbo.ORDERS WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey

   END
   OPEN @curPD
   FETCH NEXT FROM @curPD INTO @cOrderKey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- Get PickSlipNo  
      SET @cPickSlipNo = ''  
      SELECT @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @cOrderKey  
      IF @cPickSlipNo = ''  
         SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @cLoadkey ORDER BY 1
      IF @cPickSlipNo = ''  
         SELECT TOP 1 @cPickSlipNo = PickHeaderKey FROM PickHeader WITH (NOLOCK) WHERE Loadkey = @cLoadkey ORDER BY 1

      IF @cPickSlipNo = ''
      BEGIN
         SET @nErrNo = 143301
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No Pickslip'
         GOTO RollBackTran
      END

      SELECT @cZone = Zone,
             @cPH_OrderKey = OrderKey,
             @cPH_LoadKey = ExternOrderKey
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo

      -- Get PickSlip type
      IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP'
         SET @cPSType = 'XD'
      ELSE IF @cPH_OrderKey = ''
         SET @cPSType = 'CONSO'
      ELSE
         SET @cPSType = 'DISCRETE'

      SET @nSum_Packed = 0
      SELECT @nSum_Packed = ISNULL( SUM( Qty), 0)
      FROM dbo.PackDetail PD WITH (NOLOCK) 
      WHERE PickSlipNo = @cPickSlipNo

      SET @nSum_Picked = 0

      -- Cross dock PickSlip
      IF @cZone IN ('XD', 'LB', 'LP')
      BEGIN
         -- Check outstanding PickDetail
         IF EXISTS( SELECT TOP 1 1
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND PD.Status < '5'
               AND PD.QTY > 0
               AND (PD.Status = '4' OR PD.Status <> @cPickConfirmStatus))  -- Short or not yet pick
            SET @cPackConfirm = 'N'
         ELSE
            SET @cPackConfirm = 'Y'
      
         -- Check fully packed
         IF @cPackConfirm = 'Y'
         BEGIN
            SELECT @nSum_Picked = SUM( QTY) 
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
            WHERE RKL.PickSlipNo = @cPickSlipNo
         
            IF @nSum_Picked <> @nSum_Packed
               SET @cPackConfirm = 'N'
         END
      END

      -- Discrete PickSlip
      ELSE IF @cPH_OrderKey <> ''
      BEGIN
         -- Check outstanding PickDetail
         IF EXISTS( SELECT TOP 1 1
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.OrderKey = @cPH_OrderKey
               AND PD.Status < '5'
               AND PD.QTY > 0
               AND (PD.Status = '4' OR PD.Status <> @cPickConfirmStatus))  -- Short or not yet pick
            SET @cPackConfirm = 'N'
         ELSE
            SET @cPackConfirm = 'Y'
      
         -- Check fully packed
         IF @cPackConfirm = 'Y'
         BEGIN
            SELECT @nSum_Picked = SUM( PD.QTY) 
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            WHERE PD.OrderKey = @cPH_OrderKey
         
            IF @nSum_Picked <> @nSum_Packed
               SET @cPackConfirm = 'N'
         END
      END
   
      -- Conso PickSlip
      ELSE IF @cPH_LoadKey <> ''
      BEGIN
         -- Check outstanding PickDetail
         IF EXISTS( SELECT TOP 1 1 
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
            WHERE LPD.LoadKey = @cPH_LoadKey
               AND PD.Status < '5'
               AND PD.QTY > 0
               AND (PD.Status = '4' OR PD.Status <> @cPickConfirmStatus))  -- Short or not yet pick
            SET @cPackConfirm = 'N'
         ELSE
            SET @cPackConfirm = 'Y'
      
         -- Check fully packed
         IF @cPackConfirm = 'Y'
         BEGIN
            SELECT @nSum_Picked = SUM( PD.QTY) 
            FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
            WHERE LPD.LoadKey = @cPH_LoadKey
         
            IF @nSum_Picked <> @nSum_Packed
               SET @cPackConfirm = 'N'
         END
      END

      -- Custom PickSlip
      ELSE
      BEGIN
         -- Check outstanding PickDetail
         IF EXISTS( SELECT TOP 1 1 
            FROM PickDetail PD WITH (NOLOCK) 
            WHERE PD.PickSlipNo = @cPickSlipNo
               AND PD.Status < '5'
               AND PD.QTY > 0
               AND (PD.Status = '4' OR PD.Status <> @cPickConfirmStatus))  -- Short or not yet pick
            SET @cPackConfirm = 'N'
         ELSE
            SET @cPackConfirm = 'Y'

         -- Check fully packed
         IF @cPackConfirm = 'Y'
         BEGIN
            SELECT @nSum_Picked = SUM( PD.QTY) 
            FROM PickDetail PD WITH (NOLOCK) 
            WHERE PD.PickSlipNo = @cPickSlipNo
         
            IF @nSum_Picked <> @nSum_Packed
               SET @cPackConfirm = 'N'
         END
      END

      IF @cPackConfirm = 'Y'
      BEGIN
         UPDATE dbo.PackHeader WITH (ROWLOCK) SET 
            [Status] = '9'
         WHERE PickSlipNo = @cPickSlipNo
         AND   [Status] < '9'

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 143302
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PackCfm Fail
            GOTO RollBackTran
         END
      END

      FETCH NEXT FROM @curPD INTO @cOrderKey
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_1620PackCfm01

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN rdt_1620PackCfm01


   Fail:
END

GO