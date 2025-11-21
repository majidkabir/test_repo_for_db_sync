SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1638ExtVal08                                          */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 03-06-2020  1.0  Ung      WMS-13588 Created                                */
/* 21-07-2020  1.1  Ung      WMS-14235 Change order consignee, storer mapping */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1638ExtVal08] (
   @nMobile      INT,           
   @nFunc        INT,           
   @nStep        INT,
   @nInputKey    INT,           
   @cLangCode    NVARCHAR( 3),  
   @cFacility    NVARCHAR( 5),  
   @cStorerkey   NVARCHAR( 15), 
   @cPalletKey   NVARCHAR( 30), 
   @cCartonType  NVARCHAR( 10), 
   @cCaseID      NVARCHAR( 20), 
   @cLOC         NVARCHAR( 10), 
   @cSKU         NVARCHAR( 20), 
   @nQTY         INT,            
   @cLength      NVARCHAR(5),    
   @cWidth       NVARCHAR(5),    
   @cHeight      NVARCHAR(5),    
   @cGrossWeight NVARCHAR(5),    
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT 
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 1638 -- Scan to pallet
   BEGIN
      IF @nStep = 3 -- CaseID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            /***************************** New carton on pallet ***************************/
            DECLARE @cConsigneeKey     NVARCHAR(15) = ''
            DECLARE @cHubCode          NVARCHAR(45) = ''                              

            -- Get Order info
            SELECT @cConsigneeKey = LEFT( @cCaseID, 7)
            
            -- Remove leading zero
            WHILE LEFT( @cConsigneeKey, 1) = '0'
               SET @cConsigneeKey = SUBSTRING( @cConsigneeKey, 2, LEN( @cConsigneeKey))

            -- Get current hub code
            SELECT @cHubCode = ISNULL( B_City, '') 
            FROM Storer WITH (NOLOCK) 
            WHERE SUBSTRING( StorerKey, 4, 15) = @cConsigneeKey 
               AND Type = '2'
               AND ConsigneeFor = @cStorerKey

            -- Check no hub code
            IF @cHubCode = ''  
            BEGIN
               SET @nErrNo = 153251
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --HubCode needed
            END

            -- Get 1st carton on pallet
            DECLARE @cSuggCaseID NVARCHAR( 20)
            SET @cSuggCaseID = ''
            SELECT TOP 1 
               @cSuggCaseID = CaseID
            FROM dbo.PalletDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey 
               AND PalletKey = @cPalletKey
            ORDER BY PalletLineNumber

            /**************************** Existing carton on pallet ***********************/
            IF @cSuggCaseID <> ''
            BEGIN
               DECLARE @cSuggConsigneeKey NVARCHAR(15) = ''
               DECLARE @cSuggHubCode      NVARCHAR(45) = ''

               -- Get order info
               SELECT @cSuggConsigneeKey = LEFT( @cSuggCaseID, 7)
               
               -- Remove leading zero
               WHILE LEFT( @cSuggConsigneeKey, 1) = '0'
                  SET @cSuggConsigneeKey = SUBSTRING( @cSuggConsigneeKey, 2, LEN( @cSuggConsigneeKey))

               -- Get current hub code
               SELECT @cSuggHubCode = ISNULL( B_City, '') 
               FROM Storer WITH (NOLOCK) 
               WHERE SUBSTRING( StorerKey, 4, 15) = @cSuggConsigneeKey 
                  AND Type = '2'
                  AND ConsigneeFor = @cStorerKey

               -- Check different hub code
               IF @cSuggHubCode <> @cHubCode
               BEGIN
                  SET @nErrNo = 153252
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff Hub Code
               END
            END
         END
      END
   END
END

GO