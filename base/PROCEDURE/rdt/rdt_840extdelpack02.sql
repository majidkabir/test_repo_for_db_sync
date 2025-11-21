SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_840ExtDelPack02                                 */
/* Purpose: Clear pickdetail.caseid for M&M Korea                       */
/*          Clear carton track data                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2016-06-10 1.0  James      SOS368195. Created                        */
/* 2021-04-16 1.1  James      WMS-16024 Standarized use of TrackingNo   */
/*                            (james01)                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtDelPack02] (
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
           @cPickDetailKey NVARCHAR( 10), 
           @cCaseID        NVARCHAR( 20), 
           @cUserDefine04  NVARCHAR( 20) 

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_840ExtDelPack02

   IF NOT EXISTS ( SELECT 1 
                   FROM dbo.PickDetail WITH (NOLOCK) 
                   WHERE StorerKey = @cStorerKey
                   AND   OrderKey = @cOrderKey)
   BEGIN
      SET @nErrNo = 1
      GOTO Quit
   END

   -- Get the original assigned tracking no
   --SELECT @cUserDefine04 = UserDefine04
   SELECT @cUserDefine04 = TrackingNo
   FROM dbo.Orders WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey

   DECLARE CUR_UPD CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT PickDetailKey, CaseID
   FROM dbo.PickDetail WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND   OrderKey = @cOrderKey
   AND   ISNULL( CaseID, '') <> ''
   OPEN CUR_UPD
   FETCH NEXT FROM CUR_UPD INTO @cPickDetailKey, @cCaseID
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- Clear carton track data
      UPDATE dbo.CartonTrack WITH (ROWLOCK) SET 
         LabelNo = '', 
         CarrierRef2 = ''
      WHERE TrackingNo = @cCaseID
      AND   LabelNo = @cOrderKey
      AND   KeyName = 'HM'
      AND   CarrierRef2 = 'GET'
      AND   TrackingNo <> @cUserDefine04  -- do not clear original reserved tracking no

      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 101351
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd ctntrk fail
         CLOSE CUR_UPD
         DEALLOCATE CUR_UPD         
         GOTO RollBackTran
      END  

      UPDATE dbo.PickDetail WITH (ROWLOCK) SET 
         CaseID = '',
         TrafficCop = NULL
      WHERE PickDetailKey = @cPickDetailKey

      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 101352
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Clr case fail
         CLOSE CUR_UPD
         DEALLOCATE CUR_UPD         
         GOTO RollBackTran
      END   

      FETCH NEXT FROM CUR_UPD INTO @cPickDetailKey, @cCaseID
   END
   CLOSE CUR_UPD
   DEALLOCATE CUR_UPD
 
   GOTO Quit
   
   RollBackTran:  
         ROLLBACK TRAN rdt_840ExtDelPack02  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN rdt_840ExtDelPack02

GO