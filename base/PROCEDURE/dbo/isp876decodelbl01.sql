SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: isp876DecodeLBL01                                   */
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
/* 02-08-2013  1.0  ChewKP      SOS#285141 Created                      */
/* 22-12-2014  1.1  ChewKP      SOS#327634 - Add Validation (ChewKP01)  */
/* 05-08-2019  1.2  James       WMS10007 - Add new Validation (james01) */
/************************************************************************/

CREATE PROCEDURE [dbo].[isp876DecodeLBL01]
   @nMobile            INT,   
   @nFunc              INT,    
   @c_CodeString       NVARCHAR(MAX),
   @c_Storerkey        NVARCHAR(15),
   @c_OrderKey         NVARCHAR(10),
   @c_LangCode	        NVARCHAR(3),
	@c_oFieled01        NVARCHAR(20) OUTPUT,  -- SerialNo   
	@c_oFieled02        NVARCHAR(20) OUTPUT,  -- SKU
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
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue     INT,
           @b_debug        INT

   DECLARE @c_SKU             NVARCHAR(20),
           @c_SerialNo        NVARCHAR(18),
           @c_DataString      NVARCHAR(MAX),
           @n_CharIndexEAN13  INT,
           @n_CharIndexID     INT,
           @n_Len             INT,
           @nSKUCnt           INT,
           @c_SKUBUSR8        NVARCHAR(30),
           @n_CharIndexQMark  INT,
           @n_CharIndexAmp    INT
           
   DECLARE @n_OrdDtlSKUCnt    INT
   DECLARE @n_SerialNoSKUCnt  INT
   DECLARE @n_SKUExceed       INT
   DECLARE @n_SKUExistsInSerialNo   INT
   DECLARE @n_SumOrdDtlQty    INT
   DECLARE @n_SumSNPcsQty     INT
   DECLARE @n_SumSNCtnQty     INT

   SELECT @b_Success = 1, @n_ErrNo = 0, @b_debug = 0
   SELECT @c_oFieled01  = '',
          @c_oFieled02  = '',
          @c_oFieled03  = '',
          @c_oFieled04  = '',
          @c_oFieled05  = '',
          @c_oFieled06  = '',
          @c_oFieled07  = '',
          @c_oFieled08  = '',
          @c_oFieled09  = '',
          @c_oFieled10  = ''

   SELECT @c_SKU              = '',
          @c_SerialNo         = '',
          @c_DataString       = '',
          @n_CharIndexEAN13   = 0, 
          @n_CharIndexID      = 0,
          @nSKUCnt            = 0,
          @c_SKUBUSR8         = '',
          @n_CharIndexQMark   = 0,
          @n_CharIndexAmp     = 0

   
   
   SET @n_Len = LEN(@c_CodeString)
   SET @n_CharIndexQMark = CHARINDEX ('?', @c_CodeString)
   
   SET @c_DataString = SUBSTRING(@c_CodeString, @n_CharIndexQMark ,@n_Len) 
   SET @n_CharIndexAmp = CHARINDEX ('&', @c_DataString)
   SET @n_CharIndexEAN13 = CHARINDEX ('EA13=', @c_DataString)
   SET @n_CharIndexID = CHARINDEX ('ID=', @c_DataString)
   
   --SELECT @n_CharIndexAmp  '@n_CharIndexAmp', @n_CharIndexEAN13 '@n_CharIndexEAN13', @n_CharIndexID '@n_CharIndexID'
   
   IF @n_CharIndexEAN13 > 0 
   BEGIN
      
      SET @c_SKU = SUBSTRING( @c_DataString, @n_CharIndexEAN13 + 5, @n_CharIndexAmp - 7)
      
      EXEC rdt.rdt_GETSKUCNT
             @cStorerkey  = @c_Storerkey 
            ,@cSKU        = @c_SKU
            ,@nSKUCnt     = @nSKUCnt       OUTPUT
            ,@bSuccess    = @b_Success     OUTPUT
            ,@nErr        = @n_ErrNo       OUTPUT
            ,@cErrMsg     = @c_ErrMsg      OUTPUT

      -- Check SKU/UPC
      IF @nSKUCnt = 0
      BEGIN
         SET @n_ErrNo  = 82101 -- SKUCount>1
         GOTO QUIT
      END
      
      EXEC dbo.nspg_GETSKU
                           @c_Storerkey 
            ,              @c_SKU OUTPUT
            ,              @b_Success  OUTPUT
            ,              @n_ErrNo    OUTPUT
            ,              @c_ErrMsg   OUTPUT

      IF @b_success = 0
      BEGIN
         SET @n_ErrNo  = 82102 -- InvalidSKU
         GOTO QUIT
      END      

      IF NOT EXISTS ( SELECT 1 FROM dbo.OrderDetail WITH (NOLOCK)
                      WHERE StorerKey = @c_StorerKey
                      AND OrderKey = @c_OrderKey
                      AND SKU = @c_SKU ) 
      BEGIN
         SET @n_ErrNo  = 82106 -- SKUNotInOrder
         GOTO QUIT
      END     

      SELECT @c_SKUBUSR8 = BUSR8
      FROM dbo.SKU WITH (NOLOCK)
      WHERE StorerKey = @c_Storerkey
      AND SKU = @c_SKU
      
      
      IF ISNULL(RTRIM(@c_SKUBUSR8),'') = '0' OR ISNULL(RTRIM(@c_SKUBUSR8),'') = ''
      BEGIN
         SET @n_ErrNo  = 82104 -- SKUNotAllowed
         GOTO QUIT
      END
      
      IF ISNULL(RTRIM(@c_SKUBUSR8),'') <> '1' 
      BEGIN
         SET @n_ErrNo  = 82108 -- No Need ScanQR
         GOTO QUIT
      END
   END
   ELSE
   BEGIN
      SET @n_ErrNo  = 82111 -- Need SKU
      GOTO QUIT
   END

   IF @n_CharIndexID > 0 
   BEGIN
      SET @c_SerialNo = SUBSTRING( @c_DataString, @n_CharIndexID + 3 , LEN(@c_DataString))
      
      IF ISNULL(RTRIM(@c_SerialNo),'') = ''
      BEGIN
         SET @n_ErrNo  = 82103 -- InvalidSerialNo
         GOTO QUIT
      END
      ELSE  -- (ChewKP01) 
      BEGIN
         IF LEN(ISNULL(RTRIM(@c_SerialNo),'')) <> 12
         BEGIN
            SET @n_ErrNo  = 82107 -- InvalidSerialNo
            GOTO QUIT
         END
      END

      -- Check over scanned
      SELECT @n_SumOrdDtlQty = ISNULL( SUM( QtyAllocated + QtyPicked), 0)
      FROM dbo.ORDERDETAIL OD WITH (NOLOCK)
      JOIN dbo.SKU SKU WITH (NOLOCK) ON ( OD.StorerKey = SKU.StorerKey AND OD.SKU = SKU.Sku)
      WHERE OD.OrderKey = @c_OrderKey
      AND   SKU.BUSR8 = '1'

      SELECT @n_SumSNPcsQty = ISNULL( SUM(SN.Qty), 0)
      FROM dbo.SerialNo SN WITH (NOLOCK) 
      JOIN dbo.SKU SKU WITH (NOLOCK) ON ( SN.StorerKey = SKU.StorerKey AND SN.SKU = SKU.SKU )
      WHERE SN.OrderKey = @c_OrderKey
      AND   SKU.BUSR8 = '1'
      AND   SUBSTRING( SN.SerialNo, 4, 1) <> 'M'

      SELECT @n_SumSNCtnQty = ISNULL( SUM( SN.Qty * PA.CaseCnt), 0)
      FROM dbo.SerialNo SN WITH (NOLOCK) 
      JOIN dbo.SKU SKU WITH (NOLOCK) ON ( SN.StorerKey = SKU.StorerKey AND SN.SKU = SKU.SKU )
      JOIN dbo.Pack PA WITH (NOLOCK) ON ( SKU.PackKey = PA.PackKey)
      WHERE SN.OrderKey = @c_OrderKey
      AND   SKU.BUSR8 = '1'
      AND   SUBSTRING( SN.SerialNo, 4, 1) = 'M'

      IF @n_SumOrdDtlQty < ( @n_SumSNPcsQty + @n_SumSNCtnQty + 1)
      BEGIN
         SET @n_ErrNo  = 82110 -- ScanQty<>Alloc
         GOTO QUIT
      END
         
      --INSERT INTO TRACEINFOJ (TRACENAME, TIMEIN, COL1, COL2) VALUES
      --('110012508674', GETDATE(), @c_SerialNo, @c_SKU)
      SET @c_oFieled01 = RTRIM(@c_SerialNo)
      SET @c_oFieled02 = RTRIM(@c_SKU)
   END   
   ELSE
   BEGIN
      SET @n_ErrNo  = 82105 -- InvalidQR
      GOTO QUIT
   END

QUIT:
END -- End Procedure


GO