SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1791ExtUpdSP01                                  */  
/* Copyright      : IDS                                                 */  
/*                                                                      */  
/* Purpose: ANF Update DropID Logic                                     */  
/*                                                                      */  
/* Modifications log:                                                   */  
/* Date        Rev  Author   Purposes                                   */  
/* 2014-03-24  1.0  ChewKP   Created                                    */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1791ExtUpdSP01] (  
   @nMobile     INT,  
   @nFunc       INT,  
   @cLangCode   NVARCHAR( 3),  
   @cUserName   NVARCHAR( 15),  
   @cFacility   NVARCHAR( 5),  
   @cStorerKey  NVARCHAR( 15),  
   @cDROPID     NVARCHAR( 20),  
   @cToLoc      NVARCHAR( 10), 
   @nErrNo      INT          OUTPUT,  
   @cErrMsg     NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE  @cUCC NVARCHAR(20) 
          , @cDropLoc NVARCHAR(10)
          , @cLoadKey NVARCHAR(10)

   
   SET @nErrNo   = 0  
   SET @cErrMsg  = '' 
   
   SELECT
         @cLoadKey = ISNULL( MAX( PH.LoadKey), '') -- Just to bypass SQL aggregate check
   FROM dbo.DropIDDetail DD WITH (NOLOCK)
         INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON (DD.ChildID = PD.LabelNo)
         INNER JOIN dbo.PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PD.PickSlipNo)
   WHERE DD.DropID = @cDropID
      
     
   UPDATE dbo.DROPID WITH (ROWLOCK)
              SET LabelPrinted = 'Y',
              Status = '9',
              DropLoc = ISNULL(RTRIM(@cToLoc),'') 
   WHERE DropID = @cDropID
   AND Status = '0'
   
   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 86151
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd DROPID Fail'
   	GOTO FAIL
   END
   
--   UPDATE dbo.LoadPlanLaneDetail WITH (ROWLOCK)
--   SET Status = '9'
--   WHERE LoadKey = @cLoadKey 
--   AND Loc = @cToLoc 
--   AND Status = '0'
--   
--   IF @@ERROR <> 0 
--   BEGIN
--      SET @nErrNo = 86152
--      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdLPLaneFail'
--   	GOTO FAIL
--   END
   
   
  
Fail:  
END  

GO