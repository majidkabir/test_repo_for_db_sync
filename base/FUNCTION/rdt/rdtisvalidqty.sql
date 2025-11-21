SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdtIsValidQTY                                       */
/* Creation Date  : 2006-05-21                                          */
/* Copyright      : IDS                                                 */
/* Written By     : dhung                                               */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 20-Apr-2010  1.1  James      Change @cValue to 10 char (james01)     */
/* 02-Feb-2011  1.2  James      Add in checking for decimal (james02)   */
/* 21-Apr-2011  1.3  James      Cater for decimal checking ON/OFF       */
/*                              2 is used to indicate decimal checking  */
/*                              20 = check decimal but not check 0 qty  */
/*                              21 = check decimal & 0 qty (james03)    */
/* 14-Mar-2012  1.4  Ung        Fix 21 not check for 0 QTY              */
/* 22-May-2015  1.5  Ung        Fix some char pass thru IsNumeric check */
/* 16-Nov-2016  1.6  Ung        Fix int string larger then int range    */
/* 18-Nov-2016  1.7  ChewKP     Fix value contain special character     */
/*                              e.g , (ChewKP01)                        */
/* 21-Nov-2016  1.8  James      Fix empty space in variable (james04)   */
/* 22-Dec-2016  1.9  James      Perf tune, remove LTRIM/RTRIM (james05) */
/************************************************************************/

CREATE FUNCTION [RDT].[rdtIsValidQTY]( 
   @cValue NVARCHAR( 10),    -- expression to be checked  (james01)
   @iChkForZeroQTY INT = 1 -- 0=not check for 0 QTY, 1=check for 0 QTY
) RETURNS INT AS -- 0=false, 1=true
BEGIN
   DECLARE @iChkForDecimal        NVARCHAR(1)--INT

   SET @iChkForDecimal = 0


   -- If check decimal & check for 0 qty
   IF @iChkForZeroQTY = 20
   BEGIN
      SET @iChkForZeroQTY = 0
      SET @iChkForDecimal = 1
   END
   ELSE IF @iChkForZeroQTY = 21
   BEGIN
      SET @iChkForZeroQTY = 1
      SET @iChkForDecimal = 1
   END
   ELSE
   BEGIN
      SET @iChkForDecimal = 0
   END

   -- Paremeter checking
   IF @iChkForZeroQTY <> 0 AND @iChkForZeroQTY <> 1
      SET @iChkForZeroQTY = 1

   -- Validate QTY is numeric or blank
   -- Note: scientific notation (e, d), currency symbol, decimal symbol, digit grouping symbol etc still pass thru
   IF IsNumeric( @cValue) = 0
      GOTO Fail

   -- Validate QTY is integer including negative (just in case we have '-0')
   DECLARE @i INT
   DECLARE @c NVARCHAR(1)
   DECLARE @nLen INT
   
   SET @i = 1
   SET @cValue = LTRIM( RTRIM( @cValue))     -- (james05)
   SET @nLen =  LEN( @cValue)                -- (james04) 
   
   WHILE @i <= @nLen
   BEGIN
      SET @c =  SUBSTRING( @cValue, @i, 1)  -- (james04)/(james05)
      IF NOT ((@c >= '0' AND @c <= '9') OR @c = '-') 
      BEGIN
         IF @iChkForDecimal = 1 AND @c = '.'
         BEGIN
            SET @c = @c -- Do nothing
         END
         ELSE
            GOTO Fail
      END
      SET @i = @i + 1
   END

   IF @nLen = 10
   BEGIN
      IF @cValue > '2147483647'
         GOTO Fail
   END

   -- Validate -ve and 0 qty
   IF @iChkForDecimal = 0 
   BEGIN
      -- (ChewKP01) 
      IF TRY_PARSE(@cValue AS INT ) IS NULL 
         GOTO FAIL
         
      -- Validate negative QTY
      IF CAST( @cValue AS INT) < 0
         GOTO FAIL

      -- Validate 0 QTY
      IF @iChkForZeroQTY = 1 AND CAST( @cValue AS INT) = 0
         GOTO FAIL
   END

   IF @iChkForDecimal = 1 
   BEGIN
      -- (ChewKP01) 
      IF TRY_PARSE(@cValue AS FLOAT ) IS NULL 
         GOTO FAIL
         
      -- Validate negative QTY
      IF CAST( @cValue AS FLOAT) < 0 
         GOTO FAIL

      -- Validate 0 QTY
      IF @iChkForZeroQTY = 1 AND CAST( @cValue AS FLOAT) = 0
         GOTO FAIL
   END

   RETURN 1 -- true
Fail:
   RETURN 0 -- false
END

GO