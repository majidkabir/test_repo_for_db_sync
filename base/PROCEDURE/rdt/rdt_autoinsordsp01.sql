SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_AutoInsOrdSP01                                  */
/* Purpose: Cluster Pick auto insert orderkey. Use back all the         */
/*          orderkey added previously.                                  */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 01-Dec-2016 1.0  James      Created                                  */
/************************************************************************/

CREATE PROC [RDT].[rdt_AutoInsOrdSP01] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerkey       NVARCHAR( 15), 
   @cWaveKey         NVARCHAR( 10), 
   @cLoadKey         NVARCHAR( 10), 
   @cOrderKey        NVARCHAR( 10), 
   @cPutAwayZone     NVARCHAR( 10), 
   @cPickZone        NVARCHAR( 10), 
   @cLoc             NVARCHAR( 10), 
   @cDropID          NVARCHAR( 20), 
   @cSKU             NVARCHAR( 20), 
   @nQty             INT, 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cTemp_OrderKey    NVARCHAR( 10)
   DECLARE @cPickSlipNo       NVARCHAR( 10)
   DECLARE @cUserName         NVARCHAR( 18)
   DECLARE @cFacility         NVARCHAR( 5)
   DECLARE @nTranCount        INT

   SELECT @cUserName = UserName, 
          @cFacility = Facility 
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_AutoInsOrdSP01

   IF EXISTS ( SELECT 1 FROM RDT.rdtPickLock WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   Status = '1'
               AND   AddWho = @cUserName)
      GOTO Quit
                         
   DECLARE CUR_INS CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT DISTINCT OrderKey 
   FROM RDT.RDTPICKLOCK RPL WITH (NOLOCK)
   WHERE AddWho = @cUserName
   --AND   WaveKey = CASE WHEN ISNULL(@cWaveKey, '') = '' THEN WaveKey ELSE @cWaveKey END
   --AND   LoadKey = CASE WHEN ISNULL(@cLoadKey, '') = '' THEN LoadKey ELSE @cLoadKey END
   --AND   PutAwayZone = CASE WHEN @cPutAwayZone = 'ALL' THEN PutAwayZone ELSE @cPutAwayZone END
   AND   EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
                  WHERE PD.OrderKey = RPL.OrderKey
                  AND   LOC.PickZone = @cPickZone
                  AND   PD.Status = '0' )
   OPEN CUR_INS
   FETCH NEXT FROM CUR_INS INTO @cTemp_OrderKey
   WHILE @@FETCH_STATUS <> -1 
   BEGIN
      SET @cPickSlipNo = ''
      SELECT @cPickSlipNo = PickHeaderKey
      FROM dbo.PickHeader PH WITH (NOLOCK)
      JOIN dbo.Orders O WITH (NOLOCK) ON PH.WaveKey = O.UserDefine09 AND PH.OrderKey = O.OrderKey
      WHERE O.StorerKey = @cStorerKey
      AND   O.OrderKey = @cTemp_OrderKey
      AND   PH.Status = '0'

      -- If not wave plan, look in loadplan
      IF ISNULL(@cPickSlipNo, '') = ''
      BEGIN
         SELECT @cPickSlipNo = PickHeaderKey
         FROM dbo.PickHeader PH WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON PH.ExternOrderKey = O.LoadKey
         WHERE O.StorerKey = @cStorerKey
         AND   O.OrderKey = @cTemp_OrderKey
         AND   PH.Status = '0'
      END

      -- Not in wave, not in load then check 4 discrete pickslip
      IF ISNULL(@cPickSlipNo, '') = ''
      BEGIN
         SELECT @cPickSlipNo = PickHeaderKey
         FROM dbo.PickHeader PH WITH (NOLOCK)
         WHERE PH.OrderKey = @cTemp_OrderKey
            AND PH.Status = '0'
      END

      IF ISNULL(@cPickSlipNo, '') = ''
      BEGIN
         SET @nErrNo = 69358
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'PKSLIPNOTPRINT'
         GOTO RollBackTran  
      END

      INSERT INTO RDT.RDTPickLock
      (WaveKey, LoadKey, Orderkey, OrderLineNumber, StorerKey, PutAwayZone, PickZone, PickDetailKey
      , LOT, LOC, Status, AddWho, AddDate, PickSlipNo, Mobile)
      SELECT UserDefine09,
               LoadKey,
               OrderKey,
               '',
               StorerKey,
               @cPutAwayZone AS PutAwayZone,
               @cPickZone AS PickZone,
               '' AS PickDetailKey,
               '' AS LOT,
               '' AS LOC,
               '1' AS Status,
               @cUserName AS AddWho,
               GETDATE() AS AddWho,
               @cPickSlipNo AS PickSlipNo,
               @nMobile as Mobile
      FROM dbo.Orders WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND OrderKey = @cTemp_OrderKey

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 69357
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'LockOrdersFail'
         GOTO RollBackTran  
      END

      FETCH NEXT FROM CUR_INS INTO @cTemp_OrderKey
   END
   CLOSE CUR_INS
   DEALLOCATE CUR_INS

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_AutoInsOrdSP01

   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  


GO