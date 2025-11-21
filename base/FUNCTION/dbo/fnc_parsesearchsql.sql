SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: fnc_ParseSearchSQL                                  */                                                                                  
/* Creation Date: 2023-05-25                                            */                                                                                  
/* Copyright: Maersk                                                    */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-4184- PROD - CN Lululemon ECOM Combine Order function  */
/*          issues                                                      */
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.0                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */  
/* 2023-05-25  Wan      1.0   Created & Devops Conbine Script           */
/************************************************************************/       
CREATE   FUNCTION [dbo].[fnc_ParseSearchSQL]
(
   @c_SearchSQL   NVARCHAR(MAX)
,  @c_SelectSQL   NVARCHAR(1000)      
)
RETURNS NVARCHAR(MAX)  
AS
BEGIN   
 
   DECLARE @n_POS_From        INT   = 0    
         , @n_POS_To          INT   = 0
         , @n_LEN_To          INT   = 0 
         
         , @c_ParseSearchSQL  NVARCHAR(MAX) =  ''

   SET @c_ParseSearchSQL =  ''
   
   SET @n_POS_From =  CHARINDEX(' FROM ', @c_SearchSQL, 1)                                       
   IF @n_POS_From = 0
   BEGIN
      GOTO EXIT_FUNCTION 
   END

   SET @n_POS_To = CHARINDEX('OFFSET', @c_SearchSQL, 1)
  
   IF @n_POS_To = 0
   BEGIN
      SET @n_LEN_To = LEN(@c_SearchSQL) - @n_POS_From
   END
   ELSE IF @n_POS_To > 0
   BEGIN
      SET @n_LEN_To = @n_POS_To - @n_POS_From - 1
   END
   
   SET @c_ParseSearchSQL = @c_SelectSQL + ' '
                         + SUBSTRING(@c_SearchSQL, @n_POS_From, @n_LEN_To + 1)    
   EXIT_FUNCTION:   
   RETURN @c_ParseSearchSQL
END   

GO