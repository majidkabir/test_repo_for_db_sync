SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: rdt_GenUCCLabelNo_02                               */
/*                                                                      */
/* Purpose: Generate SSCC Label No                                      */
/*                                                                      */
/* Called By:                                                           */ 
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 2016-03-24   James     1.0   SOS366110 - Created (james01)           */
/************************************************************************/

CREATE PROC [RDT].[rdt_GenUCCLabelNo_02] (
   @nMobile                   INT,           
   @nFunc                     INT,           
   @cLangCode                 NVARCHAR( 3),  
   @nStep                     INT,           
   @nInputKey                 INT,           
   @cStorerkey                NVARCHAR( 15), 
   @cOrderKey                 NVARCHAR( 10), 
   @cPickSlipNo               NVARCHAR( 10), 
   @cTrackNo                  NVARCHAR( 20), 
   @cSKU                      NVARCHAR( 20), 
   @nCartonNo                 INT,           
   @cLabelNo                  NVARCHAR( 20) OUTPUT,                       
   @nErrNo                    INT           OUTPUT,  
   @cErrMsg                   NVARCHAR( 20) OUTPUT   
)
AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE 	
      @b_debug          INT,
      @cVAT             NVARCHAR(18),
      @cCounter         NVARCHAR(25),
      @cKeyname         NVARCHAR(30), 
      @bSuccess         INT, 
      @cPartial_SSCC    NVARCHAR( 17),
      @cRunningNum      NVARCHAR( 9),
      @nSumOdd          INT,
      @nSumEven         INT,
      @nSumAll          INT,
      @nPos             INT,
      @nNum             INT,
      @nTry             INT,
      @cChkDigit        NVARCHAR( 1)

   SELECT @bSuccess = 1, @cErrMsg='', @nErrNo=0 
   SELECT @b_debug = 0

   SET @cLabelNo = ''

   SELECT @cVAT = ISNULL(Vat,'')
   FROM Storer WITH (NOLOCK)
   WHERE Storerkey = @cStorerkey
	   
   IF ISNULL(@cVAT,'') = ''
	   SET @cVAT = '000000000'

   IF LEN(@cVAT) <> 9 
      SET @cVAT = RIGHT('000000000' + RTRIM(LTRIM(@cVAT)), 9)

   EXECUTE nspg_getkey
      @KeyName       = 'MHAPSSCC' ,
      @fieldlength   = 8,    
      @keystring     = @cCounter    Output,
      @b_success     = @bSuccess   Output,
      @n_err         = @nErrNo      Output,
      @c_errmsg      = @cErrMsg     Output,
      @b_resultset   = 0,
      @n_batch       = 1
			
   SET @cPartial_SSCC = RTRIM(@cVAT) + RTRIM(@cCounter) 

   IF @b_debug = 1
      SELECT '@cVAT', @cVAT, '@c_nCounter', @cCounter, '@cPartial_SSCC', @cPartial_SSCC

   SET @nSumOdd  = 0
   SET @nSumEven = 0
   SET @nSumAll  = 0
   SET @nPos = 1

   WHILE @nPos <= 17
   BEGIN
      SET @nNum = SUBSTRING(@cPartial_SSCC, @nPos, 1)

      IF @nPos % 2 = 0
         SET @nSumEven = @nSumEven + @nNum
      ELSE
         SET @nSumOdd = @nSumOdd + @nNum

      SET @nPos = @nPos + 1
   END

   SELECT @nSumAll = (@nSumOdd * 3) + @nSumEven

   IF @b_debug = 1
      SELECT @nSumEven '@nSumEven', @nSumOdd '@nSumOdd', @nSumAll '@nSumAll'

   SET @nTry = 0
   WHILE @nTry <= 9
   BEGIN
      IF (@nSumAll + @nTry) % 10 = 0 
      BEGIN
         SET @cChkDigit = CAST( @nTry as NVARCHAR(1))
         BREAK
      END
      SET @nTry = @nTry + 1
   END

   IF @b_debug = 1
      SELECT '@@cChkDigit', @cChkDigit

   SET @cLabelNo = ISNULL(RTRIM(@cPartial_SSCC), '') + CAST(@cChkDigit AS NVARCHAR( 1))
   
   Quit:

END

GO