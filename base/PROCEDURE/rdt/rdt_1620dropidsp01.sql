SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_1620DropIDSP01                                  */  
/* Purpose: Decode DropID                                               */  
/*                                                                      */
/* Called From: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2020-10-26 1.0  James      WMS-15548. Created                        */ 
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1620DropIDSP01] (  
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cStorerKey     NVARCHAR( 15),
   @cBarcode       NVARCHAR( 60),
   @cWaveKey       NVARCHAR( 10),
   @cLoadKey       NVARCHAR( 10),
   @cOrderKey      NVARCHAR( 10),
   @cPutawayZone   NVARCHAR( 10),
   @cPickZone      NVARCHAR( 10),
   @cDropID        NVARCHAR( 20)  OUTPUT,
   @cUPC           NVARCHAR( 20)  OUTPUT,
   @nQTY           INT            OUTPUT,
   @cLottable01    NVARCHAR( 18)  OUTPUT,
   @cLottable02    NVARCHAR( 18)  OUTPUT,
   @cLottable03    NVARCHAR( 18)  OUTPUT,
   @dLottable04    DATETIME       OUTPUT,
   @dLottable05    DATETIME       OUTPUT,
   @cLottable06    NVARCHAR( 30)  OUTPUT,
   @cLottable07    NVARCHAR( 30)  OUTPUT,
   @cLottable08    NVARCHAR( 30)  OUTPUT,
   @cLottable09    NVARCHAR( 30)  OUTPUT,
   @cLottable10    NVARCHAR( 30)  OUTPUT,
   @cLottable11    NVARCHAR( 30)  OUTPUT,
   @cLottable12    NVARCHAR( 30)  OUTPUT,
   @dLottable13    DATETIME       OUTPUT,
   @dLottable14    DATETIME       OUTPUT,
   @dLottable15    DATETIME       OUTPUT,
   @cUserDefine01  NVARCHAR( 60)  OUTPUT,
   @cUserDefine02  NVARCHAR( 60)  OUTPUT,
   @cUserDefine03  NVARCHAR( 60)  OUTPUT,
   @cUserDefine04  NVARCHAR( 60)  OUTPUT,
   @cUserDefine05  NVARCHAR( 60)  OUTPUT,
   @nErrNo         INT            OUTPUT,
   @cErrMsg        NVARCHAR( 20)  OUTPUT
)  
AS  
  
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF   

   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cPrefix        NVARCHAR( 10)
   DECLARE @nMaxLength     INT
   DECLARE @cDecodeCode    NVARCHAR( 30)
   
   SELECT @cDecodeCode = DecodeCode
   FROM dbo.BarcodeConfig WITH (NOLOCK)
   WHERE StorerKey = 'JTITH'
   AND Function_ID = 1620
   
   SELECT @nMaxLength = ISNULL( SUM( MaxLength), 0)
   FROM dbo.BarcodeConfigDetail (NOLOCK) 
   WHERE DecodeCode = @cDecodeCode
   
   IF LEN( @cBarcode) <> @nMaxLength
      SET @cDropID = LEFT( @cBarcode, 20)
   ELSE
   BEGIN
      SET @cDropID = ''
      EXEC rdt.rdt_Decode @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cBarcode,   
         @cID     = @cDropID OUTPUT,   
         @cType   = 'ID'  
   END
         
   IF ISNULL( @cDropID, '') <> ''
   BEGIN
      SET @cPrefix = ''
      SELECT @cPrefix = Short
      FROM dbo.CODELKUP WITH (NOLOCK)
      WHERE LISTNAME = 'DROPPREFIX'
      AND   Storerkey = @cStorerKey
      
      SET @cDropID = ISNULL( @cPrefix, '') + @cDropID
   END
      
 Quit:
    

GO