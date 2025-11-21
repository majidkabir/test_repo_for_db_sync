SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_832ExtValid02                                   */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2023-01-30  1.0  Ung         WMS-21570 Created                       */
/************************************************************************/

CREATE   PROC [RDT].[rdt_832ExtValid02] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @tExtVal        VariableTable READONLY,
   @cDoc1Value     NVARCHAR( 20),
   @cCartonID      NVARCHAR( 20),
   @cCartonSKU     NVARCHAR( 20),
   @nCartonQTY     INT,
   @cPackInfo      NVARCHAR( 4),
   @cCartonType    NVARCHAR( 10),
   @cCube          NVARCHAR( 10),
   @cWeight        NVARCHAR( 10),
   @cPackInfoRefNo NVARCHAR( 20),
   @cPickSlipNo    NVARCHAR( 10),
   @nCartonNo      INT,
   @cLabelNo       NVARCHAR( 20),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 832 -- Carton pack
   BEGIN
      IF @nStep = 1  -- Doc
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check blank
            IF @cDoc1Value = ''
            BEGIN
               SET @nErrNo = 195851
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need site
               GOTO Quit
            END

            -- Check site valid
            IF NOT EXISTS( SELECT TOP 1 1
               FROM dbo.CodelkUp WITH (NOLOCK)
               WHERE ListName = 'ALLSorting'
                  AND StorerKey = @cStorerKey
                  AND Code = @cDoc1Value)
            BEGIN
               SET @nErrNo = 195852
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid site
               GOTO Quit
            END
         END
      END

      IF @nStep = 3  -- Print pack list
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cOption NVARCHAR( 1)
            SELECT @cOption = Value FROM @tExtVal WHERE Variable = '@cOption'
            
            IF @cOption = '1' --Yes
            BEGIN
               DECLARE @cOrderKey NVARCHAR( 10)
               SELECT TOP 1 
                  @cOrderKey = OrderKey 
               FROM dbo.PickDetail WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
                  AND CaseID = @cCartonID
               
               IF EXISTS( SELECT 1 
                  FROM dbo.Orders O WITH (NOLOCK)
                     JOIN dbo.Storer S WITH (NOLOCK) ON (O.ConsigneeKey = S.StorerKey AND S.Type = '2')
                  WHERE O.OrderKey = @cOrderKey
                     AND S.SUSR3 = 'PL')
               BEGIN
                  DECLARE @cMsg1 NVARCHAR(20), @cMsg2 NVARCHAR(20)
                  SET @cMsg1 = rdt.rdtgetmessage( 195853, @cLangCode, 'DSP') --PACKING LIST 
                  SET @cMsg2 = rdt.rdtgetmessage( 195854, @cLangCode, 'DSP') --NOT REQUIRED
                  EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @cMsg1, @cMsg2
                  SET @nErrNo = -1
               END
            END
         END
      END
   END
   
Quit:

END

GO