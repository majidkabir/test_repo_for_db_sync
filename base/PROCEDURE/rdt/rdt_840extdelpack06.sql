SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtDelPack06                                 */
/* Purpose: Clear pickdetail.DropID for H&M IN only                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2022-07-22 1.0  James      WMS-20201. Created                        */
/************************************************************************/

CREATE   PROC [RDT].[rdt_840ExtDelPack06] (
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @nStep       INT, 
   @nInputKey   INT, 
   @cStorerkey  NVARCHAR( 15), 
   @cOrderKey   NVARCHAR( 10), 
   @cPickSlipNo NVARCHAR( 10), 
   @cTrackNo    NVARCHAR( 20), 
   @cSKU        NVARCHAR( 20), 
   @nCartonNo   INT,
   @cOption     NVARCHAR( 1), 
   @nErrNo      INT           OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @nErrNo = 0
   
   DECLARE @nTranCount     INT, 
           @cPickDetailKey NVARCHAR( 10)
   
   DECLARE @curUpd CURSOR
   
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_840ExtDelPack06

   SET @curUpd = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT PickDetailKey
   FROM dbo.PickDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey
   AND   ISNULL( DropID, '') <> ''
   OPEN @curUpd
   FETCH NEXT FROM @curUpd INTO @cPickDetailKey
   WHILE @@FETCH_STATUS = 0
   BEGIN
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
         DropID = '',
         EditWho = SUSER_SNAME(),
         EditDate = GETDATE()
      WHERE PickDetailKey = @cPickDetailKey

      IF @@ERROR <> 0    
         GOTO RollBackTran

      FETCH NEXT FROM @curUpd INTO @cPickDetailKey
   END
 
   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_840ExtDelPack06  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN rdt_840ExtDelPack06

GO