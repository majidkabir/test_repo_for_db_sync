SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_1665ExtInfo01                                         */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2018-03-20 1.0  Ung      WMS-4225 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1665ExtInfo01] (
   @nMobile        INT,           
   @nFunc          INT,           
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT,           
   @nAfterStep     INT,           
   @nInputKey      INT,           
   @cFacility      NVARCHAR( 5),   
   @cStorerKey     NVARCHAR( 15), 
   @cPalletKey     NVARCHAR( 20), 
   @cMBOLKey       NVARCHAR( 10), 
   @cTrackNo       NVARCHAR( 20), 
   @cOption        NVARCHAR( 1), 
   @tVar           VariableTable  READONLY, 
   @cExtendedInfo  NVARCHAR( 20)  OUTPUT, 
   @nErrNo         INT            OUTPUT,
   @cErrMsg        NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 1665 -- Pallet track no inquiry
   BEGIN
      IF @nAfterStep = 4 -- Confirm carton?
      BEGIN
         DECLARE @cOrderKey NVARCHAR( 20)
         DECLARE @cReason   NVARCHAR( 20)
         DECLARE @cNotes2   NVARCHAR( 500)
         DECLARE @cSOStatus NVARCHAR( 20)

         SET @cReason = ''
         SET @cNotes2 = ''
         SET @cSOStatus = ''
   
         -- Get tracking no info
         SELECT @cOrderKey = UserDefine01 
         FROM PalletDetail WITH (NOLOCK) 
         WHERE PalletKey = @cPalletKey
            AND CaseID = @cTrackNo
   
         -- Get order info
         SELECT 
            @cNotes2 = ISNULL( OI.Notes2, ''), 
            @cSOStatus = O.SOStatus
         FROM Orders O WITH (NOLOCK)
            LEFT JOIN OrderInfo OI WITH (NOLOCK) ON (O.OrderKey = OI.OrderKey)
         WHERE O.OrderKey = @cOrderKey
   
         -- Get track no status
         IF @cNotes2 <> ''
            SET @cReason = LEFT( @cNotes2, 20)
   
         IF @cReason = ''
            SELECT @cReason = LEFT( Long, 20) 
            FROM CodeLKUP WITH (NOLOCK) 
            WHERE ListName = 'SOSTSBLOCK' 
               AND Code = @cSOStatus 
               AND StorerKey = @cStorerKey 
               AND Code2 = @nFunc

         IF @cReason = ''
            SET @cReason = rdt.rdtgetmessage( 127101, @cLangCode, 'DSP') --ADDRESS CHANGED
   
         -- Format status
         SET @cExtendedInfo = @cReason
      END
   END
END

GO