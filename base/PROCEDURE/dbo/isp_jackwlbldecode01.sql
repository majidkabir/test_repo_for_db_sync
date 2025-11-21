SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: isp_JACKWLblDecode01                                */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: JACKW Scan To Mbol Creation label no decode                 */    
/*          Based on barcode scanned, return packdetail.refno           */
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2014-12-29 1.0  James    SOS315958 Created                           */    
/************************************************************************/    
    
CREATE PROCEDURE [dbo].[isp_JACKWLblDecode01]    
   @c_LabelNo          NVARCHAR(40),
   @c_Storerkey        NVARCHAR(15),
   @c_ReceiptKey       NVARCHAR(10),   -- MBOLKey
   @c_POKey            NVARCHAR(10),
	@c_LangCode	        NVARCHAR(3),
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
   @n_ErrNo            INT      OUTPUT, 
   @c_ErrMsg           NVARCHAR(250) OUTPUT
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @cStartPos         NVARCHAR( 5), 
           @cLen              NVARCHAR( 5), 
           @cMBOLScanCarrier  NVARCHAR( 20), 
           @cToteNo           NVARCHAR( 60), 
           @cCarrier          NVARCHAR( 10), 
           @cMBOLKey          NVARCHAR( 10), 
           @cPlaceOfLoadingQualifier   NVARCHAR( 10), 
           @nStartPos         INT, 
           @nFunc             INT, 
           @nLen              INT, 
           @nStep             INT, 
           @nMobile           INT 

   SET @cToteNo = @c_LabelNo
   SET @cCarrier = @c_POKey
   SET @cMBOLKey = @c_ReceiptKey

   SET @c_oFieled01 = ''
   SET @c_ErrMsg = ''

   SELECT @nFunc = Func, 
          @nStep = Step, 
          @nMobile = Mobile 
   FROM RDT.RDTMOBREC (NOLOCK) 
   WHERE UserName = sUser_sName()

   SELECT @cPlaceOfLoadingQualifier = PlaceOfLoadingQualifier 
   FROM dbo.MBOL WITH (NOLOCK)
   WHERE MbolKey = @cMBOLKey
      
   IF @cPlaceOfLoadingQualifier <> 'ECOMM'
   BEGIN
      SET @c_oFieled01 = @c_LabelNo
      GOTO Quit
   END

   SET @cMBOLScanCarrier = rdt.RDTGetConfig( @nFunc, 'MBOLSCANCARRIER', @c_Storerkey) 
   IF ISNULL( @cMBOLScanCarrier, '') IN ('', '0')
      SET @cMBOLScanCarrier = 0

   IF @nStep <> 2 OR @cMBOLScanCarrier <> '1'
      GOTO Quit

   IF LEN( RTRIM( ISNULL( @cToteNo, ''))) = ''
   BEGIN
      SET @c_ErrMsg = 'BARCODE IS BLANK'
      GOTO Quit
   END

   SELECT @cStartPos = Short, 
          @cLen = Long 
   FROM dbo.CODELKUP WITH (NOLOCK) 
   WHERE StorerKey = @c_Storerkey
   AND   ListName = 'CarrierTyp'
   AND   Code = @cCarrier

   IF @@ROWCOUNT = 0
   BEGIN
      SET @c_ErrMsg = 'CARRIER NOT SETUP'
      GOTO Quit
   END

   IF RDT.rdtIsValidQTY( @cStartPos, 1) <> 1
   BEGIN
      SET @c_ErrMsg = 'INVALID START POS'
      GOTO Quit
   END
      
   IF RDT.rdtIsValidQTY( @cLen, 1) <> 1
   BEGIN
      SET @c_ErrMsg = 'INVALID POSITION LEN'
      GOTO Quit
   END

   SET @nStartPos = CAST( @cStartPos AS INT)
   SET @nLen = CAST( @cLen AS INT)

   SELECT @c_oFieled01 = SUBSTRING( RTRIM( @cToteNo), @nStartPos, @nLen)

QUIT:

END -- End Procedure  

GO