SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: isp_TPS_DecodeSP05                                        */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2023-05-17   1.0  yeekung   TPS-703 Created                               */
/******************************************************************************/

CREATE   PROC [API].[isp_TPS_DecodeSP05] (
	@json       NVARCHAR( MAX),
   @jResult    NVARCHAR( MAX) OUTPUT,
   @b_Success  INT = 1        OUTPUT,
   @n_Err      INT = 0        OUTPUT,
   @c_ErrMsg   NVARCHAR( 255) = ''  OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF
BEGIN
	DECLARE
		@cStorerKey   NVARCHAR ( 15),
      @cFacility    NVARCHAR ( 5),
      @nFunc        INT,
      @cBarcode     NVARCHAR( 60),
      @cUserName    NVARCHAR( 30),
      @cLangCode    NVARCHAR( 3),
      @cSKU         NVARCHAR( 30),
      @cUPC         NVARCHAR( 20)

	--Decode Json Format
   SELECT @cStorerKey = StorerKey, @cFacility = Facility,  @nFunc = Func, @cBarcode = Barcode, @cUserName = UserName, @cLangCode = LangCode
   FROM OPENJSON(@json)
   WITH (
      StorerKey   NVARCHAR ( 15),
      Facility    NVARCHAR ( 5),
      Func        INT,
      Barcode     NVARCHAR( 60),
      UserName    NVARCHAR( 30),
      LangCode    NVARCHAR( 3)
   )

   SET @b_Success = 1

   IF EXISTS (SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey 
               AND configKey = 'ADAllowInsertExistingSerialNo'  
               AND SVALUE='1')
   BEGIN

      IF NOT EXISTS(SELECT 1 FROM SerialNo WITH (NOLOCK)
                  WHERE SerialNo = @cBarcode
                  AND storerKey = @cStorerKey )
      BEGIN
         SET @jResult = (SELECT '' AS SKU
         FOR JSON PATH,INCLUDE_NULL_VALUES)
      END
      ELSE IF NOT EXISTS(SELECT 1 FROM SerialNo WITH (NOLOCK)
                  WHERE SerialNo = @cBarcode
                  AND storerKey = @cStorerKey 
                  AND ISNULL(orderkey,'')=''
                  AND status='1')
      BEGIN
         SET @jResult = (SELECT '' AS SKU
         FOR JSON PATH,INCLUDE_NULL_VALUES)
      END
      ELSE
      BEGIN
         SELECT @cUPC =  UserDefine02
         FROM SerialNo WITH (NOLOCK)
         WHERE SerialNo = @cBarcode
         AND storerKey = @cStorerKey

   	  SET @jResult = (SELECT ISNULL(RTRIM(SKU),'') AS SKU
         FROM UPC WITH (NOLOCK)
         WHERE UPC = @cUPC
         AND storerKey = @cStorerKey
         FOR JSON AUTO, INCLUDE_NULL_VALUES)
      END

      SET @n_Err = 0
	   SET @c_ErrMsg = ''
   END
   ELSE
   BEGIN
      IF NOT EXISTS(SELECT 1 FROM SerialNo WITH (NOLOCK)
            WHERE SerialNo = @cBarcode
            AND storerKey = @cStorerKey )
      BEGIN
         SET @jResult = (SELECT '' AS SKU
         FOR JSON PATH,INCLUDE_NULL_VALUES)
      END

      IF EXISTS (SELECT 1 FROM SerialNo WITH (NOLOCK)
            WHERE SerialNo = @cBarcode
            AND storerKey = @cStorerKey )
      BEGIN
         SET @n_Err = 1000101
	      SET @c_ErrMsg = CAST(@n_Err AS NVARCHAR(20))+'Err Insert Duplicate SerialNO'

         SET @jResult = (SELECT '' AS SKU
         FOR JSON PATH,INCLUDE_NULL_VALUES )    
         SET @b_Success = 0
      END
   END


   SELECT @cStorerKey '@cStorerKey', @cBarcode '@cBarcode', @jResult '@jResult'

END


GO