SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_840ExtDelPack01                                 */
/* Purpose: Clear pickdetail.caseid for M&M JP only                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2016-01-19 1.0  James      SOS#353558. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtDelPack01] (
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

   DECLARE @nTranCount     INT, 
           @cPickDetailKey NVARCHAR( 10)

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_840ExtDelPack01

   IF NOT EXISTS ( SELECT 1 
                   FROM dbo.PickDetail WITH (NOLOCK) 
                   WHERE StorerKey = @cStorerKey
                   AND   OrderKey = @cOrderKey)
   BEGIN
      SET @nErrNo = 1
      GOTO Quit
   END

   DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT PickDetailKey
   FROM dbo.PickDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey
   AND   ISNULL( CaseID, '') <> ''
   OPEN CUR_UPD
   FETCH NEXT FROM CUR_UPD INTO @cPickDetailKey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
         CaseID = '',
         TrafficCop = NULL
      WHERE PickDetailKey = @cPickDetailKey

      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 59201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoLblPrinter
         CLOSE CUR_UPD
         DEALLOCATE CUR_UPD         
         GOTO RollBackTran
      END   

      FETCH NEXT FROM CUR_UPD INTO @cPickDetailKey
   END
   CLOSE CUR_UPD
   DEALLOCATE CUR_UPD
 
   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_840ExtDelPack01  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN rdt_840ExtDelPack01


GO