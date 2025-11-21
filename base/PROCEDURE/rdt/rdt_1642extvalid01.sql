SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1642ExtValid01                                  */
/* Purpose: If rdt config AllowPartialScanToDoor is turned on and       */
/*          orders is partially picked, return true else false          */
/*          If rdt config ScanToDoorCloseTruck is turned on then check  */
/*          whether all pallet for this mbol has been scanned to door   */
/*                                                                      */
/* Called from: rdtfnc_Scan_To_Door                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2015-02-09 1.0  James      SOS316783 - Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_1642ExtValid01] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cDropID          NVARCHAR( 20), 
   @cMbolKey         NVARCHAR( 10), 
   @cDoor            NVARCHAR( 20), 
   @cOption          NVARCHAR( 1), 
   @cRSNCode         NVARCHAR( 10), 
   @nAfterStep       INT, 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

   DECLARE @cAllowPartialScanToDoor    NVARCHAR( 1), 
           @nCloseTruck                INT, 
           @cStorerKey                 NVARCHAR( 15), 
           @cOrderKey                  NVARCHAR( 10), 
           @cErrMsg1                   NVARCHAR( 20), 
           @cErrMsg2                   NVARCHAR( 20), 
           @cErrMsg3                   NVARCHAR( 20), 
           @cErrMsg4                   NVARCHAR( 20), 
           @cErrMsg5                   NVARCHAR( 20), 
           @cFacility                  NVARCHAR( 5), 
           @cID                        NVARCHAR( 18), 
           @cMBOL4DropID               NVARCHAR( 10) 


   SET @nErrNo = 0

   SELECT @cStorerKey = StorerKey, @cFacility = Facility 
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE MOBILE = @nMobile

   IF @nInputKey = 1 
   BEGIN
      SELECT TOP 1 @cOrderKey = OrderKey 
      FROM dbo.PickDetail WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   DropID = @cDropID
      AND   [Status] < '9'

      IF ISNULL(@cOrderKey, '') = ''
      BEGIN
         SET @nErrNo = 92901   
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No Order Found
         GOTO Quit
      END

      -- Get the mbolkey for this particular dropid
      SELECT @cMBOL4DropID = MbolKey 
      FROM dbo.MBOLDetail WITH (NOLOCK) 
      WHERE OrderKey = @cOrderKey

      IF @nStep = 1
      BEGIN
         -- Every dropid must have assocaited mbol created. Prompt error if mbol not created
         IF ISNULL( @cMBOL4DropID, '') = ''
         BEGIN
            SET @nErrNo = 92902   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No mbol create 
            GOTO Quit
         END

         IF rdt.RDTGetConfig( @nFunc, 'ScanToDoorCloseTruck', @cStorerkey) <> '1'
         BEGIN
            SET @nErrNo = 92910   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not allow scan 
            GOTO Quit
         END

         SET @cAllowPartialScanToDoor = rdt.RDTGetConfig( @nFunc, 'AllowPartialScanToDoor', @cStorerKey) 
         IF ISNULL( @cAllowPartialScanToDoor, '') IN ('', '0')
            SET @cAllowPartialScanToDoor = 0

         IF @cAllowPartialScanToDoor = 0
         BEGIN
            -- Check if any orders is not picked or partially picked 
            IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey
                        AND   OrderKey = @cOrderKey
                        AND   [Status] < '5')
            BEGIN
               SET @nErrNo = 92903   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Partial Picked
               GOTO Quit
            END

            -- Check if any orders is not picked or partially picked 
            IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                        WHERE StorerKey = @cStorerKey
                        AND   OrderKey = @cOrderKey
                        AND  [Status] = '5'
                        AND   ISNULL( DropID, '') = '')
            BEGIN
               SET @nErrNo = 92911   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PLT NOT ALL PA
               GOTO Quit
            END
         END

         IF EXISTS ( SELECT 1 
                     FROM dbo.PickDetail WITH (NOLOCK) 
                     WHERE StorerKey = @cStorerKey 
                     AND   DropID = @cDropID 
                     AND  [Status] = '0')
         BEGIN
            SET @nErrNo = 92904   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Plt Not Pick
            GOTO Quit
         END

         SELECT @cID = ISNULL( ID, '') FROM dbo.PickDetail WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey 
         AND   DropID = @cDropID 
         AND  [Status] = '5'

         -- Check if DropID (pallet for merlion) has any qty not picked on pallet
         -- Return error if something not picked and cannot scan to door
         IF @cID <> ''
         BEGIN
            IF EXISTS ( SELECT 1 
                        FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
                        JOIN dbo.LOC LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
                        WHERE LOC.Facility = @cFacility
                        AND   LLI.ID = @cID
                        GROUP BY LLI.ID
                        HAVING ISNULL( SUM( LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked), 0) > 0)
            BEGIN
               SET @nErrNo = 92905   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pl has avl qty
               GOTO Quit
            END
         END
      END

      IF @nStep = 2
      BEGIN
         -- Make sure the door scanned is the same with mbol.placeofloading that dropid belong
         IF NOT EXISTS ( SELECT 1 from dbo.MBOL WITH (NOLOCK) 
                         WHERE MbolKey = @cMBOL4DropID 
                         AND PlaceOfLoading = @cDoor)
         BEGIN
            SET @nErrNo = 92909   
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Door
            GOTO Quit
         END
      END

      IF @nStep = 5
      BEGIN
         IF @cOption = '2'
            GOTO Quit

         SET @nCloseTruck = 0

         -- Check if any pallet in the mbol not yet scanned to door
         IF EXISTS ( SELECT 1 FROM dbo.DropID D WITH (NOLOCK) 
                     WHERE DropID = @cDropID
                     AND   ISNULL( DropLoc, '') = '' --OR DropLoc <> 'STAGING')
                     AND   [Status] < '9'
                     AND   EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                                    JOIN dbo.MBOLDetail MD WITH (NOLOCK) ON PD.OrderKey = MD.OrderKey
                                    WHERE D.DropID = PD.DropID
                                    AND   PD.StorerKey = @cStorerKey
                                    AND   MD.MBOLKey = @cMbolKey))
            SET @nCloseTruck = 0
         ELSE
            SET @nCloseTruck = 1

         IF @nCloseTruck = 0
         BEGIN
            SET @nErrNo = 92906
            SET @cErrMsg1 = SUBSTRING( rdt.rdtgetmessage( 92906, @cLangCode, 'DSP'), 7, 20) -- There are pallets
            SET @cErrMsg2 = SUBSTRING( rdt.rdtgetmessage( 92907, @cLangCode, 'DSP'), 7, 20) -- not scan to doors.
            SET @cErrMsg3 = SUBSTRING( rdt.rdtgetmessage( 92908, @cLangCode, 'DSP'), 7, 20) -- Cannot close.
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
            GOTO Quit
         END

      END
   END


QUIT:

GO