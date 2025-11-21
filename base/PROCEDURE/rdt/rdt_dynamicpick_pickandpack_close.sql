SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_DynamicPick_PickAndPack_Close                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get next location for Pick And Pack function                */
/*                                                                      */
/* Called from: rdtfnc_DynamicPick_PickAndPack                          */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 19-Jun-2008 1.0  UngDH       Created                                 */
/* 24-Nov-2011 1.1  Ung         Change PickDetail.Status checking       */
/* 28-Dec-2011 1.2  Ung         Only when picked=packed then confirm    */
/*                              packheader (james01)                    */
/* 22-Feb-2012 1.3  Shong       Skip Pack Confirm by Storer Config      */
/* 10-Jul-2013 1.4  Ung         Fix short pick should not pack confirm  */
/* 28-Jul-2016 1.5  Ung         SOS375224 Add LoadKey, Zone optional    */
/************************************************************************/

CREATE PROC [RDT].[rdt_DynamicPick_PickAndPack_Close] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cPickSlipType NVARCHAR( 10),
   @cPickSlipNo   NVARCHAR( 10),
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nTranCount  INT
   DECLARE @nPickQTY    INT
   DECLARE @nPackQTY    INT 

   -- Pack confirm
   IF rdt.RDTGetConfig( @nFunc, 'DynamicPickSkipPackCfm', @cStorerKey) <> '1' -- Not skip
   BEGIN
      -- Cross dock PickSlip
      IF @cPickSlipType = 'X' 
      BEGIN
         -- Check PickSlip have outstanding
         IF EXISTS (SELECT 1
            FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
            WHERE RKL.PickSlipNo = @cPickSlipNo
               AND PD.QTY > 0
               AND PD.Status IN ('0', '4')) -- 0=Allocated, 4=Short
            GOTO Quit

         -- Get pick qty
         SELECT @nPickQTY = ISNULL( SUM(QTY), 0)
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
         WHERE RKL.PickSlipNo = @cPickSlipNo
      END
         
      -- Discrete PickSlip
      ELSE IF @cPickSlipType = 'D' 
      BEGIN
         -- Check PickSlip have outstanding
         IF EXISTS (SELECT 1
            FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
            WHERE PH.PickHeaderKey = @cPickSlipNo
               AND PD.QTY > 0
               AND PD.Status IN ('0', '4')) -- 0=Allocated, 4=Short
            GOTO Quit

         -- Get pick qty
         SELECT @nPickQTY = ISNULL( SUM(QTY), 0)
         FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
         WHERE PH.PickHeaderKey = @cPickSlipNo
      END

      -- Conso PickSlip
      ELSE IF @cPickSlipType = 'C' 
      BEGIN
         -- Check PickSlip have outstanding
         IF EXISTS (SELECT 1
            FROM dbo.PickHeader PH WITH (NOLOCK)
               JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
               JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
            WHERE PH.PickHeaderKey = @cPickSlipNo
               AND PD.QTY > 0
               AND PD.Status IN ('0', '4')) -- 0=Allocated, 4=Short
            GOTO Quit

         -- Get pick qty
         SELECT @nPickQTY = ISNULL( SUM(QTY), 0)
         FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
         WHERE PH.PickHeaderKey = @cPickSlipNo
      END

      -- Get total packed qty
      SELECT @nPackQTY = ISNULL( SUM(QTY), 0)
      FROM dbo.PackDetail WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo

      IF @nPickQTY = @nPackQTY
      BEGIN
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN DynamicPick_PickAndPack_Close -- For rollback or commit only our own transaction

         -- Pack confirm (PackHeader)
         UPDATE dbo.PackHeader WITH (ROWLOCK) SET 
            Status = '9'
         WHERE PickSlipNo = @cPickSlipNo
         IF @@ERROR <> 0
   	   BEGIN
            SET @nErrNo = 64751
            SET @cErrMsg = rdt.rdtgetmessage( 64751, @cLangCode, 'DSP') --'UpdPackHdrFail'
            GOTO RollBackTran
         END
      
         /* Pack confirm will update PickingInfo
         -- Scan out (PickingInfo)
         UPDATE dbo.PickingInfo WITH (ROWLOCK) SET 
            ScanOutDate = GETDATE()
         WHERE PickSlipNo = @cPickSlipNo
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 64752
            SET @cErrMsg = rdt.rdtgetmessage( 64752, @cLangCode, 'DSP') --'UpdPKInfoFail'
            GOTO RollBackTran
         END
         */
      END
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN DynamicPick_PickAndPack_Close
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO