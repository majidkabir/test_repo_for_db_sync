SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_GenUCCLabelNo_SVW                              */  
/* Creation Date: 04-Aug-2009                                           */  
/* Copyright: IDS                                                       */  
/* Written by: NJOW                                                     */  
/*                                                                      */  
/* Purpose: SOS#141877 - Generate UCC Label No                          */  
/*                                                                      */  
/* Called By: isp_AutoPackLoad                                          */   
/*                                                                      */  
/* Parameters:                                                          */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/************************************************************************/  
  
CREATE PROC [dbo].[isp_GenUCCLabelNo_SVW] (  
   @cStorerKey NVARCHAR( 15),  
   @cLabelNo   NVARCHAR( 20) OUTPUT,   
   @b_success  int OUTPUT,  
   @n_err      int OUTPUT,  
   @c_errmsg   NVARCHAR(225) OUTPUT  
)  
AS  
BEGIN  
  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
  DECLARE    
   @cIdentifier    NVARCHAR( 2),  
   @cPacktype      NVARCHAR( 1),  
   @cSUSR1         NVARCHAR( 20),  
   @c_nCounter     NVARCHAR( 25),  
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
   @nEven          INT  
  
  SELECT @b_success = 1, @c_errmsg='', @n_err=0   
  
   IF EXISTS (SELECT 1 FROM StorerConfig WITH (NOLOCK)  
      WHERE StorerKey = @cStorerKey  
         AND ConfigKey = 'GenUCCLabelNoConfig'  
         AND SValue = '1')  
   BEGIN  
     SET @cIdentifier = '00'  
    SET @cPacktype = '0'    
     SET @cLabelNo = ''  
  
    SELECT @cSUSR1 = ISNULL(SUSR1, '0')  
    FROM Storer WITH (NOLOCK)  
    WHERE Storerkey = @cStorerkey  
    AND Type = '1'  
  
    IF LEN(@cSUSR1) >= 9   
     BEGIN  
       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 60201     
       SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Invalid part barcode. (isp_GenUCCLabelNo_SVW)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
       SELECT @b_success = 0  
      GOTO Quit  
     END   
  
    EXEC isp_getucckey  
   @cStorerkey,  
   9,  
   @c_nCounter OUTPUT ,  
   @b_success  OUTPUT,  
   @n_err      OUTPUT,  
   @c_errmsg   OUTPUT,  
   0,  
   1  
  
    IF LEN(@cSUSR1) <> 8   
         SELECT @cSUSR1 = RIGHT('0000000' + CAST(@cSUSR1 AS NVARCHAR( 7)), 7)  
  
    SET @cLabelNo = @cIdentifier + @cPacktype + RTRIM(@cSUSR1) + RTRIM(@c_nCounter) --+ @nCheckDigit  
  
    SET @nOdd = 1  
     SET @nOddCnt = 0  
     SET @nTotalOddCnt = 0  
     SET @nTotalCnt = 0  
  
     WHILE @nOdd <= 20   
     BEGIN  
	     SET @nOddCnt = CAST(SUBSTRING(@cLabelNo, @nOdd, 1) AS INT)  
	     SET @nTotalOddCnt = @nTotalOddCnt + @nOddCnt  
	     SET @nOdd = @nOdd + 2  
     END  
  
    SET @nTotalCnt = (@nTotalOddCnt * 3)   
   
    SET @nEven = 2  
     SET @nEvenCnt = 0  
     SET @nTotalEvenCnt = 0  
  
    WHILE @nEven <= 20   
    BEGIN  
    	SET @nEvenCnt = CAST(SUBSTRING(@cLabelNo, @nEven, 1) AS INT)  
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
  
  select @cLabelNo
           
   END  
   Quit:  
  
END

GO