SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER ON;
GO
/******************************************************************************/    
/* Function: fnc_WrapText                                                     */    
/* Creation Date: 29-MAY-2014                                                 */    
/* Copyright: IDS                                                             */    
/* Written by: YTWan                                                          */    
/*                                                                            */    
/* Purpose:                                                                   */    
/*                                                                            */    
/* Input Parameters: data, noofchar                                           */    
/*                                                                            */    
/* OUTPUT Parameters: newdata                                                 */    
/*                                                                            */    
/* Return Status: NONE                                                        */    
/*                                                                            */    
/* Usage:                                                                     */    
/*                                                                            */    
/* Local Variables:                                                           */    
/*                                                                            */    
/* Called By: When Retrieve Records                                           */    
/*                                                                            */    
/* PVCS Version: 1.13                                                         */    
/*                                                                            */    
/* Version: 5.4                                                               */    
/* Data Modifications:                                                        */    
/*                                                                            */    
/* Updates:                                                                   */    
/* Date         Author     Ver   Purposes                                     */    
/******************************************************************************/    

CREATE FUNCTION [dbo].[fnc_WrapText] (@c_Data NVARCHAR(4000), @n_NoOfChar INT)  
RETURNS NVARCHAR(4000)
AS  
BEGIN
   DECLARE @n_No           INT
         , @n_StartPos     INT
         , @n_Length       INT
         , @b_InsSpace     INT
         , @c_OriginalData NVARCHAR(MAX)  
         , @c_NewData      NVARCHAR(MAX)  
           
         , @c_CR           CHAR(1)

   --For Debug - START
   --declare  @c_Data nvarchar(4000), @n_NoOfChar int
   --SET @c_Data = 'maddalena.cerello@accenture.com' + CHAR(13) + 'wanyunntsu@gmail.com'
   --SET @n_NoOfChar = 17
   --For Debug - END

   SET @c_OriginalData = @c_Data
   SET @c_NewData      = ''
   SET @c_CR = CHAR(13)
--   SET @c_Data = REPLACE(@c_Data, @c_CR, ' ')
/*
   SET @n_No = 0
   SET @n_StartPos = 0

   SET @n_Length = 0
   SET @c_NewData = ''
   WHILE @n_No < FLOOR(LEN(@c_Data)/@n_NoOfChar) AND
         (LEN(@c_Data) % @n_NoOfChar) > 0
   BEGIN
      SET @n_No = @n_No + 1   
      SET @n_StartPos = @n_Length + 1
      SET @n_Length = @n_NoOfChar * @n_No
  
      SET @c_NewData = @c_NewData + SUBSTRING(@c_Data, @n_StartPos, @n_Length) + ' '
   END

   SET @n_StartPos = @n_Length + 1
   SET @n_Length = LEN(@c_Data) - (@n_StartPos - 1)
   RETURN @c_NewData
*/

            
   IF @c_Data IS NULL OR @c_Data = ''
   BEGIN
      SET @c_NewData = @c_Data
      GOTO QUIT_FNC
   END

   SET @n_No = 0
   SET @n_StartPos = 1
   SET @n_Length = 0
   SET @b_InsSpace = 0
   WHILE @n_No < LEN(@c_Data)
   BEGIN
      SET @n_No = @n_No + 1   

      SET @n_Length = @n_Length + 1
  
      IF SUBSTRING(@c_Data, @n_No, 1) = @c_CR
      BEGIN
         SET @b_InsSpace = 1
      END

      IF @n_Length = @n_NoOfChar  
      BEGIN
         SET @b_InsSpace = 1
      END

      IF @b_InsSpace = 1
      BEGIN
         SET @c_NewData = @c_NewData + SUBSTRING(@c_Data, @n_StartPos, @n_Length) 

         IF @n_Length = @n_NoOfChar AND
            SUBSTRING(@c_Data,@n_No, 1) <> ' ' AND
            SUBSTRING(@c_Data,@n_No + 1, 1) <> ' ' 
         BEGIN
            SET @c_NewData = @c_NewData + ' '
         END

         SET @n_StartPos = @n_StartPos + @n_Length
         SET @n_Length = 0
         SET @b_InsSpace = 0
      END
      NEXT_CHR:
   END
  
   SET @c_NewData = @c_NewData + SUBSTRING(@c_Data, @n_StartPos, @n_Length)

   QUIT_FNC:
   RETURN @c_NewData -- CONVERT(VARCHAR(10),LEN(@c_Data))
END


GO