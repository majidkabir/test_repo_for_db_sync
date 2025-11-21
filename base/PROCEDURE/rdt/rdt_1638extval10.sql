SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1638ExtVal10                                    */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/*	18-09-2020  1.0  Chermaine WMS-15186 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1638ExtVal10] (
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

   DECLARE @cContainerType NVARCHAR(15)
   DECLARE @cChkContainerType NVARCHAR(15)
   DECLARE @cDeliveryDate   DATETIME
   DECLARE @cChkDeliveryDate DATETIME

   IF @nFunc = 1638 -- Scan to pallet
   BEGIN
      IF @nStep = 3 -- CaseID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN				
         	 IF EXISTS (SELECT 1 FROM dbo.PALLETDETAIL WITH (NOLOCK) WHERE PalletKey=@cPalletKey)
				 BEGIN
				 	SET @cChkContainerType = '' 
				   SET @cChkDeliveryDate = ''
				   	
				   SELECT TOP 1 @cChkContainerType = O.ContainerType, @cChkDeliveryDate = O.DeliveryDate
               FROM dbo.PALLETDETAIL PKD WITH (NOLOCK) 
               JOIN dbo.PackDetail PD WITH (NOLOCK) ON (PKD.caseID = PD.LabelNo)
               JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
               JOIN dbo.ORDERS O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey
               WHERE PKD.PalletKey=@cPalletKey AND pkd.PalletLineNumber='00001'
                  
               IF @@ROWCOUNT > 0 
               BEGIN
                  SELECT TOP 1 @cDeliveryDate = O.DeliveryDate , @cContainerType = O.ContainerType
                  FROM dbo.PackDetail PD WITH (NOLOCK) 
                  JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
                  JOIN dbo.ORDERS O WITH (NOLOCK) ON O.OrderKey = PH.OrderKey
                  WHERE PD.LabelNo = @cCaseID
                     
                  IF @cContainerType <> @cChkContainerType 
                  BEGIN
                     SET @nErrNo = 159251
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')--DiffContainer
                     EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
                     GOTO Quit
                  END
                     
                  IF @cDeliveryDate <> @cChkDeliveryDate
                  BEGIN
                     SET @nErrNo = 159252
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')--Diff DelDate
                     EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
                     GOTO Quit
                  END
               END	
				END
			END
		END
	END


Quit:

END

GO