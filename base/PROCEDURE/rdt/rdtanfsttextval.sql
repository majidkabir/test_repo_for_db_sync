SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtANFSTTExtVal                                     */
/* Purpose: Validate LabelNo in MBOL                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2014-05-25 1.0  Chee       SOS#309892 Created                        */
/* 2017-02-27 1.1  TLTING     variable Nvarchar                         */
/************************************************************************/

CREATE PROC [RDT].[rdtANFSTTExtVal] (
   @nMobile     INT,
   @nFunc       INT, 
   @cLangCode   NVARCHAR( 3), 
   @nStep       INT, 
   @cStorerKey  NVARCHAR( 15), 
   @cType       NVARCHAR( 1),
   @cMBOLKey    NVARCHAR( 10),
   @cLoadKey    NVARCHAR( 10),
   @cOrderKey   NVARCHAR( 10), 
   @cLabelNo    NVARCHAR( 20),
   @nErrNo      INT       OUTPUT, 
   @cErrMsg     NVARCHAR( 20) OUTPUT, 
   @cPackInfo   NVARCHAR( 3)  = '',
   @cWeight     NVARCHAR( 10) = '',  
   @cCube       NVARCHAR( 10) = '',  
   @cCartonType NVARCHAR( 10) = ''
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

DECLARE @cOrderType NVARCHAR(10)

IF @nFunc = 922
BEGIN
   IF @nStep = 2
   BEGIN
      SELECT @cOrderType = [Type]
      FROM Orders O WITH (NOLOCK)
      WHERE MBOLKey = @cMBOLKey

      IF @cOrderType <> 'CHDORD'
         RETURN

      IF NOT EXISTS(SELECT 1 FROM DropID D (NOLOCK)
                    JOIN DropIDDetail DD (NOLOCK) on (D.DropID = DD.DropID)
                    WHERE DD.UserDefine01 = @cMBOLKey
                      AND DD.ChildID = @cLabelNo)
      BEGIN
         SET @nErrNo = 87151
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- InvalidLabelNo
         GOTO Quit
      END
   END -- IF @nStep = 2
END -- IF @nFunc = 922

Quit:

GO