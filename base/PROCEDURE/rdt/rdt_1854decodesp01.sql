SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1854DecodeSP01                                        */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Decode dropID, Lottable02                                         */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2021-07-09   Chermane  1.0   WMS-17140 Created                             */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1854DecodeSP01] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cStorerKey       NVARCHAR( 15),
   @cBarcode         NVARCHAR( 60),
   @cPickSlipNo      NVARCHAR( 20),
   @cDropID          NVARCHAR( 20)  OUTPUT,
   @cLOC             NVARCHAR( 10)  OUTPUT,
   @cID              NVARCHAR( 18)  OUTPUT,
   @cSKU             NVARCHAR( 20)  OUTPUT,
   @nTaskQTY         INT            OUTPUT,
   @cLottable01      NVARCHAR( 18)  OUTPUT,
   @cLottable02      NVARCHAR( 18)  OUTPUT,
   @cLottable03      NVARCHAR( 18)  OUTPUT,
   @dLottable04      DATETIME       OUTPUT,
   @dLottable05      DATETIME       OUTPUT,
   @cLottable06      NVARCHAR( 30)  OUTPUT,
   @cLottable07      NVARCHAR( 30)  OUTPUT,
   @cLottable08      NVARCHAR( 30)  OUTPUT,
   @cLottable09      NVARCHAR( 30)  OUTPUT,
   @cLottable10      NVARCHAR( 30)  OUTPUT,
   @cLottable11      NVARCHAR( 30)  OUTPUT,
   @cLottable12      NVARCHAR( 30)  OUTPUT,
   @dLottable13      DATETIME       OUTPUT,
   @dLottable14      DATETIME       OUTPUT,
   @dLottable15      DATETIME       OUTPUT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cClass      NVARCHAR(10)
   DECLARE @cColor      NVARCHAR(10)
   DECLARE @cPalletType NVARCHAR(5)
   DECLARE @cCurID      NVARCHAR( 18)

   IF ISNULL( @cBarcode, '') = ''
      GOTO Quit
      
   IF @nFunc = 1854 -- Pick Swap Lot
   BEGIN
      IF @nStep = 3 -- ID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
         	SELECT 
               @cPalletType = V_String5,
               @cSKU = V_Sku,
               @cLoc = V_Loc
            FROM rdt.RDTMOBREC WITH (NOLOCK)
            WHERE mobile = @nMobile
            
            SELECT 
               @cClass = Class,
               @cColor = Color
            FROM SKU WITH (NOLOCK)
            WHERE SKU = @cSKU
            AND storerKey = @cStorerKey
            
              
            IF @cClass = 'R'  OR 
            ( @cClass = 'N' AND @cColor IN ('GA','RACK') AND @cPalletType = 'PP') OR
            ( @cClass = 'N' AND @cColor NOT IN ('GA','RACK') AND @cPalletType = 'PP')
            BEGIN  	
               SELECT 
                  @nTaskQTY = SUM(PD.Qty)
               FROM pickdetail PD
               JOIN pickHeader PH ON (PD.orderKey = PH.orderKey)
               JOIN Loc L on (L.Loc = PD.Loc)
               JOIN dbo.LOTATTRIBUTE LA on (LA.lot = PD.lot)
               WHERE PH.PickHeaderKey = @cPickSlipNo
               AND PD.loc = @cLOC
               AND LA.Lottable02 = @cLottable02 
            END
            ELSE
            BEGIN
               SELECT 
                  @cCurID = PD.ID
               FROM pickdetail PD
               JOIN pickHeader PH ON (PD.orderKey = PH.orderKey)
               JOIN Loc L on (L.Loc = PD.Loc)
               JOIN dbo.LOTATTRIBUTE LA on (LA.lot = PD.lot)
               WHERE PH.PickHeaderKey = @cPickSlipNo
               AND PD.loc = @cLOC
               AND LA.Lottable02 = @cLottable02
   	         
               SELECT 
                  @nTaskQTY = SUM(PD.Qty)
               FROM pickdetail PD
               JOIN pickHeader PH ON (PD.orderKey = PH.orderKey)
               JOIN Loc L on (L.Loc = PD.Loc)
               JOIN dbo.LOTATTRIBUTE LA on (LA.lot = PD.lot)
               WHERE PH.PickHeaderKey = @cPickSlipNo
               AND PD.loc = @cLOC
               AND PD.ID = @cCurID
   	         
            END
            
            --INSERT INTO traceInfo (TraceName,timein,col1,col2,col3,col4,col5,step1,step2)        
            --VALUES ('1854decode01',GETDATE(),@cPickSlipNo,@cLOC,@cLottable02,@cID,@nTaskQTY,@cBarcode,@cCurID )
         END
      END
   END

Quit:

END

GO