SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store procedure: isp_1761LblDecode01                                 */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Purpose: TM Dynamic Pick label no decode                             */    
/*          Based on barcode scanned, return Qty & Case ID              */
/*                                                                      */    
/* Called from:                                                         */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date       Rev  Author   Purposes                                    */    
/* 2015-07-15 1.0  James    SOS332896 Created                           */    
/************************************************************************/    
    
CREATE PROCEDURE [dbo].[isp_1761LblDecode01]    
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

   DECLARE @cBoxQty     NVARCHAR( 3), 
           @cToteNo     NVARCHAR( 60), 
           @cStorerKey  NVARCHAR( 15), 
           @nSKUCnt     INT, 
           @bSuccess    INT, 
           @nErrNo      INT, 
           @cErrMsg     NVARCHAR( 20) 

   SET @c_ErrMsg = ''
   SET @c_oFieled01 = ''
   SET @c_oFieled02 = ''

   SELECT @cStorerKey = StorerKey, 
          @cBoxQty = I_Field08, 
          @cToteNo = I_Field10 
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE UserName = sUser_sName()

   -- If not a valid format then don't decode
   IF LEN( RTRIM( @c_LabelNo)) <> 11
   BEGIN
      -- Assign back original value before quit
      SET @c_oFieled01 = @cToteNo
      SET @c_oFieled02 = @cBoxQty
      GOTO Quit
   END

   EXEC [RDT].[rdt_GETSKUCNT]
      @cStorerKey  = @cStorerKey,
      @cSKU        = @c_LabelNo,
      @nSKUCnt     = @nSKUCnt       OUTPUT,
      @bSuccess    = @bSuccess      OUTPUT,
      @nErr        = @nErrNo        OUTPUT,
      @cErrMsg     = @cErrMsg       OUTPUT

   IF @nSKUCnt >= 1
   BEGIN
      SET @c_ErrMsg = 'LABEL NO = SKU/UPC'
      GOTO Quit
   END
      
   SET @cToteNo = SUBSTRING( @c_LabelNo, 1, 8)
   SET @cBoxQty = SUBSTRING( @c_LabelNo, 9, 11)

   IF rdt.rdtisValidQty( @cToteNo, 1) = 0
   BEGIN
      SET @c_ErrMsg = 'INVALID CASE ID'
      GOTO Quit
   END

   IF rdt.rdtisValidQty( @cBoxQty, 1) = 0
   BEGIN
      SET @c_ErrMsg = 'INVALID CASE QTY'
      GOTO Quit
   END

   SET @c_oFieled01 = @cToteNo
   SET @c_oFieled02 = CAST( @cBoxQty AS NVARCHAR( 3))

QUIT:

END -- End Procedure  

GO