SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: ispParseParameters                                 */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: To parse StockTake parameters                               */
/*                                                                      */
/* Called By: ispGenCountSheet                                          */
/*                                                                      */
/* PVCS Version: 1.6                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 30-Oct-2001  Shong      Inclease the length of the variable NIKE     */
/*                         having problem because the SKU length is 20  */
/*                         char plus the "" will equal to 22 char, which*/
/*                         the last char was truncated.                 */
/* 02-Nov-2001  Shong      Include the variable length of @c_object..to */
/*                         125                                          */
/* 03-Jan-2003  Shong      SOS# 9193 Bug Fixing                         */
/*                         -- System Return AND () When Paramater =     */
/*                            "ULV -10"                                 */
/*                         -- Consider "SPACE" in the Parameter         */
/* 10-Jan-2003  Shong      Add new Feature: Support Like Statement..    */
/*                         For E.g. Must input Parameter: LIKE "JDH%"   */
/* 16-Jun-2003  Wally      S0S11783 Fixed handling of BETWEEN           */
/* 09-Nov-2005  MaryVong   SOS42806 Increase length of @c_Result1 and   */
/*                         @c_Result2 to NVARCHAR(800)                  */
/* 10-Nov-2005  Shong      Replace '~' to ' '                           */
/* 04-May-2016  Wan01      SOS#366947: SG-Stocktake LocationRoom Parm   */
/* 24-NOV-2016  Wan02      WMS-648 - Fixed                              */
/************************************************************************/

