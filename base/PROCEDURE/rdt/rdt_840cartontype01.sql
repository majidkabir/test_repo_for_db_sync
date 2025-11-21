SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_840CartonType01                                 */
/* Purpose: If sales order then disable carton type input               */
/*          If move orders then default carton type on screen           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2017-07-25  1.0  James      WMS-3212. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_840CartonType01] (
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
   @cCtnType         NVARCHAR( 10)  OUTPUT, 
   @cCtnTypeEnabled  NVARCHAR( 1)   OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cDefaultCartonType   NVARCHAR( 10)

   SET @cCtnType = ''
   SET @cCtnTypeEnabled = ''

   IF @nStep = 3
   BEGIN
      -- If it is Sales type order then no need input carton type
      IF EXISTS ( SELECT 1 FROM dbo.CODELKUP C WITH (NOLOCK) 
                  JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)
                  WHERE C.ListName = 'HMORDTYPE'
                  AND   C.Short = 'S'
                  AND   O.OrderKey = @cOrderkey
                  AND   O.StorerKey = @cStorerKey)
      BEGIN
         SET @cCtnType = ''
         SET @cCtnTypeEnabled = 'O'
      END
      ELSE
      BEGIN
         SET @cDefaultCartonType = rdt.RDTGetConfig( @nFunc, 'DefaultCartonType', @cStorerKey)
         IF @cDefaultCartonType IN ('', '0')
            SET @cCtnType = ''
         ELSE
            SET @cCtnType = @cDefaultCartonType

         SET @cCtnTypeEnabled = ''
      END
   END

   GOTO Quit

   Quit:

GO