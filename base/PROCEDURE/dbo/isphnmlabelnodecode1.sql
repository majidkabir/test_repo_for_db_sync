SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispHNMLabelNoDecode1                                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Decode Label No Scanned                                     */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 11-02-2014  1.0  Ung         SOS301005 Created                       */
/* 02-01-2018  1.1  James       WMS3666 - Add config to control the     */
/*                              decoding method (james01)               */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispHNMLabelNoDecode1]
   @c_LabelNo          NVARCHAR(40),
   @c_Storerkey        NVARCHAR(15),
   @c_ReceiptKey       NVARCHAR(10),
   @c_POKey            NVARCHAR(10),
	@cLangCode	        NVARCHAR(3),
	@c_oFieled01        NVARCHAR(20) OUTPUT,
	@c_oFieled02        NVARCHAR(20) OUTPUT,
   @c_oFieled03        NVARCHAR(20) OUTPUT,
   @c_oFieled04        NVARCHAR(20) OUTPUT,
   @c_oFieled05        NVARCHAR(20) OUTPUT,
   @c_oFieled06        NVARCHAR(20) OUTPUT,
   @c_oFieled07        NVARCHAR(20) OUTPUT,
   @c_oFieled08        NVARCHAR(20) OUTPUT,
   @c_oFieled09        NVARCHAR(20) OUTPUT,
   @c_oFieled10        NVARCHAR(20) OUTPUT,
   @b_Success          INT = 1  OUTPUT,
   @nErrNo             INT      OUTPUT, 
   @cErrMsg            NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cSeason  NVARCHAR( 2)
   DECLARE @cSKU     NVARCHAR( 13)
   DECLARE @cLOT     NVARCHAR( 12)
   DECLARE @cCOO     NVARCHAR( 2)
   DECLARE @cDocType NVARCHAR( 1)
   DECLARE @cDecodeUCCNo NVARCHAR( 1)
   DECLARE @nFunc    INT

   SET @cSeason = ''
   SET @cSKU = ''
   SET @cLOT = ''
   SET @cCOO = ''

   -- Get ReceiptKey
   SELECT @c_ReceiptKey = V_ReceiptKey, @nFunc = Func FROM rdt.rdtMobRec WITH (NOLOCK) WHERE UserName = SUSER_SNAME()

   SET @cDecodeUCCNo = rdt.RDTGetConfig( @nFunc, 'DecodeUCCNo', @c_Storerkey)

   IF @cDecodeUCCNo = '1'
      SET @c_LabelNo = RIGHT( @c_LabelNo, LEN(@c_LabelNo) - 2)

   -- Get 2D barcode
   SET @cSeason = SUBSTRING( @c_LabelNo, 1, 2)
   SET @cSKU = SUBSTRING( @c_LabelNo, 3, 13)
   SET @cLOT = SUBSTRING( @c_LabelNo, 16, 12)
   SET @cCOO = SUBSTRING( @c_LabelNo, 28, 2)
   
   -- Get Receipt info
   SELECT @cDocType = DocType FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @c_ReceiptKey

   
   -- Check SKU valid
   IF @cSKU = ''
   BEGIN  
      SET @nErrNo = 85151
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU is blank
      GOTO Quit
   END 

   -- Check season valid
   IF @cSeason = ''
   BEGIN  
      SET @nErrNo = 85152
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Season IsBlank
      GOTO Quit
   END 

   -- Check season valid
   IF @cLOT = ''
   BEGIN  
      SET @nErrNo = 85153
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOT Is Blank
      GOTO Quit
   END 
   
   -- Check COO valid
   IF @cCOO = ''
   BEGIN  
      SET @nErrNo = 85154
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --COO Is Blank
      GOTO Quit
   END 

   -- Check SKU in ASN
   --IF NOT EXISTS( SELECT TOP 1 1
   --   FROM ReceiptDetail WITH (NOLOCK)
   --   WHERE ReceiptKey = @c_ReceiptKey
   --      AND SKU = @cSKU)
   --BEGIN  
   --   SET @nErrNo = 85155
   --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU Not In ASN
   --   GOTO Quit
   --END 

   -- Check season in ASN
   --IF NOT EXISTS( SELECT TOP 1 1
   --   FROM ReceiptDetail WITH (NOLOCK)
   --   WHERE ReceiptKey = @c_ReceiptKey
   --      AND SKU = @cSKU
   --      AND SUBSTRING( Lottable01, 5, 2) = @cSeason)
   --BEGIN  
   --   SET @nErrNo = 85156
   --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SeasonNotInASN
   --   GOTO Quit
   --END 

   ---- Check LOT in ASN
   --IF NOT EXISTS( SELECT TOP 1 1
   --   FROM ReceiptDetail WITH (NOLOCK)
   --   WHERE ReceiptKey = @c_ReceiptKey
   --      AND SKU = @cSKU
   --      AND SUBSTRING( Lottable02, 1, 12) = @cLOT)
   --BEGIN  
   --   SET @nErrNo = 85157
   --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOT Not In L02
   --   GOTO Quit
   --END
   
   ---- Check COO in ASN
   --IF NOT EXISTS( SELECT TOP 1 1
   --   FROM ReceiptDetail WITH (NOLOCK)
   --   WHERE ReceiptKey = @c_ReceiptKey
   --      AND SKU = @cSKU
   --      AND SUBSTRING( Lottable02, 14, 2) = @cCOO)
   --BEGIN  
   --   SET @nErrNo = 85158
   --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --COO Not In L02
   --   GOTO Quit
   --END
   
   -- Return value
   IF @cSKU <> '' 
   BEGIN
      SET @c_oFieled01 = @cSKU
      SET @c_oFieled07 = SUBSTRING( @cLOT, 1, 6)
      SET @c_oFieled08 = @cLOT + '-' + @cCOO
      SET @c_oFieled09 = CASE WHEN @cDocType = 'A' THEN 'STD' ELSE 'RET' END
   END
   
     
QUIT:
END -- End Procedure


GO