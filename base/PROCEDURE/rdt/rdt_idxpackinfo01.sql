SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Copyright: IDS                                                       */
/* Purpose: Customize Update SP for rdtfnc_PackInfo                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-03-13 1.0  James      SOS#305396                                */
/************************************************************************/

CREATE PROC [RDT].[rdt_IDXPackInfo01] (
   @nMobile     int,
   @nFunc       int,
   @cLangCode   nvarchar(3),
   @cFacility   nvarchar(5),
   @cStorerKey  nvarchar(15),
   @cPickSlipNo nvarchar(10),
   @nErrNo      int  OUTPUT,
   @cErrMsg     nvarchar(1024) OUTPUT -- screen limitation, 20 char max
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Misc variable
   DECLARE  @nCartonNo     INT,  
            @nTranCount    INT

   SELECT @nCartonNo = CAST( V_String4 AS INT) 
   FROM rdt.rdtMobRec WITH (NOLOCK) 
   WHERE Mobile = @nMobile
   
   IF ISNULL( @nCartonNo, 0) = 0
   BEGIN
      SET @nErrNo = 85801
      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'NO CARTON NO'
      GOTO Quit_Without_Tran
   END
   
   IF NOT EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) 
                   WHERE PickSlipNo = @cPickSlipNo
                   AND   CartonNo = @nCartonNo)
   BEGIN
      SET @nErrNo = 85802
      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'NO PACKINFO'
      GOTO Quit_Without_Tran
   END

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN PackInfo_Tran
     
   UPDATE dbo.PackInfo WITH (ROWLOCK) SET 
      WEIGHT = CAST( (WEIGHT * 1000) AS INT)
   WHERE PickSlipNo = @cPickSlipNo
   AND   CartonNo = @nCartonNo

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 85803
      SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') --'UPD WEIGHT ERR'
      GOTO RollBackTran
   END

   GOTO QUIT

   RollBackTran:
   ROLLBACK TRAN PackInfo_Tran

   Quit:  
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
         COMMIT TRAN PackInfo_Tran

   Quit_Without_Tran:  

END

GO