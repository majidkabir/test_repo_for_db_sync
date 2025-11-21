SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_JACKWExtValid04                                 */
/* Purpose: If the PlaceofLoadingQualifier = 'ECOMM' then return true   */
/*                                                                      */
/* Called from: rdtfnc_Scan_To_Van_MBOL_Creation                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2015-01-27 1.0  James      SOS331117 - Created                       */
/* 2015-02-09 1.1  James      Bug fix (james01)                         */
/* 09-03-2015 1.2  James      SOS335136-Extra sack validation (james01) */
/************************************************************************/

CREATE PROC [RDT].[rdt_JACKWExtValid04] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cMbolKey         NVARCHAR( 10), 
   @cToteNo          NVARCHAR( 20), 
   @cOption          NVARCHAR( 20), 
   @cOrderkey        NVARCHAR( 10), 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

   DECLARE @cPlaceOfLoadingQualifier   NVARCHAR( 10), 
           @cMBOLScanCarrier           NVARCHAR( 20) 

   SELECT @cPlaceOfLoadingQualifier = PlaceOfLoadingQualifier 
   FROM dbo.MBOL WITH (NOLOCK)
   WHERE MbolKey = @cMBOLKey


   IF @nStep = 1 AND @nInputKey = 1
   BEGIN
      SET @cMBOLScanCarrier = rdt.RDTGetConfig( @nFunc, 'MBOLSCANCARRIER', @cStorerKey) 
      IF ISNULL( @cMBOLScanCarrier, '') IN ('', '0')
         SET @cMBOLScanCarrier = 0

      IF @cPlaceOfLoadingQualifier <> 'ECOMM'
      BEGIN
         SET @nErrNo = 0
         GOTO Quit
      END

      IF @cPlaceOfLoadingQualifier = 'ECOMM' AND @cMBOLScanCarrier = '1'
      BEGIN
         SET @nErrNo = 1
         GOTO Quit
      END
      ELSE
         SET @nErrNo = 0
   END
   
   -- (james01)
   IF @nStep = 2 AND @nInputKey = 1
   BEGIN
      IF ISNULL( @cOption, '') = ''
      BEGIN
         IF @cPlaceOfLoadingQualifier = 'ECOMM'
         BEGIN
            SET @nErrNo = 0
            GOTO Quit
         END      
         
         -- Check if a sack is closed. Manifest printed upon close sack
         IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK) 
                     WHERE DropID = @cToteNo
                     AND   ManifestPrinted = 'Y')
            SET @nErrNo = 0
         ELSE
            SET @nErrNo = 93051
      END
      GOTO Quit
   END

QUIT:

GO