SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispMoveDropIDChk525                                 */
/* Copyright: IDS                                                       */
/* Purpose: DropID Validation                                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Author    Ver.  Purposes                                */
/* 2014-12-18   ChewKP    1.0   SOS#32678                               */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispMoveDropIDChk525]
   @cLangCode    NVARCHAR( 3), 
   @cFromDropID  NVARCHAR( 20), 
   @cToDropID    NVARCHAR( 20), 
   @cChildID     NVARCHAR( 20), 
   @nErrNo       INT  OUTPUT, 
   @cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @nErrNo = 0
   SET @cErrMsg = 0
   
   DECLARE @cFromPickSlipNo   NVARCHAR( 10)
          ,@cToPickSlipNo     NVARCHAR( 10)
          ,@cStorerKey        NVARCHAR( 15) 
   
   SET @cStorerKey = 'UNI'
   
   SET @cToPickSlipNo   = ''
   SET @cFromPickSlipNo = ''
   
   IF LEFT(ISNULL(RTRIM(@cFromDropID),'') ,1) <> 'T'
   BEGIN
      SET @nErrNo = 51402
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidFromTote
      GOTO QUIT
   END
   
   IF LEFT(ISNULL(RTRIM(@cToDropID),'') ,1) <> 'T'
   BEGIN
      SET @nErrNo = 51403
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidToTote
      GOTO QUIT
   END
   
   IF NOT EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                   WHERE DropID = @cFromDropID
                   AND Status = '9' ) 
   BEGIN
      SET @nErrNo = 51404
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --FromToteNotClose
      GOTO QUIT
   END   
   
   IF NOT EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                   WHERE DropID = @cToDropID
                   AND Status = '9' ) 
   BEGIN
      SET @nErrNo = 51405
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ToToteNotClose
      GOTO QUIT
   END                     
   
   
   SELECT TOP 1
         @cFromPickSlipNo = PickslipNo
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND DropID = @cFromDropID
   ORDER BY PickSlipNo Desc
   
   SELECT TOP 1
         @cToPickSlipNo = PickslipNo
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND DropID = @cToDropID
   ORDER BY PickSlipNo Desc
   
   
   
   IF ISNULL(RTRIM(@cFromPickSlipNo),'')  <> ISNULL(RTRIM(@cToPickSlipNo),'') 
   BEGIN
      SET @nErrNo = 51401
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NotSameOrder
      GOTO QUIT
   END
   
   QUIT:
   
END

GO