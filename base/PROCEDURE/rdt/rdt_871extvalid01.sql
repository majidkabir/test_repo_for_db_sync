SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_871ExtValid01                                         */
/* Purpose: Validate BOM Serial No                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2017-Sep-13 1.0  James    WMS2954 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_871ExtValid01] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR(3),
   @nStep        INT,
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR(15),
   @cSerialNo    NVARCHAR(50),
   @cOption      NVARCHAR(1),
   @nErrNo       INT          OUTPUT,
   @cErrMsg      NVARCHAR(20) OUTPUT
)
AS

   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @cNewSerialNo   NVARCHAR( 30)

   IF @nStep = 1 -- Search Criteria
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF ISNULL( @cSerialNo, '') = '' 
         BEGIN
            SET @nErrNo = 114851
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SerialNo
            GOTO Quit
         END 
         
         SET @cNewSerialNo = RIGHT( @cSerialNo, 10)

         IF RIGHT( RTRIM( @cSerialNo), 1) IN ( 'B', 'C')
         BEGIN
            IF NOT EXISTS ( 
                  SELECT 1 
                  FROM dbo.MasterSerialNo WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND   ParentSerialNo = @cNewSerialNo
                  AND   UnitType='BUNDLEPCS' )
            BEGIN
               SET @nErrNo = 114852
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not BOM SrNo
               GOTO Quit
            END

            IF NOT EXISTS ( 
                  SELECT 1 
                  FROM dbo.MasterSerialNo MS WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND   ParentSerialNo = @cNewSerialNo
                  AND   UnitType='BUNDLEPCS'
                  AND   EXISTS ( SELECT 1
                                 FROM dbo.SerialNo CS WITH (NOLOCK) 
                                 WHERE MS.SerialNo = CS.SerialNo 
                                 AND   MS.StorerKey = CS.StorerKey))
            BEGIN
               SET @nErrNo = 114853
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Child SrNo
               GOTO Quit      
            END
         END
         ELSE
         BEGIN
            IF NOT EXISTS (
               SELECT 1 FROM dbo.SERIALNO WITH (NOLOCK) 
               WHERE SERIALNO = @cNewSerialNo 
                  AND STORERKEY = @cStorerKey)
            BEGIN
               SET @nErrNo = 114854
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid serialno
               GOTO Quit      
            END
         END
      END
   END

   Quit:



GO