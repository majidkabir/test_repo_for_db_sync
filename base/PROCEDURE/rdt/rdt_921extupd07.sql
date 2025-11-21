SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_921ExtUpd07                                     */
/* Purpose: Pack confirm                                                */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2024-08-06 1.0  JHU151    FCR-631 Created                            */
/************************************************************************/
CREATE   PROC [RDT].[rdt_921ExtUpd07] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cDropID        NVARCHAR( 20),
   @cLabelNo       NVARCHAR( 20),
   @cOrderKey      NVARCHAR( 10),
   @cCartonNo      NVARCHAR( 5),
   @cPickSlipNo    NVARCHAR( 10),
   @cCartonType    NVARCHAR( 10),
   @cCube          NVARCHAR( 20),
   @cWeight        NVARCHAR( 20),
   @cLength        NVARCHAR( 20),
   @cWidth         NVARCHAR( 20),
   @cHeight        NVARCHAR( 20),
   @cRefNo         NVARCHAR( 20),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @nTranCount  INT
SET @nTranCount = @@TRANCOUNT


-- Handling transaction
BEGIN TRAN  -- Begin our own transaction
SAVE TRAN rdt_921ExtUpd07 -- For rollback or commit only our own transaction


IF @nFunc = 921 -- Capture PackInfo
BEGIN
   IF @nStep = 2 -- Packinfo
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         DECLARE @cPackConfirm       NVARCHAR(1)         
         DECLARE @npickedQty     INT = 0
         DECLARE @nPackedQty     INT = 0

         SET @cPackConfirm = rdt.RDTGetConfig( @nFunc, 'PackConfirm', @cStorerKey)

         IF @cPackConfirm = '1'
         BEGIN


            -- Check pack confirm already
            IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND storerkey = @cStorerkey AND Status = '9')
               GOTO Quit

            SELECT TOP 1 @cOrderKey = orderkey
			FROM PackHeader WIHT(NOLOCK)
			WHERE PickSlipNo = @cPickSlipNo AND storerkey = @cStorerkey

            SELECT @npickedQty = SUM(qty) FROM PickDetail WITH(NOLOCK) 
            WHERE orderkey = @cOrderKey 
            AND Storerkey = @cStorerKey
            AND status = '5'

            SELECT @nPackedQty = SUM(qty) 
			FROM PackDetail pd WITH(NOLOCK) 
			INNER JOIN PackHeader ph WITH(NOLOCK) 
			ON pd.pickslipno = ph.pickslipno 
			WHERE ph.orderkey = @cOrderKey AND ph.Storerkey = @cStorerKey

            -- Pack confirm
            IF @npickedQty = @nPackedQty
            BEGIN
               -- Pack confirm
               UPDATE PackHeader SET
                  Status = '9'
               WHERE PickSlipNo = @cPickSlipNo
                  AND Status <> '9'
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 221001
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PackCfm Fail
                  GOTO RollBackTran
               END            
            END
         END
         COMMIT TRAN rdt_921ExtUpd07
         GOTO Quit
      END
   END
END
GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_921ExtUpd07 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

GO