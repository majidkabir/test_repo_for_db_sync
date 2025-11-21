SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: rdt_GenUCCLabelNo_01                               */
/*                                                                      */
/* Purpose: Generate UCC Label No (Packing)                             */
/*          Turn on config GenUCCLabelNoConfig but do not setup record  */
/*          in UCCCounter table.                                        */
/*                                                                      */
/* Called By: RDT Pack By Track No                                      */ 
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 2016-01-16   James     1.0   SOS361387 - Created (james01)           */
/* 2021-08-10   YeeKung   1.1   Fix the params not match (yeekung01)    */
/************************************************************************/

CREATE PROC [RDT].[rdt_GenUCCLabelNo_01] (
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
   @cLabelNo                  NVARCHAR( 20) OUTPUT, --(yeekung01)
   @nCartonNo                 INT           OUTPUT,                      
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
   @cIdentifier    NVARCHAR(2),
	 @cPacktype      NVARCHAR(1),
   @cVAT           NVARCHAR(18),
   @c_nCounter     NVARCHAR(25),
   @cKeyname       NVARCHAR(30), 
   @cPackNo_Long   NVARCHAR(250),
   @c_errmsg         NVARCHAR(20),
   @nCheckDigit    INT,
   @nTotalCnt      INT,
   @nTotalOddCnt   INT,
   @nTotalEvenCnt  INT,
   @nAdd           INT,
   @nDivide        INT,
   @nRemain        INT,
   @nOddCnt        INT,
   @nEvenCnt       INT,
   @nOdd           INT,
   @nEven          INT, 
   @b_success      INT, 
   @n_err          INT

	 SELECT @b_success = 1, @c_errmsg='', @n_err=0 
         
   IF EXISTS (SELECT 1 FROM dbo.StorerConfig WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ConfigKey = 'GenUCCLabelNoConfig'
         AND SValue = '1')
   BEGIN
     SET @cIdentifier = '00'
	   SET @cPacktype = '0'  
     SET @cLabelNo = ''

     SELECT @cVAT = ISNULL(Vat,'')
	   FROM Storer WITH (NOLOCK)
	   WHERE Storerkey = @cStorerkey
	   
	   IF ISNULL(@cVAT,'') = ''
	      SET @cVAT = '000000000'

--	   IF LEN(@cVAT) <> 9 
--        SET @cVAT = RIGHT('000000000 RTRIM(LTRIM(@cVAT)), 9)
	   
	   SELECT @cPackNo_Long = Long 
     FROM  CODELKUP (NOLOCK)
     WHERE ListName = 'PACKNO'
     AND Code = @cStorerkey
     
     IF ISNULL(@cPackNo_Long,'') = ''
     	  SET @cKeyname = 'TBLPackNo'
     ELSE
        SET @cKeyname = 'PackNo' + LTRIM(RTRIM(@cPackNo_Long))
          
	    EXECUTE nspg_getkey
			@cKeyname ,
			7,
			@c_nCounter  	 Output ,
			@b_success      = @b_success output,
			@n_err          = @n_err output,
			@c_errmsg       = @c_errmsg output,
			@b_resultset    = 0,
			@n_batch        = 1
			
	   SET @cLabelNo = @cIdentifier + @cPacktype + RTRIM(@cVAT) + RTRIM(@c_nCounter) --+ @nCheckDigit

	   SET @nOdd = 1
     SET @nOddCnt = 0
     SET @nTotalOddCnt = 0
     SET @nTotalCnt = 0

     WHILE @nOdd <= 20 
     BEGIN
         IF ISNUMERIC( SUBSTRING(@cLabelNo, @nOdd, 1)) = 1
		      SET @nOddCnt = CAST(SUBSTRING(@cLabelNo, @nOdd, 1) AS INT)
		   ELSE 
		      SET @nOddCnt = 0

		   SET @nTotalOddCnt = @nTotalOddCnt + @nOddCnt
		   SET @nOdd = @nOdd + 2
     END

	   SET @nTotalCnt = (@nTotalOddCnt * 3) 
	
	  SET @nEven = 2
     SET @nEvenCnt = 0
     SET @nTotalEvenCnt = 0

	  WHILE @nEven <= 20 
     BEGIN
         IF ISNUMERIC( SUBSTRING(@cLabelNo, @nEven, 1)) = 1
		      SET @nEvenCnt = CAST(SUBSTRING(@cLabelNo, @nEven, 1) AS INT)
		   ELSE 
		      SET @nEvenCnt = 0
         
		   SET @nTotalEvenCnt = @nTotalEvenCnt + @nEvenCnt
		   SET @nEven = @nEven + 2
	   END

     SET @nAdd = 0
     SET @nRemain = 0
     SET @nCheckDigit = 0

	   SET @nAdd = @nTotalCnt + @nTotalEvenCnt
	   SET @nRemain = @nAdd % 10
	   SET @nCheckDigit = 10 - @nRemain

	   IF @nCheckDigit = 10 
			  SET @nCheckDigit = 0

	   SET @cLabelNo = ISNULL(RTRIM(@cLabelNo), '') + CAST(@nCheckDigit AS NVARCHAR( 1))
   END   -- GenUCCLabelNoConfig
   ELSE
   BEGIN
      EXECUTE nspg_GetKey
         'PACKNO', 
         10 ,
         @cLabelNo   OUTPUT,
         @b_success  OUTPUT,
         @n_err      OUTPUT,
         @c_errmsg   OUTPUT
   END
   Quit:

END

GO