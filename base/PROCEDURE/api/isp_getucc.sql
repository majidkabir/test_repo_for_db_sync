SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: isp_getUCC                                                */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2021-09-22   1.0  Chermaine	TPS-616 Created                              */
/* 2024-07-26   1.1  yeekung		TPS-952 Add UCC Status								*/
/* 2024-01-03   1.2  yeekung     INC-????? add UCC Status for qty (yeekung02) */
/* 2025-02-14   1.3  yeekung     TPS-995 Change Error Message (yeekung03)     */
/******************************************************************************/

CREATE    PROC [API].[isp_getUCC] (
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
      @cPickSlipNo  NVARCHAR( 20)

	--Decode Json Format
   SELECT @cStorerKey = StorerKey, @cFacility = Facility,  @nFunc = Func, @cBarcode = Barcode,@cPickSlipno=PickslipNo, @cUserName = UserName, @cLangCode = LangCode
   FROM OPENJSON(@json)
   WITH (
      StorerKey   NVARCHAR ( 15),
      Facility    NVARCHAR ( 5),
      Func        INT,
      Barcode     NVARCHAR( 60),
      PickSlipNo  NVARCHAR( 20),
      UserName    NVARCHAR( 30),
      LangCode    NVARCHAR( 3)

   )

   SET @b_Success = 1

   DECLARE @nSKUCOUNT INT

           
   -- Get SKU count        
   DECLARE @nSKUCnt INT     = 0    
   SET @nSKUCnt = 0        
   EXEC RDT.rdt_GetSKUCNT        
       @cStorerKey  = @cStorerKey        
      ,@cSKU        = @cBarcode        
      ,@nSKUCnt     = @nSKUCnt   OUTPUT        
      ,@bSuccess    = @b_Success OUTPUT        
      ,@nErr        = @n_Err    OUTPUT        
      ,@cErrMsg     = @c_ErrMsg   OUTPUT        
        
   -- Check SKU        
   IF @nSKUCnt = 1      
   BEGIN        
      SET @jResult = (SELECT @cBarcode AS SKU, '1' AS QTYPacked,'SKU' AS type
      FOR JSON PATH, INCLUDE_NULL_VALUES)    
   END       
   ELSE
   BEGIN
      SELECT @nSKUCnt=COUNT(1)
      FROM UCC (NOLOCK)
      where UCCno=@cBarcode
      AND storerkey=@cStorerKey  
      AND STATUS  IN ('1','2','3','4','5')

      IF @nSKUCnt =1
      BEGIN
         SET @jResult = (SELECT ISNULL(RTRIM(SKU),'') AS SKU,qty as qtypacked,@cBarcode AS UCC,'UCC' AS type
         FROM UCC WITH (NOLOCK)
         where UCCno=@cBarcode
         AND storerkey=@cStorerKey
         AND STATUS  IN ('1','2','3','4','5')
         FOR JSON AUTO, INCLUDE_NULL_VALUES)    
      END

   END

   IF @nSKUCnt <>'1'
   BEGIN
      SET @b_Success = 0
      SET @n_Err = 1001251
	   SET @c_ErrMsg = API.TouchPadGetMessage( @n_Err, @cLangCode, 'DSP') --'SKU NOT FOUND. Function : isp_getUCC'
      SET @jResult = (SELECT '' AS SKU
         FOR JSON PATH,INCLUDE_NULL_VALUES )  
   END

END

GO