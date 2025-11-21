SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GenUPSTrackNo                                  */
/* Creation Date: 10-May-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: 320415-Container# validation ISO 6346                       */
/*                                                                      */
/* Called By: finalize ASN                                              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispRCCHK04]
   @c_ReceiptKey       NVARCHAR(10),
   @b_Success          INT = 1  OUTPUT,
   @n_ErrNo            INT = 0  OUTPUT,
   @c_Errmsg           NVARCHAR(250) = '' OUTPUT,
   @c_ReceiptLineNumber  NVARCHAR(5) = ''     
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @c_Containerkey NVARCHAR(18),
           @n_Continue INT,
           @n_LenCnt INT,
           @n_Pos INT,
           @n_ConvNum INT,
           @n_MultiplyNum INT,
           @c_Char NCHAR(1),
           @n_Total INT,
           @n_CheckDigit INT
   
   SELECT @b_Success = 1, @n_ErrNo = 0, @c_Errmsg = '', @n_Continue = 1
   
   SELECT @c_Containerkey = ISNULL(Containerkey,'')
   FROM RECEIPT (NOLOCK)
   WHERE Receiptkey = @c_Receiptkey
   
   SET @n_LenCnt = LEN(RTRIM(ISNULL(@c_Containerkey,''))) 
   
   IF @n_LenCnt <> 11
      GOTO EXIT_SP
                     
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN   	  
   	  SET @n_Pos = 1
   	  SET @n_Total = 0
   	  WHILE @n_Pos <= (@n_LenCnt - 1) -- Exclude check digit
   	  BEGIN
   	  	 SET @c_Char = SUBSTRING(@c_Containerkey,@n_Pos,1)
   	  	 
   	  	 IF ASCII(@c_Char) >= 97 AND ASCII(@c_Char) <= 122
   	  	 BEGIN
      	    SELECT @n_continue = 3
            SELECT @n_errno = 75851
            SELECT @c_errmsg = 'Invalid Container#. Lower Case Is Not Allowed(ispRCCHK04)' 
            SELECT @b_Success = 0
            GOTO EXIT_SP
   	  	 END
   	  	 
   	  	 SELECT @n_ConvNum = CASE @c_Char
   	  	                        WHEN 'A' THEN 10
   	  	                        WHEN 'B' THEN 12
   	  	                        WHEN 'C' THEN 13
   	  	                        WHEN 'D' THEN 14
   	  	                        WHEN 'E' THEN 15
   	  	                        WHEN 'F' THEN 16
   	  	                        WHEN 'G' THEN 17
   	  	                        WHEN 'H' THEN 18
   	  	                        WHEN 'I' THEN 19
   	  	                        WHEN 'J' THEN 20
   	  	                        WHEN 'K' THEN 21
   	  	                        WHEN 'L' THEN 23
   	  	                        WHEN 'M' THEN 24
   	  	                        WHEN 'N' THEN 25
   	  	                        WHEN 'O' THEN 26
   	  	                        WHEN 'P' THEN 27
   	  	                        WHEN 'Q' THEN 28
   	  	                        WHEN 'R' THEN 29
   	  	                        WHEN 'S' THEN 30
   	  	                        WHEN 'T' THEN 31
   	  	                        WHEN 'U' THEN 32
   	  	                        WHEN 'V' THEN 34
   	  	                        WHEN 'W' THEN 35
   	  	                        WHEN 'X' THEN 36
   	  	                        WHEN 'Y' THEN 37
   	  	                        WHEN 'Z' THEN 38
   	  	                        ELSE CAST(@c_Char AS INT)
   	  	                     END
   	  	                     
         SELECT @n_MultiplyNum = @n_ConvNum * POWER(2, @n_Pos - 1)
         
         SELECT @n_Total = @n_Total + @n_MultiplyNum                           
   	  	 
   	  	 SET @n_Pos = @n_Pos + 1
   	  END 
   	  
   	  SELECT @n_checkdigit = @n_Total - (CAST(@n_Total / 11 AS INT) * 11)
   	  
   	  IF @n_checkdigit = 10 
   	     SET @n_checkdigit = 0   	   	
   	     
      IF CAST(SUBSTRING(@c_Containerkey,11,1) AS INT) <> @n_checkdigit
      BEGIN
      	 SELECT @n_continue = 3
         SELECT @n_errno = 75852
         SELECT @c_errmsg = 'Invalid Container# Check Digit(ispRCCHK04)' 
         SELECT @b_Success = 0
      END
   END
   
   EXIT_SP:  
END

GO