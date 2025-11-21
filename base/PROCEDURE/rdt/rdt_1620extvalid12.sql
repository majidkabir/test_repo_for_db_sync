SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1620ExtValid12                                  */
/* Purpose: Validate Lottable01 during picking                          */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2023-06-21  1.0  James      WMS-22740. Created                       */
/************************************************************************/

CREATE   PROC [RDT].[rdt_1620ExtValid12] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cStorerkey       NVARCHAR( 15),
   @cWaveKey         NVARCHAR( 10),
   @cLoadKey         NVARCHAR( 10),
   @cOrderKey        NVARCHAR( 10),
   @cLoc             NVARCHAR( 10),
   @cDropID          NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQty             INT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

	SET NOCOUNT ON
	SET QUOTED_IDENTIFIER OFF
	SET ANSI_NULLS OFF
	SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cBarcode       NVARCHAR( 60)  
   DECLARE @cInField04     NVARCHAR( 60)  
   DECLARE @cLottable01    NVARCHAR( 18)
   DECLARE @cUPC           NVARCHAR( 30)
   DECLARE @nDecodeQTY     INT
   DECLARE @bsuccess       INT
   
   SELECT @cInField04 = I_Field04
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   SET @nErrNo = 0
   
   IF @nFunc = 1620  
   BEGIN  
      IF @nStep = 8  
      BEGIN  
         IF @nInputKey = 1  
         BEGIN  
            SET @cBarcode = @cInField04
            
         	IF CHARINDEX( ':', @cBarcode) = 0
         	BEGIN
         		SET @cUPC = @cBarcode
         		SET @cLottable01 = ''
         	END
         	ELSE
         	BEGIN
         	   SET @cUPC = SUBSTRING( @cBarcode, 1, CHARINDEX( ':', @cBarcode) - 1)
         	   SET @cLottable01 = SUBSTRING( @cBarcode,  CHARINDEX( ':', @cBarcode) + 1, LEN( @cBarcode))
         	END

	         SELECT @bsuccess = 1
      
            -- Validate SKU/UPC
            EXEC dbo.nspg_GETSKU
                @c_StorerKey= @cStorerKey  OUTPUT
               ,@c_Sku      = @cUPC        OUTPUT
               ,@b_Success  = @bSuccess    OUTPUT
               ,@n_Err      = @nErrNo      OUTPUT
               ,@c_ErrMsg   = @cErrMsg     OUTPUT

            IF @cLottable01 = ''
               GOTO QUIT
                                
            IF NOT EXISTS ( SELECT 1 
                            FROM dbo.PICKDETAIL PD WITH (NOLOCK)
                            JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON ( PD.Lot = LA.Lot)
                            WHERE PD.OrderKey = @cOrderKey
                            AND   PD.Loc = @cLoc
                            AND   PD.Sku = @cUPC
                            AND   PD.[Status] = '0'
                            AND   LA.Lottable01 = @cLottable01)
            BEGIN
               SET @nErrNo = 202852  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --L01 Not Exists  
               GOTO Quit              	
            END
         END  
      END  
   END  

QUIT:

GO