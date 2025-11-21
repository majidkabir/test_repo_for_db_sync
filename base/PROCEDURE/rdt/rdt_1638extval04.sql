SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1638ExtVal04                                    */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/*	19-02-2018  1.0  James    WMS3988. Created                           */
/*	13-08-2018  1.1  James    Add NOLOCK                                 */
/* 16-08-2018  1.2  Ung      Performance tuning                         */
/* 23-07-2019  1.3  James    WMS9882-Add Markforkey checking (james01)  */
/************************************************************************/

CREATE PROC [RDT].[rdt_1638ExtVal04] (
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

   DECLARE @cSuggMarkforKey   NVARCHAR( 15)
   DECLARE @cMarkforKey       NVARCHAR( 15)

   IF @nFunc = 1638 -- Scan to pallet
   BEGIN
      IF @nStep = 3 -- CaseID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get 1st case on pallet
            DECLARE @cSuggCaseID NVARCHAR( 20)
            SET @cSuggCaseID = ''
            SELECT TOP 1 
               @cSuggCaseID = CaseID
            FROM dbo.PalletDetail WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey 
               AND PalletKey = @cPalletKey
            ORDER BY PalletLineNumber

            IF @cSuggCaseID <> ''
            BEGIN
               DECLARE @cSuggConsigneeKey NVARCHAR(15)
               DECLARE @cSuggPriority     NVARCHAR(10)
               DECLARE @cSuggBuyerPO      NVARCHAR(20)
               DECLARE @cSuggLottable01   NVARCHAR(18)

               DECLARE @cConsigneeKey     NVARCHAR(15)
               DECLARE @cPriority         NVARCHAR(10)
               DECLARE @cBuyerPO          NVARCHAR(20)
               DECLARE @cLottable01       NVARCHAR(18)

               -- Get 1st case info
               SET @cSuggConsigneeKey = ''
               SET @cSuggPriority = '' 
               SET @cSuggBuyerPO = ''
               SET @cSuggLottable01 = ''
               SELECT TOP 1 
                  @cSuggConsigneeKey = O.ConsigneeKey, 
                  @cSuggPriority = O.Priority, 
                  @cSuggBuyerPO = O.BuyerPO, 
                  @cSuggLottable01 = LA.Lottable01,
                  @cSuggMarkforKey = O.MarkforKey
               FROM Orders O WITH (NOLOCK) 
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                  JOIN LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.CaseID = @cSuggCaseID
               
               -- Get case info
               SET @cConsigneeKey = ''
               SET @cPriority = '' 
               SET @cBuyerPO = ''
               SET @cLottable01 = ''
               SELECT TOP 1 
                  @cConsigneeKey = O.ConsigneeKey, 
                  @cPriority = O.Priority, 
                  @cBuyerPO = O.BuyerPO, 
                  @cLottable01 = LA.Lottable01,
                  @cMarkforKey = O.MarkforKey
               FROM Orders O WITH (NOLOCK) 
                  JOIN PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
                  JOIN LOTAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
               WHERE PD.StorerKey = @cStorerKey
                  AND PD.CaseID = @cCaseID

               IF @cPriority = 'HUB'
               BEGIN
                  IF EXISTS( SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK) WHERE StorerKey = @cStorerkey AND ListName = 'CABuyerPO' AND Code = @cConsigneeKey)
                  BEGIN
                     IF (@cSuggConsigneeKey <> @cConsigneeKey) OR
                        (@cBuyerPO <> @cSuggBuyerPO) OR 
                        (@cSuggLottable01 <> @cLottable01 AND @cSuggLottable01 <> '')
						   BEGIN
							   SET @nErrNo = 119651
							   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --DiffShip/PO/BU
							   GOTO Quit
						   END
						END
						ELSE
						BEGIN
                     IF (@cSuggConsigneeKey <> @cConsigneeKey) OR
                        (@cSuggLottable01 <> @cLottable01 AND @cSuggLottable01 <> '')
						   BEGIN
							   SET @nErrNo = 119652
							   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff ShipTo/BU
							   GOTO Quit
						   END
						END
               END
               ELSE IF @cPriority = 'IFC'
               BEGIN
                  IF (@cBuyerPO <> @cSuggBuyerPO) OR 
                     (@cSuggLottable01 <> @cLottable01 AND @cSuggLottable01 <> '')
						BEGIN
							SET @nErrNo = 119653
							SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff PO/BU
							GOTO Quit
						END                        

                  IF @cSuggMarkforKey <> @cMarkforKey
					   BEGIN
						   SET @nErrNo = 119654
						   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff Mark4Key
						   GOTO Quit
					   END
               END
            END
         END
         
