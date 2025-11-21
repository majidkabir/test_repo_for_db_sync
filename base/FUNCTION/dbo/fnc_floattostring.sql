SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Function:  fnc_FloatToString                                         */
/* Creation Date: 15-Jul-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose: Convert Float to string                                     */
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
/* Date         Author    Ver.  Purposes                                */
/* 30-Jul-2010  Audrey    1.0   SOS181713 - Change length from 20 to 15 */
/* 18-May-2011  ChewKP    1.1   Add Grant Statement (ChewKP01)          */
/************************************************************************/

Create FUNCTION [dbo].[fnc_FloatToString] ( 
   @n_Number  FLOAT,
   @n_RoundDec INT
) RETURNS NVARCHAR(15) AS
BEGIN  
  
  SET QUOTED_IDENTIFIER OFF
  
  DECLARE @c_RtnNum NVARCHAR(15)

  SELECT @c_RtnNum = RTRIM(LTRIM(REVERSE(SUBSTRING(Truncatenumstr ,PATINDEX('%[^.]%' ,Truncatenumstr) ,15))))
  FROM   (
              SELECT SUBSTRING(Revnumstr ,PATINDEX('%[^0]%' ,Revnumstr) ,15) AS Truncatenumstr
              FROM   (
                         SELECT REVERSE(STR(@n_Number ,15 ,@n_RoundDec)) AS Revnumstr
                     ) Rev
          ) Trunc
                        
  RETURN RIGHT(SPACE(15) + ISNULL(@c_RtnNum,'0.00'),15)
END

GO