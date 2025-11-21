SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1638ExtVal05                                    */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/*	19-02-2018  1.0  James    WMS3988. Created                           */
/*	13-08-2018  1.1  James    Add NOLOCK                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_1638ExtVal05] (
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

   DECLARE @c_Code      NVARCHAR( 20)
	DECLARE @c_ChkCode   NVARCHAR( 20)
   DECLARE @c_Lot01     NVARCHAR( 20)
	DECLARE @c_ChkLot01  NVARCHAR( 20)

   IF @nFunc = 1638 -- Scan to pallet
   BEGIN
      IF @nStep = 3 -- CaseID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get 1st case on pallet
            IF EXISTS (SELECT 1 FROM dbo.PALLETDETAIL WITH (NOLOCK) WHERE PalletKey=@cPalletKey)
				BEGIN
					SET @c_ChkCode = ''
					SELECT TOP 1 @c_ChkCode = ISNULL(o.M_Address4, ''), @c_ChkLot01 = ISNULL( la.Lottable01, '')
					FROM dbo.PALLETDETAIL pkd WITH (NOLOCK) 
               JOIN dbo.PackDetail pld WITH (NOLOCK) ON pld.LabelNo = pkd.CaseId
					JOIN dbo.PackHeader ph WITH (NOLOCK) ON ph.PickSlipNo = pld.PickSlipNo
					JOIN dbo.ORDERS o WITH (NOLOCK) ON o.LoadKey=ph.LoadKey
               JOIN dbo.PickDetail pdtl WITH (NOLOCK) ON o.OrderKey = pdtl.OrderKey
               JOIN dbo.LotAttribute la WITH (NOLOCK) ON pdtl.Lot = la.Lot
					WHERE PalletKey=@cPalletKey AND pkd.PalletLineNumber='00001'

					IF @c_ChkCode <> ''
					BEGIN
						SET @c_Code = ''       
						SELECT TOP 1 @c_Code = ISNULL(o.M_Address4, ''), @c_Lot01 = ISNULL( la.Lottable01, '')
						FROM dbo.PackDetail pd WITH (NOLOCK) 
                  JOIN dbo.PackHeader ph WITH (NOLOCK) ON ph.PickSlipNo = pd.PickSlipNo
						JOIN dbo.ORDERS o WITH (NOLOCK) ON o.LoadKey = ph.LoadKey
                  JOIN dbo.PickDetail pdtl WITH (NOLOCK) ON o.OrderKey = pdtl.OrderKey
                  JOIN dbo.LotAttribute la WITH (NOLOCK) ON pdtl.Lot = la.Lot
						WHERE pd.LabelNo = @cCaseID

						IF @c_Lot01 <> @c_ChkLot01
						BEGIN
							SET @nErrNo = 127051
							SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff Consignee
							GOTO Quit
						END

                  IF @c_Code <> @c_ChkCode
						BEGIN
							SET @nErrNo = 127052
							SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff BU
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