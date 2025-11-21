SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_848ExtUpd01                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 29-Jun-2017 1.0  James       WMS2297. Created                        */
/* 11-dec-2022 1.1 YeeKung    WMS-21260 Add palletid/taskdetail         */
/*                            (yeekung02)                               */
/************************************************************************/

CREATE   PROC [RDT].[rdt_848ExtUpd01] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cRefNo       NVARCHAR( 10),
   @cPickSlipNo  NVARCHAR( 10),
   @cLoadKey     NVARCHAR( 10),
   @cOrderKey    NVARCHAR( 10),
   @cDropID      NVARCHAR( 20),
   @cID          NVARCHAR( 18), 
   @cTaskdetailKey NVARCHAR( 10),
   @cSKU         NVARCHAR( 20),
   @cOption      NVARCHAR( 1),
   @nErrNo       INT OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount	      INT,
           @cCartonNo         NVARCHAR( 10),
           @cLabelNo          NVARCHAR( 20),
           @cLabelLine        NVARCHAR( 5),
           @nCartonNo         INT

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_848ExtUpd01 -- For rollback or commit only our own transaction

   IF @nFunc = 848
   BEGIN
      IF @nStep = 4
      BEGIN
         -- Get Orders info
         SELECT TOP 1 @cPickSlipNo = PickSlipNo
         FROM dbo.PickDetail WITH (NOLOCK)
         WHERE CaseID = @cDropID
         AND   StorerKey = @cStorerKey

         IF ISNULL( @cPickSlipNo, '') = ''
         BEGIN
            SET @nErrNo = 111801
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Pickslip
            GOTO RollBackTran
         END

         -- Only allow delete packdetail if packheader.status = '0' (not pack confirm)
         IF EXISTS ( SELECT 1 FROM PackHeader WITH (NOLOCK)
                     WHERE PickSlipNo = @cPickSlipNo
                     AND   [Status] = '0')
         BEGIN
            DECLARE CUR_DELPACKD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT CartonNo, LabelLine
            FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
            AND   LabelNo = @cDropID
            AND   (( @cSKU = '') OR ( SKU = @cSKU))
            OPEN CUR_DELPACKD
            FETCH NEXT FROM CUR_DELPACKD INTO @cCartonNo, @cLabelLine
            WHILE @@FETCH_STATUS <> -1
            BEGIN
               DELETE FROM dbo.PackDetail
               WHERE PickSlipNo = @cPickSlipNo
               AND   CartonNo = @cCartonNo
               AND   LabelNo = @cDropID
               AND   LabelLine = @cLabelLine

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 111802
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Del PackD Fail
                  CLOSE CUR_DELPACKD
                  DEALLOCATE CUR_DELPACKD
                  GOTO RollBackTran
               END

               FETCH NEXT FROM CUR_DELPACKD INTO @cCartonNo, @cLabelLine
            END
            CLOSE CUR_DELPACKD
            DEALLOCATE CUR_DELPACKD
         END
      END
   END

   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_848ExtUpd01
   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
END

GO