CREATE PROC [dbo].[ispParseParameters] (
@c_Parameters NVARCHAR(125),
@c_ColumnType NVARCHAR(10),
@c_ColumnName NVARCHAR(50),      --(Wan01)  -- Extend variable length to 50
@c_Result1 NVARCHAR(800) OUTPUT, -- SOS42806 Changed NVARCHAR(255) to NVARCHAR(800)
@c_Result2 NVARCHAR(800) OUTPUT, -- SOS42806 Changed NVARCHAR(255) to NVARCHAR(800)
@n_success  int OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @n_position int,
           @n_pos2     int,
           @c_object   NVARCHAR(125),
           @c_object2  NVARCHAR(125),
           @c_object3  NVARCHAR(125),
           @b_FirstObj int,
           @n_TypeString int

   IF dbo.fnc_RTrim(@c_Parameters) = '' OR @c_Parameters IS NULL 
      RETURN

   IF dbo.fnc_RTrim(@c_Parameters) = 'ALL' 
      RETURN

   IF LEFT(dbo.fnc_LTrim(@c_Parameters),5)  = 'LIKE '
   BEGIN
      SELECT @c_Result1 = ' AND (' + dbo.fnc_RTrim(@c_ColumnName) + ' ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Parameters)) + ')'
      RETURN 
   END

   SELECT @b_FirstObj = 1
   SELECT @n_TypeString = 1
   -- SELECT @c_Result1 = dbo.fnc_RTrim(@c_ColumnName) + ' IN ('
   -- Remark by June 29.Oct.02
   -- SELECT @c_Result2 = dbo.fnc_RTrim(@c_ColumnName) + ' BETWEEN ' 
   
   IF (CHARINDEX(',', @c_Parameters, 1) = 0 AND CHARINDEX('-', @c_Parameters, 1) = 0)
   AND LEN(@c_Parameters) > 0
   BEGIN
      IF dbo.fnc_RTrim(@c_Parameters) = 'ALL' 
         SELECT @c_Result1 = ''
      ELSE
      BEGIN
         -- Start - Add by June 11.Mar.02 FBR063
         IF (CHARINDEX('*', @c_Parameters, 1) > 0)
         BEGIN
            SELECT @c_Parameters = SUBSTRING(@c_Parameters, 1, CHARINDEX('*', @c_Parameters, 1) - 1) + '%'
            SELECT @c_Result1 = CASE WHEN @c_ColumnType = 'STRING' 
                                     THEN dbo.fnc_RTrim(@c_ColumnName) + ' LIKE N''' + dbo.fnc_RTrim(@c_Parameters) + ''''
                                     WHEN @c_ColumnType = 'NUMBER'   
                                     THEN dbo.fnc_RTrim(@c_ColumnName) + ' LIKE ' + dbo.fnc_RTrim(@c_Parameters) 
                                END
         END
         ELSE
         BEGIN
            IF (CHARINDEX('?', @c_Parameters, 1) > 0)
            BEGIN
               SELECT @c_Parameters = SUBSTRING(@c_Parameters, 1, CHARINDEX('?', @c_Parameters, 1) - 1) + '_'
               SELECT @c_Result1 = CASE WHEN @c_ColumnType = 'STRING' 
                                        THEN dbo.fnc_RTrim(@c_ColumnName) + ' LIKE N''' + dbo.fnc_RTrim(@c_Parameters) + ''''
                                        WHEN @c_ColumnType = 'NUMBER'   
                                        THEN dbo.fnc_RTrim(@c_ColumnName) + ' LIKE ' + dbo.fnc_RTrim(@c_Parameters) 
                                   END
            END
            ELSE
            -- End - Add by June 11.Mar.02 FBR063
            BEGIN
               SELECT @c_Result1 = CASE WHEN @c_ColumnType = 'STRING' 
                                        THEN dbo.fnc_RTrim(@c_ColumnName) + ' = N''' + dbo.fnc_RTrim(@c_Parameters) + ''''
                                        WHEN @c_ColumnType = 'NUMBER'   
                                        THEN dbo.fnc_RTrim(@c_ColumnName) + ' = ' + dbo.fnc_RTrim(@c_Parameters) 
                                   END
            END
         END
      END   
      SELECT @c_Result2 = ''
   END
   ELSE
   BEGIN
 DECLARE @c_Char NVARCHAR(1),
              @n_Pos  int,
              @c_OpenQuote NVARCHAR(1),
              @c_StartCol  NVARCHAR(20),
              @c_PrevSign  NVARCHAR(1)

      SELECT @c_object = '' , @c_object2 = '', @c_object3 = ''   
      SELECT @n_TypeString = 0
      SELECT @c_Parameters = dbo.fnc_RTrim(@c_Parameters)
      SELECT @c_OpenQuote = ''
      SELECT @c_StartCol = ''

      SELECT @n_Pos = 1
      WHILE @n_Pos <= LEN(dbo.fnc_RTrim(@c_Parameters)) 
      BEGIN
         SELECT @c_Char = SubString(@c_Parameters, @n_Pos, 1)
         IF ((@c_Char = "-" OR @c_Char = ',' ) AND (dbo.fnc_RTrim(@c_OpenQuote) IS NULL OR dbo.fnc_RTrim(@c_OpenQuote) = '')) 
         BEGIN  
            SELECT @c_Object = CASE WHEN @c_ColumnType = 'STRING' 
                                     THEN 'N''' + dbo.fnc_RTrim(@c_Object) + ''''
                                     WHEN @c_ColumnType = 'NUMBER'   
                                     THEN dbo.fnc_RTrim(@c_Object) 
                                END
            IF @c_Char = "-" OR @c_PrevSign = "-"
            BEGIN
               IF dbo.fnc_RTrim(@c_StartCol) IS NULL OR dbo.fnc_RTrim(@c_StartCol) = ''
               BEGIN
--                   SELECT @c_Result1 = ' ' + dbo.fnc_RTrim(@c_ColumnName) +  dbo.fnc_RTrim(@c_Result1) + ' BETWEEN ' 
--                                       + dbo.fnc_RTrim(@c_Object) + ' AND '
                  select @c_object = replace(@c_object, '"~', '"')
                  if len(dbo.fnc_RTrim(@c_result1)) > 0
                     SELECT @c_Result1 = dbo.fnc_RTrim(@c_Result1) + ' OR ' + dbo.fnc_RTrim(@c_columnname) + ' BETWEEN ' 
                                      + dbo.fnc_RTrim(@c_Object) + ' AND '
                  else
                     SELECT @c_Result1 = ' ' + dbo.fnc_RTrim(@c_ColumnName) + ' BETWEEN ' + dbo.fnc_RTrim(@c_Object) + ' AND '
                    
                  SELECT @c_StartCol = @c_Object
               END
               ELSE
               BEGIN
                  SELECT @c_Result1 = dbo.fnc_RTrim(@c_Result1) + ' ' + dbo.fnc_RTrim(@c_Object)
                  SELECT @c_StartCol = ''
               END
            END
            ELSE
            IF @c_Char = "," 
            BEGIN
               -- Added by Shong on 10-Nov-2005 
               SELECT @c_Object = REPLACE(@c_Object, '~', ' ')               
               
               IF @c_PrevSign = ',' 
                  SELECT @c_Result1 = dbo.fnc_RTrim(@c_Result1) + ' OR ' + dbo.fnc_RTrim(@c_ColumnName) + ' = ' + dbo.fnc_RTrim(@c_Object)
               ELSE 
                  SELECT @c_Result1 = dbo.fnc_RTrim(@c_Result1) + dbo.fnc_RTrim(@c_ColumnName) + ' = ' + dbo.fnc_RTrim(@c_Object)
            END
            SELECT @c_PrevSign = @c_Char
            SELECT @c_object = ''
         END
         ELSE
         BEGIN
            IF @c_Char = "'" OR @c_Char = '"'
            BEGIN
               IF @c_Char = @c_OpenQuote 
               BEGIN
                  -- SELECT @c_Object = dbo.fnc_RTrim(@c_Object) + @c_Char
                  SELECT @c_OpenQuote = ''
                  SELECT @c_Object = dbo.fnc_RTrim(@c_Object)
               END
               ELSE
               BEGIN
                  SELECT @c_OpenQuote = @c_Char                  
               END
            END 
            ELSE
            BEGIN
               -- 03-Jan-2002 By SHONG
               -- Use ~ indicate SPACE 
               IF @c_Char = SPACE(1)
                  SELECT @c_Char = '~'

               SELECT @c_Object = dbo.fnc_RTrim(@c_Object) + @c_Char
            END
            
         END
         -- Print @c_Object
         SELECT @n_Pos = @n_Pos + 1
      END -- While

      -- 03-Jan-2002 By SHONG
      -- Replace ~ back to SPACE
      --SELECT @c_Object = REPLACE(@c_Object, '~', ' ')  --(Wan02)

      IF @c_ColumnType = 'STRING' 
         SELECT @c_Object = 'N''' + dbo.fnc_RTrim(@c_Object) + ''''
      

      IF @c_PrevSign = "-" 
      BEGIN
         SELECT @c_Result1 = dbo.fnc_RTrim(@c_Result1) + " " + dbo.fnc_RTrim(@c_Object)
      END
      ELSE IF @c_PrevSign = "," 
         BEGIN
            SELECT @c_Result1 = dbo.fnc_RTrim(@c_Result1) + ' OR ' + dbo.fnc_RTrim(@c_ColumnName) + ' = ' + dbo.fnc_RTrim(@c_Object)
         END
      ELSE
      -- Added By SHONG -- SOS# 9193 Bug Fixing 
      -- System Return AND () When Paramater = "ULV -10" 
      BEGIN
         SELECT @c_Result1 = dbo.fnc_RTrim(@c_ColumnName) + ' = ' + dbo.fnc_RTrim(@c_Object)
      END 
   END
         
   SELECT @c_result1 = ' AND (' + dbo.fnc_RTrim(@c_result1) + ')'

   --(Wan02) - START
   WHILE CHARINDEX('~', @c_Result1) > 0
   BEGIN
      SET @c_Result1 = REPLACE(@c_Result1, '~', ' ')
   END
   --(Wan02) - END
END

GO