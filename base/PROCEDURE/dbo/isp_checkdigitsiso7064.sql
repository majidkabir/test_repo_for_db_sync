SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_CheckDigitsISO7064   	 					         */
/* Creation Date: 14-Jul-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: AQSACM                                                   */
/*                                                                      */
/* Purpose: Get Check Digit barcode string Using ISO 7064 Mod 37,36     */
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
/* 02-Sep_2010  James   1.1   Change pass in parameter length (james01) */
/************************************************************************/

CREATE PROC [dbo].[isp_CheckDigitsISO7064] 
   @iChar NVARCHAR(27), -- (james01)
	@b_success int OUTPUT,
	@oChar NVARCHAR(1) OUTPUT
AS
BEGIN 
	SET NOCOUNT ON;
	SET QUOTED_IDENTIFIER OFF 
	SET ANSI_NULLS OFF 

	Declare @i_V int, @i_Cd int
	Declare @i_CharLen int, @i int, @i_CharCheck NVARCHAR(1)
	Declare @n_debug int

   SET @i_V = 0
   SET @i_Cd = 36
   SET @b_success = 1
   SET @n_debug = 0
   SET @oChar = ''

   SET @i_CharLen = Len(LTRIM(RTRIM(@iChar)))
	SET @i = 1

   While @i <= @i_CharLen
	BEGIN
      SET @i_V = 0
      SET @i_CharCheck = ''

      SET @i_CharCheck = RIGHT(LEFT(RTRIM(@iChar),@i),1) 

      SET @i_V = ascii(@i_CharCheck)

      IF @i_V >= 48 AND @i_V <= 57
         SET @i_V = @i_V - 48
      ELSE IF @i_V >= 65 AND @i_V <= 90
         SET @i_V = @i_V - 55
      ELSE  --Fail
      BEGIN        
         SET @b_success = 0
         GOTO CHECK_FAIL
      END

      SET @i_Cd = @i_Cd + @i_V
      IF @i_Cd > 36
         SET @i_Cd = @i_Cd - 36

      SET @i_Cd = @i_Cd * 2
 
      IF @i_Cd > 36
         SET @i_Cd = @i_Cd - 37

		Set @i = @i + 1
	END 

   SET @i_Cd =  37 - @i_Cd
   IF @i_Cd = 36
      SET @i_Cd = 0

   IF @i_Cd > 9
      SET @i_Cd = @i_Cd + 55
   ELSE
      SET @i_Cd = @i_Cd + 48


   CHECK_FAIL:
   IF @b_success = 0
      SET @oChar = ''
   ELSE
      SET @oChar = master.dbo.fnc_GetCharASCII(@i_Cd)

   IF @n_debug = 1
      SELECT '@iChar=',@iChar,'@i_Cd=',@i_Cd,'@b_success=',@b_success,'@oChar=',@oChar

END  

GO