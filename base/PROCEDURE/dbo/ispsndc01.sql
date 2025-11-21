SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: ispSNDC01                                          */  
/* Creation Date: 03-MAR-2021                                           */  
/* Copyright: LFL                                                       */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-16407 - TH Nuskin serial number decode                  */  
/*                                                                      */  
/* Called By: isp_SerialNoDecode_Wrapper                                */  
/*            storerconfig: SerialNoDecode_SP                           */
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/   

CREATE PROCEDURE [dbo].[ispSNDC01]
   @c_Pickslipno       NVARCHAR(10),
   @c_Storerkey        NVARCHAR(15),
   @c_Sku              NVARCHAR(20),
   @c_SerialNo         NVARCHAR(200),
   @c_NewSerialNo      NVARCHAR(50)     OUTPUT,
   @c_Code01           NVARCHAR(60) = '' OUTPUT,
   @c_Code02           NVARCHAR(60) = '' OUTPUT,
   @c_Code03           NVARCHAR(60) = '' OUTPUT,
   @b_Success          INT      OUTPUT,
   @n_Err              INT      OUTPUT, 
   @c_ErrMsg           NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = ''  
   
   DECLARE @n_Foundpos INT,
           @n_LastFoundpos INT
   
   SET @n_Foundpos = 0
   SET @n_LastFoundpos = 0

   WHILE 1=1
   BEGIN
   	  SELECT @n_Foundpos = CHARINDEX('/', @c_SerialNo, @n_Foundpos + 1)
   	  
   	  IF @n_Foundpos > 0 
   	     SET @n_LastFoundpos = @n_Foundpos
   	  ELSE
   	     BREAK     	  
   END 
   
   IF @n_LastFoundpos > 0
   	  SELECT @c_NewSerialNo = SUBSTRING(@c_SerialNo, @n_LastFoundpos + 1, LEN(@c_SerialNo) - @n_LastFoundpos)
   ELSE
      SELECT @c_NewSerialNo = @c_SerialNo
   
   IF LEN(@c_NewSerialNo) = 0
   BEGIN
   	  SELECT @b_Success = 0
      SELECT @n_Err = 31100 
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
              ': Wrong format, please re-check (ispSNDC01)'  
      
      SET @c_NewSerialNo = ''        
   END
   ELSE IF LEN(@c_NewSerialNo) > 30
   BEGIN
   	  SELECT @b_Success = 0
      SELECT @n_Err = 31100 
      SELECT @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + 
              ': Serial Number Over Length 30 (ispSNDC01)'  
      
      SET @c_NewSerialNo = ''        
   END   
         
END -- End Procedure

GO