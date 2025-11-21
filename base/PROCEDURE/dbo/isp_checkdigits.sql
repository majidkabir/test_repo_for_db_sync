SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_CheckDigits   	 					            */
/* Creation Date: 31-Jul-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: GT Goh                                                   */
/*                                                                      */
/* Purpose: Get Check Digit Number                         	            */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 19-Apr-2010	NJOW01 	1.1   Change @inum from numeric to bigint to    */
/*                            cater more than 18 digits label no. Fix   */
/*                            check digit result if 10 then should rtn 0*/
/* 27-Jul-2010  NJOW02  1.2   change inum param type from bigint to num */
/************************************************************************/


CREATE PROC [dbo].[isp_CheckDigits] 
   @inum numeric(38,0), --NJOW01
	@onum int OUTPUT

AS
BEGIN 
	SET NOCOUNT ON;
	SET QUOTED_IDENTIFIER OFF 
	SET ANSI_NULLS OFF 

	Declare @gtot int, @i int, @len int
	Declare @odd int, @even int
			
	Set @len = Len(LTRIM(RTRIM(@inum)))
	SET @i = 1
	SET @odd = 0

    While @i <= @len
	BEGIN
		Set @odd = @odd + LEFT(RIGHT(RTRIM(@inum),@i),1) 
		Set @i = @i + 2
	END 
		
		Set @odd = @odd * 3

	SET @i = 2
	SET @even = 0

    While @i <= @len
	BEGIN
		Set @even = @even + LEFT(RIGHT(RTRIM(@inum),@i),1) 
		Set @i = @i + 2
	END 

	Set @gtot = @odd + @even
	Set @onum = 10 - LEFT(RIGHT(RTRIM(@gtot),1),1)
	
	IF @onum = 10  --NJOW01
	   SET @onum = 0

END  

SET QUOTED_IDENTIFIER OFF 

GO