/*         
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT @cPriority = '', @cConsigneeKey = '', @cBuyerPO = '', @cLottable01 = ''

            -- Get 1st case info on pallet
            IF EXISTS (SELECT 1 FROM dbo.PALLETDETAIL WITH (NOLOCK) 
                        WHERE PalletKey = @cPalletKey)
				BEGIN
					SELECT TOP 1 
                  @cPriority = ISNULL(O.Priority, ''), 
                  @cConsigneeKey = ISNULL(O.ConsigneeKey, ''), 
                  @cBuyerPO = ISNULL(O.BuyerPO, ''), 
                  @cLottable01 = ISNULL( LA.Lottable01, '')
					FROM dbo.PackDetail PD WITH (NOLOCK) 
               JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
					JOIN dbo.ORDERS O WITH (NOLOCK) ON O.LoadKey = PH.LoadKey
               JOIN dbo.PickDetail PDTL WITH (NOLOCK) ON O.OrderKey = PDTL.OrderKey
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON pdtl.Lot = LA.Lot
					WHERE PD.LabelNo = @cCaseID

               IF @cPriority = 'HUB'
               BEGIN
                  IF EXISTS ( SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) 
                              WHERE StorerKey = @cStorerkey
                              AND   ListName = 'CABuyerPO'
                              AND   Code = @cConsigneeKey)
                  BEGIN
                     IF EXISTS ( SELECT 1 
					         FROM dbo.PALLETDETAIL PKD WITH (NOLOCK) 
                        JOIN dbo.PackDetail PLD WITH (NOLOCK) ON pld.LabelNo = PKD.CaseId
					         JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PLD.PickSlipNo
					         JOIN dbo.ORDERS O WITH (NOLOCK) ON O.LoadKey = PH.LoadKey
                        JOIN dbo.PickDetail PDTL WITH (NOLOCK) ON O.OrderKey = PDTL.OrderKey
                        JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PDTL.Lot = LA.Lot
					         WHERE PalletKey = @cPalletKey
                        AND   ( CAST( O.ConsigneeKey AS NCHAR( 15)) + CAST( O.BuyerPO AS NCHAR( 20)) + CAST( LA.Lottable01 AS NCHAR( 18))) <> 
                              ( CAST( @cConsigneeKey AS NCHAR( 15)) + CAST( @cBuyerPO AS NCHAR( 20)) + CAST( @cLottable01 AS NCHAR( 18))))
						   BEGIN
							   SET @nErrNo = 119651
							   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --DiffShip/PO/BU
							   GOTO Quit
						   END                        
                  END
                  ELSE
                  BEGIN
                     IF EXISTS ( SELECT 1 
					         FROM dbo.PALLETDETAIL PKD WITH (NOLOCK) 
                        JOIN dbo.PackDetail PLD WITH (NOLOCK) ON pld.LabelNo = PKD.CaseId
					         JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PLD.PickSlipNo
					         JOIN dbo.ORDERS O WITH (NOLOCK) ON O.LoadKey = PH.LoadKey
                        JOIN dbo.PickDetail PDTL WITH (NOLOCK) ON O.OrderKey = PDTL.OrderKey
                        JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PDTL.Lot = LA.Lot
					         WHERE PalletKey = @cPalletKey
                        AND   ( CAST( O.ConsigneeKey AS NCHAR( 15)) + CAST( LA.Lottable01 AS NCHAR( 18))) <> 
                              ( CAST( @cConsigneeKey AS NCHAR( 15)) + CAST( @cLottable01 AS NCHAR( 18))))
						   BEGIN
							   SET @nErrNo = 119652
							   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff ShipTo/BU
							   GOTO Quit
						   END                        
                  END
               END   -- @cPriority = 'HUB'
               ELSE IF @cPriority = 'IFC'
               BEGIN
                  IF EXISTS ( SELECT 1 
					      FROM dbo.PALLETDETAIL PKD WITH (NOLOCK) 
                     JOIN dbo.PackDetail PLD WITH (NOLOCK) ON pld.LabelNo = PKD.CaseId
					      JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PLD.PickSlipNo
					      JOIN dbo.ORDERS O WITH (NOLOCK) ON O.LoadKey = PH.LoadKey
                     JOIN dbo.PickDetail PDTL WITH (NOLOCK) ON O.OrderKey = PDTL.OrderKey
                     JOIN dbo.LotAttribute LA WITH (NOLOCK) ON PDTL.Lot = LA.Lot
					      WHERE PalletKey = @cPalletKey
                     AND   ( CAST( O.BuyerPO AS NCHAR( 20)) + CAST( LA.Lottable01 AS NCHAR( 18))) <> 
                           ( CAST( @cBuyerPO AS NCHAR( 20)) + CAST( @cLottable01 AS NCHAR( 18))))
						BEGIN
							SET @nErrNo = 119653
							SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff PO/BU
							GOTO Quit
						END                        
               END   -- @cPriority = 'IFC'
				END
			END
*/
		END
	END


Quit:

END

GO