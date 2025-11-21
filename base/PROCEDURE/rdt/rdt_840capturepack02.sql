SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_840CapturePack02                                */
/* Purpose: If sales order then disable capture pack info               */
/*          If move orders then enable capture pack info                */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2020-04-01  1.0  James      WMS-12757. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_840CapturePack02] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cStorerkey       NVARCHAR( 15),
   @cOrderKey        NVARCHAR( 10),
   @cPickSlipNo      NVARCHAR( 10),
   @cTrackNo         NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nCartonNo        INT,
   @cCapturePackInfo NVARCHAR( 10) OUTPUT, 
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT 
)
AS

   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   IF @nStep = 3
   BEGIN
      IF @nInputKey IN ( 1, 0)
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK)
                     JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.[Type] AND C.StorerKey = O.StorerKey)  
                     WHERE C.ListName = 'HMORDTYPE'
                     AND   C.UDF01 = 'M'
                     AND   O.OrderKey = @cOrderkey
                     AND   O.StorerKey = @cStorerKey)
            SET @cCapturePackInfo = '1'
         ELSE
            SET @cCapturePackInfo = ''
      END
   END

   GOTO Quit

   Quit:

GO